/**
 * Phase 7 exams/marks RLS gate (doc 06 Phase 7): the assigned subject teacher
 * (or admin) enters marks; marks are bounded by max (trigger) and graded; a
 * parent sees a child's marks ONLY once the term is published. Local Supabase.
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
  termId: string;
  examSubjectId: string;
  studentA1: string;
  subjectTeacher: SupabaseClient; // teaches Math in section A
  otherTeacher: SupabaseClient; // teaches nothing relevant
  parent: SupabaseClient; // guardian of A1
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
  const { data: school } = await admin.from("schools").insert({ name: `Exam ${rand()}` }).select().single();
  ctx.schoolId = school!.id;
  // default grade scale (migration backfills existing schools before this one existed)
  await admin.from("grade_scales").insert(
    [[90, 100, "A+"], [80, 89, "A"], [70, 79, "B+"], [60, 69, "B"], [50, 59, "C"], [40, 49, "D"], [0, 39, "F"]].map(
      ([min, max, label]) => ({ school_id: ctx.schoolId, min_percent: min, max_percent: max, grade_label: label })
    )
  );
  const { data: year } = await admin
    .from("academic_years")
    .insert({ school_id: ctx.schoolId, name: "Y", start_date: "2025-06-01", end_date: "2026-04-30", is_active: true })
    .select().single();
  const { data: klass } = await admin.from("classes").insert({ school_id: ctx.schoolId, name: "Grade 1" }).select().single();
  const { data: secA } = await admin.from("sections").insert({ school_id: ctx.schoolId, class_id: klass!.id, name: "A", academic_year_id: year!.id }).select().single();
  const { data: math } = await admin.from("subjects").insert({ school_id: ctx.schoolId, name: "Math" }).select().single();

  const adminId = await makeUser(`admin.${rand()}@t.local`);
  const stId = await makeUser(`st.${rand()}@t.local`);
  const otherId = await makeUser(`other.${rand()}@t.local`);
  const parentId = await makeUser(`parent.${rand()}@t.local`);
  await admin.from("school_members").insert([
    { school_id: ctx.schoolId, user_id: adminId, role: "school_admin", status: "active" },
    { school_id: ctx.schoolId, user_id: stId, role: "teacher", status: "active" },
    { school_id: ctx.schoolId, user_id: otherId, role: "teacher", status: "active" },
    { school_id: ctx.schoolId, user_id: parentId, role: "parent", status: "active" },
  ]);
  const { data: kid } = await admin.from("students").insert({ school_id: ctx.schoolId, admission_no: `A1-${rand()}`, first_name: "Kid" }).select().single();
  ctx.studentA1 = kid!.id;
  await admin.from("enrollments").insert({ school_id: ctx.schoolId, student_id: ctx.studentA1, section_id: secA!.id, academic_year_id: year!.id });
  await admin.from("student_guardians").insert({ school_id: ctx.schoolId, student_id: ctx.studentA1, guardian_user_id: parentId, relation: "mother", is_primary: true });

  const { data: stStaff } = await admin.from("staff").select("id").eq("user_id", stId).single();
  await admin.from("teacher_assignments").insert({ school_id: ctx.schoolId, staff_id: stStaff!.id, section_id: secA!.id, subject_id: math!.id, academic_year_id: year!.id });

  const { data: term } = await admin.from("exam_terms").insert({ school_id: ctx.schoolId, academic_year_id: year!.id, name: "Term 1" }).select().single();
  ctx.termId = term!.id;
  const { data: es } = await admin.from("exam_subjects").insert({ school_id: ctx.schoolId, term_id: ctx.termId, class_id: klass!.id, subject_id: math!.id, max_marks: 50 }).select().single();
  ctx.examSubjectId = es!.id;

  ctx.adminClient = await signIn(await emailOf(adminId));
  ctx.subjectTeacher = await signIn(await emailOf(stId));
  ctx.otherTeacher = await signIn(await emailOf(otherId));
  ctx.parent = await signIn(await emailOf(parentId));
});

afterAll(async () => {
  await admin.from("schools").delete().eq("id", ctx.schoolId);
});

const mark = (obtained: number) => ({
  school_id: ctx.schoolId, term_id: ctx.termId, exam_subject_id: ctx.examSubjectId, student_id: ctx.studentA1, marks_obtained: obtained,
});

describe("Phase 7 RLS: exams & marks", () => {
  test("subject teacher CAN enter marks; grade is computed", async () => {
    const { error } = await ctx.subjectTeacher.from("marks").upsert(mark(45), { onConflict: "exam_subject_id,student_id" });
    expect(error).toBeNull();
    // 45/50 = 90% -> A+
    const { data } = await admin.from("marks").select("grade").eq("exam_subject_id", ctx.examSubjectId).eq("student_id", ctx.studentA1).single();
    expect(data!.grade).toBe("A+");
  });

  test("marks above max are rejected by the bound trigger", async () => {
    const { error } = await ctx.subjectTeacher.from("marks").upsert(mark(60), { onConflict: "exam_subject_id,student_id" });
    expect(error).not.toBeNull();
    expect(error!.message).toMatch(/between 0 and 50/i);
  });

  test("a teacher NOT assigned the subject CANNOT enter marks", async () => {
    const { error } = await ctx.otherTeacher.from("marks").upsert(mark(30), { onConflict: "exam_subject_id,student_id" });
    expect(error).not.toBeNull();
  });

  test("parent CANNOT see marks while the term is unpublished", async () => {
    const { data } = await ctx.parent.from("marks").select("id").eq("student_id", ctx.studentA1);
    expect(data ?? []).toHaveLength(0);
  });

  test("parent CAN see the child's marks once published", async () => {
    await admin.from("exam_terms").update({ is_published: true, published_at: new Date().toISOString() }).eq("id", ctx.termId);
    const { data } = await ctx.parent.from("marks").select("marks_obtained, grade").eq("student_id", ctx.studentA1);
    expect((data ?? []).length).toBe(1);
    expect(data![0].grade).toBe("A+");
  });

  test("parent CANNOT enter marks", async () => {
    const { error } = await ctx.parent.from("marks").upsert(mark(10), { onConflict: "exam_subject_id,student_id" });
    expect(error).not.toBeNull();
  });
});
