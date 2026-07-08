"use client";

import { useRouter } from "next/navigation";
import { useTransition } from "react";
import { Label } from "@/components/ui/label";
import { Input } from "@/components/ui/input";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

type Target = { key: string; label: string };

export function AttendancePicker({
  targets,
  selectedKey,
  date,
}: {
  targets: Target[];
  selectedKey: string;
  date: string;
}) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();

  function go(nextTarget: string, nextDate: string) {
    const params = new URLSearchParams();
    if (nextTarget) params.set("target", nextTarget);
    params.set("date", nextDate);
    startTransition(() => router.push(`/attendance?${params.toString()}`));
  }

  return (
    <div className="rounded-2xl border border-slate-200/80 bg-white/95 p-4 shadow-sm shadow-slate-950/5 ring-1 ring-slate-900/[0.02] sm:p-5">
      <div className="grid gap-4 sm:grid-cols-[1fr_auto] sm:items-end">
        <div className="space-y-1.5">
          <Label className="text-xs font-semibold uppercase tracking-wide text-slate-500">
            Class / session
          </Label>
          <Select
            value={selectedKey}
            onValueChange={(v) => go(v, date)}
            disabled={isPending}
          >
            <SelectTrigger className="w-full border-slate-200/80 focus-visible:ring-blue-500">
              <SelectValue placeholder="Choose what to mark" />
            </SelectTrigger>
            <SelectContent>
              {targets.map((t) => (
                <SelectItem key={t.key} value={t.key}>
                  {t.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
        <div className="space-y-1.5">
          <Label
            htmlFor="att-date"
            className="text-xs font-semibold uppercase tracking-wide text-slate-500"
          >
            Date
          </Label>
          <Input
            id="att-date"
            type="date"
            value={date}
            max={new Date().toISOString().slice(0, 10)}
            onChange={(e) => go(selectedKey, e.target.value)}
            disabled={isPending}
            className="w-full border-slate-200/80 focus-visible:ring-blue-500 sm:w-44"
          />
        </div>
      </div>
    </div>
  );
}
