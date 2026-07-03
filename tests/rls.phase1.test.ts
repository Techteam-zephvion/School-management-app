/**
 * Phase 1 critical RLS gate (doc 06 Phase 1 "Gate", doc 05 §12 rules):
 * a user from School B must get 0 rows from School A, and cross-school
 * writes must be denied. Runs against the local Supabase stack -- start it
 * with `supabase start` before running `npm run test:rls`.
 */
import { beforeAll, afterAll, describe, expect, test } from "vitest";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { config } from "dotenv";

config({ path: ".env.local" });

const URL = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const ANON = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;
const SERVICE = process.env.SUPABASE_SERVICE_ROLE_KEY!;

const admin = createClient(URL, SERVICE, {
  auth: { autoRefreshToken: false, persistSession: false },
});

type Ctx = {
  schoolAId: string;
  schoolBId: string;
  adminAEmail: string;
  parentBEmail: string;
  password: string;
  clientA: SupabaseClient; // school_admin of School A
  clientB: SupabaseClient; // parent of School B
};

const ctx = {} as Ctx;
const rand = () => Math.random().toString(36).slice(2, 8);

async function makeUser(email: string, password: string) {
  const { data, error } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
  });
  if (error) throw error;
  return data.user.id;
}

async function signIn(email: string, password: string) {
  const client = createClient(URL, ANON, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { error } = await client.auth.signInWithPassword({ email, password });
  if (error) throw error;
  return client;
}

beforeAll(async () => {
  ctx.password = "password123";
  ctx.adminAEmail = `admin.a.${rand()}@test.local`;
  ctx.parentBEmail = `parent.b.${rand()}@test.local`;

  // Two isolated schools.
  const { data: schoolA } = await admin
    .from("schools")
    .insert({ name: `School A ${rand()}` })
    .select()
    .single();
  const { data: schoolB } = await admin
    .from("schools")
    .insert({ name: `School B ${rand()}` })
    .select()
    .single();
  ctx.schoolAId = schoolA!.id;
  ctx.schoolBId = schoolB!.id;

  // School A gets an active academic year (the row we'll try to leak to B).
  await admin.from("academic_years").insert({
    school_id: ctx.schoolAId,
    name: "2025-26",
    start_date: "2025-06-01",
    end_date: "2026-04-30",
    is_active: true,
  });

  // Users + memberships.
  const adminAId = await makeUser(ctx.adminAEmail, ctx.password);
  const parentBId = await makeUser(ctx.parentBEmail, ctx.password);
  await admin.from("school_members").insert([
    { school_id: ctx.schoolAId, user_id: adminAId, role: "school_admin", status: "active" },
    { school_id: ctx.schoolBId, user_id: parentBId, role: "parent", status: "active" },
  ]);

  ctx.clientA = await signIn(ctx.adminAEmail, ctx.password);
  ctx.clientB = await signIn(ctx.parentBEmail, ctx.password);
});

afterAll(async () => {
  await admin.from("schools").delete().eq("id", ctx.schoolAId);
  await admin.from("schools").delete().eq("id", ctx.schoolBId);
});

describe("Phase 1 RLS: cross-school isolation", () => {
  test("School A admin sees School A's academic year", async () => {
    const { data } = await ctx.clientA
      .from("academic_years")
      .select("*")
      .eq("school_id", ctx.schoolAId);
    expect(data?.length).toBe(1);
  });

  test("School B parent sees ZERO of School A's academic years", async () => {
    const { data } = await ctx.clientB
      .from("academic_years")
      .select("*")
      .eq("school_id", ctx.schoolAId);
    expect(data ?? []).toHaveLength(0);
  });

  test("School B parent sees ZERO of School A's schools row", async () => {
    const { data } = await ctx.clientB
      .from("schools")
      .select("*")
      .eq("id", ctx.schoolAId);
    expect(data ?? []).toHaveLength(0);
  });

  test("School B parent sees ZERO of School A's members", async () => {
    const { data } = await ctx.clientB
      .from("school_members")
      .select("*")
      .eq("school_id", ctx.schoolAId);
    expect(data ?? []).toHaveLength(0);
  });

  test("School B parent CANNOT write an academic year into School A", async () => {
    const { data, error } = await ctx.clientB
      .from("academic_years")
      .insert({
        school_id: ctx.schoolAId,
        name: "hacked",
        start_date: "2025-06-01",
        end_date: "2026-04-30",
        is_active: false,
      })
      .select();
    // RLS denies the insert -- either an error or zero rows returned.
    expect(error !== null || (data ?? []).length === 0).toBe(true);

    // Confirm nothing landed.
    const { data: check } = await admin
      .from("academic_years")
      .select("*")
      .eq("school_id", ctx.schoolAId)
      .eq("name", "hacked");
    expect(check ?? []).toHaveLength(0);
  });

  test("A parent (non-admin) CANNOT write staff-only rows in their own school", async () => {
    const { error } = await ctx.clientB
      .from("academic_years")
      .insert({
        school_id: ctx.schoolBId,
        name: "parent-should-not-do-this",
        start_date: "2025-06-01",
        end_date: "2026-04-30",
        is_active: false,
      })
      .select();
    const { data: check } = await admin
      .from("academic_years")
      .select("*")
      .eq("school_id", ctx.schoolBId);
    expect(check ?? []).toHaveLength(0);
    expect(error).not.toBeNull();
  });
});
