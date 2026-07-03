"use client";

import { useActionState } from "react";
import { User, Lock } from "lucide-react";
import { acceptInvite } from "@/lib/actions/auth";
import {
  AuthCard,
  AuthField,
  PasswordField,
  AuthSubmit,
  AuthError,
} from "@/components/auth/auth-ui";

export function AcceptInviteForm({
  greetingName,
  defaultFullName,
}: {
  greetingName: string;
  defaultFullName: string;
}) {
  const [state, formAction, pending] = useActionState(acceptInvite, undefined);

  return (
    <AuthCard
      title={`Welcome, ${greetingName}!`}
      description="Confirm your name and set a password to activate your account."
    >
      <form action={formAction} className="space-y-4">
        <AuthField
          label="Full name"
          name="fullName"
          icon={User}
          autoComplete="name"
          defaultValue={defaultFullName}
          placeholder="Your full name"
          required
        />
        <PasswordField
          label="Create a password"
          name="password"
          icon={Lock}
          autoComplete="new-password"
          placeholder="At least 8 characters"
          required
        />
        <PasswordField
          label="Confirm password"
          name="confirmPassword"
          icon={Lock}
          autoComplete="new-password"
          placeholder="Re-enter your password"
          required
        />
        <AuthError>{state?.error}</AuthError>
        <AuthSubmit pending={pending} pendingLabel="Setting up…">
          Activate account
        </AuthSubmit>
      </form>
    </AuthCard>
  );
}
