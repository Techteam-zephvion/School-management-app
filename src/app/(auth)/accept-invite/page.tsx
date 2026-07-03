import type { Metadata } from "next";
import { School, BadgeCheck } from "lucide-react";
import { getAuthUser, getPendingInvite } from "@/lib/auth/session";
import { roleLabel } from "@/lib/roles";
import { AcceptInviteForm } from "./accept-invite-form";

export const metadata: Metadata = { title: "Activate your account — EduSphere" };

export default async function AcceptInvitePage() {
  const [user, invite] = await Promise.all([getAuthUser(), getPendingInvite()]);
  const invitedName =
    (user?.user_metadata?.full_name as string | undefined) ?? "";
  const firstName = invitedName.split(" ")[0] || "there";

  return (
    <div className="space-y-4">
      {invite ? (
        <div className="overflow-hidden rounded-2xl border border-border/70 bg-card/90 shadow-[0_10px_40px_-12px_rgba(16,32,63,0.18)] backdrop-blur-sm">
          <div className="flex items-center gap-3.5 bg-muted/50 px-5 py-4">
            <span className="flex size-11 shrink-0 items-center justify-center rounded-xl bg-background ring-1 ring-border">
              <School className="size-5 text-primary" />
            </span>
            <div className="min-w-0">
              <p className="truncate text-sm font-semibold text-foreground">
                {invite.schoolName}
              </p>
              <p className="text-xs text-muted-foreground">
                Invited you to join their team as:
              </p>
            </div>
          </div>
          <div className="px-5 py-3">
            <span className="inline-flex items-center gap-1.5 rounded-full border border-accent/20 bg-accent/10 px-3 py-1 text-xs font-semibold text-accent">
              <BadgeCheck className="size-3.5" />
              {roleLabel(invite.role)}
            </span>
          </div>
        </div>
      ) : null}

      <AcceptInviteForm
        greetingName={firstName}
        defaultFullName={invitedName}
      />
    </div>
  );
}
