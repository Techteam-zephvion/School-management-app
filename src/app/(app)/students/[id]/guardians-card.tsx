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
    <Card>
      <CardHeader className="flex-row items-start justify-between space-y-0">
        <div>
          <CardTitle>Guardians</CardTitle>
          <CardDescription>Parents linked to this student get app access.</CardDescription>
        </div>
        {canEdit && (
          <Dialog open={open} onOpenChange={setOpen}>
            <DialogTrigger asChild>
              <Button variant="outline" className="gap-2">
                <UserPlus className="size-4" /> Invite guardian
              </Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>Invite a guardian</DialogTitle>
                <DialogDescription>
                  They&apos;ll get an email to set a password and see this child in the app.
                </DialogDescription>
              </DialogHeader>
              <form action={formAction} className="space-y-4">
                <input type="hidden" name="studentId" value={studentId} />
                <input type="hidden" name="relation" value={relation} />
                <div className="space-y-2">
                  <Label htmlFor="fullName">Full name</Label>
                  <Input id="fullName" name="fullName" required />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="email">Email</Label>
                  <Input id="email" name="email" type="email" required />
                </div>
                <div className="grid gap-4 sm:grid-cols-2">
                  <div className="space-y-2">
                    <Label>Relation</Label>
                    <Select value={relation} onValueChange={setRelation}>
                      <SelectTrigger className="w-full">
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
                    <Input id="phone" name="phone" />
                  </div>
                </div>
                {state?.error && <p className="text-sm text-destructive">{state.error}</p>}
                <DialogFooter>
                  <Button type="submit" disabled={pending} className="gap-2">
                    {pending && <Loader2 className="size-4 animate-spin" />}
                    {pending ? "Inviting…" : "Send invite"}
                  </Button>
                </DialogFooter>
              </form>
            </DialogContent>
          </Dialog>
        )}
      </CardHeader>
      <CardContent className="divide-y divide-border">
        {guardians.length === 0 ? (
          <p className="py-4 text-sm text-muted-foreground">
            No guardians linked yet.
          </p>
        ) : (
          guardians.map((g) => (
            <div key={g.id} className="flex items-center gap-3 py-3">
              <div className="min-w-0 flex-1">
                <div className="flex items-center gap-1.5">
                  <p className="truncate font-medium">{g.name}</p>
                  {g.isPrimary && (
                    <Star className="size-3.5 fill-accent text-accent" aria-label="Primary" />
                  )}
                </div>
                <p className="truncate text-xs text-muted-foreground">
                  {g.relation ? `${g.relation} · ` : ""}
                  {g.email}
                </p>
              </div>
              <Badge variant={g.status === "active" ? "success" : "warning"}>
                {g.status}
              </Badge>
              {canEdit && (
                <Button
                  variant="ghost"
                  size="icon-sm"
                  disabled={isPending}
                  onClick={() => remove(g.id, g.name)}
                  aria-label={`Remove ${g.name}`}
                  className="text-muted-foreground hover:text-destructive"
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
