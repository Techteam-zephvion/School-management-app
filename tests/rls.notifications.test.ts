/**
 * Phase 10 notifications gate (doc 06 Phase 10): events fan out notification
 * rows to the right recipients (homework/message/invoice) with a deeplink, and a
 * user sees only their own notifications. Local Supabase.
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
  sectionId: string;
  subjectId: string;
  studentA1: string;
  teacherUserId: string;
  parentAId: string;
  parentBId: string;
  teacher: SupabaseClient;
  parentA: SupabaseClient; // guardian of A1
  parentB: SupabaseClient; // guardian of B1 (unrelated)
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
const notifsFor = (client: SupabaseClient) => client.from("notifications").select("type, title, deeplink, user_id");

beforeAll(async () => {
  const { data: school } = await admin.from("schools").insert({ name: `Notif ${rand()}` }).select().single();
  ctx.schoolId = school!.id;
  const { data: year } = await admin.from("academic_years").insert({ school_id: ctx.schoolId, name: "Y", start_date: "2025-06-01", end_date: "2026-04-30", is_active: true }).select().single();
  const { data: klass } = await admin.from("classes").insert({ school_id: ctx.schoolId, name: "Grade 1" }).select().single();
  const { data: sec } = await admin.from("sections").insert({ school_id: ctx.schoolId, class_id: klass!.id, name: "A", academic_year_id: year!.id }).select().single();
  ctx.sectionId = sec!.id;
  const { data: subj } = await admin.from("subjects").insert({ school_id: ctx.schoolId, name: "Math" }).select().single();
  ctx.subjectId = subj!.id;

  ctx.teacherUserId = await makeUser(`t.${rand()}@t.local`);
  ctx.parentAId = await makeUser(`pa.${rand()}@t.local`);
  ctx.parentBId = await makeUser(`pb.${rand()}@t.local`);
  await admin.from("school_members").insert([
    { school_id: ctx.schoolId, user_id: ctx.teacherUserId, role: "teacher", status: "active" },
    { school_id: ctx.schoolId, user_id: ctx.parentAId, role: "parent", status: "active" },
    { school_id: ctx.schoolId, user_id: ctx.parentBId, role: "parent", status: "active" },
  ]);
  const { data: a1 } = await admin.from("students").insert({ school_id: ctx.schoolId, admission_no: `A1-${rand()}`, first_name: "A1" }).select().single();
  const { data: b1 } = await admin.from("students").insert({ school_id: ctx.schoolId, admission_no: `B1-${rand()}`, first_name: "B1" }).select().single();
  ctx.studentA1 = a1!.id;
  await admin.from("enrollments").insert({ school_id: ctx.schoolId, student_id: ctx.studentA1, section_id: ctx.sectionId, academic_year_id: year!.id });
  await admin.from("student_guardians").insert([
    { school_id: ctx.schoolId, student_id: ctx.studentA1, guardian_user_id: ctx.parentAId, relation: "mother", is_primary: true },
    { school_id: ctx.schoolId, student_id: b1!.id, guardian_user_id: ctx.parentBId, relation: "mother", is_primary: true },
  ]);
  const { data: staff } = await admin.from("staff").select("id").eq("user_id", ctx.teacherUserId).single();
  await admin.from("sections").update({ class_teacher_staff_id: staff!.id }).eq("id", ctx.sectionId);

  ctx.teacher = await signIn(await emailOf(ctx.teacherUserId));
  ctx.parentA = await signIn(await emailOf(ctx.parentAId));
  ctx.parentB = await signIn(await emailOf(ctx.parentBId));
});

afterAll(async () => {
  await admin.from("schools").delete().eq("id", ctx.schoolId);
});

describe("Phase 10: notifications", () => {
  test("posting homework notifies the section's guardians with a deeplink", async () => {
    const { data: hw } = await admin
      .from("homework")
      .insert({ school_id: ctx.schoolId, section_id: ctx.sectionId, subject_id: ctx.subjectId, title: "Read ch. 3", due_date: "2027-01-01", created_by: ctx.teacherUserId })
      .select("id")
      .single();
    const { data } = await notifsFor(ctx.parentA).eq("type", "homework");
    expect((data ?? []).length).toBeGreaterThanOrEqual(1);
    expect(data![0].deeplink).toBe(`schoolerp://homework/${hw!.id}`);
  });

  test("guardian B (other family) is NOT notified of A's section homework", async () => {
    const { data } = await notifsFor(ctx.parentB).eq("type", "homework");
    expect(data ?? []).toHaveLength(0);
  });

  test("a message notifies the other participant (not the sender)", async () => {
    const { data: threadId } = await ctx.teacher.rpc("start_thread_with_guardians", {
      p_student: ctx.studentA1,
      p_subject: "Hi",
      p_body: "Hello!",
    });
    // parent A (recipient) gets a 'message' notification; teacher (sender) does not
    const { data: pa } = await notifsFor(ctx.parentA).eq("type", "message");
    expect((pa ?? []).length).toBeGreaterThanOrEqual(1);
    expect(pa![0].deeplink).toBe(`schoolerp://messages/${threadId as string}`);
    const { data: te } = await notifsFor(ctx.teacher).eq("type", "message");
    expect(te ?? []).toHaveLength(0);
  });

  test("a new invoice notifies the student's guardian", async () => {
    const { data: fs } = await admin.from("fee_structures").insert({ school_id: ctx.schoolId, academic_year_id: (await admin.from("academic_years").select("id").eq("school_id", ctx.schoolId).single()).data!.id, name: "Fee", due_date: "2027-03-01" }).select("id").single();
    await admin.from("fee_items").insert({ school_id: ctx.schoolId, fee_structure_id: fs!.id, label: "Tuition", amount: 1000 });
    await admin.from("invoices").insert({ school_id: ctx.schoolId, student_id: ctx.studentA1, fee_structure_id: fs!.id, amount_total: 1000, due_date: "2027-03-01" });
    const { data } = await notifsFor(ctx.parentA).eq("type", "fee");
    expect((data ?? []).length).toBeGreaterThanOrEqual(1);
  });

  test("a user only reads their OWN notifications and can mark them read", async () => {
    const { data: all } = await ctx.parentA.from("notifications").select("user_id");
    expect((all ?? []).every((n) => n.user_id === ctx.parentAId)).toBe(true);

    // parentB cannot read parentA's rows
    const { data: leak } = await ctx.parentB.from("notifications").select("id").eq("user_id", ctx.parentAId);
    expect(leak ?? []).toHaveLength(0);

    const { error } = await ctx.parentA.from("notifications").update({ read_at: new Date().toISOString() }).eq("user_id", ctx.parentAId).is("read_at", null);
    expect(error).toBeNull();
  });
});
