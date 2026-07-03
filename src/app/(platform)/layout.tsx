import { redirect } from "next/navigation";
import { getAuthUser, getProfile } from "@/lib/auth/session";
import { AppSidebar } from "@/components/app-sidebar";
import { AppTopbar } from "@/components/app-topbar";

// Platform admins are global (doc 01 §2) and typically have zero school_members
// rows, so they get their own shell instead of going through the per-school
// membership gate in (app)/layout.tsx.
export default async function PlatformLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const user = await getAuthUser();
  if (!user) redirect("/login");

  const profile = await getProfile();
  if (!profile?.is_platform_admin) redirect("/no-access");

  return (
    <div className="flex h-screen overflow-hidden">
      <div className="hidden lg:block">
        <AppSidebar role="super_admin" />
      </div>
      <div className="flex min-w-0 flex-1 flex-col">
        <AppTopbar
          fullName={profile.full_name || "there"}
          avatarUrl={profile.avatar_url}
          role="super_admin"
          schoolName="Platform"
        />
        <main className="flex-1 overflow-y-auto bg-background p-4 sm:p-6">
          {children}
        </main>
      </div>
    </div>
  );
}
