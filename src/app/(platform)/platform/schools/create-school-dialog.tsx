"use client";

import { useActionState, useState } from "react";
import { toast } from "sonner";
import { Plus, Loader2 } from "lucide-react";
import { createSchoolWithAdmin } from "@/lib/actions/platform";
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

export function CreateSchoolDialog() {
  const [open, setOpen] = useState(false);
  const [state, formAction, pending] = useActionState(
    async (prev: Awaited<ReturnType<typeof createSchoolWithAdmin>>, fd: FormData) => {
      const result = await createSchoolWithAdmin(prev, fd);
      if (!result?.error) {
        toast.success("School created — admin invited.");
        setOpen(false);
      }
      return result;
    },
    undefined
  );

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button className="gap-2">
          <Plus className="size-4" /> New school
        </Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Onboard a school</DialogTitle>
          <DialogDescription>Creates the school and emails its first admin an invite.</DialogDescription>
        </DialogHeader>
        <form action={formAction} className="space-y-4">
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-2">
              <Label htmlFor="name" className="text-sm font-medium text-foreground">School name</Label>
              <Input id="name" name="name" placeholder="Riverside Academy" required className="rounded-lg" />
            </div>
            <div className="space-y-2">
              <Label htmlFor="city" className="text-sm font-medium text-foreground">City (optional)</Label>
              <Input id="city" name="city" placeholder="Bengaluru" className="rounded-lg" />
            </div>
          </div>
          <div className="border-t border-border pt-4">
            <p className="mb-3 text-xs font-semibold tracking-wide text-muted-foreground uppercase">First admin</p>
            <div className="grid gap-4 sm:grid-cols-2">
              <div className="space-y-2">
                <Label htmlFor="adminName" className="text-sm font-medium text-foreground">Name</Label>
                <Input id="adminName" name="adminName" placeholder="Priya Nair" required className="rounded-lg" />
              </div>
              <div className="space-y-2">
                <Label htmlFor="adminEmail" className="text-sm font-medium text-foreground">Email</Label>
                <Input id="adminEmail" name="adminEmail" type="email" placeholder="admin@riverside.edu" required className="rounded-lg" />
              </div>
            </div>
          </div>
          {state?.error && <p className="text-sm text-destructive">{state.error}</p>}
          <DialogFooter>
            <Button type="submit" disabled={pending} className="gap-2">
              {pending && <Loader2 className="size-4 animate-spin" />}
              Create &amp; invite admin
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
