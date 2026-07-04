/**
 * Phase 6 announcements RLS gate (doc 06 Phase 6): admin targets any audience; a
 * teacher can only post section/individual notices; a parent sees notices aimed
 * at their child (school / their section / their child) and nobody else's, and
 * records their own read receipt. Local Supabase.
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
  classId: string;
  sectionA: string;
  sectionB: string;
  studentA1: string;
  teacherId: string;
  classTeacher: SupabaseClient; // class teacher of A
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

// helper: create an announcement + its target via service role (as if admin composed it)
async function seedNotice(
  audience: "school" | "class" | "section" | "individual",
  target: { class_id?: string; section_id?: string; student_id?: string }
) {
  const { data: a } = await admin
    .from("announcements")
    .insert({ school_id: ctx.schoolId, audience, title: `${audience} ${rand()}`, body: "hi", created_by: ctx.teacherId })
    .select()
    .single();
  if (audience !== "school") {
    await admin.from("announcement_targets").insert({ announcement_id: a!.id, school_id: ctx.schoolId, ...target });
  }
  return a!.id;
}

beforeAll(async () => {
  const { data: school } = await admin.from("schools").insert({ name: `Ann ${rand()}` }).select().single();
  ctx.schoolId = school!.id;
  const { data: year } = await admin
    .from("academic_years")
    .insert({ school_id: ctx.schoolId, name: "Y", start_date: "2025-06-01", end_date: "2026-04-30", is_active: true })
    .select().single();
  const { data: klass } = await admin.from("classes").insert({ school_id: ctx.schoolId, name: "Grade 1" }).select().single();
  ctx.classId = klass!.id;
  const { data: secA } = await admin.from("sections").insert({ school_id: ctx.schoolId, class_id: klass!.id, name: "A", academic_year_id: year!.id }).select().single();
  const { data: secB } = await admin.from("sections").insert({ school_id: ctx.schoolId, class_id: klass!.id, name: "B", academic_year_id: year!.id }).select().single();
  ctx.sectionA = secA!.id;
  ctx.sectionB = secB!.id;

  const adminId = await makeUser(`admin.${rand()}@t.local`);
  ctx.teacherId = await makeUser(`ct.${rand()}@t.local`);
  const parentId = await makeUser(`parent.${rand()}@t.local`);
  await admin.from("school_members").insert([
    { school_id: ctx.schoolId, user_id: adminId, role: "school_admin", status: "active" },
    { school_id: ctx.schoolId, user_id: ctx.teacherId, role: "teacher", status: "active" },
    { school_id: ctx.schoolId, user_id: parentId, role: "parent", status: "active" },
  ]);
  const { data: kid } = await admin.from("students").insert({ school_id: ctx.schoolId, admission_no: `A1-${rand()}`, first_name: "Kid" }).select().single();
  ctx.studentA1 = kid!.id;
  await admin.from("enrollments").insert({ school_id: ctx.schoolId, student_id: ctx.studentA1, section_id: ctx.sectionA, academic_year_id: year!.id });
  await admin.from("student_guardians").insert({ school_id: ctx.schoolId, student_id: ctx.studentA1, guardian_user_id: parentId, relation: "mother", is_primary: true });

  const { data: ctStaff } = await admin.from("staff").select("id").eq("user_id", ctx.teacherId).single();
  await admin.from("sections").update({ class_teacher_staff_id: ctStaff!.id }).eq("id", ctx.sectionA);

  ctx.adminClient = await signIn(await emailOf(adminId));
  ctx.classTeacher = await signIn(await emailOf(ctx.teacherId));
  ctx.parent = await signIn(await emailOf(parentId));
});

afterAll(async () => {
  await admin.from("schools").delete().eq("id", ctx.schoolId);
});

describe("Phase 6 RLS: announcements", () => {
  test("admin CAN create a school-wide notice", async () => {
    const { error } = await ctx.adminClient
      .from("announcements")
      .insert({ school_id: ctx.schoolId, audience: "school", title: "All", body: "hi" });
    expect(error).toBeNull();
  });

  test("teacher CANNOT create a school-wide or class-wide notice", async () => {
    const { error: e1 } = await ctx.classTeacher
      .from("announcements")
      .insert({ school_id: ctx.schoolId, audience: "school", title: "T school", body: "hi" });
    const { error: e2 } = await ctx.classTeacher
      .from("announcements")
      .insert({ school_id: ctx.schoolId, audience: "class", title: "T class", body: "hi" });
    expect(e1).not.toBeNull();
    expect(e2).not.toBeNull();
  });

  test("teacher CAN create a section notice", async () => {
    const { error } = await ctx.classTeacher
      .from("announcements")
      .insert({ school_id: ctx.schoolId, audience: "section", title: "T section", body: "hi" });
    expect(error).toBeNull();
  });

  test("parent sees a notice targeted to their child's section, not another section", async () => {
    const mine = await seedNotice("section", { section_id: ctx.sectionA });
    const notMine = await seedNotice("section", { section_id: ctx.sectionB });
    const { data } = await ctx.parent.from("announcements").select("id");
    const ids = new Set((data ?? []).map((r) => r.id));
    expect(ids.has(mine)).toBe(true);
    expect(ids.has(notMine)).toBe(false);
  });

  test("parent sees a school-wide and an individual notice for their child", async () => {
    const school = await seedNotice("school", {});
    const individual = await seedNotice("individual", { student_id: ctx.studentA1 });
    const { data } = await ctx.parent.from("announcements").select("id");
    const ids = new Set((data ?? []).map((r) => r.id));
    expect(ids.has(school)).toBe(true);
    expect(ids.has(individual)).toBe(true);
  });

  test("parent records their own read receipt but CANNOT post notices", async () => {
    const nid = await seedNotice("section", { section_id: ctx.sectionA });
    const { data: me } = await ctx.parent.auth.getUser();
    const { error: readErr } = await ctx.parent
      .from("announcement_reads")
      .insert({ announcement_id: nid, school_id: ctx.schoolId, user_id: me.user!.id });
    expect(readErr).toBeNull();

    const { error: postErr } = await ctx.parent
      .from("announcements")
      .insert({ school_id: ctx.schoolId, audience: "section", title: "hack", body: "x" });
    expect(postErr).not.toBeNull();
  });
});
