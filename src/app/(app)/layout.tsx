import { requireActiveMembership, getProfile, getAuthUser } from "@/lib/auth/session";
import { createClient } from "@/lib/supabase/server";
import { AppSidebar } from "@/components/app-sidebar";
import { AppTopbar } from "@/components/app-topbar";
import type { AppNotification } from "@/components/notification-bell";

export default async function AppLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const membership = await requireActiveMembership();
  const profile = await getProfile();
  const user = await getAuthUser();

  const supabase = await createClient();
  const { data: notifications } = await supabase
    .from("notifications")
    .select("id, type, title, body, deeplink, read_at, created_at")
    .order("created_at", { ascending: false })
    .limit(30);

  return (
    <div className="flex h-screen overflow-hidden">
      <div className="hidden lg:block">
        <AppSidebar role={membership.role} />
      </div>
      <div className="flex min-w-0 flex-1 flex-col">
        <AppTopbar
          fullName={profile?.full_name || "there"}
          avatarUrl={profile?.avatar_url ?? null}
          role={membership.role}
          schoolName={membership.schoolName}
          userId={user?.id ?? ""}
          notifications={(notifications ?? []) as AppNotification[]}
        />
        <main className="flex-1 overflow-y-auto bg-background p-4 sm:p-6">
          {children}
        </main>
      </div>
    </div>
  );
}
