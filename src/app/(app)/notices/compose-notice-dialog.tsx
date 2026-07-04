"use client";

import { useActionState, useState } from "react";
import { toast } from "sonner";
import { Megaphone, Loader2 } from "lucide-react";
import { createAnnouncement } from "@/lib/actions/announcements";
import { createClient } from "@/lib/supabase/client";
import type { ClassOption, SectionOption, StudentOption } from "./page";
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

type Audience = "school" | "class" | "section" | "individual";

export function ComposeNoticeDialog({
  isAdmin,
  schoolId,
  classes,
  sections,
  students,
}: {
  isAdmin: boolean;
  schoolId: string;
  classes: ClassOption[];
  sections: SectionOption[];
  students: StudentOption[];
}) {
  const [open, setOpen] = useState(false);
  const [audience, setAudience] = useState<Audience>(isAdmin ? "school" : "section");
  const [targetId, setTargetId] = useState("");
  const [file, setFile] = useState<File | null>(null);
  const [uploading, setUploading] = useState(false);

  const audienceOptions: { value: Audience; label: string }[] = isAdmin
    ? [
        { value: "school", label: "Whole school" },
        { value: "class", label: "A class" },
        { value: "section", label: "A section" },
        { value: "individual", label: "One student" },
      ]
    : [
        { value: "section", label: "A section" },
        { value: "individual", label: "One student" },
      ];

  const needsTarget = audience !== "school";
  const targetItems =
    audience === "class" ? classes.map((c) => ({ id: c.id, label: c.name }))
    : audience === "section" ? sections
    : audience === "individual" ? students
    : [];
  const targetLabel =
    audience === "class" ? "Class" : audience === "section" ? "Section" : "Student";

  const [state, formAction, pending] = useActionState(
    async (prev: Awaited<ReturnType<typeof createAnnouncement>>, fd: FormData) => {
      fd.set("audience", audience);
      fd.set("classId", audience === "class" ? targetId : "");
      fd.set("sectionId", audience === "section" ? targetId : "");
      fd.set("studentId", audience === "individual" ? targetId : "");

      if (file) {
        setUploading(true);
        const supabase = createClient();
        const path = `${schoolId}/${crypto.randomUUID()}-${file.name.replace(/[^\w.-]/g, "_")}`;
        const { error: upErr } = await supabase.storage.from("notices").upload(path, file);
        setUploading(false);
        if (upErr) return { error: `Attachment upload failed: ${upErr.message}` };
        fd.set("attachmentUrl", path);
      }

      const result = await createAnnouncement(prev, fd);
      if (!result?.error) {
        toast.success("Announcement posted.");
        setOpen(false);
        setTargetId("");
        setFile(null);
      }
      return result;
    },
    undefined
  );

  const busy = pending || uploading;
  const canSubmit = !needsTarget || Boolean(targetId);

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button className="gap-2">
          <Megaphone className="size-4" /> New announcement
        </Button>
      </DialogTrigger>
      <DialogContent className="max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>New announcement</DialogTitle>
          <DialogDescription>Reaches the guardians you target, in their app.</DialogDescription>
        </DialogHeader>
        <form action={formAction} className="space-y-4">
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-2">
              <Label>Send to</Label>
              <Select
                value={audience}
                onValueChange={(v) => {
                  setAudience(v as Audience);
                  setTargetId("");
                }}
              >
                <SelectTrigger className="w-full">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {audienceOptions.map((o) => (
                    <SelectItem key={o.value} value={o.value}>
                      {o.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            {needsTarget && (
              <div className="space-y-2">
                <Label>{targetLabel}</Label>
                <Select
                  value={targetId}
                  onValueChange={setTargetId}
                  disabled={targetItems.length === 0}
                >
                  <SelectTrigger className="w-full">
                    <SelectValue
                      placeholder={targetItems.length === 0 ? `No ${targetLabel.toLowerCase()}s` : `Choose ${targetLabel.toLowerCase()}`}
                    />
                  </SelectTrigger>
                  <SelectContent>
                    {targetItems.map((t) => (
                      <SelectItem key={t.id} value={t.id}>
                        {t.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            )}
          </div>

          <div className="space-y-2">
            <Label htmlFor="title">Title</Label>
            <Input id="title" name="title" placeholder="Parent–teacher meeting" required />
          </div>
          <div className="space-y-2">
            <Label htmlFor="body">Message</Label>
            <Textarea id="body" name="body" rows={4} placeholder="Write your notice…" required />
          </div>
          <div className="space-y-2">
            <Label htmlFor="file">Attachment (optional)</Label>
            <Input id="file" type="file" onChange={(e) => setFile(e.target.files?.[0] ?? null)} />
          </div>

          {state?.error && <p className="text-sm text-destructive">{state.error}</p>}

          <DialogFooter>
            <Button type="submit" disabled={busy || !canSubmit} className="gap-2">
              {busy && <Loader2 className="size-4 animate-spin" />}
              {uploading ? "Uploading…" : pending ? "Posting…" : "Post announcement"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
