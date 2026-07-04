import { getProfile, requireActiveMembership } from "@/lib/auth/session";
import { PageHeader } from "@/components/page-header";
import { ProfileForm } from "./profile-form";

export default async function ProfileSettingsPage() {
  const membership = await requireActiveMembership();
  const profile = await getProfile();

  return (
    <div className="mx-auto max-w-xl space-y-6">
      <PageHeader
        title="Profile settings"
        description={`${membership.schoolName} · ${membership.role.replace("_", " ")}`}
      />
      <ProfileForm
        fullName={profile?.full_name ?? ""}
        phone={profile?.phone ?? ""}
        email={profile?.email ?? ""}
      />
    </div>
  );
}
