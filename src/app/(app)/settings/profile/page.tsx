import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Label } from "@/components/ui/label";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { getProfile, requireActiveMembership } from "@/lib/auth/session";
import { updateProfile } from "@/lib/actions/profile";

export default async function ProfileSettingsPage() {
  const membership = await requireActiveMembership();
  const profile = await getProfile();

  return (
    <div className="max-w-xl space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Profile settings</h1>
        <p className="text-muted-foreground">
          {membership.schoolName} ·{" "}
          <span className="capitalize">{membership.role.replace("_", " ")}</span>
        </p>
      </div>
      <Card>
        <CardHeader>
          <CardTitle>Your details</CardTitle>
          <CardDescription>Visible to staff at your school.</CardDescription>
        </CardHeader>
        <CardContent>
          <form action={updateProfile} className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="full_name">Full name</Label>
              <Input
                id="full_name"
                name="full_name"
                defaultValue={profile?.full_name ?? ""}
                required
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="phone">Phone</Label>
              <Input id="phone" name="phone" defaultValue={profile?.phone ?? ""} />
            </div>
            <div className="space-y-2">
              <Label>Email</Label>
              <Input value={profile?.email ?? ""} disabled />
            </div>
            <Button type="submit">Save changes</Button>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}
