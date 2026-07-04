/**
 * Phase 5 homework RLS gate (doc 06 Phase 5): admin, the section's class teacher
 * (any subject), and the assigned subject teacher may post homework; nobody else
 * can; a parent reads homework only for their child's section. Local Supabase.
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
const DUE = "2025-12-01";

type Ctx = {
  schoolId: string;
  sectionA: string;
  sectionB: string;
  mathId: string;
  sciId: string;
  classTeacher: SupabaseClient; // class teacher of A
  subjectTeacher: SupabaseClient; // teaches Math in A
  parent: SupabaseClient; // child in A
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
  const { data: school } = await admin.from("schools").insert({ name: `HW ${rand()}` }).select().single();
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
  const { data: sci } = await admin.from("subjects").insert({ school_id: ctx.schoolId, name: "Sci" }).select().single();
  ctx.mathId = math!.id;
  ctx.sciId = sci!.id;
  await admin.from("class_subjects").insert([
    { school_id: ctx.schoolId, class_id: klass!.id, subject_id: ctx.mathId },
    { school_id: ctx.schoolId, class_id: klass!.id, subject_id: ctx.sciId },
  ]);

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

  const { data: kid } = await admin.from("students").insert({ school_id: ctx.schoolId, admission_no: `A1-${rand()}`, first_name: "Kid" }).select().single();
  await admin.from("enrollments").insert({ school_id: ctx.schoolId, student_id: kid!.id, section_id: ctx.sectionA, academic_year_id: year!.id });
  await admin.from("student_guardians").insert({ school_id: ctx.schoolId, student_id: kid!.id, guardian_user_id: parentId, relation: "mother", is_primary: true });

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

const hw = (sectionId: string, subjectId: string, title: string) => ({
  school_id: ctx.schoolId, section_id: sectionId, subject_id: subjectId, title, due_date: DUE,
});

describe("Phase 5 RLS: homework", () => {
  test("class teacher CAN post homework for their section (any subject)", async () => {
    const { error } = await ctx.classTeacher.from("homework").insert(hw(ctx.sectionA, ctx.sciId, "CT Sci"));
    expect(error).toBeNull();
  });

  test("class teacher CANNOT post for a section they don't class-teach", async () => {
    const { error } = await ctx.classTeacher.from("homework").insert(hw(ctx.sectionB, ctx.mathId, "CT B"));
    expect(error).not.toBeNull();
  });

  test("subject teacher CAN post for their subject in their section", async () => {
    const { error } = await ctx.subjectTeacher.from("homework").insert(hw(ctx.sectionA, ctx.mathId, "ST Math"));
    expect(error).toBeNull();
  });

  test("subject teacher CANNOT post for a subject they don't teach", async () => {
    const { error } = await ctx.subjectTeacher.from("homework").insert(hw(ctx.sectionA, ctx.sciId, "ST Sci"));
    expect(error).not.toBeNull();
  });

  test("admin CAN post for any section/subject", async () => {
    const { error } = await ctx.adminClient.from("homework").insert(hw(ctx.sectionB, ctx.sciId, "Admin B"));
    expect(error).toBeNull();
  });

  test("parent reads homework for their child's section, not other sections", async () => {
    const { data } = await ctx.parent.from("homework").select("section_id");
    const sections = new Set((data ?? []).map((r) => r.section_id));
    expect(sections.has(ctx.sectionA)).toBe(true); // child's section
    expect(sections.has(ctx.sectionB)).toBe(false); // not their child's
  });

  test("parent CANNOT post homework", async () => {
    const { error } = await ctx.parent.from("homework").insert(hw(ctx.sectionA, ctx.mathId, "Parent hack"));
    expect(error).not.toBeNull();
  });
});
