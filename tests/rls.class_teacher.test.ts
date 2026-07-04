/**
 * Class-teacher student-add gate (user request): a class teacher can create
 * students and enrol them ONLY into a section they are the class teacher of.
 * Enforced by 0008 policies students_insert_class_teacher /
 * enrollments_insert_class_teacher. Runs against local Supabase.
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
  ownSectionId: string; // teacher is class teacher of this
  otherSectionId: string; // teacher is NOT
  yearId: string;
  teacher: SupabaseClient; // class teacher of ownSection
  plainTeacher: SupabaseClient; // a teacher who is NOT a class teacher
};
const ctx = {} as Ctx;

async function makeUser(email: string, password: string) {
  const { data, error } = await admin.auth.admin.createUser({ email, password, email_confirm: true });
  if (error) throw error;
  return data.user.id;
}
async function signIn(email: string, password: string) {
  const c = createClient(URL, ANON, { auth: { autoRefreshToken: false, persistSession: false } });
  const { error } = await c.auth.signInWithPassword({ email, password });
  if (error) throw error;
  return c;
}

beforeAll(async () => {
  const pw = "password123";
  const { data: school } = await admin.from("schools").insert({ name: `CT ${rand()}` }).select().single();
  ctx.schoolId = school!.id;

  const adminId = await makeUser(`admin.${rand()}@t.local`, pw);
  const teacherId = await makeUser(`teacher.${rand()}@t.local`, pw);
  const plainId = await makeUser(`plain.${rand()}@t.local`, pw);
  await admin.from("school_members").insert([
    { school_id: ctx.schoolId, user_id: adminId, role: "school_admin", status: "active" },
    { school_id: ctx.schoolId, user_id: teacherId, role: "teacher", status: "active" },
    { school_id: ctx.schoolId, user_id: plainId, role: "teacher", status: "active" },
  ]);

  const { data: year } = await admin
    .from("academic_years")
    .insert({ school_id: ctx.schoolId, name: "Y", start_date: "2025-06-01", end_date: "2026-04-30", is_active: true })
    .select().single();
  ctx.yearId = year!.id;
  const { data: klass } = await admin.from("classes").insert({ school_id: ctx.schoolId, name: "Grade 1" }).select().single();
  const { data: own } = await admin
    .from("sections")
    .insert({ school_id: ctx.schoolId, class_id: klass!.id, name: "A", academic_year_id: year!.id })
    .select().single();
  const { data: other } = await admin
    .from("sections")
    .insert({ school_id: ctx.schoolId, class_id: klass!.id, name: "B", academic_year_id: year!.id })
    .select().single();
  ctx.ownSectionId = own!.id;
  ctx.otherSectionId = other!.id;

  // Make `teacher` the class teacher of section A (via their auto-created staff row).
  const { data: staff } = await admin
    .from("staff").select("id").eq("school_id", ctx.schoolId).eq("user_id", teacherId).single();
  await admin.from("sections").update({ class_teacher_staff_id: staff!.id }).eq("id", ctx.ownSectionId);

  ctx.teacher = await signIn((await admin.auth.admin.getUserById(teacherId)).data.user!.email!, pw);
  ctx.plainTeacher = await signIn((await admin.auth.admin.getUserById(plainId)).data.user!.email!, pw);
});

afterAll(async () => {
  await admin.from("schools").delete().eq("id", ctx.schoolId);
});

async function insertStudent(client: SupabaseClient) {
  return client
    .from("students")
    .insert({ school_id: ctx.schoolId, admission_no: `ADM-${rand()}`, first_name: "Kid" })
    .select("id")
    .single();
}

describe("Class-teacher student add", () => {
  test("class teacher CAN create a student + enrol into their OWN section", async () => {
    const { data: student, error } = await insertStudent(ctx.teacher);
    expect(error).toBeNull();
    const { error: enrErr } = await ctx.teacher.from("enrollments").insert({
      school_id: ctx.schoolId,
      student_id: student!.id,
      section_id: ctx.ownSectionId,
      academic_year_id: ctx.yearId,
    });
    expect(enrErr).toBeNull();
  });

  test("class teacher CANNOT enrol into a section they don't class-teach", async () => {
    const { data: student } = await insertStudent(ctx.teacher);
    const { error } = await ctx.teacher.from("enrollments").insert({
      school_id: ctx.schoolId,
      student_id: student!.id,
      section_id: ctx.otherSectionId,
      academic_year_id: ctx.yearId,
    });
    expect(error).not.toBeNull();
  });

  test("a teacher who is NOT a class teacher CANNOT create a student", async () => {
    const { error } = await insertStudent(ctx.plainTeacher);
    expect(error).not.toBeNull();
  });

  test("class teacher CANNOT update/delete students (admin-only)", async () => {
    const { data: student } = await insertStudent(ctx.teacher);
    // RLS filters the row out of the write scope, so delete/update affect 0 rows
    // (no error, but nothing changes) -- verify the row survives untouched.
    await ctx.teacher.from("students").delete().eq("id", student!.id);
    await ctx.teacher.from("students").update({ first_name: "Hacked" }).eq("id", student!.id);
    const { data: still } = await admin
      .from("students")
      .select("first_name")
      .eq("id", student!.id)
      .maybeSingle();
    expect(still).not.toBeNull(); // survived the delete
    expect(still!.first_name).toBe("Kid"); // survived the update
  });
});
