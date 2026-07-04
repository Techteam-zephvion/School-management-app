"use client";

import { useActionState, useState } from "react";
import { toast } from "sonner";
import { Plus, Loader2 } from "lucide-react";
import { createHomework } from "@/lib/actions/homework";
import { createClient } from "@/lib/supabase/client";
import type { HomeworkTarget } from "./page";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogTrigger,
  DialogFooter,
} from "@/components/ui/dialog";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

function tomorrowISO() {
  const d = new Date();
  d.setDate(d.getDate() + 1);
  return d.toISOString().slice(0, 10);
}

export function CreateHomeworkDialog({
  targets,
  schoolId,
}: {
  targets: HomeworkTarget[];
  schoolId: string;
}) {
  const [open, setOpen] = useState(false);
  const [targetKey, setTargetKey] = useState("");
  const [file, setFile] = useState<File | null>(null);
  const [uploading, setUploading] = useState(false);

  const [state, formAction, pending] = useActionState(
    async (prev: Awaited<ReturnType<typeof createHomework>>, fd: FormData) => {
      const target = targets.find((t) => t.key === targetKey);
      if (!target) return { error: "Choose a class and subject." };
      fd.set("sectionId", target.sectionId);
      fd.set("subjectId", target.subjectId);

      // Upload the attachment (if any) to the private `homework` bucket first.
      if (file) {
        setUploading(true);
        const supabase = createClient();
        const path = `${schoolId}/${crypto.randomUUID()}-${file.name.replace(/[^\w.-]/g, "_")}`;
        const { error: upErr } = await supabase.storage.from("homework").upload(path, file);
        setUploading(false);
        if (upErr) return { error: `Attachment upload failed: ${upErr.message}` };
        fd.set("attachmentUrl", path);
      }

      const result = await createHomework(prev, fd);
      if (!result?.error) {
        toast.success("Homework posted.");
        setOpen(false);
        setTargetKey("");
        setFile(null);
      }
      return result;
    },
    undefined
  );

  const busy = pending || uploading;

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button className="gap-2">
          <Plus className="size-4" /> Assign homework
        </Button>
      </DialogTrigger>
      <DialogContent className="max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>Assign homework</DialogTitle>
          <DialogDescription>Parents of the class will see this in their app.</DialogDescription>
        </DialogHeader>
        <form action={formAction} className="space-y-4">
          <div className="space-y-2">
            <Label>Class &amp; subject</Label>
            <Select value={targetKey} onValueChange={setTargetKey}>
              <SelectTrigger className="w-full">
                <SelectValue placeholder="Choose a class and subject" />
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
          <div className="space-y-2">
            <Label htmlFor="title">Title</Label>
            <Input id="title" name="title" placeholder="Chapter 4 exercises" required />
          </div>
          <div className="space-y-2">
            <Label htmlFor="description">Details (optional)</Label>
            <Textarea id="description" name="description" rows={3} placeholder="Questions 1–10, show your working." />
          </div>
          <div className="space-y-2">
            <Label htmlFor="dueDate">Due date</Label>
            <Input id="dueDate" name="dueDate" type="date" defaultValue={tomorrowISO()} required />
          </div>
          <div className="space-y-2">
            <Label htmlFor="file">Attachment (optional)</Label>
            <Input
              id="file"
              type="file"
              onChange={(e) => setFile(e.target.files?.[0] ?? null)}
            />
          </div>
          {state?.error && <p className="text-sm text-destructive">{state.error}</p>}
          <DialogFooter>
            <Button type="submit" disabled={busy || !targetKey} className="gap-2">
              {busy && <Loader2 className="size-4 animate-spin" />}
              {uploading ? "Uploading…" : pending ? "Posting…" : "Post homework"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
