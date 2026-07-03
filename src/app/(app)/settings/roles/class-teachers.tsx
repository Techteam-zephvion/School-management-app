"use client";

import { useTransition } from "react";
import { toast } from "sonner";
import { assignClassTeacher } from "@/lib/actions/academic";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  CardDescription,
} from "@/components/ui/card";
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
    <Card>
      <CardHeader>
        <CardTitle>Class teachers</CardTitle>
        <CardDescription>
          One class teacher per section — they get extra rights over it.
        </CardDescription>
      </CardHeader>
      <CardContent className="divide-y divide-border">
        {sections.length === 0 ? (
          <p className="py-4 text-sm text-muted-foreground">
            No sections yet. Create sections in Classes & subjects.
          </p>
        ) : (
          sections.map((s) => (
            <div key={s.id} className="flex items-center justify-between gap-4 py-3">
              <span className="font-medium">{s.label}</span>
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
