"use client";

import { useActionState, useState } from "react";
import Link from "next/link";
import { Mail, MailCheck, ArrowLeft } from "lucide-react";
import { requestPasswordReset } from "@/lib/actions/auth";
import {
  AuthCard,
  AuthField,
  AuthSubmit,
  AuthError,
} from "@/components/auth/auth-ui";

export function ForgotPasswordForm() {
  const [submitted, setSubmitted] = useState(false);
  const [state, formAction, pending] = useActionState(
    async (prevState: { error?: string } | undefined, formData: FormData) => {
      const result = await requestPasswordReset(prevState, formData);
      setSubmitted(true);
      return result;
    },
    undefined
  );

  if (submitted && !state?.error) {
    return (
      <AuthCard
        title="Check your inbox"
        description="If that email is registered, we've sent a link to reset your password. It may take a minute to arrive — remember to check spam."
        footer={
          <Link
            href="/login"
            className="inline-flex items-center gap-1.5 font-medium text-accent hover:underline"
          >
            <ArrowLeft className="size-4" /> Back to sign in
          </Link>
        }
      >
        <div className="flex items-center gap-3 rounded-xl border border-success-soft-foreground/15 bg-success-soft/60 px-4 py-3.5 text-success-soft-foreground">
          <MailCheck className="size-5 shrink-0" />
          <p className="text-sm font-medium">Reset link sent.</p>
        </div>
      </AuthCard>
    );
  }

  return (
    <AuthCard
      title="Reset your password"
      description="Enter the email tied to your account and we'll send you a secure reset link."
      footer={
        <Link
          href="/login"
          className="inline-flex items-center gap-1.5 font-medium text-accent hover:underline"
        >
          <ArrowLeft className="size-4" /> Back to sign in
        </Link>
      }
    >
      <form action={formAction} className="space-y-4">
        <AuthField
          label="Email"
          name="email"
          type="email"
          icon={Mail}
          autoComplete="email"
          placeholder="you@school.edu"
          required
        />
        <AuthError>{state?.error}</AuthError>
        <AuthSubmit pending={pending} pendingLabel="Sending…">
          Send reset link
        </AuthSubmit>
      </form>
    </AuthCard>
  );
}
