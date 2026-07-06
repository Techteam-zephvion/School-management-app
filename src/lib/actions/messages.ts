"use server";

import { z } from "zod";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { getAuthUser } from "@/lib/auth/session";

export type SentMessage = {
  id: string;
  sender_id: string;
  body: string;
  created_at: string;
};

const startSchema = z.object({
  studentId: z.string().uuid({ error: "Choose a student." }),
  subject: z.string().trim().optional(),
  body: z.string().trim().min(1, { error: "Write a message." }),
});

/** Staff starts (or reuses) a thread with a student's guardians. Returns the
 *  thread id so the caller can navigate to it. */
export async function startThread(
  input: { studentId: string; subject?: string; body: string }
): Promise<{ threadId: string } | { error: string }> {
  const parsed = startSchema.safeParse(input);
  if (!parsed.success) return { error: parsed.error.issues[0]?.message ?? "Invalid input." };

  const supabase = await createClient();
  const { data, error } = await supabase.rpc("start_thread_with_guardians", {
    p_student: parsed.data.studentId,
    p_subject: parsed.data.subject ?? "",
    p_body: parsed.data.body,
  });
  if (error) {
    return {
      error: /no linked guardians/i.test(error.message)
        ? "This student has no linked guardians to message yet."
        : /not authorized/i.test(error.message)
          ? "You can't message this student's guardians."
          : error.message,
    };
  }
  revalidatePath("/messages");
  return { threadId: data as string };
}

export async function sendMessage(
  threadId: string,
  body: string
): Promise<{ message: SentMessage } | { error: string }> {
  const trimmed = body.trim();
  if (trimmed.length === 0) return { error: "Message is empty." };
  const user = await getAuthUser();
  if (!user) return { error: "You are not signed in." };

  const supabase = await createClient();
  const { data: thread } = await supabase
    .from("message_threads")
    .select("school_id")
    .eq("id", threadId)
    .maybeSingle();
  if (!thread) return { error: "Conversation not found." };

  const { data, error } = await supabase
    .from("messages")
    .insert({ school_id: thread.school_id, thread_id: threadId, sender_id: user.id, body: trimmed })
    .select("id, sender_id, body, created_at")
    .single();
  if (error) return { error: error.message };

  revalidatePath("/messages");
  return { message: data as SentMessage };
}

/** Mark every message in the thread that the current user hasn't authored as read. */
export async function markThreadRead(threadId: string): Promise<void> {
  const user = await getAuthUser();
  if (!user) return;
  const supabase = await createClient();

  const { data: unread } = await supabase
    .from("messages")
    .select("id")
    .eq("thread_id", threadId)
    .neq("sender_id", user.id);
  if (!unread || unread.length === 0) return;

  await supabase
    .from("message_reads")
    .upsert(
      unread.map((m) => ({ message_id: m.id, user_id: user.id })),
      { onConflict: "message_id,user_id", ignoreDuplicates: true }
    );
  revalidatePath("/messages");
}
