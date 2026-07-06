/**
 * Phase 11 gate (doc 06 Phase 11): approving a leave auto-marks the student
 * 'excused' across the range; only the class teacher (or admin) may review; a
 * parent files for their own child; periods/events are members-read/staff-write.
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
  schoolId: string;
  yearId: string;
  sectionId: string;
  studentA1: string;
  classTeacher: SupabaseClient; // class teacher of the section
  otherTeacher: SupabaseClient; // not the class teacher
  parentA: SupabaseClient; // guardian of A1
  parentAId: string;
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
  const { data: school } = await admin.from("schools").insert({ name: `Leave ${rand()}` }).select().single();
  ctx.schoolId = school!.id;
  const { data: year } = await admin.from("academic_years").insert({ school_id: ctx.schoolId, name: "Y", start_date: "2025-06-01", end_date: "2026-04-30", is_active: true }).select().single();
  ctx.yearId = year!.id;
  const { data: klass } = await admin.from("classes").insert({ school_id: ctx.schoolId, name: "Grade 1" }).select().single();
  const { data: sec } = await admin.from("sections").insert({ school_id: ctx.schoolId, class_id: klass!.id, name: "A", academic_year_id: year!.id }).select().single();
  ctx.sectionId = sec!.id;

  const ctId = await makeUser(`ct.${rand()}@t.local`);
  const otherId = await makeUser(`other.${rand()}@t.local`);
  ctx.parentAId = await makeUser(`pa.${rand()}@t.local`);
  await admin.from("school_members").insert([
    { school_id: ctx.schoolId, user_id: ctId, role: "teacher", status: "active" },
    { school_id: ctx.schoolId, user_id: otherId, role: "teacher", status: "active" },
    { school_id: ctx.schoolId, user_id: ctx.parentAId, role: "parent", status: "active" },
  ]);
  const { data: a1 } = await admin.from("students").insert({ school_id: ctx.schoolId, admission_no: `A1-${rand()}`, first_name: "A1" }).select().single();
  ctx.studentA1 = a1!.id;
  await admin.from("enrollments").insert({ school_id: ctx.schoolId, student_id: ctx.studentA1, section_id: ctx.sectionId, academic_year_id: year!.id });
  await admin.from("student_guardians").insert({ school_id: ctx.schoolId, student_id: ctx.studentA1, guardian_user_id: ctx.parentAId, relation: "mother", is_primary: true });
  const { data: ctStaff } = await admin.from("staff").select("id").eq("user_id", ctId).single();
  await admin.from("sections").update({ class_teacher_staff_id: ctStaff!.id }).eq("id", ctx.sectionId);

  ctx.classTeacher = await signIn(await emailOf(ctId));
  ctx.otherTeacher = await signIn(await emailOf(otherId));
  ctx.parentA = await signIn(await emailOf(ctx.parentAId));
});

afterAll(async () => {
  await admin.from("schools").delete().eq("id", ctx.schoolId);
});

async function fileLeave(client: SupabaseClient, requestedBy: string, from = "2025-09-01", to = "2025-09-03") {
  return client
    .from("leave_requests")
    .insert({ school_id: ctx.schoolId, student_id: ctx.studentA1, requested_by: requestedBy, from_date: from, to_date: to, reason: "fever" })
    .select("id")
    .single();
}

describe("Phase 11: leave + calendar", () => {
  test("a parent files a leave for their own child", async () => {
    const { error } = await fileLeave(ctx.parentA, ctx.parentAId);
    expect(error).toBeNull();
  });

  test("a teacher who is NOT the class teacher cannot approve it", async () => {
    const { data: lr } = await admin.from("leave_requests").select("id").eq("student_id", ctx.studentA1).limit(1).single();
    await ctx.otherTeacher.from("leave_requests").update({ status: "approved" }).eq("id", lr!.id);
    const { data: after } = await admin.from("leave_requests").select("status").eq("id", lr!.id).single();
    expect(after!.status).toBe("pending"); // blocked by RLS -> unchanged
  });

  test("the class teacher approves -> attendance is marked excused for the range", async () => {
    const { data: lr } = await admin.from("leave_requests").select("id, from_date, to_date").eq("student_id", ctx.studentA1).limit(1).single();
    const { error } = await ctx.classTeacher.from("leave_requests").update({ status: "approved", reviewed_at: new Date().toISOString() }).eq("id", lr!.id);
    expect(error).toBeNull();

    const { data: att } = await admin
      .from("attendance")
      .select("date, status")
      .eq("student_id", ctx.studentA1)
      .gte("date", lr!.from_date)
      .lte("date", lr!.to_date);
    // Sep 1..3 inclusive = 3 excused rows
    expect((att ?? []).length).toBe(3);
    expect((att ?? []).every((a) => a.status === "excused")).toBe(true);
  });

  test("events: only the admin adds holidays; teachers & parents read-only", async () => {
    // a teacher (even a class teacher) cannot create an event...
    const { error: teacherErr } = await ctx.classTeacher
      .from("events")
      .insert({ school_id: ctx.schoolId, title: "Sports Day", start_date: "2025-10-01", end_date: "2025-10-01", is_holiday: true });
    expect(teacherErr).not.toBeNull();
    const { error: parentErr } = await ctx.parentA
      .from("events")
      .insert({ school_id: ctx.schoolId, title: "hack", start_date: "2025-10-02", end_date: "2025-10-02" });
    expect(parentErr).not.toBeNull();

    // ...but everyone in the school can read the admin's holiday
    await admin.from("events").insert({ school_id: ctx.schoolId, title: "Republic Day", start_date: "2025-10-03", end_date: "2025-10-03", is_holiday: true });
    const { data: seen } = await ctx.classTeacher.from("events").select("id").eq("title", "Republic Day");
    expect((seen ?? []).length).toBe(1);
  });

  test("periods: a teacher (non-admin) cannot create; a parent sees them read-only via membership", async () => {
    const { error } = await ctx.classTeacher
      .from("periods")
      .insert({ school_id: ctx.schoolId, section_id: ctx.sectionId, academic_year_id: ctx.yearId, weekday: 0, period_no: 1 });
    expect(error).not.toBeNull(); // periods are admin-write only

    await admin.from("periods").insert({ school_id: ctx.schoolId, section_id: ctx.sectionId, academic_year_id: ctx.yearId, weekday: 0, period_no: 1 });
    const { data } = await ctx.parentA.from("periods").select("id").eq("section_id", ctx.sectionId);
    expect((data ?? []).length).toBeGreaterThanOrEqual(1); // members can read
  });
});
