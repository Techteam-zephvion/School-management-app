/**
 * Phase 9 messaging RLS gate (doc 06 Phase 9): only thread participants read a
 * thread and its messages; a participant can send; a non-participant (another
 * parent, or unrelated staff) is blocked; staff start threads only with a
 * student's guardians. Local Supabase.
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
  studentA1: string;
  teacher: SupabaseClient; // will start the thread (class teacher of A1's section)
  parentA: SupabaseClient; // guardian of A1
  parentB: SupabaseClient; // guardian of a different student
  threadId: string;
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
  const { data: school } = await admin.from("schools").insert({ name: `Msg ${rand()}` }).select().single();
  ctx.schoolId = school!.id;
  const { data: year } = await admin
    .from("academic_years")
    .insert({ school_id: ctx.schoolId, name: "Y", start_date: "2025-06-01", end_date: "2026-04-30", is_active: true })
    .select().single();
  const { data: klass } = await admin.from("classes").insert({ school_id: ctx.schoolId, name: "Grade 1" }).select().single();
  const { data: secA } = await admin.from("sections").insert({ school_id: ctx.schoolId, class_id: klass!.id, name: "A", academic_year_id: year!.id }).select().single();

  const teacherId = await makeUser(`teacher.${rand()}@t.local`);
  const parentAId = await makeUser(`pa.${rand()}@t.local`);
  const parentBId = await makeUser(`pb.${rand()}@t.local`);
  await admin.from("school_members").insert([
    { school_id: ctx.schoolId, user_id: teacherId, role: "teacher", status: "active" },
    { school_id: ctx.schoolId, user_id: parentAId, role: "parent", status: "active" },
    { school_id: ctx.schoolId, user_id: parentBId, role: "parent", status: "active" },
  ]);
  const { data: a1 } = await admin.from("students").insert({ school_id: ctx.schoolId, admission_no: `A1-${rand()}`, first_name: "A1" }).select().single();
  const { data: b1 } = await admin.from("students").insert({ school_id: ctx.schoolId, admission_no: `B1-${rand()}`, first_name: "B1" }).select().single();
  ctx.studentA1 = a1!.id;
  await admin.from("enrollments").insert([
    { school_id: ctx.schoolId, student_id: ctx.studentA1, section_id: secA!.id, academic_year_id: year!.id },
    { school_id: ctx.schoolId, student_id: b1!.id, section_id: secA!.id, academic_year_id: year!.id },
  ]);
  await admin.from("student_guardians").insert([
    { school_id: ctx.schoolId, student_id: ctx.studentA1, guardian_user_id: parentAId, relation: "mother", is_primary: true },
    { school_id: ctx.schoolId, student_id: b1!.id, guardian_user_id: parentBId, relation: "mother", is_primary: true },
  ]);
  const { data: staff } = await admin.from("staff").select("id").eq("user_id", teacherId).single();
  await admin.from("sections").update({ class_teacher_staff_id: staff!.id }).eq("id", secA!.id);

  ctx.teacher = await signIn(await emailOf(teacherId));
  ctx.parentA = await signIn(await emailOf(parentAId));
  ctx.parentB = await signIn(await emailOf(parentBId));
});

afterAll(async () => {
  await admin.from("schools").delete().eq("id", ctx.schoolId);
});

describe("Phase 9 RLS: messaging", () => {
  test("staff starts a thread with the student's guardians", async () => {
    const { data, error } = await ctx.teacher.rpc("start_thread_with_guardians", {
      p_student: ctx.studentA1,
      p_subject: "Hello",
      p_body: "Good morning, a quick update about A1.",
    });
    expect(error).toBeNull();
    ctx.threadId = data as string;
    expect(ctx.threadId).toBeTruthy();
  });

  test("the guardian (participant) reads the thread and its message", async () => {
    const { data: threads } = await ctx.parentA.from("message_threads").select("id").eq("id", ctx.threadId);
    expect((threads ?? []).length).toBe(1);
    const { data: msgs } = await ctx.parentA.from("messages").select("body").eq("thread_id", ctx.threadId);
    expect((msgs ?? []).length).toBe(1);
  });

  test("the guardian can reply; realtime insert is a normal participant insert", async () => {
    const { data: me } = await ctx.parentA.auth.getUser();
    const { error } = await ctx.parentA
      .from("messages")
      .insert({ school_id: ctx.schoolId, thread_id: ctx.threadId, sender_id: me.user!.id, body: "Thanks for the update!" });
    expect(error).toBeNull();
    // staff sees both messages
    const { data: staffView } = await ctx.teacher.from("messages").select("id").eq("thread_id", ctx.threadId);
    expect((staffView ?? []).length).toBe(2);
  });

  test("a non-participant parent sees NOTHING of the thread", async () => {
    const { data: threads } = await ctx.parentB.from("message_threads").select("id").eq("id", ctx.threadId);
    expect(threads ?? []).toHaveLength(0);
    const { data: msgs } = await ctx.parentB.from("messages").select("id").eq("thread_id", ctx.threadId);
    expect(msgs ?? []).toHaveLength(0);
  });

  test("a non-participant cannot post into the thread", async () => {
    const { data: me } = await ctx.parentB.auth.getUser();
    const { error } = await ctx.parentB
      .from("messages")
      .insert({ school_id: ctx.schoolId, thread_id: ctx.threadId, sender_id: me.user!.id, body: "intruding" });
    expect(error).not.toBeNull();
  });

  test("a parent cannot start a staff thread via the staff RPC", async () => {
    const { error } = await ctx.parentA.rpc("start_thread_with_guardians", {
      p_student: ctx.studentA1,
      p_subject: "x",
      p_body: "hi",
    });
    expect(error).not.toBeNull();
  });
});
