/**
 * Phase 8 fees RLS + logic gate (doc 06 Phase 8): invoice status transitions
 * unpaid -> partial -> paid (and overdue for a past-due invoice); a payment can
 * never exceed the balance; a parent reads only their own child's invoices;
 * only admins create fees/invoices/payments. Local Supabase.
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
  schoolId: string;
  structureId: string;
  studentA1: string;
  studentB1: string;
  adminClient: SupabaseClient;
  teacher: SupabaseClient;
  parent: SupabaseClient; // guardian of A1
};
const ctx = {} as Ctx;

async function makeUser(email: string) {
  const { data, error } = await admin.auth.admin.createUser({ email, password: "password123", email_confirm: true });
  if (error) throw error;
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
  const { data: school } = await admin.from("schools").insert({ name: `Fee ${rand()}` }).select().single();
  ctx.schoolId = school!.id;
  const { data: year } = await admin
    .from("academic_years")
    .insert({ school_id: ctx.schoolId, name: "Y", start_date: "2025-06-01", end_date: "2026-04-30", is_active: true })
    .select().single();
  const { data: klass } = await admin.from("classes").insert({ school_id: ctx.schoolId, name: "Grade 1" }).select().single();
  const { data: secA } = await admin.from("sections").insert({ school_id: ctx.schoolId, class_id: klass!.id, name: "A", academic_year_id: year!.id }).select().single();

  const adminId = await makeUser(`admin.${rand()}@t.local`);
  const teacherId = await makeUser(`teacher.${rand()}@t.local`);
  const parentId = await makeUser(`parent.${rand()}@t.local`);
  await admin.from("school_members").insert([
    { school_id: ctx.schoolId, user_id: adminId, role: "school_admin", status: "active" },
    { school_id: ctx.schoolId, user_id: teacherId, role: "teacher", status: "active" },
    { school_id: ctx.schoolId, user_id: parentId, role: "parent", status: "active" },
  ]);
  const { data: a1 } = await admin.from("students").insert({ school_id: ctx.schoolId, admission_no: `A1-${rand()}`, first_name: "A1" }).select().single();
  const { data: b1 } = await admin.from("students").insert({ school_id: ctx.schoolId, admission_no: `B1-${rand()}`, first_name: "B1" }).select().single();
  ctx.studentA1 = a1!.id;
  ctx.studentB1 = b1!.id;
  await admin.from("enrollments").insert([
    { school_id: ctx.schoolId, student_id: ctx.studentA1, section_id: secA!.id, academic_year_id: year!.id },
    { school_id: ctx.schoolId, student_id: ctx.studentB1, section_id: secA!.id, academic_year_id: year!.id },
  ]);
  await admin.from("student_guardians").insert({ school_id: ctx.schoolId, student_id: ctx.studentA1, guardian_user_id: parentId, relation: "mother", is_primary: true });

  // a structure with items totalling 5000
  const { data: structure } = await admin
    .from("fee_structures")
    .insert({ school_id: ctx.schoolId, academic_year_id: year!.id, name: "Term 1", due_date: "2025-12-01" })
    .select().single();
  ctx.structureId = structure!.id;
  await admin.from("fee_items").insert([
    { school_id: ctx.schoolId, fee_structure_id: ctx.structureId, label: "Tuition", amount: 4000 },
    { school_id: ctx.schoolId, fee_structure_id: ctx.structureId, label: "Transport", amount: 1000 },
  ]);

  ctx.adminClient = await signIn(await emailOf(adminId));
  ctx.teacher = await signIn(await emailOf(teacherId));
  ctx.parent = await signIn(await emailOf(parentId));
});

afterAll(async () => {
  await admin.from("schools").delete().eq("id", ctx.schoolId);
});

async function invoiceFor(studentId: string) {
  const { data } = await admin
    .from("invoices")
    .select("id, amount_total, amount_paid, status")
    .eq("student_id", studentId)
    .eq("fee_structure_id", ctx.structureId)
    .single();
  return data!;
}

describe("Phase 8: fees, invoices & payments", () => {
  test("structure total is the sum of its items", async () => {
    const { data } = await admin.from("fee_structures").select("total_amount").eq("id", ctx.structureId).single();
    expect(Number(data!.total_amount)).toBe(5000);
  });

  test("admin creates an invoice (unpaid); a teacher cannot", async () => {
    const { error: teacherErr } = await ctx.teacher
      .from("invoices")
      .insert({ school_id: ctx.schoolId, student_id: ctx.studentA1, fee_structure_id: ctx.structureId, amount_total: 5000, due_date: "2027-06-01" });
    expect(teacherErr).not.toBeNull();

    const { error } = await ctx.adminClient
      .from("invoices")
      .insert({ school_id: ctx.schoolId, student_id: ctx.studentA1, fee_structure_id: ctx.structureId, amount_total: 5000, due_date: "2027-06-01" });
    expect(error).toBeNull();
    const inv = await invoiceFor(ctx.studentA1);
    expect(inv.status).toBe("unpaid");
  });

  test("partial then full payment moves status unpaid -> partial -> paid", async () => {
    const inv = await invoiceFor(ctx.studentA1);
    await ctx.adminClient.from("payments").insert({ school_id: ctx.schoolId, invoice_id: inv.id, amount: 2000, method: "cash", status: "captured" });
    let after = await invoiceFor(ctx.studentA1);
    expect(Number(after.amount_paid)).toBe(2000);
    expect(after.status).toBe("partial");

    await ctx.adminClient.from("payments").insert({ school_id: ctx.schoolId, invoice_id: inv.id, amount: 3000, method: "upi", status: "captured" });
    after = await invoiceFor(ctx.studentA1);
    expect(Number(after.amount_paid)).toBe(5000);
    expect(after.status).toBe("paid");
  });

  test("a payment cannot exceed the remaining balance", async () => {
    // A1 is fully paid now -> any positive payment exceeds the 0 balance.
    const inv = await invoiceFor(ctx.studentA1);
    const { error } = await ctx.adminClient
      .from("payments")
      .insert({ school_id: ctx.schoolId, invoice_id: inv.id, amount: 100, method: "cash", status: "captured" });
    expect(error).not.toBeNull();
    expect(error!.message).toMatch(/exceeds the balance/i);
  });

  test("an invoice past its due date is overdue", async () => {
    const { data: inv } = await ctx.adminClient
      .from("invoices")
      .insert({ school_id: ctx.schoolId, student_id: ctx.studentB1, fee_structure_id: ctx.structureId, amount_total: 5000, due_date: "2020-01-01" })
      .select("status")
      .single();
    expect(inv!.status).toBe("overdue");
  });

  test("parent reads only their own child's invoice; cannot record a payment", async () => {
    const { data } = await ctx.parent.from("invoices").select("student_id");
    const ids = new Set((data ?? []).map((r) => r.student_id));
    expect(ids.has(ctx.studentA1)).toBe(true);
    expect(ids.has(ctx.studentB1)).toBe(false);

    const inv = await invoiceFor(ctx.studentA1);
    const { error } = await ctx.parent
      .from("payments")
      .insert({ school_id: ctx.schoolId, invoice_id: inv.id, amount: 1, method: "cash", status: "captured" });
    expect(error).not.toBeNull();
  });
});
