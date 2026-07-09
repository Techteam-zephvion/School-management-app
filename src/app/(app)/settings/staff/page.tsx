import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import { Users } from "lucide-react";
import { requireActiveMembership, getAuthUser } from "@/lib/auth/session";
import { createClient } from "@/lib/supabase/server";
import { PageHeader } from "@/components/page-header";
import { InviteStaffForm } from "./invite-staff-form";
import { RemoveStaffButton } from "./remove-staff-button";

function initials(name: string) {
  return (
    name
      .trim()
      .split(/\s+/)
      .map((p) => p[0])
      .slice(0, 2)
      .join("")
      .toUpperCase() || "?"
  );
}

export default async function StaffPage() {
  const membership = await requireActiveMembership();
  const currentUser = await getAuthUser();
  const supabase = await createClient();

  const { data: members } = await supabase
    .from("school_members")
    .select("id, user_id, role, status, profiles(full_name, email)")
    .eq("school_id", membership.schoolId)
    .in("role", ["school_admin", "teacher"])
    .order("role");

  return (
    <div className="mx-auto max-w-5xl space-y-6 pb-8">
      <PageHeader
        title="Staff"
        description={`Admins and teachers at ${membership.schoolName}.`}
        action={membership.role === "school_admin" ? <InviteStaffForm /> : undefined}
      />

      <Card className="overflow-hidden border border-slate-200/80 bg-white shadow-sm shadow-slate-950/5 ring-1 ring-slate-900/[0.02]">
        {/* Card header */}
        <div className="flex items-center gap-3 border-b border-slate-100 px-5 py-4">
          <span className="flex size-9 items-center justify-center rounded-xl bg-blue-50 text-blue-700 ring-1 ring-blue-100">
            <Users className="size-4.5" />
          </span>
          <div>
            <h2 className="text-base font-semibold text-slate-900">Team members</h2>
            <p className="text-xs text-slate-500">{members?.length ?? 0} people</p>
          </div>
        </div>

        <CardContent className="divide-y divide-slate-100 p-0">
          {!members || members.length === 0 ? (
            <div className="flex flex-col items-center gap-4 px-5 py-14 text-center">
              <span className="flex size-12 items-center justify-center rounded-2xl bg-slate-50 text-slate-400 ring-1 ring-slate-200">
                <Users className="size-5" />
              </span>
              <div>
                <p className="text-sm font-medium text-slate-700">No staff yet</p>
                <p className="mt-0.5 text-xs text-slate-500">Invite your first teacher or admin above.</p>
              </div>
            </div>
          ) : (
            members.map((m) => {
              const person = m.profiles as { full_name: string | null; email: string | null } | null;
              const name = person?.full_name || person?.email || "Invited user";
              return (
                <div
                  key={m.id}
                  className="group flex items-center gap-4 px-5 py-4 transition-colors hover:bg-blue-50/50"
                >
                  <Avatar className="size-10 shrink-0">
                    <AvatarFallback className="bg-blue-50 text-blue-700 ring-1 ring-blue-100">
                      {initials(name)}
                    </AvatarFallback>
                  </Avatar>
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-semibold text-slate-900">{name}</p>
                    <p className="truncate text-xs text-slate-500">
                      {person?.email}
                    </p>
                  </div>
                  <Badge variant="secondary" className="shrink-0 capitalize">
                    {m.role.replace("_", " ")}
                  </Badge>
                  <Badge variant={m.status === "active" ? "success" : "warning"} className="shrink-0">
                    {m.status}
                  </Badge>
                  {membership.role === "school_admin" && m.user_id !== currentUser?.id && (
                    <RemoveStaffButton memberId={m.id} name={name} />
                  )}
                </div>
              );
            })
          )}
        </CardContent>
      </Card>
    </div>
  );
}
