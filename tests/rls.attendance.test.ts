/**
 * Phase 4 attendance RLS gate (doc 06 Phase 4): admin marks anything; the class
 * teacher marks DAILY for their section; the subject teacher marks THEIR subject
 * in their section; nobody else can; parents read only their own child. Runs
 * against local Supabase.
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
const DATE = "2025-09-01";

type Ctx = {
  schoolId: string;
  sectionA: string;
  sectionB: string;
  mathId: string;
  studentA1: string; // in section A, parent P's child
  studentB1: string; // in section B
  classTeacher: SupabaseClient; // class teacher of section A
  subjectTeacher: SupabaseClient; // teaches Math in section A
  parent: SupabaseClient; // guardian of studentA1
  adminClient: SupabaseClient;
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
  const { data: school } = await admin.from("schools").insert({ name: `Att ${rand()}` }).select().single();
  ctx.schoolId = school!.id;
  const { data: year } = await admin
    .from("academic_years")
    .insert({ school_id: ctx.schoolId, name: "Y", start_date: "2025-06-01", end_date: "2026-04-30", is_active: true })
    .select().single();
  const { data: klass } = await admin.from("classes").insert({ school_id: ctx.schoolId, name: "Grade 1" }).select().single();
  const { data: secA } = await admin.from("sections").insert({ school_id: ctx.schoolId, class_id: klass!.id, name: "A", academic_year_id: year!.id }).select().single();
  const { data: secB } = await admin.from("sections").insert({ school_id: ctx.schoolId, class_id: klass!.id, name: "B", academic_year_id: year!.id }).select().single();
  ctx.sectionA = secA!.id;
  ctx.sectionB = secB!.id;
  const { data: math } = await admin.from("subjects").insert({ school_id: ctx.schoolId, name: "Math" }).select().single();
  ctx.mathId = math!.id;
  await admin.from("class_subjects").insert({ school_id: ctx.schoolId, class_id: klass!.id, subject_id: ctx.mathId });

  const adminId = await makeUser(`admin.${rand()}@t.local`);
  const ctId = await makeUser(`ct.${rand()}@t.local`);
  const stId = await makeUser(`st.${rand()}@t.local`);
  const parentId = await makeUser(`parent.${rand()}@t.local`);
  await admin.from("school_members").insert([
    { school_id: ctx.schoolId, user_id: adminId, role: "school_admin", status: "active" },
    { school_id: ctx.schoolId, user_id: ctId, role: "teacher", status: "active" },
    { school_id: ctx.schoolId, user_id: stId, role: "teacher", status: "active" },
    { school_id: ctx.schoolId, user_id: parentId, role: "parent", status: "active" },
  ]);

  // students + enrollments
  const { data: s1 } = await admin.from("students").insert({ school_id: ctx.schoolId, admission_no: `A1-${rand()}`, first_name: "A1" }).select().single();
  const { data: s2 } = await admin.from("students").insert({ school_id: ctx.schoolId, admission_no: `B1-${rand()}`, first_name: "B1" }).select().single();
  ctx.studentA1 = s1!.id;
  ctx.studentB1 = s2!.id;
  await admin.from("enrollments").insert([
    { school_id: ctx.schoolId, student_id: ctx.studentA1, section_id: ctx.sectionA, academic_year_id: year!.id },
    { school_id: ctx.schoolId, student_id: ctx.studentB1, section_id: ctx.sectionB, academic_year_id: year!.id },
  ]);
  await admin.from("student_guardians").insert({ school_id: ctx.schoolId, student_id: ctx.studentA1, guardian_user_id: parentId, relation: "mother", is_primary: true });

  // roles: ct = class teacher of A ; st = Math teacher in A
  const { data: ctStaff } = await admin.from("staff").select("id").eq("user_id", ctId).single();
  const { data: stStaff } = await admin.from("staff").select("id").eq("user_id", stId).single();
  await admin.from("sections").update({ class_teacher_staff_id: ctStaff!.id }).eq("id", ctx.sectionA);
  await admin.from("teacher_assignments").insert({ school_id: ctx.schoolId, staff_id: stStaff!.id, section_id: ctx.sectionA, subject_id: ctx.mathId, academic_year_id: year!.id });

  ctx.adminClient = await signIn(await emailOf(adminId));
  ctx.classTeacher = await signIn(await emailOf(ctId));
  ctx.subjectTeacher = await signIn(await emailOf(stId));
  ctx.parent = await signIn(await emailOf(parentId));
});

afterAll(async () => {
  await admin.from("schools").delete().eq("id", ctx.schoolId);
});

const daily = (studentId: string, sectionId: string) => ({
  school_id: ctx.schoolId, student_id: studentId, section_id: sectionId, date: DATE, subject_id: null, status: "present" as const,
});
const subject = (studentId: string, sectionId: string, subjectId: string) => ({
  school_id: ctx.schoolId, student_id: studentId, section_id: sectionId, date: DATE, subject_id: subjectId, status: "present" as const,
});

describe("Phase 4 RLS: attendance", () => {
  test("class teacher CAN mark DAILY attendance for their section", async () => {
    const { error } = await ctx.classTeacher.from("attendance").insert(daily(ctx.studentA1, ctx.sectionA));
    expect(error).toBeNull();
  });

  test("class teacher CANNOT mark daily for a section they don't class-teach", async () => {
    const { error } = await ctx.classTeacher.from("attendance").insert(daily(ctx.studentB1, ctx.sectionB));
    expect(error).not.toBeNull();
  });

  test("class teacher CANNOT mark subject attendance (not the subject teacher)", async () => {
    const { error } = await ctx.classTeacher.from("attendance").insert(subject(ctx.studentA1, ctx.sectionA, ctx.mathId));
    expect(error).not.toBeNull();
  });

  test("subject teacher CAN mark THEIR subject in their section", async () => {
    const { error } = await ctx.subjectTeacher.from("attendance").insert(subject(ctx.studentA1, ctx.sectionA, ctx.mathId));
    expect(error).toBeNull();
  });

  test("subject teacher CANNOT mark daily attendance", async () => {
    const { error } = await ctx.subjectTeacher.from("attendance").insert(daily(ctx.studentA1, ctx.sectionA));
    expect(error).not.toBeNull();
  });

  test("admin CAN mark both daily and subject attendance", async () => {
    const { error: e1 } = await ctx.adminClient.from("attendance").insert(daily(ctx.studentB1, ctx.sectionB));
    const { error: e2 } = await ctx.adminClient.from("attendance").insert(subject(ctx.studentB1, ctx.sectionB, ctx.mathId));
    expect(e1).toBeNull();
    expect(e2).toBeNull();
  });

  test("parent sees ONLY their own child's attendance", async () => {
    const { data } = await ctx.parent.from("attendance").select("student_id");
    const ids = new Set((data ?? []).map((r) => r.student_id));
    expect(ids.has(ctx.studentA1)).toBe(true);
    expect(ids.has(ctx.studentB1)).toBe(false);
  });
});
