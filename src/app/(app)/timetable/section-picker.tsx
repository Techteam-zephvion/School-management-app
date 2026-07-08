"use client";

import { useRouter } from "next/navigation";
import { useTransition } from "react";
import type { SectionOption } from "./page";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

export function SectionPicker({ sections, selected }: { sections: SectionOption[]; selected: string }) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();
  return (
    <Select
      value={selected}
      onValueChange={(v) => startTransition(() => router.push(`/timetable?section=${v}`))}
      disabled={isPending || sections.length === 0}
    >
      <SelectTrigger className="w-48 rounded-xl border-slate-200/80 bg-white shadow-sm focus:border-blue-400 focus:ring-2 focus:ring-blue-100">
        <SelectValue placeholder="Choose section" />
      </SelectTrigger>
      <SelectContent>
        {sections.map((s) => (
          <SelectItem key={s.id} value={s.id}>
            {s.name}
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  );
}
