import Link from "next/link";
import { redirect } from "next/navigation";
import { Megaphone, ChevronRight, Paperclip } from "lucide-react";
import { requireActiveMembership, getAuthUser } from "@/lib/auth/session";
import { createClient } from "@/lib/supabase/server";
import { PageHeader } from "@/components/page-header";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { ComposeNoticeDialog } from "./compose-notice-dialog";

export type ClassOption = { id: string; name: string };
export type SectionOption = { id: string; label: string };
export type StudentOption = { id: string; label: string };

function fmt(d: string) {
  return new Date(d).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" });
}

const AUDIENCE_BADGE: Record<string, { label: string; variant: "secondary" | "warning" | "success" | "info" }> = {
  school: { label: "Whole school", variant: "info" },
  class: { label: "Class", variant: "secondary" },
  section: { label: "Section", variant: "secondary" },
  individual: { label: "Individual", variant: "success" },
};

export default async function NoticesPage() {
  const membership = await requireActiveMembership();
  if (membership.role === "parent") redirect("/dashboard");
  const supabase = await createClient();
  const schoolId = membership.schoolId;
  const isAdmin = membership.role === "school_admin";

  const { data: activeYear } = await supabase
    .from("academic_years")
    .select("id")
    .eq("school_id", schoolId)
    .eq("is_active", true)
    .maybeSingle();

  // ---- compose options, scoped by role ----
  let classes: ClassOption[] = [];
  let sections: SectionOption[] = [];
  let students: StudentOption[] = [];

  if (activeYear) {
    const [{ data: allSections }, { data: enrollments }] = await Promise.all([
      supabase
        .from("sections")
        .select("id, name, class_id, class_teacher_staff_id, classes(name)")
        .eq("school_id", schoolId)
        .eq("academic_year_id", activeYear.id)
        .order("name"),
      supabase
        .from("enrollments")
        .select("section_id, students(id, first_name, last_name)")
        .eq("school_id", schoolId)
        .eq("academic_year_id", activeYear.id)
        .eq("status", "active"),
    ]);

    const sectionLabel = (s: { name: string; classes: { name: string } | null }) =>
      `${(s.classes as { name: string } | null)?.name ?? ""} · ${s.name}`;

    let allowedSectionIds: Set<string> | null = null; // null = all (admin)
    if (!isAdmin) {
      const user = await getAuthUser();
      const { data: staff } = await supabase
        .from("staff")
        .select("id")
        .eq("school_id", schoolId)
        .eq("user_id", user?.id ?? "")
        .maybeSingle();
      const ids = new Set<string>();
      if (staff) {
        for (const s of allSections ?? []) if (s.class_teacher_staff_id === staff.id) ids.add(s.id);
        const { data: assignments } = await supabase
          .from("teacher_assignments")
          .select("section_id")
          .eq("staff_id", staff.id)
          .eq("academic_year_id", activeYear.id);
        for (const a of assignments ?? []) ids.add(a.section_id);
      }
      allowedSectionIds = ids;
    }

    const visibleSections = (allSections ?? []).filter(
      (s) => allowedSectionIds === null || allowedSectionIds.has(s.id)
    );
    sections = visibleSections.map((s) => ({ id: s.id, label: sectionLabel(s) }));

    if (isAdmin) {
      const classMap = new Map<string, string>();
      for (const s of allSections ?? [])
        classMap.set(s.class_id, (s.classes as { name: string } | null)?.name ?? "Class");
      classes = [...classMap].map(([id, name]) => ({ id, name })).sort((a, b) => a.name.localeCompare(b.name));
    }

    const sectionLabelById = new Map(visibleSections.map((s) => [s.id, sectionLabel(s)]));
    students = (enrollments ?? [])
      .filter((e) => allowedSectionIds === null || allowedSectionIds.has(e.section_id))
      .map((e) => {
        const st = e.students as { id: string; first_name: string; last_name: string | null } | null;
        return st
          ? {
              id: st.id,
              label: `${st.first_name} ${st.last_name ?? ""}`.trim() + ` — ${sectionLabelById.get(e.section_id) ?? ""}`,
            }
          : null;
      })
      .filter((s): s is StudentOption => s !== null)
      .sort((a, b) => a.label.localeCompare(b.label));
  }

  // ---- notices list (RLS scopes it) + read counts ----
  const { data: notices } = await supabase
    .from("announcements")
    .select("id, title, audience, published_at, attachment_url")
    .eq("school_id", schoolId)
    .order("published_at", { ascending: false });

  const readCounts = new Map<string, number>();
  if (notices && notices.length > 0) {
    const { data: reads } = await supabase
      .from("announcement_reads")
      .select("announcement_id")
      .in(
        "announcement_id",
        notices.map((n) => n.id)
      );
    for (const r of reads ?? [])
      readCounts.set(r.announcement_id, (readCounts.get(r.announcement_id) ?? 0) + 1);
  }

  const canCompose = isAdmin || sections.length > 0;

  return (
    <div className="mx-auto max-w-5xl space-y-6 pb-8">
      <PageHeader
        title="Announcements"
        description="Notices for the whole school, a class, a section, or a single student."
        action={
          canCompose ? (
            <ComposeNoticeDialog
              isAdmin={isAdmin}
              schoolId={schoolId}
              classes={classes}
              sections={sections}
              students={students}
            />
          ) : undefined
        }
      />

      <Card className="overflow-hidden border border-slate-200/80 bg-white shadow-sm shadow-slate-950/5 ring-1 ring-slate-900/[0.02]">
        {/* Card header */}
        <div className="flex items-center gap-3 border-b border-slate-100 px-5 py-4">
          <span className="flex size-9 items-center justify-center rounded-xl bg-blue-50 text-blue-700 ring-1 ring-blue-100">
            <Megaphone className="size-4.5" />
          </span>
          <div>
            <h2 className="text-base font-semibold text-slate-900">All announcements</h2>
            <p className="text-xs text-slate-500">
              {notices?.length ?? 0} notice{(notices?.length ?? 0) !== 1 ? "s" : ""}
            </p>
          </div>
        </div>

        <CardContent className="divide-y divide-slate-100 p-0">
          {!notices || notices.length === 0 ? (
            <div className="flex flex-col items-center gap-4 px-5 py-16 text-center">
              <span className="flex size-12 items-center justify-center rounded-2xl bg-slate-50 text-slate-400 ring-1 ring-slate-200">
                <Megaphone className="size-5" />
              </span>
              <div>
                <p className="text-sm font-medium text-slate-700">No announcements yet</p>
                <p className="mt-0.5 text-xs text-slate-500">
                  {canCompose ? "Post your first notice above." : "Announcements will appear here once posted."}
                </p>
              </div>
            </div>
          ) : (
            notices.map((n) => {
              const badge = AUDIENCE_BADGE[n.audience] ?? AUDIENCE_BADGE.section;
              const reads = readCounts.get(n.id) ?? 0;
              return (
                <Link
                  key={n.id}
                  href={`/notices/${n.id}`}
                  className="group flex items-center gap-4 px-5 py-4 transition-colors hover:bg-blue-50/50"
                >
                  <span className="flex size-10 shrink-0 items-center justify-center rounded-2xl bg-blue-50 text-blue-700 ring-1 ring-blue-100 transition-colors group-hover:bg-blue-100">
                    <Megaphone className="size-5" />
                  </span>
                  <div className="min-w-0 flex-1">
                    <p className="flex items-center gap-1.5 truncate text-sm font-semibold text-slate-900">
                      {n.title}
                      {n.attachment_url && <Paperclip className="size-3.5 shrink-0 text-slate-400" />}
                    </p>
                    <p className="mt-0.5 truncate text-xs text-slate-500">
                      {fmt(n.published_at)}
                      {reads > 0 ? ` · ${reads} read` : " · Unread"}
                    </p>
                  </div>
                  <Badge variant={badge.variant} className="shrink-0">
                    {badge.label}
                  </Badge>
                  <ChevronRight className="size-4 shrink-0 text-slate-300 transition-colors group-hover:text-slate-500" />
                </Link>
              );
            })
          )}
        </CardContent>
      </Card>
    </div>
  );
}
