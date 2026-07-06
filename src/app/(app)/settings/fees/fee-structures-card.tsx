"use client";

import { useActionState, useState, useTransition } from "react";
import { toast } from "sonner";
import { Plus, X, Trash2, ReceiptText, Loader2, FileStack } from "lucide-react";
import {
  createStructure,
  addFeeItem,
  deleteFeeItem,
  deleteStructure,
  generateInvoices,
} from "@/lib/actions/fees";
import type { FeeStructure } from "./page";
import { formatMoney } from "@/lib/utils";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
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

type ClassOption = { id: string; name: string };

function fmtDate(d: string) {
  return new Date(d + "T00:00:00").toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" });
}

const ALL = "__all__";

export function FeeStructuresCard({
  classes,
  structures,
}: {
  classes: ClassOption[];
  structures: FeeStructure[];
}) {
  const [open, setOpen] = useState(false);
  const [classId, setClassId] = useState(ALL);

  const [state, formAction, pending] = useActionState(
    async (prev: Awaited<ReturnType<typeof createStructure>>, fd: FormData) => {
      fd.set("classId", classId === ALL ? "" : classId);
      const result = await createStructure(prev, fd);
      if (!result?.error) {
        toast.success("Fee structure created.");
        setOpen(false);
        setClassId(ALL);
      }
      return result;
    },
    undefined
  );

  return (
    <Card className="overflow-hidden border-0 shadow-md shadow-muted-foreground/5 ring-1 ring-border/50">
      <CardHeader className="flex-row items-start justify-between space-y-0">
        <div>
          <CardTitle className="text-base">Fee structures</CardTitle>
          <CardDescription>Define a fee, add its line items, then generate invoices.</CardDescription>
        </div>
        <Dialog open={open} onOpenChange={setOpen}>
          <DialogTrigger asChild>
            <Button className="gap-2">
              <Plus className="size-4" /> New fee
            </Button>
          </DialogTrigger>
          <DialogContent>
            <DialogHeader>
              <DialogTitle>New fee structure</DialogTitle>
            </DialogHeader>
            <form action={formAction} className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="name" className="text-sm font-medium text-foreground">Name</Label>
                <Input id="name" name="name" placeholder="Term 1 Fees" required className="rounded-lg" />
              </div>
              <div className="grid gap-4 sm:grid-cols-2">
                <div className="space-y-2">
                  <Label className="text-sm font-medium text-foreground">Applies to</Label>
                  <Select value={classId} onValueChange={setClassId}>
                    <SelectTrigger className="w-full rounded-lg">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value={ALL}>All classes</SelectItem>
                      {classes.map((c) => (
                        <SelectItem key={c.id} value={c.id}>
                          {c.name}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div className="space-y-2">
                  <Label htmlFor="dueDate" className="text-sm font-medium text-foreground">Due date</Label>
                  <Input id="dueDate" name="dueDate" type="date" required className="rounded-lg" />
                </div>
              </div>
              {state?.error && <p className="text-sm text-destructive">{state.error}</p>}
              <DialogFooter>
                <Button type="submit" disabled={pending} className="gap-2">
                  {pending && <Loader2 className="size-4 animate-spin" />}
                  Create
                </Button>
              </DialogFooter>
            </form>
          </DialogContent>
        </Dialog>
      </CardHeader>
      <CardContent className="space-y-3">
        {structures.length === 0 ? (
          <div className="flex flex-col items-center gap-3 py-8 text-center">
            <span className="flex size-12 items-center justify-center rounded-2xl bg-muted/60">
              <ReceiptText className="size-6 text-muted-foreground/70" />
            </span>
            <p className="text-sm font-medium text-muted-foreground">No fee structures yet.</p>
            <p className="text-xs text-muted-foreground/70">Create one to bill tuition, transport and more.</p>
          </div>
        ) : (
          structures.map((s) => <StructureRow key={s.id} structure={s} />)
        )}
      </CardContent>
    </Card>
  );
}

function StructureRow({ structure }: { structure: FeeStructure }) {
  const [isPending, startTransition] = useTransition();
  const [addingItem, setAddingItem] = useState(false);

  function removeItem(id: string) {
    startTransition(async () => {
      const result = await deleteFeeItem(id);
      if (result?.error) toast.error(result.error);
    });
  }
  function removeStructure() {
    startTransition(async () => {
      const result = await deleteStructure(structure.id);
      if (result?.error) toast.error(result.error);
      else toast.success(`Removed ${structure.name}.`);
    });
  }
  function generate() {
    startTransition(async () => {
      const result = await generateInvoices(structure.id);
      if (result?.error) toast.error(result.error);
      else toast.success("Invoices generated.");
    });
  }

  return (
    <div className="rounded-xl border border-border/70 p-4">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div>
          <p className="font-semibold">
            {structure.name}
            <span className="ml-2 text-sm font-normal text-muted-foreground">
              {structure.className ?? "All classes"} · due {fmtDate(structure.dueDate)}
            </span>
          </p>
          <p className="text-sm text-muted-foreground">
            Total <span className="font-semibold text-foreground">{formatMoney(structure.totalAmount)}</span>
            {structure.invoiceCount > 0 ? ` · ${structure.invoiceCount} invoice${structure.invoiceCount === 1 ? "" : "s"}` : ""}
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Button
            size="sm"
            variant="outline"
            className="gap-1.5"
            disabled={isPending || structure.totalAmount <= 0}
            onClick={generate}
          >
            <FileStack className="size-4" /> Generate invoices
          </Button>
          <Button
            size="icon-sm"
            variant="ghost"
            aria-label={`Delete ${structure.name}`}
            disabled={isPending}
            onClick={removeStructure}
            className="text-muted-foreground hover:text-destructive"
          >
            <Trash2 className="size-4" />
          </Button>
        </div>
      </div>

      <div className="mt-3 flex flex-wrap items-center gap-2">
        {structure.items.map((it) => (
          <span
            key={it.id}
            className="group inline-flex items-center gap-1.5 rounded-lg border border-border bg-secondary/50 py-1 pl-3 pr-1.5 text-sm font-medium"
          >
            {it.label}
            <span className="text-xs text-muted-foreground">{formatMoney(it.amount)}</span>
            <button
              type="button"
              disabled={isPending}
              onClick={() => removeItem(it.id)}
              aria-label={`Remove ${it.label}`}
              className="flex size-5 items-center justify-center rounded text-muted-foreground transition-colors hover:bg-destructive/10 hover:text-destructive"
            >
              <X className="size-3.5" />
            </button>
          </span>
        ))}
        {addingItem ? (
          <AddItemForm structureId={structure.id} onDone={() => setAddingItem(false)} />
        ) : (
          <Button variant="outline" size="sm" className="gap-1" onClick={() => setAddingItem(true)}>
            <Plus className="size-3.5" /> Item
          </Button>
        )}
      </div>
    </div>
  );
}

function AddItemForm({ structureId, onDone }: { structureId: string; onDone: () => void }) {
  const [state, formAction, pending] = useActionState(
    async (prev: Awaited<ReturnType<typeof addFeeItem>>, fd: FormData) => {
      fd.set("structureId", structureId);
      const result = await addFeeItem(prev, fd);
      if (!result?.error) onDone();
      else toast.error(result.error);
      return result;
    },
    undefined
  );
  return (
    <form action={formAction} className="flex items-center gap-1.5">
      <Input name="label" placeholder="Tuition" required autoFocus className="h-8 w-28 rounded-lg" aria-label="Item label" />
      <Input name="amount" type="number" min={0} step="any" placeholder="5000" required className="h-8 w-24 rounded-lg" aria-label="Item amount" />
      <Button type="submit" size="sm" disabled={pending}>
        {pending ? "…" : "Add"}
      </Button>
      <Button type="button" size="sm" variant="ghost" onClick={onDone}>
        Cancel
      </Button>
      {state?.error ? <span className="sr-only">{state.error}</span> : null}
    </form>
  );
}
