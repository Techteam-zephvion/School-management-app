"use server";

import { createClient } from "@/lib/supabase/server";
import { getActiveMembership } from "@/lib/auth/session";

export type SearchItem = { type: string; label: string; sub?: string; href: string };
export type SearchGroup = { title: string; items: SearchItem[] };

type Client = Awaited<ReturnType<typeof createClient>>;
type Searcher = (sb: Client, schoolId: string, term: string) => Promise<SearchItem[]>;

const PER_GROUP = 6;
const like = (t: string) => `%${t}%`;
function fullName(first: string, last: string | null) {
  return [first, last].filter(Boolean).join(" ") || "—";
}

// Each searcher is RLS-scoped to the caller, so results are automatically
// limited to what this user is allowed to see.
const SEARCHERS: Record<string, { title: string; run: Searcher }> = {
  students: {
    title: "Students",
    run: async (sb, schoolId, t) => {
      const { data } = await sb
        .from("students")
        .select("id, first_name, last_name, admission_no")
        .eq("school_id", schoolId)
        .or(`first_name.ilike.${like(t)},last_name.ilike.${like(t)},admission_no.ilike.${like(t)}`)
        .limit(PER_GROUP);
      return (data ?? []).map((s) => ({
        type: "student",
        label: fullName(s.first_name, s.last_name),
        sub: s.admission_no,
        href: `/students/${s.id}`,
      }));
    },
  },
  staff: {
    title: "Staff",
    run: async (sb, schoolId, t) => {
      const { data } = await sb
        .from("staff")
        .select("id, profiles!inner(full_name, email)")
        .eq("school_id", schoolId)
        .ilike("profiles.full_name", like(t))
        .limit(PER_GROUP);
      return (data ?? []).map((s) => {
        const p = s.profiles as { full_name: string | null; email: string | null } | null;
        return { type: "staff", label: p?.full_name || p?.email || "Staff", sub: p?.email ?? undefined, href: "/settings/staff" };
      });
    },
  },
  classes: {
    title: "Classes",
    run: async (sb, schoolId, t) => {
      const { data } = await sb
        .from("classes")
        .select("id, name")
        .eq("school_id", schoolId)
        .ilike("name", like(t))
        .limit(PER_GROUP);
      return (data ?? []).map((c) => ({ type: "class", label: c.name, href: "/settings/classes" }));
    },
  },
  subjects: {
    title: "Subjects",
    run: async (sb, schoolId, t) => {
      const { data } = await sb
        .from("subjects")
        .select("id, name, code")
        .eq("school_id", schoolId)
        .or(`name.ilike.${like(t)},code.ilike.${like(t)}`)
        .limit(PER_GROUP);
      return (data ?? []).map((s) => ({ type: "subject", label: s.name, sub: s.code ?? undefined, href: "/settings/classes" }));
    },
  },
  homework: {
    title: "Homework",
    run: async (sb, schoolId, t) => {
      const { data } = await sb
        .from("homework")
        .select("id, title, due_date")
        .eq("school_id", schoolId)
        .ilike("title", like(t))
        .order("due_date", { ascending: false })
        .limit(PER_GROUP);
      return (data ?? []).map((h) => ({ type: "homework", label: h.title, sub: `Due ${h.due_date}`, href: `/homework/${h.id}` }));
    },
  },
  announcements: {
    title: "Announcements",
    run: async (sb, schoolId, t) => {
      const { data } = await sb
        .from("announcements")
        .select("id, title, audience")
        .eq("school_id", schoolId)
        .ilike("title", like(t))
        .order("created_at", { ascending: false })
        .limit(PER_GROUP);
      return (data ?? []).map((a) => ({ type: "announcement", label: a.title, sub: a.audience, href: `/notices/${a.id}` }));
    },
  },
  exams: {
    title: "Exam terms",
    run: async (sb, schoolId, t) => {
      const { data } = await sb
        .from("exam_terms")
        .select("id, name, is_published")
        .eq("school_id", schoolId)
        .ilike("name", like(t))
        .order("created_at", { ascending: false })
        .limit(PER_GROUP);
      return (data ?? []).map((e) => ({ type: "exam", label: e.name, sub: e.is_published ? "Published" : "Draft", href: `/exams/${e.id}` }));
    },
  },
  feeStructures: {
    title: "Fees",
    run: async (sb, schoolId, t) => {
      const { data } = await sb
        .from("fee_structures")
        .select("id, name")
        .eq("school_id", schoolId)
        .eq("is_transport", false)
        .ilike("name", like(t))
        .limit(PER_GROUP);
      return (data ?? []).map((f) => ({ type: "fee", label: f.name, href: "/settings/fees" }));
    },
  },
  transport: {
    title: "Bus routes",
    run: async (sb, schoolId, t) => {
      const { data } = await sb
        .from("bus_routes")
        .select("id, name")
        .eq("school_id", schoolId)
        .ilike("name", like(t))
        .limit(PER_GROUP);
      return (data ?? []).map((r) => ({ type: "route", label: r.name, href: "/transport" }));
    },
  },
  schools: {
    title: "Schools",
    run: async (sb, _schoolId, t) => {
      const { data } = await sb
        .from("schools")
        .select("id, name, city")
        .ilike("name", like(t))
        .limit(PER_GROUP);
      return (data ?? []).map((s) => ({ type: "school", label: s.name, sub: s.city ?? undefined, href: `/platform/schools/${s.id}` }));
    },
  },
};

/** Which entities the search covers on a given route. Dashboard/other = global. */
function keysForPath(path: string): string[] {
  if (path.startsWith("/platform")) return ["schools"];
  if (path.startsWith("/students")) return ["students"];
  if (path.startsWith("/attendance")) return ["students"];
  if (path.startsWith("/exams")) return ["exams", "students"];
  if (path.startsWith("/homework")) return ["homework"];
  if (path.startsWith("/timetable")) return ["classes", "subjects"];
  if (path.startsWith("/notices")) return ["announcements"];
  if (path.startsWith("/leave")) return ["students"];
  if (path.startsWith("/settings/fees")) return ["students", "feeStructures"];
  if (path.startsWith("/settings/classes")) return ["classes", "subjects"];
  if (path.startsWith("/settings/staff")) return ["staff"];
  if (path.startsWith("/settings/roles")) return ["staff", "subjects"];
  if (path.startsWith("/transport")) return ["transport", "students"];
  if (path.startsWith("/messages")) return ["staff", "students"];
  return ["students", "staff", "classes", "subjects", "homework", "announcements", "exams"];
}

export async function searchApp(pathname: string, query: string): Promise<SearchGroup[]> {
  const term = query.replace(/[%,()*\\]/g, " ").trim();
  if (term.length < 2) return [];

  const supabase = await createClient();
  const keys = keysForPath(pathname);

  // Platform (super_admin) has no school membership; school scopes need one.
  let schoolId = "";
  if (!(keys.length === 1 && keys[0] === "schools")) {
    const membership = await getActiveMembership();
    if (!membership) return [];
    schoolId = membership.schoolId;
  }

  const groups = await Promise.all(
    keys.map(async (k) => {
      const s = SEARCHERS[k];
      if (!s) return null;
      const items = await s.run(supabase, schoolId, term).catch(() => []);
      return items.length ? { title: s.title, items } : null;
    })
  );
  return groups.filter((g): g is SearchGroup => g !== null);
}
