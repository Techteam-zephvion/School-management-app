"use client";

import { useActionState, useState } from "react";
import { toast } from "sonner";
import { UserPlus, Loader2 } from "lucide-react";
import { inviteStaffMember } from "@/lib/actions/staff";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
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

export function InviteStaffForm() {
  const [open, setOpen] = useState(false);
  const [state, formAction, pending] = useActionState(
    async (prevState: Awaited<ReturnType<typeof inviteStaffMember>>, formData: FormData) => {
      const result = await inviteStaffMember(prevState, formData);
      if (!result?.error) {
        toast.success("Invite sent.");
        setOpen(false);
      }
      return result;
    },
    undefined
  );

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button className="gap-2 bg-primary text-primary-foreground hover:bg-primary/80">
          <UserPlus className="size-4" />
          Invite staff
        </Button>
      </DialogTrigger>
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <div className="flex items-center gap-3">
            <span className="flex size-9 shrink-0 items-center justify-center rounded-xl bg-blue-50 text-blue-700 ring-1 ring-blue-100">
              <UserPlus className="size-4.5" />
            </span>
            <div>
              <DialogTitle>Invite a staff member</DialogTitle>
              <DialogDescription>
                They&apos;ll get an email to set their password and sign in.
              </DialogDescription>
            </div>
          </div>
        </DialogHeader>
        <form action={formAction} className="space-y-5">
          <div className="space-y-2">
            <Label htmlFor="fullName" className="text-xs font-semibold text-slate-600">Full name</Label>
            <Input id="fullName" name="fullName" required />
          </div>
          <div className="space-y-2">
            <Label htmlFor="email" className="text-xs font-semibold text-slate-600">Email</Label>
            <Input id="email" name="email" type="email" required />
          </div>
          <div className="space-y-2">
            <Label htmlFor="role" className="text-xs font-semibold text-slate-600">Role</Label>
            <Select name="role" defaultValue="teacher">
              <SelectTrigger id="role" className="w-full">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="teacher">Teacher</SelectItem>
                <SelectItem value="school_admin">School admin</SelectItem>
              </SelectContent>
            </Select>
          </div>
          {state?.error && (
            <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
              {state.error}
            </div>
          )}
          <DialogFooter className="gap-2 sm:gap-0">
            <Button type="submit" disabled={pending} className="gap-2 bg-primary text-primary-foreground hover:bg-primary/80">
              {pending ? <><Loader2 className="size-4 animate-spin" /> Sending…</> : "Send invite"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
