import type { Database } from "@/lib/supabase/database.types";

type BadgeVariant =
  | "success"
  | "warning"
  | "danger"
  | "info"
  | "holiday"
  | "secondary";

type AttendStatus = Database["public"]["Enums"]["attend_status"];
type InvoiceStatus = Database["public"]["Enums"]["invoice_status"];
type LeaveStatus = Database["public"]["Enums"]["leave_status"];
type PaymentStatus = Database["public"]["Enums"]["payment_status"];

// doc 04 §2.2 -- status -> color mapping must be identical across web and mobile.
export const attendanceStatus: Record<
  AttendStatus,
  { label: string; variant: BadgeVariant }
> = {
  present: { label: "Present", variant: "success" },
  absent: { label: "Absent", variant: "danger" },
  late: { label: "Late", variant: "warning" },
  excused: { label: "Excused", variant: "info" },
  holiday: { label: "Holiday", variant: "holiday" },
};

export const invoiceStatus: Record<
  InvoiceStatus,
  { label: string; variant: BadgeVariant }
> = {
  unpaid: { label: "Unpaid", variant: "warning" },
  partial: { label: "Partial", variant: "warning" },
  paid: { label: "Paid", variant: "success" },
  overdue: { label: "Overdue", variant: "danger" },
  cancelled: { label: "Cancelled", variant: "secondary" },
};

export const leaveStatus: Record<
  LeaveStatus,
  { label: string; variant: BadgeVariant }
> = {
  pending: { label: "Pending", variant: "warning" },
  approved: { label: "Approved", variant: "success" },
  rejected: { label: "Rejected", variant: "danger" },
  cancelled: { label: "Cancelled", variant: "secondary" },
};

export const paymentStatus: Record<
  PaymentStatus,
  { label: string; variant: BadgeVariant }
> = {
  created: { label: "Created", variant: "secondary" },
  pending: { label: "Pending", variant: "warning" },
  captured: { label: "Captured", variant: "success" },
  failed: { label: "Failed", variant: "danger" },
  refunded: { label: "Refunded", variant: "info" },
};
