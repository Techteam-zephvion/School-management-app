/**
 * Phase 12 gate (doc 06 Phase 12): audit logs are written by triggers and read
 * only by the school's admin (or platform admin); a platform admin can create a
 * school (RLS) while a normal user cannot; audit rows don't leak across schools.
 * Local Supabase.
 */
import { beforeAll, afterAll, describe, expect, test } from "vitest";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { config } from "dotenv";

config({ path: ".env.local" });

const URL = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const ANON = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;
const SERVICE = process.env.SUPABASE_SERVICE_ROLE_KEY!;
const admin = createClient(URL, SERVICE, { auth: { autoRefreshToken: false, persistSession: false } });
const rand = () => Math.random().toString(36).slice(2, 8);

type Ctx = {
  schoolAId: string;
  schoolBId: string;
  invoiceAId: string;
  adminA: SupabaseClient; // admin of A
  adminB: SupabaseClient; // admin of B
  platform: SupabaseClient; // is_platform_admin
};
const ctx = {} as Ctx;

async function makeUser(email: string, platform = false) {
  const { data, error } = await admin.auth.admin.createUser({ email, password: "password123", email_confirm: true });
  if (error) throw error;
  if (platform) await admin.from("profiles").update({ is_platform_admin: true }).eq("id", data.user.id);
  return data.user.id;
}
async function signIn(email: string) {
  const c = createClient(URL, ANON, { auth: { autoRefreshToken: false, persistSession: false } });
  const { error } = await c.auth.signInWithPassword({ email, password: "password123" });
  if (error) throw error;
  return c;
}
const emailOf = async (id: string) => (await admin.auth.admin.getUserById(id)).data.user!.email!;

beforeAll(async () => {
  const { data: sa } = await admin.from("schools").insert({ name: `PA ${rand()}` }).select().single();
  const { data: sb } = await admin.from("schools").insert({ name: `PB ${rand()}` }).select().single();
  ctx.schoolAId = sa!.id;
  ctx.schoolBId = sb!.id;
  const { data: year } = await admin.from("academic_years").insert({ school_id: ctx.schoolAId, name: "Y", start_date: "2025-06-01", end_date: "2026-04-30", is_active: true }).select().single();

  const adminAId = await makeUser(`admin.a.${rand()}@t.local`);
  const adminBId = await makeUser(`admin.b.${rand()}@t.local`);
  const platformId = await makeUser(`platform.${rand()}@t.local`, true);
  await admin.from("school_members").insert([
    { school_id: ctx.schoolAId, user_id: adminAId, role: "school_admin", status: "active" },
    { school_id: ctx.schoolBId, user_id: adminBId, role: "school_admin", status: "active" },
  ]);

  // a student + fee structure + invoice in A, so a payment can be audited
  const { data: stu } = await admin.from("students").insert({ school_id: ctx.schoolAId, admission_no: `A1-${rand()}`, first_name: "A1" }).select().single();
  const { data: fs } = await admin.from("fee_structures").insert({ school_id: ctx.schoolAId, academic_year_id: year!.id, name: "Fee", due_date: "2027-01-01" }).select().single();
  await admin.from("fee_items").insert({ school_id: ctx.schoolAId, fee_structure_id: fs!.id, label: "Tuition", amount: 1000 });
  const { data: inv } = await admin.from("invoices").insert({ school_id: ctx.schoolAId, student_id: stu!.id, fee_structure_id: fs!.id, amount_total: 1000, due_date: "2027-01-01" }).select().single();
  ctx.invoiceAId = inv!.id;

  ctx.adminA = await signIn(await emailOf(adminAId));
  ctx.adminB = await signIn(await emailOf(adminBId));
  ctx.platform = await signIn(await emailOf(platformId));
});

afterAll(async () => {
  await admin.from("schools").delete().eq("id", ctx.schoolAId);
  await admin.from("schools").delete().eq("id", ctx.schoolBId);
});

describe("Phase 12: audit logs + platform", () => {
  test("recording a payment writes an audit log the school admin can read", async () => {
    const { error } = await ctx.adminA.from("payments").insert({ school_id: ctx.schoolAId, invoice_id: ctx.invoiceAId, amount: 500, method: "cash", status: "captured" });
    expect(error).toBeNull();
    const { data } = await ctx.adminA.from("audit_logs").select("action, entity").eq("action", "payment_recorded");
    expect((data ?? []).length).toBeGreaterThanOrEqual(1);
  });

  test("another school's admin cannot read School A's audit logs", async () => {
    const { data } = await ctx.adminB.from("audit_logs").select("id").eq("school_id", ctx.schoolAId);
    expect(data ?? []).toHaveLength(0);
  });

  test("a platform admin can read audit logs across schools", async () => {
    const { data } = await ctx.platform.from("audit_logs").select("id").eq("school_id", ctx.schoolAId);
    expect((data ?? []).length).toBeGreaterThanOrEqual(1);
  });

  test("a platform admin can create a school; a school admin cannot", async () => {
    const { error: platErr } = await ctx.platform.from("schools").insert({ name: `New ${rand()}` }).select();
    expect(platErr).toBeNull();

    const { error: adminErr } = await ctx.adminA.from("schools").insert({ name: `Sneaky ${rand()}` }).select();
    expect(adminErr).not.toBeNull();
  });

  test("deleting a school cascades all its data; a school admin cannot delete", async () => {
    // school admin cannot delete their own school
    await ctx.adminA.from("schools").delete().eq("id", ctx.schoolAId);
    const { data: still } = await admin.from("schools").select("id").eq("id", ctx.schoolAId);
    expect(still ?? []).toHaveLength(1);

    // create a throwaway school with a student, then delete via service role (as
    // the platform action does) and confirm the student is gone (cascade)
    const { data: tmp } = await admin.from("schools").insert({ name: `Tmp ${rand()}`, status: "suspended" }).select().single();
    const { data: stu } = await admin.from("students").insert({ school_id: tmp!.id, admission_no: `T-${rand()}`, first_name: "Tmp" }).select().single();
    await admin.from("schools").delete().eq("id", tmp!.id);
    const { data: goneSchool } = await admin.from("schools").select("id").eq("id", tmp!.id);
    const { data: goneStudent } = await admin.from("students").select("id").eq("id", stu!.id);
    expect(goneSchool ?? []).toHaveLength(0);
    expect(goneStudent ?? []).toHaveLength(0); // cascaded
  });

  test("a platform admin can suspend a school; a school admin cannot touch another school", async () => {
    const { error } = await ctx.platform.from("schools").update({ status: "suspended" }).eq("id", ctx.schoolBId);
    expect(error).toBeNull();
    const { data: check } = await admin.from("schools").select("status").eq("id", ctx.schoolBId).single();
    expect(check!.status).toBe("suspended");

    // school A admin cannot change school B
    await ctx.adminA.from("schools").update({ name: "hacked" }).eq("id", ctx.schoolBId);
    const { data: b } = await admin.from("schools").select("name").eq("id", ctx.schoolBId).single();
    expect(b!.name).not.toBe("hacked");
  });
});
