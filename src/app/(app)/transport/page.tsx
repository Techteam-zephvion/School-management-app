import { redirect } from "next/navigation";
import { requireActiveMembership, getAuthUser } from "@/lib/auth/session";
import { createClient } from "@/lib/supabase/server";
import { TransportAdmin } from "./transport-admin";
import { TransportClassTeacher } from "./transport-classteacher";

export type RouteRow = {
  id: string;
  name: string;
  description: string | null;
  fee_amount: number;
  driver_name: string | null;
  driver_phone: string | null;
  vehicle_no: string | null;
  capacity: number | null;
};
export type StopRow = { id: string; route_id: string; name: string; seq: number; pickup_time: string | null };
export type RiderRow = {
  studentId: string;
  routeId: string;
  stopId: string | null;
  studentName: string;
  admissionNo: string;
  stopName: string | null;
  fee: number;
};
export type BusLoc = { route_id: string; lat: number; lng: number; updated_at: string };

function fullName(first: string, last: string | null) {
  return [first, last].filter(Boolean).join(" ");
}

export default async function TransportPage() {
  const membership = await requireActiveMembership();
  if (membership.role === "parent") redirect("/dashboard");
  const supabase = await createClient();
  const user = await getAuthUser();
  const schoolId = membership.schoolId;
  const isAdmin = membership.role === "school_admin";

  const [{ data: routes }, { data: stops }, { data: rosterRaw }, { data: locations }] = await Promise.all([
    supabase
      .from("bus_routes")
      .select("id, name, description, fee_amount, driver_name, driver_phone, vehicle_no, capacity")
      .eq("school_id", schoolId)
      .order("name"),
    supabase.from("bus_stops").select("id, route_id, name, seq, pickup_time").eq("school_id", schoolId).order("seq"),
    supabase
      .from("student_transport")
      .select("student_id, route_id, stop_id, fee_amount, students(first_name, last_name, admission_no), bus_stops(name)")
      .eq("school_id", schoolId),
    supabase.from("bus_locations").select("route_id, lat, lng, updated_at"),
  ]);

  const riders: RiderRow[] = (rosterRaw ?? []).map((r) => {
    const s = r.students as { first_name: string; last_name: string | null; admission_no: string } | null;
    const stop = r.bus_stops as { name: string } | null;
    return {
      studentId: r.student_id,
      routeId: r.route_id,
      stopId: r.stop_id,
      studentName: s ? fullName(s.first_name, s.last_name) : "Student",
      admissionNo: s?.admission_no ?? "",
      stopName: stop?.name ?? null,
      fee: Number(r.fee_amount),
    };
  });
  const routeRows = (routes ?? []) as RouteRow[];
  const stopRows = (stops ?? []) as StopRow[];
  const locs = (locations ?? []).map((l) => ({ ...l, lat: Number(l.lat), lng: Number(l.lng) })) as BusLoc[];
  const userId = user?.id ?? "";

  if (isAdmin) {
    const { data: students } = await supabase
      .from("students")
      .select("id, first_name, last_name, admission_no")
      .eq("school_id", schoolId)
      .eq("status", "active")
      .order("first_name");
    const assigned = new Set(riders.map((r) => r.studentId));
    const available = (students ?? [])
      .filter((s) => !assigned.has(s.id))
      .map((s) => ({ id: s.id, name: fullName(s.first_name, s.last_name), admissionNo: s.admission_no }));
    return (
      <TransportAdmin
        routes={routeRows}
        stops={stopRows}
        riders={riders}
        available={available}
        locations={locs}
        userId={userId}
      />
    );
  }

  // Teacher: scope to the students of the section(s) they class-teach.
  let myStudentIds = new Set<string>();
  const { data: myStaff } = await supabase
    .from("staff")
    .select("id")
    .eq("school_id", schoolId)
    .eq("user_id", user?.id ?? "")
    .maybeSingle();
  if (myStaff) {
    const { data: mySections } = await supabase.from("sections").select("id").eq("class_teacher_staff_id", myStaff.id);
    const secIds = (mySections ?? []).map((s) => s.id);
    if (secIds.length) {
      const { data: enr } = await supabase
        .from("enrollments")
        .select("student_id")
        .in("section_id", secIds)
        .eq("status", "active");
      myStudentIds = new Set((enr ?? []).map((e) => e.student_id));
    }
  }
  const myRiders = riders.filter((r) => myStudentIds.has(r.studentId));

  // Their class students (names) minus anyone already on a bus → the picker list.
  let classStudents: { id: string; name: string; admissionNo: string }[] = [];
  if (myStudentIds.size) {
    const { data } = await supabase
      .from("students")
      .select("id, first_name, last_name, admission_no")
      .in("id", [...myStudentIds])
      .order("first_name");
    classStudents = (data ?? []).map((s) => ({ id: s.id, name: fullName(s.first_name, s.last_name), admissionNo: s.admission_no }));
  }
  const riderIds = new Set(myRiders.map((r) => r.studentId));
  const available = classStudents.filter((s) => !riderIds.has(s.id));

  // All routes/stops are pickable; the map only shows buses the class rides
  // (bus_locations is RLS-filtered to the teacher's trackable routes).
  return (
    <TransportClassTeacher
      routes={routeRows}
      stops={stopRows}
      riders={myRiders}
      available={available}
      locations={locs}
      userId={userId}
    />
  );
}
