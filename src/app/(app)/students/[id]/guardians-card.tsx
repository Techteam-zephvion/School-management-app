"use client";

import { useActionState, useState, useTransition } from "react";
import { toast } from "sonner";
import { UserPlus, X, Loader2, Star } from "lucide-react";
import { inviteGuardian, removeGuardian } from "@/lib/actions/students";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  CardDescription,
} from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
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

type Guardian = {
  id: string;
  name: string;
  email: string;
  relation: string | null;
  isPrimary: boolean;
  status: string;
};

export function GuardiansCard({
  studentId,
  guardians,
  canEdit,
}: {
  studentId: string;
  guardians: Guardian[];
  canEdit: boolean;
}) {
  const [open, setOpen] = useState(false);
  const [relation, setRelation] = useState("");
  const [isPending, startTransition] = useTransition();

  const [state, formAction, pending] = useActionState(
    async (prev: Awaited<ReturnType<typeof inviteGuardian>>, fd: FormData) => {
      const result = await inviteGuardian(prev, fd);
      if (!result?.error) {
        toast.success("Guardian invited.");
        setOpen(false);
        setRelation("");
      }
      return result;
    },
    undefined
  );

  function remove(id: string, name: string) {
    startTransition(async () => {
      const result = await removeGuardian(id);
      if (result?.error) toast.error(result.error);
      else toast.success(`Removed ${name}.`);
    });
  }

  return (
    <Card className="border border-slate-200/80 bg-white/95 shadow-sm shadow-slate-950/5 ring-1 ring-slate-900/[0.02]">
      <CardHeader className="flex-row items-start justify-between space-y-0">
        <div>
          <CardTitle className="flex items-center gap-2 text-base font-semibold text-slate-900">
            <span className="flex size-8 items-center justify-center rounded-xl bg-blue-50 text-blue-700 ring-1 ring-blue-100">
              <UserPlus className="size-4" />
            </span>
            Guardians
          </CardTitle>
          <CardDescription className="mt-1.5 text-slate-500">
            Parents linked to this student get app access.
          </CardDescription>
        </div>
        {canEdit && (
          <Dialog open={open} onOpenChange={setOpen}>
            <DialogTrigger asChild>
              <Button variant="outline" className="gap-2 border-slate-200/80 text-slate-700 hover:bg-slate-50 hover:text-slate-900">
                <UserPlus className="size-4" /> Invite guardian
              </Button>
            </DialogTrigger>
            <DialogContent className="rounded-2xl border-slate-200/80 shadow-xl shadow-slate-950/10">
              <DialogHeader>
                <DialogTitle className="text-xl font-bold tracking-tight text-slate-900">Invite a guardian</DialogTitle>
                <DialogDescription className="text-slate-500">
                  They&apos;ll get an email to set a password and see this child in the app.
                </DialogDescription>
              </DialogHeader>
              <form action={formAction} className="space-y-4">
                <input type="hidden" name="studentId" value={studentId} />
                <input type="hidden" name="relation" value={relation} />
                <div className="space-y-2">
                  <Label htmlFor="fullName">Full name</Label>
                  <Input id="fullName" name="fullName" required className="border-slate-200/80 focus-visible:ring-blue-500" />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="email">Email</Label>
                  <Input id="email" name="email" type="email" required className="border-slate-200/80 focus-visible:ring-blue-500" />
                </div>
                <div className="grid gap-4 sm:grid-cols-2">
                  <div className="space-y-2">
                    <Label>Relation</Label>
                    <Select value={relation} onValueChange={setRelation}>
                      <SelectTrigger className="w-full border-slate-200/80 focus-visible:ring-blue-500">
                        <SelectValue placeholder="Select" />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="mother">Mother</SelectItem>
                        <SelectItem value="father">Father</SelectItem>
                        <SelectItem value="guardian">Guardian</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="phone">Phone (optional)</Label>
                    <Input id="phone" name="phone" className="border-slate-200/80 focus-visible:ring-blue-500" />
                  </div>
                </div>
                {state?.error && (
                  <p className="rounded-lg border border-red-100 bg-red-50/80 px-3 py-2 text-sm text-red-700">
                    {state.error}
                  </p>
                )}
                <DialogFooter>
                  <Button                  type="submit" disabled={pending} className="gap-2 bg-[#10203f] text-white hover:bg-[#1b2d5e]"
            >
              {pending && <Loader2 className="size-4 animate-spin" />}
              {pending ? "Inviting…" : "Send invite"}
                  </Button>
                </DialogFooter>
              </form>
            </DialogContent>
          </Dialog>
        )}
      </CardHeader>
      <CardContent className="divide-y divide-slate-100">
        {guardians.length === 0 ? (
          <div className="flex min-h-[120px] flex-col items-center justify-center gap-2 py-6 text-center">
            <span className="flex size-10 items-center justify-center rounded-xl bg-slate-50 text-slate-400 ring-1 ring-slate-200">
              <UserPlus className="size-4" />
            </span>
            <p className="text-sm text-slate-500">No guardians linked yet.</p>
          </div>
        ) : (
          guardians.map((g, idx) => (
            <div key={g.id} className="flex items-center gap-3 px-1 py-3.5 transition-colors hover:bg-slate-50/60">
              <div className="min-w-0 flex-1">
                <div className="flex items-center gap-1.5">
                  <p className="truncate text-sm font-semibold text-slate-900">{g.name}</p>
                  {g.isPrimary && (
                    <Star className="size-3.5 fill-amber-400 text-amber-400" aria-label="Primary" />
                  )}
                </div>
                <p className="mt-0.5 truncate text-xs text-slate-500">
                  {g.relation ? (
                    <Badge variant="outline" className="mr-1.5 border-slate-200 px-1.5 py-0 text-[10px] font-normal capitalize text-slate-500">
                      {g.relation}
                    </Badge>
                  ) : null}
                  {g.email}
                </p>
              </div>
              <Badge
                variant={g.status === "active" ? "success" : "warning"}
                className="shrink-0 capitalize"
              >
                {g.status}
              </Badge>
              {canEdit && (
                <Button
                  variant="ghost"
                  size="icon-sm"
                  disabled={isPending}
                  onClick={() => remove(g.id, g.name)}
                  aria-label={`Remove ${g.name}`}
                  className="shrink-0 text-slate-400 hover:text-red-600 hover:bg-red-50"
                >
                  <X className="size-4" />
                </Button>
              )}
            </div>
          ))
        )}
      </CardContent>
    </Card>
  );
}
