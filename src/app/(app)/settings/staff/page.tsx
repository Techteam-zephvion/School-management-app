import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import { requireActiveMembership } from "@/lib/auth/session";
import { createClient } from "@/lib/supabase/server";
import { InviteStaffForm } from "./invite-staff-form";

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
  const supabase = await createClient();

  const { data: members } = await supabase
    .from("school_members")
    .select("id, role, status, profiles(full_name, email)")
    .eq("school_id", membership.schoolId)
    .in("role", ["school_admin", "teacher"])
    .order("role");

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">Staff</h1>
          <p className="text-muted-foreground">
            Admins and teachers at {membership.schoolName}.
          </p>
        </div>
        {membership.role === "school_admin" && <InviteStaffForm />}
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Team members</CardTitle>
          <CardDescription>{members?.length ?? 0} people</CardDescription>
        </CardHeader>
        <CardContent className="divide-y divide-border">
          {!members || members.length === 0 ? (
            <p className="py-6 text-center text-sm text-muted-foreground">
              No staff yet. Invite your first teacher or admin above.
            </p>
          ) : (
            members.map((m) => {
              const person = m.profiles as { full_name: string | null; email: string | null } | null;
              const name = person?.full_name || person?.email || "Invited user";
              return (
                <div key={m.id} className="flex items-center gap-3 py-3">
                  <Avatar className="size-9">
                    <AvatarFallback>{initials(name)}</AvatarFallback>
                  </Avatar>
                  <div className="min-w-0 flex-1">
                    <p className="truncate font-medium">{name}</p>
                    <p className="truncate text-xs text-muted-foreground">
                      {person?.email}
                    </p>
                  </div>
                  <Badge variant="secondary" className="capitalize">
                    {m.role.replace("_", " ")}
                  </Badge>
                  <Badge variant={m.status === "active" ? "success" : "warning"}>
                    {m.status}
                  </Badge>
                </div>
              );
            })
          )}
        </CardContent>
      </Card>
    </div>
  );
}
