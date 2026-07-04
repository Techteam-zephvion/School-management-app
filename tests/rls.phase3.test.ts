/**
 * Phase 3 RLS gate (doc 06 Phase 3, doc 05 §12): a parent sees exactly their
 * own children (my_children()) and nothing else; staff read/write their school's
 * students; cross-school access is denied. Runs against local Supabase.
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
const rand = () => Math.random().toString(36).slice(2, 8);

type Ctx = {
  schoolAId: string;
  schoolBId: string;
  studentA1: string; // parent P1's child
  studentA2: string; // another School A student, NOT P1's
  adminA: SupabaseClient;
  teacherA: SupabaseClient;
  parentP1: SupabaseClient;
  adminB: SupabaseClient;
};
const ctx = {} as Ctx;

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
  const pw = "password123";
  const { data: sa } = await admin.from("schools").insert({ name: `A ${rand()}` }).select().single();
  const { data: sb } = await admin.from("schools").insert({ name: `B ${rand()}` }).select().single();
  ctx.schoolAId = sa!.id;
  ctx.schoolBId = sb!.id;

  const adminAId = await makeUser(`admin.a.${rand()}@t.local`, pw);
  const teacherAId = await makeUser(`teacher.a.${rand()}@t.local`, pw);
  const p1Id = await makeUser(`parent1.${rand()}@t.local`, pw);
  const adminBId = await makeUser(`admin.b.${rand()}@t.local`, pw);
  await admin.from("school_members").insert([
    { school_id: ctx.schoolAId, user_id: adminAId, role: "school_admin", status: "active" },
    { school_id: ctx.schoolAId, user_id: teacherAId, role: "teacher", status: "active" },
    { school_id: ctx.schoolAId, user_id: p1Id, role: "parent", status: "active" },
    { school_id: ctx.schoolBId, user_id: adminBId, role: "school_admin", status: "active" },
  ]);

  const { data: st1 } = await admin
    .from("students")
    .insert({ school_id: ctx.schoolAId, admission_no: `A1-${rand()}`, first_name: "Child", last_name: "One" })
    .select()
    .single();
  const { data: st2 } = await admin
    .from("students")
    .insert({ school_id: ctx.schoolAId, admission_no: `A2-${rand()}`, first_name: "Child", last_name: "Two" })
    .select()
    .single();
  ctx.studentA1 = st1!.id;
  ctx.studentA2 = st2!.id;

  // Link P1 to student A1 only.
  await admin.from("student_guardians").insert({
    school_id: ctx.schoolAId,
    student_id: ctx.studentA1,
    guardian_user_id: p1Id,
    relation: "mother",
    is_primary: true,
  });

  ctx.adminA = await signIn((await admin.auth.admin.getUserById(adminAId)).data.user!.email!, pw);
  ctx.teacherA = await signIn((await admin.auth.admin.getUserById(teacherAId)).data.user!.email!, pw);
  ctx.parentP1 = await signIn((await admin.auth.admin.getUserById(p1Id)).data.user!.email!, pw);
  ctx.adminB = await signIn((await admin.auth.admin.getUserById(adminBId)).data.user!.email!, pw);
});

afterAll(async () => {
  await admin.from("schools").delete().eq("id", ctx.schoolAId);
  await admin.from("schools").delete().eq("id", ctx.schoolBId);
});

describe("Phase 3 RLS: students & guardians", () => {
  test("staff (teacher) of School A read all its students", async () => {
    const { data } = await ctx.teacherA.from("students").select("id").eq("school_id", ctx.schoolAId);
    expect((data ?? []).length).toBe(2);
  });

  test("parent P1 sees ONLY their child (my_children)", async () => {
    const { data } = await ctx.parentP1.from("students").select("id");
    const ids = (data ?? []).map((s) => s.id);
    expect(ids).toContain(ctx.studentA1);
    expect(ids).not.toContain(ctx.studentA2);
    expect(ids).toHaveLength(1);
  });

  test("parent P1 CANNOT read the other School A student directly", async () => {
    const { data } = await ctx.parentP1.from("students").select("id").eq("id", ctx.studentA2);
    expect(data ?? []).toHaveLength(0);
  });

  test("parent P1 CANNOT create a student (staff-only write)", async () => {
    const { error } = await ctx.parentP1
      .from("students")
      .insert({ school_id: ctx.schoolAId, admission_no: `HACK-${rand()}`, first_name: "No" })
      .select();
    expect(error).not.toBeNull();
  });

  test("School B admin sees ZERO of School A's students", async () => {
    const { data } = await ctx.adminB.from("students").select("id").eq("school_id", ctx.schoolAId);
    expect(data ?? []).toHaveLength(0);
  });

  test("School A admin CAN create a student; parent P1 still can't see it", async () => {
    const { data: created, error } = await ctx.adminA
      .from("students")
      .insert({ school_id: ctx.schoolAId, admission_no: `A3-${rand()}`, first_name: "Child", last_name: "Three" })
      .select()
      .single();
    expect(error).toBeNull();
    const { data: seen } = await ctx.parentP1.from("students").select("id").eq("id", created!.id);
    expect(seen ?? []).toHaveLength(0);
  });

  test("parent P1 reads their child's enrollment but not others", async () => {
    // give A1 and A2 enrollments via admin
    const { data: year } = await admin
      .from("academic_years")
      .insert({ school_id: ctx.schoolAId, name: "Y", start_date: "2025-06-01", end_date: "2026-04-30", is_active: true })
      .select()
      .single();
    const { data: klass } = await admin
      .from("classes")
      .insert({ school_id: ctx.schoolAId, name: "Grade 1" })
      .select()
      .single();
    const { data: section } = await admin
      .from("sections")
      .insert({ school_id: ctx.schoolAId, class_id: klass!.id, name: "A", academic_year_id: year!.id })
      .select()
      .single();
    await admin.from("enrollments").insert([
      { school_id: ctx.schoolAId, student_id: ctx.studentA1, section_id: section!.id, academic_year_id: year!.id },
      { school_id: ctx.schoolAId, student_id: ctx.studentA2, section_id: section!.id, academic_year_id: year!.id },
    ]);

    const { data } = await ctx.parentP1.from("enrollments").select("student_id");
    const ids = (data ?? []).map((e) => e.student_id);
    expect(ids).toContain(ctx.studentA1);
    expect(ids).not.toContain(ctx.studentA2);
  });
});
