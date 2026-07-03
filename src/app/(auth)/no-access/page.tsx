import type { Metadata } from "next";
import { ShieldAlert } from "lucide-react";
import { AuthCard } from "@/components/auth/auth-ui";
import { LogoutButton } from "@/components/logout-button";

export const metadata: Metadata = { title: "No access — EduSphere" };

export default function NoAccessPage() {
  return (
    <AuthCard title="No school access yet">
      <div className="flex flex-col items-center gap-4 text-center">
        <span className="flex size-14 items-center justify-center rounded-2xl bg-warning-soft text-warning-soft-foreground">
          <ShieldAlert className="size-7" />
        </span>
        <p className="text-sm leading-relaxed text-muted-foreground">
          Your account isn&apos;t linked to a school yet. Ask your school admin
          to invite you, or wait for your pending invite to be activated.
        </p>
        <LogoutButton />
      </div>
    </AuthCard>
  );
}
