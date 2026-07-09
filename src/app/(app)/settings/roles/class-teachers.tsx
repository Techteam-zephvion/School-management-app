"use client";

import { useTransition } from "react";
import { toast } from "sonner";
import { ShieldCheck } from "lucide-react";
import { assignClassTeacher } from "@/lib/actions/academic";
import { Card, CardContent } from "@/components/ui/card";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

type SectionRow = {
  id: string;
  label: string;
  classTeacherStaffId: string | null;
};
type StaffOption = { id: string; name: string };

const UNASSIGNED = "__none__";

export function ClassTeachers({
  sections,
  staff,
}: {
  sections: SectionRow[];
  staff: StaffOption[];
}) {
  const [isPending, startTransition] = useTransition();

  function assign(sectionId: string, value: string) {
    const staffId = value === UNASSIGNED ? null : value;
    startTransition(async () => {
      const result = await assignClassTeacher(sectionId, staffId);
      if (result?.error) toast.error(result.error);
      else toast.success("Class teacher updated.");
    });
  }

  return (
    <Card className="overflow-hidden border border-slate-200/80 bg-white shadow-sm shadow-slate-950/5 ring-1 ring-slate-900/[0.02]">
      {/* Card header */}
      <div className="border-b border-slate-100 px-5 py-4">
        <div className="flex items-center gap-3">
          <span className="flex size-9 items-center justify-center rounded-xl bg-blue-50 text-blue-700 ring-1 ring-blue-100">
            <ShieldCheck className="size-4.5" />
          </span>
          <div>
            <h2 className="text-base font-semibold text-slate-900">Class teachers</h2>
            <p className="text-xs text-slate-500">
              One class teacher per section — they get extra rights over it.
            </p>
          </div>
        </div>
      </div>

      <CardContent className="divide-y divide-slate-100 p-0">
        {sections.length === 0 ? (
          <div className="flex flex-col items-center gap-4 px-5 py-10 text-center">
            <span className="flex size-12 items-center justify-center rounded-2xl bg-slate-50 text-slate-400 ring-1 ring-slate-200">
              <ShieldCheck className="size-5" />
            </span>
            <div>
              <p className="text-sm font-medium text-slate-700">No sections yet</p>
              <p className="mt-0.5 text-xs text-slate-500">
                Create sections in Classes &amp; subjects first.
              </p>
            </div>
          </div>
        ) : (
          sections.map((s) => (
            <div
              key={s.id}
              className="group flex items-center justify-between gap-4 px-5 py-4 transition-colors hover:bg-blue-50/50"
            >
              <span className="text-sm font-semibold text-slate-900">{s.label}</span>
              <Select
                defaultValue={s.classTeacherStaffId ?? UNASSIGNED}
                onValueChange={(v) => assign(s.id, v)}
                disabled={isPending}
              >
                <SelectTrigger className="w-56">
                  <SelectValue placeholder="Unassigned" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value={UNASSIGNED}>Unassigned</SelectItem>
                  {staff.map((t) => (
                    <SelectItem key={t.id} value={t.id}>
                      {t.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          ))
        )}
      </CardContent>
    </Card>
  );
}
