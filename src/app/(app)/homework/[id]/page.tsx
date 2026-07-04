import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { ArrowLeft, CalendarClock, Paperclip, Download } from "lucide-react";
import { requireActiveMembership, getAuthUser } from "@/lib/auth/session";
import { createClient } from "@/lib/supabase/server";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
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
    <div className="mx-auto max-w-2xl space-y-6">
      <Link
        href="/homework"
        className="inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground"
      >
        <ArrowLeft className="size-4" /> All homework
      </Link>

      <Card>
        <CardHeader className="space-y-3">
          <div className="flex flex-wrap items-start justify-between gap-3">
            <div>
              <CardTitle className="text-xl">{hw.title}</CardTitle>
              <p className="mt-1 text-sm text-muted-foreground">
                {section?.classes?.name} · {section?.name} ·{" "}
                {(hw.subjects as { name: string } | null)?.name}
              </p>
            </div>
            <Badge variant={overdue ? "destructive" : "secondary"} className="gap-1">
              <CalendarClock className="size-3" />
              {overdue ? "Overdue" : "Due"} {fmt(hw.due_date)}
            </Badge>
          </div>
        </CardHeader>
        <CardContent className="space-y-5">
          {hw.description ? (
            <p className="text-sm leading-relaxed whitespace-pre-wrap text-foreground">
              {hw.description}
            </p>
          ) : (
            <p className="text-sm text-muted-foreground">No further details.</p>
          )}

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
              Posted by {(hw.profiles as { full_name: string | null } | null)?.full_name ?? "Staff"}
            </p>
            {canManage && <DeleteHomeworkButton id={hw.id} />}
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
