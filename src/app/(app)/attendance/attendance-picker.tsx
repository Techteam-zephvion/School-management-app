"use client";

import { useRouter } from "next/navigation";
import { useTransition } from "react";
import { Card, CardContent } from "@/components/ui/card";
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
    <Card>
      <CardContent className="grid gap-3 py-4 sm:grid-cols-[1fr_auto] sm:items-end">
        <div className="space-y-1.5">
          <Label>Class / session</Label>
          <Select
            value={selectedKey}
            onValueChange={(v) => go(v, date)}
            disabled={isPending}
          >
            <SelectTrigger className="w-full">
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
          <Label htmlFor="att-date">Date</Label>
          <Input
            id="att-date"
            type="date"
            value={date}
            max={new Date().toISOString().slice(0, 10)}
            onChange={(e) => go(selectedKey, e.target.value)}
            disabled={isPending}
            className="w-full sm:w-44"
          />
        </div>
      </CardContent>
    </Card>
  );
}
