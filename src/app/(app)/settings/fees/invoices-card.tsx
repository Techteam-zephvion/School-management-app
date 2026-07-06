"use client";

import { useActionState, useState } from "react";
import { toast } from "sonner";
import { Wallet, Loader2 } from "lucide-react";
import { recordPayment } from "@/lib/actions/fees";
import type { InvoiceRow } from "./page";
import { formatMoney } from "@/lib/utils";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
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

const STATUS: Record<string, { label: string; variant: "success" | "warning" | "destructive" | "secondary" | "outline" }> = {
  paid: { label: "Paid", variant: "success" },
  partial: { label: "Partial", variant: "warning" },
  overdue: { label: "Overdue", variant: "destructive" },
  unpaid: { label: "Unpaid", variant: "secondary" },
  cancelled: { label: "Cancelled", variant: "outline" },
};

function effectiveStatus(row: InvoiceRow): string {
  if (row.status !== "paid" && row.status !== "cancelled" && row.dueDate < new Date().toISOString().slice(0, 10)) {
    return "overdue";
  }
  return row.status;
}

export function InvoicesCard({ invoices, canRecord }: { invoices: InvoiceRow[]; canRecord: boolean }) {
  return (
    <Card className="overflow-hidden border-0 shadow-md shadow-muted-foreground/5 ring-1 ring-border/50">
      <CardHeader>
        <CardTitle className="text-base">Invoices</CardTitle>
        <CardDescription>
          {canRecord ? "Record payments and track balances." : "Fee status across the school."}
        </CardDescription>
      </CardHeader>
      <CardContent className="p-0">
        {invoices.length === 0 ? (
          <div className="flex flex-col items-center gap-3 py-12 text-center">
            <span className="flex size-12 items-center justify-center rounded-2xl bg-muted/60">
              <Wallet className="size-6 text-muted-foreground/70" />
            </span>
            <p className="text-sm font-medium text-muted-foreground">No invoices yet.</p>
            <p className="text-xs text-muted-foreground/70">
              {canRecord ? "Generate invoices from a fee structure above." : "Invoices will appear here once generated."}
            </p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <div className="min-w-[520px] divide-y divide-border/60">
              {invoices.map((inv) => {
                const status = effectiveStatus(inv);
                const badge = STATUS[status] ?? STATUS.unpaid;
                const balance = inv.total - inv.paid;
                return (
                  <div key={inv.id} className="flex items-center gap-3 px-5 py-3">
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-sm font-semibold">{inv.student}</p>
                      <p className="truncate text-xs text-muted-foreground">{inv.structure}</p>
                    </div>
                    <div className="w-40 text-right text-xs tabular-nums">
                      <p className="font-medium text-foreground">
                        {formatMoney(inv.paid)} <span className="text-muted-foreground">/ {formatMoney(inv.total)}</span>
                      </p>
                      {balance > 0 ? (
                        <p className="text-muted-foreground">{formatMoney(balance)} due</p>
                      ) : (
                        <p className="text-success">Cleared</p>
                      )}
                    </div>
                    <Badge variant={badge.variant} className="w-20 justify-center px-2 py-1 text-xs font-medium">
                      {badge.label}
                    </Badge>
                    {canRecord && balance > 0 && (
                      <RecordPaymentDialog invoiceId={inv.id} student={inv.student} balance={balance} />
                    )}
                  </div>
                );
              })}
            </div>
          </div>
        )}
      </CardContent>
    </Card>
  );
}

function RecordPaymentDialog({
  invoiceId,
  student,
  balance,
}: {
  invoiceId: string;
  student: string;
  balance: number;
}) {
  const [open, setOpen] = useState(false);
  const [method, setMethod] = useState("cash");

  const [state, formAction, pending] = useActionState(
    async (prev: Awaited<ReturnType<typeof recordPayment>>, fd: FormData) => {
      fd.set("invoiceId", invoiceId);
      fd.set("method", method);
      const result = await recordPayment(prev, fd);
      if (!result?.error) {
        toast.success("Payment recorded.");
        setOpen(false);
      }
      return result;
    },
    undefined
  );

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button size="sm" variant="outline" className="gap-1.5">
          <Wallet className="size-4" /> Record
        </Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Record payment</DialogTitle>
          <DialogDescription>
            {student} · balance {formatMoney(balance)}
          </DialogDescription>
        </DialogHeader>
        <form action={formAction} className="space-y-4">
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-2">
              <Label htmlFor="amount" className="text-sm font-medium text-foreground">Amount</Label>
              <Input
                id="amount"
                name="amount"
                type="number"
                min={1}
                max={balance}
                step="any"
                defaultValue={balance}
                required
                className="rounded-lg"
              />
            </div>
            <div className="space-y-2">
              <Label className="text-sm font-medium text-foreground">Method</Label>
              <Select value={method} onValueChange={setMethod}>
                <SelectTrigger className="w-full rounded-lg">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="cash">Cash</SelectItem>
                  <SelectItem value="upi">UPI</SelectItem>
                  <SelectItem value="card">Card</SelectItem>
                  <SelectItem value="bank">Bank transfer</SelectItem>
                  <SelectItem value="offline">Other (offline)</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>
          {state?.error && <p className="text-sm text-destructive">{state.error}</p>}
          <DialogFooter>
            <Button type="submit" disabled={pending} className="gap-2">
              {pending && <Loader2 className="size-4 animate-spin" />}
              Record payment
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
