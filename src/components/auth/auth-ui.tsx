"use client";

import * as React from "react";
import { Eye, EyeOff, Loader2, type LucideIcon } from "lucide-react";
import { cn } from "@/lib/utils";

/** Elevated card that hosts an auth form: title, optional description, body,
 *  optional footer. Comfortable spacing + soft shadow per doc 04 §4. */
export function AuthCard({
  title,
  description,
  children,
  footer,
  className,
}: {
  title: string;
  description?: React.ReactNode;
  children: React.ReactNode;
  footer?: React.ReactNode;
  className?: string;
}) {
  return (
    <div
      className={cn(
        "rounded-2xl border border-border/70 bg-card/90 p-7 shadow-[0_10px_40px_-12px_rgba(16,32,63,0.18)] backdrop-blur-sm sm:p-8",
        className
      )}
    >
      <div className="mb-6 space-y-1.5">
        <h1 className="text-2xl font-bold tracking-tight text-foreground">
          {title}
        </h1>
        {description ? (
          <p className="text-sm leading-relaxed text-muted-foreground">
            {description}
          </p>
        ) : null}
      </div>
      {children}
      {footer ? (
        <div className="mt-6 border-t border-border/70 pt-5 text-center text-sm text-muted-foreground">
          {footer}
        </div>
      ) : null}
    </div>
  );
}

/** Label + input with optional leading icon, trailing slot, and error text. */
export function AuthField({
  label,
  labelAside,
  icon: Icon,
  error,
  trailing,
  className,
  id,
  ...props
}: React.ComponentProps<"input"> & {
  label: string;
  labelAside?: React.ReactNode;
  icon?: LucideIcon;
  error?: string;
  trailing?: React.ReactNode;
}) {
  const inputId = id ?? props.name;
  return (
    <div className="space-y-1.5">
      <div className="flex items-center justify-between">
        <label
          htmlFor={inputId}
          className="text-sm font-medium text-foreground"
        >
          {label}
        </label>
        {labelAside}
      </div>
      <div className="relative">
        {Icon ? (
          <Icon className="pointer-events-none absolute left-3.5 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
        ) : null}
        <input
          id={inputId}
          aria-invalid={error ? true : undefined}
          className={cn(
            "h-11 w-full rounded-xl border border-input bg-background/80 text-[15px] text-foreground shadow-sm outline-none transition-colors placeholder:text-muted-foreground/70",
            "focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/25",
            "aria-[invalid=true]:border-destructive aria-[invalid=true]:ring-destructive/20",
            "disabled:pointer-events-none disabled:opacity-50",
            Icon ? "pl-10" : "pl-3.5",
            trailing ? "pr-11" : "pr-3.5",
            className
          )}
          {...props}
        />
        {trailing ? (
          <div className="absolute right-2 top-1/2 -translate-y-1/2">
            {trailing}
          </div>
        ) : null}
      </div>
      {error ? (
        <p className="text-sm font-medium text-destructive">{error}</p>
      ) : null}
    </div>
  );
}

/** Password field with a show/hide toggle. */
export function PasswordField({
  label,
  labelAside,
  icon,
  error,
  ...props
}: React.ComponentProps<typeof AuthField>) {
  const [show, setShow] = React.useState(false);
  return (
    <AuthField
      {...props}
      label={label}
      labelAside={labelAside}
      icon={icon}
      error={error}
      type={show ? "text" : "password"}
      trailing={
        <button
          type="button"
          onClick={() => setShow((s) => !s)}
          aria-label={show ? "Hide password" : "Show password"}
          className="flex size-8 items-center justify-center rounded-lg text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
        >
          {show ? <EyeOff className="size-4" /> : <Eye className="size-4" />}
        </button>
      }
    />
  );
}

/** Full-width primary submit with a spinner while pending. */
export function AuthSubmit({
  pending,
  children,
  pendingLabel,
  className,
  ...props
}: React.ComponentProps<"button"> & {
  pending?: boolean;
  pendingLabel?: string;
}) {
  return (
    <button
      type="submit"
      disabled={pending || props.disabled}
      className={cn(
        "inline-flex h-11 w-full items-center justify-center gap-2 rounded-xl bg-accent text-[15px] font-semibold text-accent-foreground shadow-sm transition-all",
        "hover:bg-accent/90 focus-visible:outline-none focus-visible:ring-[3px] focus-visible:ring-ring/40",
        "active:translate-y-px disabled:pointer-events-none disabled:opacity-60",
        className
      )}
      {...props}
    >
      {pending ? (
        <>
          <Loader2 className="size-4 animate-spin" />
          {pendingLabel ?? "Please wait…"}
        </>
      ) : (
        children
      )}
    </button>
  );
}

/** Inline error banner for form-level (non-field) errors. */
export function AuthError({ children }: { children: React.ReactNode }) {
  if (!children) return null;
  return (
    <div
      role="alert"
      className="rounded-xl border border-destructive/20 bg-destructive/8 px-3.5 py-2.5 text-sm font-medium text-destructive"
    >
      {children}
    </div>
  );
}
