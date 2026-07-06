import { clsx, type ClassValue } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

const inr = new Intl.NumberFormat("en-IN", {
  style: "currency",
  currency: "INR",
  maximumFractionDigits: 0,
});

/** Format a rupee amount, e.g. 5000 -> "₹5,000". */
export function formatMoney(amount: number | string | null | undefined): string {
  return inr.format(Number(amount ?? 0));
}
