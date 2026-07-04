import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { ArrowLeft, Paperclip, Download, Eye, Users } from "lucide-react";
import { requireActiveMembership, getAuthUser } from "@/lib/auth/session";
import { createClient } from "@/lib/supabase/server";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
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

const AUDIENCE_BADGE: Record<string, { label: string; variant: "secondary" | "warning" | "success" }> = {
  school: { label: "Whole school", variant: "warning" },
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
    <div className="mx-auto max-w-2xl space-y-6">
      <Link
        href="/notices"
        className="inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground"
      >
        <ArrowLeft className="size-4" /> All announcements
      </Link>

      <Card>
        <CardHeader className="space-y-3">
          <div className="flex flex-wrap items-start justify-between gap-3">
            <CardTitle className="text-xl">{notice.title}</CardTitle>
            <Badge variant={badge.variant}>{badge.label}</Badge>
          </div>
          <div className="flex flex-wrap items-center gap-x-4 gap-y-1 text-sm text-muted-foreground">
            <span className="inline-flex items-center gap-1.5">
              <Users className="size-3.5" /> {targetText}
            </span>
            <span className="inline-flex items-center gap-1.5">
              <Eye className="size-3.5" /> {readCount ?? 0} read
            </span>
          </div>
        </CardHeader>
        <CardContent className="space-y-5">
          <p className="text-sm leading-relaxed whitespace-pre-wrap text-foreground">{notice.body}</p>

          {attachmentUrl && (
            <a
              href={attachmentUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-2 rounded-lg border border-border bg-muted/40 px-3 py-2 text-sm font-medium transition-colors hover:bg-muted"
            >
              <Paperclip className="size-4 text-muted-foreground" />
              <span className="max-w-xs truncate">{attachmentName}</span>
              <Download className="size-4 text-muted-foreground" />
            </a>
          )}

          <div className="flex items-center justify-between border-t border-border pt-4">
            <p className="text-xs text-muted-foreground">
              {fmt(notice.published_at)} · by{" "}
              {(notice.profiles as { full_name: string | null } | null)?.full_name ?? "Staff"}
            </p>
            {canManage && <DeleteNoticeButton id={notice.id} title={notice.title} />}
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
