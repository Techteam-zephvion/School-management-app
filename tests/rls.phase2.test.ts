/**
 * Phase 2 RLS gate (doc 06 Phase 2, doc 05 §12): academic-setup tables are
 * readable by school members and writable only by school_admin; cross-school
 * access returns zero rows / is denied. Runs against the local Supabase stack.
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
  classAId: string;
  adminA: SupabaseClient; // school_admin of School A
  teacherA: SupabaseClient; // teacher of School A
  adminB: SupabaseClient; // school_admin of School B
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
  const password = "password123";
  const { data: schoolA } = await admin
    .from("schools")
    .insert({ name: `A ${rand()}` })
    .select()
    .single();
  const { data: schoolB } = await admin
    .from("schools")
    .insert({ name: `B ${rand()}` })
    .select()
    .single();
  ctx.schoolAId = schoolA!.id;
  ctx.schoolBId = schoolB!.id;

  const adminAId = await makeUser(`admin.a.${rand()}@t.local`, password);
  const teacherAId = await makeUser(`teacher.a.${rand()}@t.local`, password);
  const adminBId = await makeUser(`admin.b.${rand()}@t.local`, password);
  await admin.from("school_members").insert([
    { school_id: ctx.schoolAId, user_id: adminAId, role: "school_admin", status: "active" },
    { school_id: ctx.schoolAId, user_id: teacherAId, role: "teacher", status: "active" },
    { school_id: ctx.schoolBId, user_id: adminBId, role: "school_admin", status: "active" },
  ]);

  // A class in School A (the row we test isolation against).
  const { data: klass } = await admin
    .from("classes")
    .insert({ school_id: ctx.schoolAId, name: "Grade 5" })
    .select()
    .single();
  ctx.classAId = klass!.id;

  ctx.adminA = await signIn(
    (await admin.auth.admin.getUserById(adminAId)).data.user!.email!,
    password
  );
  ctx.teacherA = await signIn(
    (await admin.auth.admin.getUserById(teacherAId)).data.user!.email!,
    password
  );
  ctx.adminB = await signIn(
    (await admin.auth.admin.getUserById(adminBId)).data.user!.email!,
    password
  );
});

afterAll(async () => {
  await admin.from("schools").delete().eq("id", ctx.schoolAId);
  await admin.from("schools").delete().eq("id", ctx.schoolBId);
});

describe("Phase 2 RLS: academic setup", () => {
  test("teacher of School A can READ its classes", async () => {
    const { data } = await ctx.teacherA
      .from("classes")
      .select("*")
      .eq("school_id", ctx.schoolAId);
    expect((data ?? []).length).toBeGreaterThanOrEqual(1);
  });

  test("teacher CANNOT create a class (admin-only write)", async () => {
    const { error } = await ctx.teacherA
      .from("classes")
      .insert({ school_id: ctx.schoolAId, name: "Sneaky" })
      .select();
    const { data: check } = await admin
      .from("classes")
      .select("id")
      .eq("school_id", ctx.schoolAId)
      .eq("name", "Sneaky");
    expect(check ?? []).toHaveLength(0);
    expect(error).not.toBeNull();
  });

  test("School B admin sees ZERO of School A's classes", async () => {
    const { data } = await ctx.adminB
      .from("classes")
      .select("*")
      .eq("school_id", ctx.schoolAId);
    expect(data ?? []).toHaveLength(0);
  });

  test("School B admin CANNOT create a class in School A", async () => {
    const { error } = await ctx.adminB
      .from("classes")
      .insert({ school_id: ctx.schoolAId, name: "Cross" })
      .select();
    const { data: check } = await admin
      .from("classes")
      .select("id")
      .eq("school_id", ctx.schoolAId)
      .eq("name", "Cross");
    expect(check ?? []).toHaveLength(0);
    expect(error).not.toBeNull();
  });

  test("School A admin CAN create a subject; School B admin cannot see it", async () => {
    const name = `Subj ${rand()}`;
    const { error } = await ctx.adminA
      .from("subjects")
      .insert({ school_id: ctx.schoolAId, name });
    expect(error).toBeNull();

    const { data: seenByB } = await ctx.adminB
      .from("subjects")
      .select("*")
      .eq("school_id", ctx.schoolAId);
    expect(seenByB ?? []).toHaveLength(0);
  });

  test("staff auto-created for School A's teacher and admin (backfill/trigger)", async () => {
    const { data } = await ctx.adminA
      .from("staff")
      .select("id")
      .eq("school_id", ctx.schoolAId);
    // admin + teacher => 2 staff rows, created by ensure_staff_record trigger.
    expect((data ?? []).length).toBe(2);
  });

  test("School B admin sees ZERO of School A's staff", async () => {
    const { data } = await ctx.adminB
      .from("staff")
      .select("*")
      .eq("school_id", ctx.schoolAId);
    expect(data ?? []).toHaveLength(0);
  });
});
