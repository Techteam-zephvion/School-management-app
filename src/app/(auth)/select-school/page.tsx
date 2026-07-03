import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { Building2, ChevronRight } from "lucide-react";
import { AuthCard } from "@/components/auth/auth-ui";
import { getMemberships } from "@/lib/auth/session";
import { roleLabel } from "@/lib/roles";
import { selectSchool } from "@/lib/actions/auth";

export const metadata: Metadata = { title: "Choose a school — EduSphere" };

export default async function SelectSchoolPage() {
  const memberships = await getMemberships();
  if (memberships.length === 0) redirect("/no-access");
  if (memberships.length === 1) redirect("/dashboard");

  return (
    <AuthCard
      title="Choose a school"
      description="Your account has access to more than one school. Pick one to continue."
    >
      <div className="space-y-2.5">
        {memberships.map((m) => (
          <form
            key={m.schoolId}
            action={async () => {
              "use server";
              await selectSchool(m.schoolId);
            }}
          >
            <button
              type="submit"
              className="group flex w-full items-center gap-3.5 rounded-xl border border-border bg-background/70 px-4 py-3.5 text-left shadow-sm transition-colors hover:border-accent/40 hover:bg-accent/5"
            >
              <span className="flex size-10 shrink-0 items-center justify-center rounded-lg bg-primary/8 text-primary">
                <Building2 className="size-5" />
              </span>
              <span className="min-w-0 flex-1">
                <span className="block truncate font-medium text-foreground">
                  {m.schoolName}
                </span>
                <span className="block text-xs text-muted-foreground">
                  {roleLabel(m.role)}
                </span>
              </span>
              <ChevronRight className="size-4 shrink-0 text-muted-foreground transition-transform group-hover:translate-x-0.5" />
            </button>
          </form>
        ))}
      </div>
    </AuthCard>
  );
}
