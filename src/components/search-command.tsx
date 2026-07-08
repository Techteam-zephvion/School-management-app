"use client";

import { useEffect, useMemo, useRef, useState, useTransition } from "react";
import { usePathname, useRouter } from "next/navigation";
import {
  Search,
  Loader2,
  User,
  UserCog,
  GraduationCap,
  BookOpen,
  Megaphone,
  FileSpreadsheet,
  Wallet,
  Bus,
  Building2,
  CornerDownLeft,
} from "lucide-react";
import { searchApp, type SearchGroup, type SearchItem } from "@/lib/actions/search";
import { Input } from "@/components/ui/input";
import { cn } from "@/lib/utils";

const ICONS: Record<string, React.ComponentType<{ className?: string }>> = {
  student: User,
  staff: UserCog,
  class: GraduationCap,
  subject: BookOpen,
  homework: BookOpen,
  announcement: Megaphone,
  exam: FileSpreadsheet,
  fee: Wallet,
  route: Bus,
  school: Building2,
};

function placeholderFor(path: string): string {
  if (path.startsWith("/platform")) return "Search schools…";
  if (path.startsWith("/students")) return "Search students…";
  if (path.startsWith("/attendance")) return "Search a student…";
  if (path.startsWith("/exams")) return "Search exams or students…";
  if (path.startsWith("/homework")) return "Search homework…";
  if (path.startsWith("/timetable")) return "Search classes or subjects…";
  if (path.startsWith("/notices")) return "Search announcements…";
  if (path.startsWith("/leave")) return "Search a student…";
  if (path.startsWith("/settings/fees")) return "Search students or fees…";
  if (path.startsWith("/settings/classes")) return "Search classes or subjects…";
  if (path.startsWith("/settings/staff")) return "Search staff…";
  if (path.startsWith("/settings/roles")) return "Search staff or subjects…";
  if (path.startsWith("/transport")) return "Search routes or students…";
  if (path.startsWith("/messages")) return "Search people…";
  return "Search students, classes, exams…";
}

export function SearchCommand() {
  const pathname = usePathname();
  const router = useRouter();
  const [q, setQ] = useState("");
  const [groups, setGroups] = useState<SearchGroup[]>([]);
  const [open, setOpen] = useState(false);
  const [active, setActive] = useState(0);
  const [pending, startTransition] = useTransition();
  const boxRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  // Number the items across groups for keyboard navigation.
  const { indexed, flat } = useMemo(() => {
    let count = 0;
    const indexed = groups.map((g) => ({
      title: g.title,
      items: g.items.map((it) => ({ item: it, i: count++ })),
    }));
    const flat = groups.flatMap((g) => g.items);
    return { indexed, flat };
  }, [groups]);

  // Debounced, route-aware search. All setState happens inside the async
  // timeout callback (not synchronously in the effect body).
  useEffect(() => {
    const term = q.trim();
    const h = setTimeout(() => {
      if (term.length < 2) {
        setGroups([]);
        return;
      }
      startTransition(async () => {
        const res = await searchApp(pathname, term);
        setGroups(res);
        setActive(0);
        setOpen(true);
      });
    }, 220);
    return () => clearTimeout(h);
  }, [q, pathname]);

  // Close on outside click.
  useEffect(() => {
    function onClick(e: MouseEvent) {
      if (boxRef.current && !boxRef.current.contains(e.target as Node)) setOpen(false);
    }
    document.addEventListener("mousedown", onClick);
    return () => document.removeEventListener("mousedown", onClick);
  }, []);

  // "/" focuses the search from anywhere (unless already typing in a field).
  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      const tag = (document.activeElement?.tagName ?? "").toLowerCase();
      if (e.key === "/" && tag !== "input" && tag !== "textarea") {
        e.preventDefault();
        inputRef.current?.focus();
      }
    }
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, []);

  function go(href: string) {
    setOpen(false);
    setQ("");
    setGroups([]);
    router.push(href);
  }

  function onKeyDown(e: React.KeyboardEvent) {
    if (e.key === "Escape") {
      setOpen(false);
      inputRef.current?.blur();
      return;
    }
    if (!open || flat.length === 0) return;
    if (e.key === "ArrowDown") {
      e.preventDefault();
      setActive((a) => (a + 1) % flat.length);
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      setActive((a) => (a - 1 + flat.length) % flat.length);
    } else if (e.key === "Enter") {
      e.preventDefault();
      const item = flat[active];
      if (item) go(item.href);
    }
  }

  const showPanel = open && q.trim().length >= 2;

  return (
    <div ref={boxRef} className="relative hidden max-w-sm flex-1 sm:block">
      <Search className="absolute top-1/2 left-3 size-4 -translate-y-1/2 text-muted-foreground" />
      <Input
        ref={inputRef}
        value={q}
        onChange={(e) => setQ(e.target.value)}
        onFocus={() => q.trim().length >= 2 && setOpen(true)}
        onKeyDown={onKeyDown}
        placeholder={placeholderFor(pathname)}
        className="pl-9"
        aria-label="Search"
        autoComplete="off"
      />
      {pending && <Loader2 className="absolute top-1/2 right-3 size-4 -translate-y-1/2 animate-spin text-muted-foreground" />}

      {showPanel && (
        <div className="absolute top-full left-0 z-50 mt-2 w-[22rem] max-w-[calc(100vw-2rem)] overflow-hidden rounded-xl border border-border/60 bg-popover shadow-lg">
          {flat.length === 0 ? (
            <p className="px-4 py-6 text-center text-sm text-muted-foreground">
              {pending ? "Searching…" : "No results"}
            </p>
          ) : (
            <div className="max-h-[22rem] overflow-y-auto py-1.5">
              {indexed.map((g) => (
                <div key={g.title} className="px-1.5 pb-1">
                  <p className="px-2.5 py-1 text-[11px] font-semibold tracking-wide text-muted-foreground uppercase">
                    {g.title}
                  </p>
                  {g.items.map(({ item, i }) => {
                    const Icon = ICONS[item.type] ?? Search;
                    return (
                      <button
                        key={`${item.type}-${i}`}
                        type="button"
                        onMouseEnter={() => setActive(i)}
                        onClick={() => go(item.href)}
                        className={cn(
                          "flex w-full items-center gap-2.5 rounded-lg px-2.5 py-2 text-left",
                          active === i ? "bg-accent text-accent-foreground" : "hover:bg-muted/60"
                        )}
                      >
                        <span className="flex size-7 shrink-0 items-center justify-center rounded-md bg-muted text-muted-foreground">
                          <Icon className="size-4" />
                        </span>
                        <span className="min-w-0 flex-1">
                          <span className="block truncate text-sm font-medium">{item.label}</span>
                          {item.sub && <span className="block truncate text-xs text-muted-foreground">{item.sub}</span>}
                        </span>
                        {active === i && <CornerDownLeft className="size-3.5 shrink-0 text-muted-foreground" />}
                      </button>
                    );
                  })}
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}

export type { SearchItem };
