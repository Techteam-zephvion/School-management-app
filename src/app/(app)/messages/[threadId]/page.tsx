import { notFound, redirect } from "next/navigation";
import { requireActiveMembership, getAuthUser } from "@/lib/auth/session";
import { createClient } from "@/lib/supabase/server";
import { markThreadRead } from "@/lib/actions/messages";
import { ThreadView } from "./thread-view";

export default async function MessageThreadPage({ params }: { params: Promise<{ threadId: string }> }) {
  const { threadId } = await params;
  const membership = await requireActiveMembership();
  if (membership.role === "parent") redirect("/dashboard");
  const supabase = await createClient();
  const user = await getAuthUser();
  const me = user?.id ?? "";

  const { data: thread } = await supabase
    .from("message_threads")
    .select("id, subject, student_id, students(first_name, last_name), thread_participants(user_id, profiles(full_name))")
    .eq("id", threadId)
    .maybeSingle();
  if (!thread) notFound();

  const { data: messages } = await supabase
    .from("messages")
    .select("id, sender_id, body, created_at")
    .eq("thread_id", threadId)
    .order("created_at");

  // Mark everything read now that the thread is open.
  await markThreadRead(threadId);

  const student = thread.students as { first_name: string; last_name: string | null } | null;
  const participants = ((thread.thread_participants as { user_id: string; profiles: { full_name: string | null } | null }[] | null) ?? []).map(
    (p) => ({ userId: p.user_id, name: p.profiles?.full_name || "Guardian" })
  );
  const others = participants.filter((p) => p.userId !== me).map((p) => p.name);
  const nameByUser = Object.fromEntries(participants.map((p) => [p.userId, p.name]));

  return (
    <ThreadView
      threadId={threadId}
      me={me}
      title={others.length ? others.join(", ") : "Conversation"}
      studentName={student ? `${student.first_name} ${student.last_name ?? ""}`.trim() : null}
      nameByUser={nameByUser}
      initialMessages={(messages ?? []).map((m) => ({
        id: m.id,
        sender_id: m.sender_id ?? "",
        body: m.body,
        created_at: m.created_at,
      }))}
    />
  );
}
