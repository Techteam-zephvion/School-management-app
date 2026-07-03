import { requireActiveMembership, getProfile } from "@/lib/auth/session";
import { AppSidebar } from "@/components/app-sidebar";
import { AppTopbar } from "@/components/app-topbar";

export default async function AppLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const membership = await requireActiveMembership();
  const profile = await getProfile();

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
        />
        <main className="flex-1 overflow-y-auto bg-background p-4 sm:p-6">
          {children}
        </main>
      </div>
    </div>
  );
}
