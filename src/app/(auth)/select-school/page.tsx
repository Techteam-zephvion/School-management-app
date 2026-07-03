import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { Building2 } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { getMemberships } from "@/lib/auth/session";
import { selectSchool } from "@/lib/actions/auth";

export const metadata: Metadata = { title: "Choose a school — EduSphere" };

export default async function SelectSchoolPage() {
  const memberships = await getMemberships();
  if (memberships.length === 0) redirect("/no-access");
  if (memberships.length === 1) redirect("/dashboard");

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-xl">Choose a school</CardTitle>
        <CardDescription>
          Your account has access to more than one school.
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-2">
        {memberships.map((m) => (
          <form
            key={m.schoolId}
            action={async () => {
              "use server";
              await selectSchool(m.schoolId);
            }}
          >
            <Button
              type="submit"
              variant="outline"
              className="w-full justify-start gap-3 py-6"
            >
              <Building2 className="size-4 text-muted-foreground" />
              <span className="flex flex-col items-start">
                <span className="font-medium">{m.schoolName}</span>
                <span className="text-xs capitalize text-muted-foreground">
                  {m.role.replace("_", " ")}
                </span>
              </span>
            </Button>
          </form>
        ))}
      </CardContent>
    </Card>
  );
}
