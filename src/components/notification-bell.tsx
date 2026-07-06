"use client";

import { useEffect, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import {
  Bell,
  BookOpen,
  ClipboardCheck,
  Megaphone,
  GraduationCap,
  MessagesSquare,
  Wallet,
  CalendarX2,
  CheckCheck,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { markNotificationRead, markAllNotificationsRead } from "@/lib/actions/notifications";
import { Button } from "@/components/ui/button";
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover";
import { cn } from "@/lib/utils";

export type AppNotification = {
  id: string;
  type: string;
  title: string;
  body: string | null;
  deeplink: string | null;
  read_at: string | null;
  created_at: string;
};

const ICON: Record<string, LucideIcon> = {
  homework: BookOpen,
  attendance: ClipboardCheck,
  notice: Megaphone,
  result: GraduationCap,
  message: MessagesSquare,
  fee: Wallet,
  leave: CalendarX2,
  system: Bell,
};

// schoolerp://homework/123 -> /homework/123 ; fees -> /settings/fees
function webPath(deeplink: string | null): string | null {
  if (!deeplink) return null;
  const path = deeplink.replace(/^schoolerp:\/\//, "");
  if (path === "fees" || path.startsWith("fees/")) return "/settings/fees";
  return `/${path}`;
}

function timeago(iso: string) {
  const m = Math.floor((Date.now() - new Date(iso).getTime()) / 60000);
  if (m < 1) return "now";
  if (m < 60) return `${m}m`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h`;
  return `${Math.floor(h / 24)}d`;
}

export function NotificationBell({
  userId,
  initial,
}: {
  userId: string;
  initial: AppNotification[];
}) {
  const router = useRouter();
  const [items, setItems] = useState<AppNotification[]>(initial);
  const [open, setOpen] = useState(false);
  const [, startTransition] = useTransition();

  const unread = items.filter((n) => !n.read_at).length;

  // Realtime: prepend new notifications for me as they arrive.
  useEffect(() => {
    const supabase = createClient();
    let channel: ReturnType<typeof supabase.channel> | null = null;
    let cancelled = false;
    (async () => {
      const { data } = await supabase.auth.getSession();
      if (cancelled) return;
      if (data.session?.access_token) supabase.realtime.setAuth(data.session.access_token);
      channel = supabase
        .channel(`notifications:${userId}`)
        .on(
          "postgres_changes",
          { event: "INSERT", schema: "public", table: "notifications", filter: `user_id=eq.${userId}` },
          (payload) => {
            const n = payload.new as AppNotification;
            setItems((prev) => (prev.some((x) => x.id === n.id) ? prev : [n, ...prev].slice(0, 30)));
          }
        )
        .subscribe();
    })();
    return () => {
      cancelled = true;
      if (channel) supabase.removeChannel(channel);
    };
  }, [userId]);

  function openItem(n: AppNotification) {
    if (!n.read_at) {
      setItems((prev) => prev.map((x) => (x.id === n.id ? { ...x, read_at: new Date().toISOString() } : x)));
      startTransition(() => markNotificationRead(n.id));
    }
    setOpen(false);
    const path = webPath(n.deeplink);
    if (path) router.push(path);
  }

  function markAll() {
    setItems((prev) => prev.map((x) => ({ ...x, read_at: x.read_at ?? new Date().toISOString() })));
    startTransition(() => markAllNotificationsRead());
  }

  return (
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger asChild>
        <Button variant="ghost" size="icon" aria-label={`Notifications${unread ? `, ${unread} unread` : ""}`} className="relative">
          <Bell className="size-5" />
          {unread > 0 && (
            <span className="absolute -top-0.5 -right-0.5 flex h-4 min-w-4 items-center justify-center rounded-full bg-destructive px-1 text-[10px] font-semibold text-white">
              {unread > 9 ? "9+" : unread}
            </span>
          )}
        </Button>
      </PopoverTrigger>
      <PopoverContent align="end" className="w-80 p-0">
        <div className="flex items-center justify-between border-b border-border px-4 py-2.5">
          <p className="text-sm font-semibold">Notifications</p>
          {unread > 0 && (
            <button
              type="button"
              onClick={markAll}
              className="inline-flex items-center gap-1 text-xs font-medium text-accent hover:underline"
            >
              <CheckCheck className="size-3.5" /> Mark all read
            </button>
          )}
        </div>
        <div className="max-h-96 overflow-y-auto">
          {items.length === 0 ? (
            <div className="flex flex-col items-center gap-2 py-10 text-center">
              <Bell className="size-7 text-muted-foreground/60" />
              <p className="text-sm text-muted-foreground">No notifications yet.</p>
            </div>
          ) : (
            items.map((n) => {
              const Icon = ICON[n.type] ?? Bell;
              return (
                <button
                  key={n.id}
                  type="button"
                  onClick={() => openItem(n)}
                  className={cn(
                    "flex w-full items-start gap-3 border-b border-border/50 px-4 py-3 text-left transition-colors last:border-0 hover:bg-muted/50",
                    !n.read_at && "bg-accent/5"
                  )}
                >
                  <span
                    className={cn(
                      "mt-0.5 flex size-8 shrink-0 items-center justify-center rounded-lg",
                      n.read_at ? "bg-muted text-muted-foreground" : "bg-primary/10 text-primary"
                    )}
                  >
                    <Icon className="size-4" />
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="flex items-center justify-between gap-2">
                      <span className={cn("truncate text-sm", n.read_at ? "font-medium" : "font-semibold")}>{n.title}</span>
                      <span className="shrink-0 text-[11px] text-muted-foreground">{timeago(n.created_at)}</span>
                    </span>
                    {n.body && <span className="mt-0.5 line-clamp-2 text-xs text-muted-foreground">{n.body}</span>}
                  </span>
                  {!n.read_at && <span className="mt-1.5 size-2 shrink-0 rounded-full bg-accent" />}
                </button>
              );
            })
          )}
        </div>
      </PopoverContent>
    </Popover>
  );
}
