"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { MessageSquarePlus, Loader2 } from "lucide-react";
import { startThread } from "@/lib/actions/messages";
import type { StudentPick } from "./page";
import { Button } from "@/components/ui/button";
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

export function NewMessageDialog({ students }: { students: StudentPick[] }) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [studentId, setStudentId] = useState("");
  const [body, setBody] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();

  function submit() {
    setError(null);
    startTransition(async () => {
      const result = await startThread({ studentId, body });
      if ("error" in result) {
        setError(result.error);
      } else {
        toast.success("Message sent.");
        setOpen(false);
        setStudentId("");
        setBody("");
        router.push(`/messages/${result.threadId}`);
      }
    });
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button className="gap-2 bg-primary text-primary-foreground hover:bg-primary/80">
          <MessageSquarePlus className="size-4" /> New message
        </Button>
      </DialogTrigger>
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <div className="flex items-center gap-3">
            <span className="flex size-9 shrink-0 items-center justify-center rounded-xl bg-blue-50 text-blue-700 ring-1 ring-blue-100">
              <MessageSquarePlus className="size-4.5" />
            </span>
            <div>
              <DialogTitle>Message a parent</DialogTitle>
              <DialogDescription>Goes to the student&apos;s linked guardian(s) in their app.</DialogDescription>
            </div>
          </div>
        </DialogHeader>
        <div className="space-y-5">
          <div className="space-y-2">
            <Label className="text-xs font-semibold text-slate-600">About student</Label>
            <Select value={studentId} onValueChange={setStudentId}>
              <SelectTrigger className="w-full">
                <SelectValue placeholder="Choose a student" />
              </SelectTrigger>
              <SelectContent>
                {students.map((s) => (
                  <SelectItem key={s.id} value={s.id}>
                    {s.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <div className="space-y-2">
            <Label htmlFor="body" className="text-xs font-semibold text-slate-600">Message</Label>
            <Textarea
              id="body"
              rows={4}
              value={body}
              onChange={(e) => setBody(e.target.value)}
              placeholder="Hello, I wanted to share an update about…"
            />
          </div>
          {error && (
            <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
              {error}
            </div>
          )}
        </div>
        <DialogFooter className="gap-2 sm:gap-0">
          <Button onClick={submit} disabled={isPending || !studentId || body.trim().length === 0} className="gap-2 bg-primary text-primary-foreground hover:bg-primary/80">
            {isPending && <Loader2 className="size-4 animate-spin" />}
            Send
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
