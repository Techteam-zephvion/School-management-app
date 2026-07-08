import { redirect } from "next/navigation";
import { CalendarClock } from "lucide-react";
import { requireActiveMembership } from "@/lib/auth/session";
import { createClient } from "@/lib/supabase/server";
import { PageHeader } from "@/components/page-header";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { FeeStructuresCard } from "./fee-structures-card";
import { InvoicesCard } from "./invoices-card";

export type StructureItem = { id: string; label: string; amount: number };
export type FeeStructure = {
  id: string;
  name: string;
  className: string | null;
  totalAmount: number;
  dueDate: string;
  invoiceCount: number;
  items: StructureItem[];
};
export type InvoiceRow = {
  id: string;
  student: string;
  structure: string;
  total: number;
  paid: number;
  status: string;
  dueDate: string;
};

export default async function FeesPage() {
  const membership = await requireActiveMembership();
  if (membership.role === "parent") redirect("/dashboard");
  const supabase = await createClient();
  const schoolId = membership.schoolId;
  const isAdmin = membership.role === "school_admin";

  const { data: activeYear } = await supabase
    .from("academic_years")
    .select("id, name")
    .eq("school_id", schoolId)
    .eq("is_active", true)
    .maybeSingle();

  if (!activeYear) {
    return (
      <div className="mx-auto max-w-3xl space-y-6">
        <PageHeader title="Fees" description="Fee structures, invoices and payments." />
        <Alert className="border-amber-200/60 bg-amber-50/60 text-amber-900">
          <CalendarClock className="size-4 text-amber-600" />
          <AlertDescription>Set an active academic year and enrol students first.</AlertDescription>
        </Alert>
      </div>
    );
  }

  const [{ data: classes }, { data: structures }, { data: invoices }] = await Promise.all([
    supabase.from("classes").select("id, name").eq("school_id", schoolId).order("sort_order"),
    supabase
      .from("fee_structures")
      .select("id, name, class_id, total_amount, due_date, classes(name), fee_items(id, label, amount), invoices(id)")
      .eq("school_id", schoolId)
      .eq("academic_year_id", activeYear.id)
      .eq("is_transport", false) // auto-managed transport container is hidden here
      .order("created_at", { ascending: false }),
    supabase
      .from("invoices")
      .select("id, amount_total, amount_paid, status, due_date, students(first_name, last_name), fee_structures(name)")
      .eq("school_id", schoolId)
      .order("created_at", { ascending: false }),
  ]);

  const feeStructures: FeeStructure[] = (structures ?? []).map((s) => ({
    id: s.id,
    name: s.name,
    className: (s.classes as { name: string } | null)?.name ?? null,
    totalAmount: Number(s.total_amount),
    dueDate: s.due_date,
    invoiceCount: (s.invoices as { id: string }[] | null)?.length ?? 0,
    items: ((s.fee_items as { id: string; label: string; amount: number }[] | null) ?? []).map((i) => ({
      id: i.id,
      label: i.label,
      amount: Number(i.amount),
    })),
  }));

  const invoiceRows: InvoiceRow[] = (invoices ?? []).map((i) => {
    const st = i.students as { first_name: string; last_name: string | null } | null;
    return {
      id: i.id,
      student: st ? `${st.first_name} ${st.last_name ?? ""}`.trim() : "Student",
      structure: (i.fee_structures as { name: string } | null)?.name ?? "Fee",
      total: Number(i.amount_total),
      paid: Number(i.amount_paid),
      status: i.status,
      dueDate: i.due_date,
    };
  });

  return (
    <div className="mx-auto max-w-3xl space-y-6">
      <PageHeader
        title="Fees"
        description={
          isAdmin
            ? `Fee structures, invoices and payments for ${activeYear.name}.`
            : `Invoice status for ${activeYear.name}.`
        }
      />

      {isAdmin && <FeeStructuresCard classes={classes ?? []} structures={feeStructures} />}

      <InvoicesCard invoices={invoiceRows} canRecord={isAdmin} />
    </div>
  );
}
