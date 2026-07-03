"use client";

import { useActionState } from "react";
import { Lock, ShieldCheck } from "lucide-react";
import { updatePassword } from "@/lib/actions/auth";
import {
  AuthCard,
  PasswordField,
  AuthSubmit,
  AuthError,
} from "@/components/auth/auth-ui";

export function ResetPasswordForm() {
  const [state, formAction, pending] = useActionState(updatePassword, undefined);

  return (
    <AuthCard
      title="Choose a new password"
      description="You're verified — set a new password to finish securing your account."
    >
      <form action={formAction} className="space-y-4">
        <div className="flex items-center gap-2.5 rounded-xl border border-info-soft-foreground/15 bg-info-soft/50 px-3.5 py-2.5 text-info-soft-foreground">
          <ShieldCheck className="size-4 shrink-0" />
          <p className="text-xs font-medium">
            Use at least 8 characters with a mix of letters and numbers.
          </p>
        </div>
        <PasswordField
          label="New password"
          name="password"
          icon={Lock}
          autoComplete="new-password"
          placeholder="••••••••"
          required
        />
        <PasswordField
          label="Confirm new password"
          name="confirmPassword"
          icon={Lock}
          autoComplete="new-password"
          placeholder="••••••••"
          required
        />
        <AuthError>{state?.error}</AuthError>
        <AuthSubmit pending={pending} pendingLabel="Updating…">
          Update password
        </AuthSubmit>
      </form>
    </AuthCard>
  );
}
