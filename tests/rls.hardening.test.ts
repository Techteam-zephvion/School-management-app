/**
 * Phase 13 hardening gate (doc 06 Phase 13): the cross-tenant security matrix.
 * A parent AND a teacher authenticated in School A must read ZERO rows of School
 * B across every sensitive table, and must not be able to write into School B.
 * A positive control (the parent DOES see their own child) proves the harness is
 * exercising real RLS, not an empty database. Runs against local Supabase.
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
  schoolAId: string;
  schoolBId: string;
  childA1: string; // the parent's own child (positive control)
  // School B rows the School A users must never see:
  b: { student: string; section: string; subject: string; homework: string; announcement: string; invoice: string };
  parentA: SupabaseClient;
  teacherA: SupabaseClient;
};
const ctx = {} as Ctx;

async function makeUser(email: string) {
  const { data, error } = await admin.auth.admin.createUser({ email, password: "password123", email_confirm: true });
  if (error) throw error;
  return data.user.id;
}
async function signIn(id: string) {
  const email = (await admin.auth.admin.getUserById(id)).data.user!.email!;
  const c = createClient(URL, ANON, { auth: { autoRefreshToken: false, persistSession: false } });
  const { error } = await c.auth.signInWithPassword({ email, password: "password123" });
  if (error) throw error;
  return c;
}

/** Build a full mini-tenant and return the ids the matrix will probe. */
async function buildSchoolB(schoolId: string) {
  const { data: year } = await admin.from("academic_years").insert({ school_id: schoolId, name: "Y", start_date: "2025-06-01", end_date: "2026-04-30", is_active: true }).select().single();
  const { data: klass } = await admin.from("classes").insert({ school_id: schoolId, name: "Grade 3" }).select().single();
  const { data: section } = await admin.from("sections").insert({ school_id: schoolId, class_id: klass!.id, name: "A", academic_year_id: year!.id }).select().single();
  const { data: subject } = await admin.from("subjects").insert({ school_id: schoolId, name: "Math", code: `M-${rand()}` }).select().single();
  const { data: student } = await admin.from("students").insert({ school_id: schoolId, admission_no: `B-${rand()}`, first_name: "Bee" }).select().single();
  await admin.from("enrollments").insert({ school_id: schoolId, student_id: student!.id, section_id: section!.id, academic_year_id: year!.id });
  const { data: hw } = await admin.from("homework").insert({ school_id: schoolId, section_id: section!.id, subject_id: subject!.id, title: "B secret hw", due_date: "2027-01-01" }).select().single();
  const { data: ann } = await admin.from("announcements").insert({ school_id: schoolId, audience: "school", title: "B secret notice", body: "private" }).select().single();
  const { data: fs } = await admin.from("fee_structures").insert({ school_id: schoolId, academic_year_id: year!.id, name: "Term 1", due_date: "2027-01-01" }).select().single();
  const { data: inv } = await admin.from("invoices").insert({ school_id: schoolId, student_id: student!.id, fee_structure_id: fs!.id, amount_total: 5000, due_date: "2027-01-01" }).select().single();
  return { student: student!.id, section: section!.id, subject: subject!.id, homework: hw!.id, announcement: ann!.id, invoice: inv!.id };
}

beforeAll(async () => {
  const { data: sa } = await admin.from("schools").insert({ name: `A ${rand()}` }).select().single();
  const { data: sb } = await admin.from("schools").insert({ name: `B ${rand()}` }).select().single();
  ctx.schoolAId = sa!.id;
  ctx.schoolBId = sb!.id;

  const parentAId = await makeUser(`parent.a.${rand()}@t.local`);
  const teacherAId = await makeUser(`teacher.a.${rand()}@t.local`);
  await admin.from("school_members").insert([
    { school_id: ctx.schoolAId, user_id: parentAId, role: "parent", status: "active" },
    { school_id: ctx.schoolAId, user_id: teacherAId, role: "teacher", status: "active" },
  ]);

  // School A's own child, linked to the parent (positive control).
  const { data: childA } = await admin.from("students").insert({ school_id: ctx.schoolAId, admission_no: `A-${rand()}`, first_name: "Aay" }).select().single();
  ctx.childA1 = childA!.id;
  await admin.from("student_guardians").insert({ school_id: ctx.schoolAId, student_id: ctx.childA1, guardian_user_id: parentAId, relation: "father", is_primary: true });

  ctx.b = await buildSchoolB(ctx.schoolBId);
  ctx.parentA = await signIn(parentAId);
  ctx.teacherA = await signIn(teacherAId);
});

afterAll(async () => {
  await admin.from("schools").delete().eq("id", ctx.schoolAId);
  await admin.from("schools").delete().eq("id", ctx.schoolBId);
});

describe("Phase 13: cross-tenant security matrix", () => {
  test("positive control — School A parent DOES see their own child", async () => {
    const { data } = await ctx.parentA.from("students").select("id");
    expect((data ?? []).map((r) => r.id)).toEqual([ctx.childA1]);
  });

  // The matrix: for each actor, for each table, reading a School B row → 0 rows.
  // ctx.b is only populated in beforeAll, so resolve the id inside the test body
  // (collection runs before beforeAll) via a key rather than a value here.
  const tables: { table: string; key: keyof Ctx["b"] }[] = [
    { table: "students", key: "student" },
    { table: "homework", key: "homework" },
    { table: "announcements", key: "announcement" },
    { table: "invoices", key: "invoice" },
    { table: "sections", key: "section" },
    { table: "subjects", key: "subject" },
  ];

  for (const actor of ["parentA", "teacherA"] as const) {
    for (const t of tables) {
      test(`${actor} reads ZERO of School B ${t.table}`, async () => {
        const { data } = await ctx[actor].from(t.table).select("id").eq("id", ctx.b[t.key]);
        expect(data ?? []).toHaveLength(0);
      });
    }
  }

  test("School A parent CANNOT write homework into School B", async () => {
    const { error } = await ctx.parentA
      .from("homework")
      .insert({ school_id: ctx.schoolBId, section_id: ctx.b.section, subject_id: ctx.b.subject, title: "hack", due_date: "2027-02-01" })
      .select();
    expect(error).not.toBeNull();
  });

  test("School A teacher CANNOT write an announcement into School B", async () => {
    const { error } = await ctx.teacherA
      .from("announcements")
      .insert({ school_id: ctx.schoolBId, audience: "school", title: "hack", body: "x" })
      .select();
    expect(error).not.toBeNull();
  });
});
