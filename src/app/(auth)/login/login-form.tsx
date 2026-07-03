"use client";

import { useActionState } from "react";
import { useSearchParams } from "next/navigation";
import Link from "next/link";
import { Mail, Lock } from "lucide-react";
import { login } from "@/lib/actions/auth";
import {
  AuthCard,
  AuthField,
  PasswordField,
  AuthSubmit,
  AuthError,
} from "@/components/auth/auth-ui";

export function LoginForm() {
  const searchParams = useSearchParams();
  const next = searchParams.get("next") ?? "";
  const [state, formAction, pending] = useActionState(login, undefined);

  return (
    <AuthCard
      title="Welcome back"
      description="Sign in to your EduSphere teacher portal."
    >
      <form action={formAction} className="space-y-4">
        <input type="hidden" name="next" value={next} />
        <AuthField
          label="Email"
          name="email"
          type="email"
          icon={Mail}
          autoComplete="email"
          placeholder="you@school.edu"
          required
        />
        <PasswordField
          label="Password"
          name="password"
          icon={Lock}
          autoComplete="current-password"
          placeholder="••••••••"
          required
          labelAside={
            <Link
              href="/forgot-password"
              className="text-sm font-medium text-accent hover:underline"
            >
              Forgot password?
            </Link>
          }
        />
        <AuthError>{state?.error}</AuthError>
        <AuthSubmit pending={pending} pendingLabel="Signing in…">
          Sign in
        </AuthSubmit>
      </form>
    </AuthCard>
  );
}
