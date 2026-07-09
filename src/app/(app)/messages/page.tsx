import Link from "next/link";
import { redirect } from "next/navigation";
import { MessagesSquare, ChevronRight } from "lucide-react";
import { requireActiveMembership, getAuthUser } from "@/lib/auth/session";
import { createClient } from "@/lib/supabase/server";
import { PageHeader } from "@/components/page-header";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import { NewMessageDialog } from "./new-message-dialog";

export type StudentPick = { id: string; label: string };

function initials(name: string) {
  return name.split(/\s+/).map((p) => p[0]).slice(0, 2).join("").toUpperCase() || "?";
}
function timeago(iso: string) {
  const diff = Date.now() - new Date(iso).getTime();
  const m = Math.floor(diff / 60000);
  if (m < 1) return "now";
  if (m < 60) return `${m}m`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h`;
  return new Date(iso).toLocaleDateString("en-IN", { day: "2-digit", month: "short" });
}

export default async function MessagesPage() {
  const membership = await requireActiveMembership();
  if (membership.role === "parent") redirect("/dashboard");
  const supabase = await createClient();
  const schoolId = membership.schoolId;
  const user = await getAuthUser();
  const me = user?.id ?? "";
  const isAdmin = membership.role === "school_admin";

  const { data: activeYear } = await supabase
    .from("academic_years")
    .select("id")
    .eq("school_id", schoolId)
    .eq("is_active", true)
    .maybeSingle();

  // ---- student picker (for starting a thread), scoped by role ----
  let students: StudentPick[] = [];
  if (activeYear) {
    const { data: enrollments } = await supabase
      .from("enrollments")
      .select("section_id, students(id, first_name, last_name), sections(name, class_teacher_staff_id, classes(name))")
      .eq("school_id", schoolId)
      .eq("academic_year_id", activeYear.id)
      .eq("status", "active");

    let allowed: Set<string> | null = null;
    if (!isAdmin) {
      const { data: staff } = await supabase
        .from("staff")
        .select("id")
        .eq("school_id", schoolId)
        .eq("user_id", me)
        .maybeSingle();
      const ids = new Set<string>();
      if (staff) {
        for (const e of enrollments ?? []) {
          if ((e.sections as { class_teacher_staff_id: string | null } | null)?.class_teacher_staff_id === staff.id)
            ids.add(e.section_id);
        }
        const { data: assignments } = await supabase
          .from("teacher_assignments")
          .select("section_id")
          .eq("staff_id", staff.id)
          .eq("academic_year_id", activeYear.id);
        for (const a of assignments ?? []) ids.add(a.section_id);
      }
      allowed = ids;
    }

    students = (enrollments ?? [])
      .filter((e) => allowed === null || allowed.has(e.section_id))
      .map((e) => {
        const st = e.students as { id: string; first_name: string; last_name: string | null } | null;
        const sec = e.sections as { name: string; classes: { name: string } | null } | null;
        return st
          ? { id: st.id, label: `${st.first_name} ${st.last_name ?? ""}`.trim() + ` — ${sec?.classes?.name ?? ""} · ${sec?.name ?? ""}` }
          : null;
      })
      .filter((s): s is StudentPick => s !== null)
      .sort((a, b) => a.label.localeCompare(b.label));
  }

  // ---- my threads (RLS returns only threads I participate in) ----
  const { data: threads } = await supabase
    .from("message_threads")
    .select("id, subject, last_message_at, student_id, students(first_name, last_name), thread_participants(user_id, profiles(full_name))")
    .order("last_message_at", { ascending: false });

  const threadIds = (threads ?? []).map((t) => t.id);
  const [{ data: msgs }, { data: reads }] = await Promise.all([
    threadIds.length
      ? supabase.from("messages").select("id, thread_id, sender_id, body, created_at").in("thread_id", threadIds).order("created_at")
      : Promise.resolve({ data: [] as { id: string; thread_id: string; sender_id: string; body: string; created_at: string }[] }),
    supabase.from("message_reads").select("message_id"),
  ]);

  const readSet = new Set((reads ?? []).map((r) => r.message_id));
  const lastByThread = new Map<string, { body: string; created_at: string }>();
  const unreadByThread = new Map<string, number>();
  for (const m of msgs ?? []) {
    lastByThread.set(m.thread_id, { body: m.body, created_at: m.created_at });
    if (m.sender_id !== me && !readSet.has(m.id)) {
      unreadByThread.set(m.thread_id, (unreadByThread.get(m.thread_id) ?? 0) + 1);
    }
  }

  const rows = (threads ?? []).map((t) => {
    const student = t.students as { first_name: string; last_name: string | null } | null;
    const others = ((t.thread_participants as { user_id: string; profiles: { full_name: string | null } | null }[] | null) ?? [])
      .filter((p) => p.user_id !== me)
      .map((p) => p.profiles?.full_name || "Guardian");
    const last = lastByThread.get(t.id);
    return {
      id: t.id,
      title: others.length ? others.join(", ") : "Conversation",
      studentName: student ? `${student.first_name} ${student.last_name ?? ""}`.trim() : null,
      preview: last?.body ?? t.subject ?? "",
      at: last?.created_at ?? t.last_message_at,
      unread: unreadByThread.get(t.id) ?? 0,
    };
  });

  return (
    <div className="mx-auto max-w-5xl space-y-6 pb-8">
      <PageHeader
        title="Messages"
        description="Private conversations with parents."
        action={students.length > 0 ? <NewMessageDialog students={students} /> : undefined}
      />

      <Card className="overflow-hidden border border-slate-200/80 bg-white shadow-sm shadow-slate-950/5 ring-1 ring-slate-900/[0.02]">
        {/* Card header */}
        <div className="flex items-center gap-3 border-b border-slate-100 px-5 py-4">
          <span className="flex size-9 items-center justify-center rounded-xl bg-blue-50 text-blue-700 ring-1 ring-blue-100">
            <MessagesSquare className="size-4.5" />
          </span>
          <div>
            <h2 className="text-base font-semibold text-slate-900">Conversations</h2>
            <p className="text-xs text-slate-500">
              {rows.length} thread{rows.length !== 1 ? "s" : ""}
            </p>
          </div>
        </div>

        <CardContent className="divide-y divide-slate-100 p-0">
          {rows.length === 0 ? (
            <div className="flex flex-col items-center gap-4 px-5 py-16 text-center">
              <span className="flex size-12 items-center justify-center rounded-2xl bg-slate-50 text-slate-400 ring-1 ring-slate-200">
                <MessagesSquare className="size-5" />
              </span>
              <div>
                <p className="text-sm font-medium text-slate-700">No conversations yet</p>
                <p className="mt-0.5 text-xs text-slate-500">Start a message to a parent above.</p>
              </div>
            </div>
          ) : (
            rows.map((r) => (
              <Link
                key={r.id}
                href={`/messages/${r.id}`}
                className="group flex items-center gap-4 px-5 py-4 transition-colors hover:bg-blue-50/50"
              >
                <Avatar className="size-10 shrink-0">
                  <AvatarFallback className={r.unread > 0 ? "bg-blue-50 text-blue-700 ring-1 ring-blue-100" : "bg-slate-100 text-slate-500"}>
                    {initials(r.title)}
                  </AvatarFallback>
                </Avatar>
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2">
                    <p className={`truncate text-sm ${r.unread > 0 ? "font-bold text-slate-900" : "font-semibold text-slate-900"}`}>
                      {r.title}
                    </p>
                    {r.studentName && (
                      <span className="shrink-0 rounded-full bg-blue-50 px-2 py-0.5 text-[11px] font-medium text-blue-700 ring-1 ring-blue-100">
                        re: {r.studentName}
                      </span>
                    )}
                  </div>
                  <p className={`mt-0.5 truncate text-xs ${r.unread > 0 ? "font-medium text-slate-700" : "text-slate-500"}`}>
                    {r.preview}
                  </p>
                </div>
                <div className="flex shrink-0 flex-col items-end gap-1.5">
                  <span className="text-xs text-slate-400">{timeago(r.at)}</span>
                  {r.unread > 0 ? (
                    <Badge variant="default" className="h-5 min-w-5 justify-center rounded-full px-1.5 text-xs">
                      {r.unread}
                    </Badge>
                  ) : (
                    <ChevronRight className="size-4 text-slate-300 transition-colors group-hover:text-slate-500" />
                  )}
                </div>
              </Link>
            ))
          )}
        </CardContent>
      </Card>
    </div>
  );
}
