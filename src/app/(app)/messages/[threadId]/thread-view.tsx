"use client";

import { useEffect, useRef, useState, useTransition } from "react";
import Link from "next/link";
import { toast } from "sonner";
import { ArrowLeft, Send, Loader2 } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { sendMessage, type SentMessage } from "@/lib/actions/messages";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { cn } from "@/lib/utils";

type Message = { id: string; sender_id: string; body: string; created_at: string };

function fmtTime(iso: string) {
  return new Date(iso).toLocaleTimeString("en-IN", { hour: "numeric", minute: "2-digit" });
}
function dayLabel(iso: string) {
  return new Date(iso).toLocaleDateString("en-IN", { weekday: "long", day: "numeric", month: "long" });
}

export function ThreadView({
  threadId,
  me,
  title,
  studentName,
  nameByUser,
  initialMessages,
}: {
  threadId: string;
  me: string;
  title: string;
  studentName: string | null;
  nameByUser: Record<string, string>;
  initialMessages: Message[];
}) {
  const [messages, setMessages] = useState<Message[]>(initialMessages);
  const [body, setBody] = useState("");
  const [isPending, startTransition] = useTransition();
  const bottomRef = useRef<HTMLDivElement>(null);

  const add = (m: Message) =>
    setMessages((prev) => (prev.some((x) => x.id === m.id) ? prev : [...prev, m]));

  // Realtime: append new messages for this thread as they arrive.
  useEffect(() => {
    const supabase = createClient();
    let channel: ReturnType<typeof supabase.channel> | null = null;
    let cancelled = false;

    (async () => {
      const { data } = await supabase.auth.getSession();
      if (cancelled) return;
      if (data.session?.access_token) supabase.realtime.setAuth(data.session.access_token);
      channel = supabase
        .channel(`thread:${threadId}`)
        .on(
          "postgres_changes",
          { event: "INSERT", schema: "public", table: "messages", filter: `thread_id=eq.${threadId}` },
          (payload) => add(payload.new as Message)
        )
        .subscribe();
    })();

    return () => {
      cancelled = true;
      if (channel) supabase.removeChannel(channel);
    };
  }, [threadId]);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  function send() {
    const text = body.trim();
    if (!text) return;
    setBody("");
    startTransition(async () => {
      const result = await sendMessage(threadId, text);
      if ("error" in result) {
        toast.error(result.error);
        setBody(text);
      } else {
        add(result.message as SentMessage);
      }
    });
  }

  // Precompute which messages start a new day.
  const dayDividers = new Set<string>();
  {
    let prev = "";
    for (const m of messages) {
      const day = dayLabel(m.created_at);
      if (day !== prev) {
        dayDividers.add(m.id);
        prev = day;
      }
    }
  }

  return (
    <div className="mx-auto flex h-[calc(100vh-8rem)] max-w-2xl flex-col gap-4">
      {/* Header */}
      <div className="flex items-center gap-3">
        <Link
          href="/messages"
          aria-label="Back to messages"
          className="flex size-9 items-center justify-center rounded-lg text-slate-400 transition-colors hover:bg-slate-100 hover:text-slate-700"
        >
          <ArrowLeft className="size-4" />
        </Link>
        <div className="min-w-0">
          <p className="truncate text-sm font-semibold text-slate-900">{title}</p>
          {studentName && <p className="truncate text-xs text-slate-500">re: {studentName}</p>}
        </div>
      </div>

      {/* Chat card */}
      <Card className="flex min-h-0 flex-1 flex-col overflow-hidden border border-slate-200/80 bg-white shadow-sm shadow-slate-950/5 ring-1 ring-slate-900/[0.02]">
        <div className="flex-1 space-y-1 overflow-y-auto p-5">
          {messages.length === 0 && (
            <div className="flex h-full flex-col items-center justify-center gap-2 text-center">
              <p className="text-sm text-slate-400">No messages yet. Say hello.</p>
            </div>
          )}
          {messages.map((m) => {
            const mine = m.sender_id === me;
            const showDay = dayDividers.has(m.id);
            return (
              <div key={m.id}>
                {showDay && (
                  <div className="my-4 flex items-center justify-center">
                    <span className="rounded-full bg-slate-100 px-3 py-0.5 text-xs font-medium text-slate-500">
                      {dayLabel(m.created_at)}
                    </span>
                  </div>
                )}
                <div className={cn("flex", mine ? "justify-end" : "justify-start")}>
                  <div
                    className={cn(
                      "max-w-[78%] rounded-2xl px-3.5 py-2.5 text-sm",
                      mine
                        ? "rounded-br-sm bg-blue-600 text-white"
                        : "rounded-bl-sm bg-slate-100 text-slate-900"
                    )}
                  >
                    {!mine && (
                      <p className="mb-0.5 text-xs font-semibold text-slate-500">
                        {nameByUser[m.sender_id] ?? "Guardian"}
                      </p>
                    )}
                    <p className="whitespace-pre-wrap break-words leading-relaxed">{m.body}</p>
                    <p className={cn("mt-0.5 text-right text-[10px]", mine ? "text-blue-200" : "text-slate-400")}>
                      {fmtTime(m.created_at)}
                    </p>
                  </div>
                </div>
              </div>
            );
          })}
          <div ref={bottomRef} />
        </div>

        {/* Composer */}
        <div className="flex items-end gap-2 border-t border-slate-100 bg-white p-4">
          <Textarea
            value={body}
            onChange={(e) => setBody(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter" && !e.shiftKey) {
                e.preventDefault();
                send();
              }
            }}
            rows={1}
            placeholder="Write a message…  (Enter to send)"
            aria-label="Message"
            className="max-h-32 min-h-10 flex-1 resize-none rounded-xl border-slate-200 bg-slate-50/60"
          />
          <Button
            onClick={send}
            disabled={isPending || body.trim().length === 0}
            size="icon"
            aria-label="Send message"
            className="size-10 shrink-0 rounded-xl bg-primary text-primary-foreground hover:bg-primary/80"
          >
            {isPending ? <Loader2 className="size-4 animate-spin" /> : <Send className="size-4" />}
          </Button>
        </div>
      </Card>
    </div>
  );
}
