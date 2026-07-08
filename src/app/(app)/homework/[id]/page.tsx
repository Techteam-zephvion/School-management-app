import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { ArrowLeft, CalendarClock, Paperclip, Download, BookOpen } from "lucide-react";
import { requireActiveMembership, getAuthUser } from "@/lib/auth/session";
import { createClient } from "@/lib/supabase/server";
import { Badge } from "@/components/ui/badge";
import { DeleteHomeworkButton } from "./delete-homework-button";

function fmt(d: string) {
  return new Date(d + "T00:00:00").toLocaleDateString("en-IN", {
    weekday: "long",
    day: "numeric",
    month: "long",
    year: "numeric",
  });
}

export default async function HomeworkDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const membership = await requireActiveMembership();
  if (membership.role === "parent") redirect("/dashboard");
  const supabase = await createClient();

  const { data: hw } = await supabase
    .from("homework")
    .select(
      "id, title, description, due_date, attachment_url, section_id, subject_id, created_by, sections(name, class_teacher_staff_id, classes(name)), subjects(name), profiles(full_name)"
    )
    .eq("id", id)
    .eq("school_id", membership.schoolId)
    .maybeSingle();
  if (!hw) notFound();

  const section = hw.sections as
    | { name: string; class_teacher_staff_id: string | null; classes: { name: string } | null }
    | null;
  const overdue = hw.due_date < new Date().toISOString().slice(0, 10);

  // A signed URL for the private attachment (valid ~1h).
  let attachmentUrl: string | null = null;
  let attachmentName: string | null = null;
  if (hw.attachment_url) {
    const { data: signed } = await supabase.storage
      .from("homework")
      .createSignedUrl(hw.attachment_url, 3600);
    attachmentUrl = signed?.signedUrl ?? null;
    attachmentName = hw.attachment_url.split("/").pop()?.replace(/^[0-9a-f-]{36}-/, "") ?? "Attachment";
  }

  // Can this user manage (delete) it? Admin, the creator, or the class teacher.
  const user = await getAuthUser();
  const isAdmin = membership.role === "school_admin";
  let canManage = isAdmin || hw.created_by === user?.id;
  if (!canManage && section?.class_teacher_staff_id) {
    const { data: staff } = await supabase
      .from("staff")
      .select("id")
      .eq("school_id", membership.schoolId)
      .eq("user_id", user?.id ?? "")
      .maybeSingle();
    canManage = Boolean(staff) && section.class_teacher_staff_id === staff!.id;
  }

  return (
    <div className="mx-auto max-w-3xl space-y-6">
      <Link
        href="/homework"
        className="group inline-flex items-center gap-1.5 text-sm text-slate-500 transition-colors hover:text-slate-900"
      >
        <ArrowLeft className="size-4 transition-transform group-hover:-translate-x-0.5" /> All homework
      </Link>

      <div className="rounded-2xl border border-slate-200/80 bg-white shadow-sm shadow-slate-950/5 ring-1 ring-slate-900/[0.02]">

        <div className="space-y-6 p-6">
          {/* Header */}
          <div className="flex flex-wrap items-start justify-between gap-4">
            <div className="min-w-0 flex-1">
              <div className="flex items-center gap-3">
                <span className="flex size-10 shrink-0 items-center justify-center rounded-xl bg-blue-50 text-blue-700 ring-1 ring-blue-100">
                  <BookOpen className="size-5" />
                </span>
                <div>
                  <h1 className="text-lg font-bold tracking-tight text-slate-900">{hw.title}</h1>
                  <p className="mt-0.5 text-xs text-slate-500">
                    {section?.classes?.name} · {section?.name} ·{" "}
                    {(hw.subjects as { name: string } | null)?.name}
                  </p>
                </div>
              </div>
            </div>
            <Badge
              variant={overdue ? "destructive" : "secondary"}
              className="shrink-0 gap-1.5 px-3 py-1.5 text-xs font-medium"
            >
              <CalendarClock className="size-3.5" />
              {overdue ? "Overdue" : "Due"} {fmt(hw.due_date)}
            </Badge>
          </div>

          {/* Description */}
          <div className="rounded-xl border border-slate-200/60 bg-slate-50/60 p-5">
            <div className="mb-3 flex items-center gap-2">
              <span className="flex size-6 items-center justify-center rounded-lg bg-blue-100 text-blue-700 ring-1 ring-blue-200">
                <BookOpen className="size-3" />
              </span>
              <span className="text-xs font-semibold uppercase tracking-wide text-slate-600">Details</span>
            </div>
            {hw.description ? (
              <p className="text-sm leading-relaxed whitespace-pre-wrap text-slate-700">
                {hw.description}
              </p>
            ) : (
              <p className="text-sm italic text-slate-400">No further details provided.</p>
            )}
          </div>

          {/* Attachment */}
          {attachmentUrl && (
            <a
              href={attachmentUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="group flex items-center gap-3 rounded-xl border border-slate-200/80 bg-white px-4 py-3 shadow-sm transition-all hover:border-blue-200 hover:shadow-md"
            >
              <span className="flex size-9 shrink-0 items-center justify-center rounded-lg bg-blue-50 text-blue-700 ring-1 ring-blue-100">
                <Paperclip className="size-4.5" />
              </span>
              <span className="min-w-0 flex-1">
                <p className="truncate text-sm font-medium text-slate-900">{attachmentName}</p>
                <p className="text-xs text-slate-500">Click to download</p>
              </span>
              <span className="flex size-8 items-center justify-center rounded-lg bg-slate-50 text-slate-400 ring-1 ring-slate-200 transition-colors group-hover:bg-blue-50 group-hover:text-blue-600 group-hover:ring-blue-100">
                <Download className="size-4" />
              </span>
            </a>
          )}

          {/* Footer */}
          <div className="flex items-center justify-between border-t border-slate-100 pt-5">
            <div className="flex items-center gap-2 text-xs text-slate-500">
              <span className="inline-flex size-1.5 rounded-full bg-slate-300" />
              Posted by {(hw.profiles as { full_name: string | null } | null)?.full_name ?? "Staff"}
            </div>
            {canManage && <DeleteHomeworkButton id={hw.id} title={hw.title} />}
          </div>
        </div>
      </div>
    </div>
  );
}
