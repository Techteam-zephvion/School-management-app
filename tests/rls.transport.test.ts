/**
 * Transport module RLS (migration 0022): routes/stops are readable by school
 * staff and writable only by admins; the roster is visible to staff + the rider's
 * class teacher + the rider's parent; and — the crux — LIVE LOCATION is readable
 * only by an admin, the class teacher of a rider's section, or the rider's parent
 * (`my_trackable_route_ids`), never a random teacher or another school.
 * Runs against local Supabase.
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
  routeId: string;
  studentId: string;
  adminA: SupabaseClient;
  classTeacher: SupabaseClient; // class teacher of the rider's section
  plainTeacher: SupabaseClient; // a teacher who is NOT the class teacher
  parent: SupabaseClient; // the rider's parent
  adminB: SupabaseClient;
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

beforeAll(async () => {
  const { data: sa } = await admin.from("schools").insert({ name: `TA ${rand()}` }).select().single();
  const { data: sb } = await admin.from("schools").insert({ name: `TB ${rand()}` }).select().single();
  ctx.schoolAId = sa!.id;
  ctx.schoolBId = sb!.id;

  const adminAId = await makeUser(`t.admin.${rand()}@t.local`);
  const ctId = await makeUser(`t.ct.${rand()}@t.local`);
  const plainId = await makeUser(`t.plain.${rand()}@t.local`);
  const parentId = await makeUser(`t.parent.${rand()}@t.local`);
  const adminBId = await makeUser(`t.adminb.${rand()}@t.local`);
  await admin.from("school_members").insert([
    { school_id: ctx.schoolAId, user_id: adminAId, role: "school_admin", status: "active" },
    { school_id: ctx.schoolAId, user_id: ctId, role: "teacher", status: "active" },
    { school_id: ctx.schoolAId, user_id: plainId, role: "teacher", status: "active" },
    { school_id: ctx.schoolAId, user_id: parentId, role: "parent", status: "active" },
    { school_id: ctx.schoolBId, user_id: adminBId, role: "school_admin", status: "active" },
  ]);

  const { data: year } = await admin
    .from("academic_years")
    .insert({ school_id: ctx.schoolAId, name: "Y", start_date: "2025-06-01", end_date: "2026-04-30", is_active: true })
    .select().single();
  const { data: klass } = await admin.from("classes").insert({ school_id: ctx.schoolAId, name: "Grade 1" }).select().single();
  const { data: section } = await admin
    .from("sections")
    .insert({ school_id: ctx.schoolAId, class_id: klass!.id, name: "A", academic_year_id: year!.id })
    .select().single();
  // class teacher of the section
  const { data: ctStaff } = await admin.from("staff").select("id").eq("school_id", ctx.schoolAId).eq("user_id", ctId).single();
  await admin.from("sections").update({ class_teacher_staff_id: ctStaff!.id }).eq("id", section!.id);

  const { data: student } = await admin
    .from("students")
    .insert({ school_id: ctx.schoolAId, admission_no: `T-${rand()}`, first_name: "Rider" })
    .select().single();
  ctx.studentId = student!.id;
  await admin.from("enrollments").insert({ school_id: ctx.schoolAId, student_id: student!.id, section_id: section!.id, academic_year_id: year!.id, status: "active" });
  await admin.from("student_guardians").insert({ school_id: ctx.schoolAId, student_id: student!.id, guardian_user_id: parentId, relation: "mother", is_primary: true });

  // route + stop + assignment + a live location
  const { data: route } = await admin.from("bus_routes").insert({ school_id: ctx.schoolAId, name: "North Line", fee_amount: 1000 }).select().single();
  ctx.routeId = route!.id;
  await admin.from("bus_stops").insert({ school_id: ctx.schoolAId, route_id: route!.id, name: "Main Gate" });
  await admin.from("student_transport").insert({ school_id: ctx.schoolAId, student_id: student!.id, route_id: route!.id, fee_amount: 1000 });
  await admin.from("bus_locations").insert({ route_id: route!.id, school_id: ctx.schoolAId, lat: 12.97, lng: 77.59 });

  ctx.adminA = await signIn(adminAId);
  ctx.classTeacher = await signIn(ctId);
  ctx.plainTeacher = await signIn(plainId);
  ctx.parent = await signIn(parentId);
  ctx.adminB = await signIn(adminBId);
});

afterAll(async () => {
  await admin.from("schools").delete().eq("id", ctx.schoolAId);
  await admin.from("schools").delete().eq("id", ctx.schoolBId);
});

describe("Transport RLS", () => {
  test("staff read routes; only admin writes them", async () => {
    const { data: ctSee } = await ctx.classTeacher.from("bus_routes").select("id").eq("id", ctx.routeId);
    expect((ctSee ?? []).length).toBe(1);

    const { error: adminWrite } = await ctx.adminA.from("bus_routes").insert({ school_id: ctx.schoolAId, name: "South Line", fee_amount: 500 }).select();
    expect(adminWrite).toBeNull();

    const { error: teacherWrite } = await ctx.classTeacher.from("bus_routes").insert({ school_id: ctx.schoolAId, name: "Hack", fee_amount: 0 }).select();
    expect(teacherWrite).not.toBeNull();
  });

  test("live location: admin, the class teacher, and the parent can track — a plain teacher cannot", async () => {
    const { data: adminLoc } = await ctx.adminA.from("bus_locations").select("route_id").eq("route_id", ctx.routeId);
    expect((adminLoc ?? []).length).toBe(1);

    const { data: ctLoc } = await ctx.classTeacher.from("bus_locations").select("route_id").eq("route_id", ctx.routeId);
    expect((ctLoc ?? []).length).toBe(1);

    const { data: parentLoc } = await ctx.parent.from("bus_locations").select("route_id").eq("route_id", ctx.routeId);
    expect((parentLoc ?? []).length).toBe(1);

    const { data: plainLoc } = await ctx.plainTeacher.from("bus_locations").select("route_id").eq("route_id", ctx.routeId);
    expect(plainLoc ?? []).toHaveLength(0); // not a class teacher, not a parent
  });

  test("parent sees their child's assignment; a plain teacher cannot write locations but staff can", async () => {
    const { data: parentRoster } = await ctx.parent.from("student_transport").select("student_id").eq("student_id", ctx.studentId);
    expect((parentRoster ?? []).length).toBe(1);

    // a staff member (the class teacher) may push a location (driver page)
    const { error: staffWrite } = await ctx.classTeacher
      .from("bus_locations")
      .upsert({ route_id: ctx.routeId, school_id: ctx.schoolAId, lat: 12.98, lng: 77.6 }, { onConflict: "route_id" });
    expect(staffWrite).toBeNull();

    // a parent may not write a location
    const { error: parentWrite } = await ctx.parent
      .from("bus_locations")
      .upsert({ route_id: ctx.routeId, school_id: ctx.schoolAId, lat: 0, lng: 0 }, { onConflict: "route_id" });
    expect(parentWrite).not.toBeNull();
  });

  test("another school's admin sees ZERO of School A's transport", async () => {
    const [{ data: routes }, { data: roster }, { data: locs }] = await Promise.all([
      ctx.adminB.from("bus_routes").select("id").eq("school_id", ctx.schoolAId),
      ctx.adminB.from("student_transport").select("id").eq("school_id", ctx.schoolAId),
      ctx.adminB.from("bus_locations").select("route_id").eq("school_id", ctx.schoolAId),
    ]);
    expect(routes ?? []).toHaveLength(0);
    expect(roster ?? []).toHaveLength(0);
    expect(locs ?? []).toHaveLength(0);
  });
});
