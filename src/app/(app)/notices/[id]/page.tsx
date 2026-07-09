import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { ArrowLeft, Megaphone, Paperclip, Download, Eye, Users, Calendar } from "lucide-react";
import { requireActiveMembership, getAuthUser } from "@/lib/auth/session";
import { createClient } from "@/lib/supabase/server";
import { Badge } from "@/components/ui/badge";
import { DeleteNoticeButton } from "./delete-notice-button";

function fmt(d: string) {
  return new Date(d).toLocaleDateString("en-IN", {
    weekday: "long",
    day: "numeric",
    month: "long",
    year: "numeric",
  });
}

const AUDIENCE_BADGE: Record<string, { label: string; variant: "secondary" | "warning" | "success" | "info" }> = {
  school: { label: "Whole school", variant: "info" },
  class: { label: "Class", variant: "secondary" },
  section: { label: "Section", variant: "secondary" },
  individual: { label: "Individual", variant: "success" },
};

export default async function NoticeDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const membership = await requireActiveMembership();
  if (membership.role === "parent") redirect("/dashboard");
  const supabase = await createClient();

  const { data: notice } = await supabase
    .from("announcements")
    .select(
      "id, title, body, audience, published_at, attachment_url, created_by, profiles(full_name), announcement_targets(class_id, section_id, student_id, classes(name), sections(name, classes(name)), students(first_name, last_name))"
    )
    .eq("id", id)
    .eq("school_id", membership.schoolId)
    .maybeSingle();
  if (!notice) notFound();

  const { count: readCount } = await supabase
    .from("announcement_reads")
    .select("id", { count: "exact", head: true })
    .eq("announcement_id", id);

  // Human-readable target.
  const target = (notice.announcement_targets as
    | {
        class_id: string | null;
        section_id: string | null;
        student_id: string | null;
        classes: { name: string } | null;
        sections: { name: string; classes: { name: string } | null } | null;
        students: { first_name: string; last_name: string | null } | null;
      }[]
    | null)?.[0];
  let targetText = "The whole school";
  if (notice.audience === "class" && target?.classes) targetText = `Class ${target.classes.name}`;
  else if (notice.audience === "section" && target?.sections)
    targetText = `${target.sections.classes?.name ?? ""} · ${target.sections.name}`;
  else if (notice.audience === "individual" && target?.students)
    targetText = `${target.students.first_name} ${target.students.last_name ?? ""}`.trim();

  let attachmentUrl: string | null = null;
  let attachmentName: string | null = null;
  if (notice.attachment_url) {
    const { data: signed } = await supabase.storage
      .from("notices")
      .createSignedUrl(notice.attachment_url, 3600);
    attachmentUrl = signed?.signedUrl ?? null;
    attachmentName =
      notice.attachment_url.split("/").pop()?.replace(/^[0-9a-f-]{36}-/, "") ?? "Attachment";
  }

  const user = await getAuthUser();
  const canManage = membership.role === "school_admin" || notice.created_by === user?.id;
  const badge = AUDIENCE_BADGE[notice.audience] ?? AUDIENCE_BADGE.section;

  return (
    <div className="mx-auto max-w-3xl space-y-6 pb-8">
      <Link
        href="/notices"
        className="group inline-flex items-center gap-1.5 text-sm text-slate-500 transition-colors hover:text-slate-900"
      >
        <ArrowLeft className="size-4 transition-transform group-hover:-translate-x-0.5" /> All announcements
      </Link>

      <div className="overflow-hidden rounded-2xl border border-slate-200/80 bg-white shadow-sm shadow-slate-950/5 ring-1 ring-slate-900/[0.02]">
        {/* Header with icon */}
        <div className="border-b border-slate-100 px-6 pt-6 pb-5">
          <div className="flex flex-wrap items-start justify-between gap-4">
            <div className="flex min-w-0 items-start gap-4">
              <span className="flex size-12 shrink-0 items-center justify-center rounded-2xl bg-blue-50 text-blue-700 ring-1 ring-blue-100">
                <Megaphone className="size-6" />
              </span>
              <div className="min-w-0">
                <div className="flex items-center gap-3">
                  <h1 className="truncate text-xl font-bold tracking-tight text-slate-900">
                    {notice.title}
                  </h1>
                  <Badge variant={badge.variant} className="shrink-0">
                    {badge.label}
                  </Badge>
                </div>
                <div className="mt-3 flex flex-wrap items-center gap-x-5 gap-y-1.5 text-sm text-slate-500">
                  <span className="inline-flex items-center gap-1.5">
                    <Users className="size-3.5" />
                    {targetText}
                  </span>
                  <span className="inline-flex items-center gap-1.5">
                    <Eye className="size-3.5" />
                    {readCount ?? 0} read
                  </span>
                  <span className="inline-flex items-center gap-1.5">
                    <Calendar className="size-3.5" />
                    {fmt(notice.published_at)}
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Body */}
        <div className="px-6 py-6">
          <div className="rounded-xl border border-slate-200/60 bg-slate-50/60 p-5">
            <p className="text-sm leading-relaxed whitespace-pre-wrap text-slate-700">
              {notice.body}
            </p>
          </div>

          {/* Attachment */}
          {attachmentUrl && (
            <a
              href={attachmentUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="group mt-5 flex items-center gap-3 rounded-xl border border-slate-200/80 bg-white px-4 py-3 shadow-sm transition-all hover:border-blue-200 hover:shadow-md"
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
        </div>

        {/* Footer */}
        <div className="flex items-center justify-between border-t border-slate-100 px-6 py-4">
          <div className="flex items-center gap-2 text-xs text-slate-500">
            <span className="inline-flex size-1.5 rounded-full bg-slate-300" />
            Posted by {(notice.profiles as { full_name: string | null } | null)?.full_name ?? "Staff"}
          </div>
          {canManage && <DeleteNoticeButton id={notice.id} title={notice.title} />}
        </div>
      </div>
    </div>
  );
}
