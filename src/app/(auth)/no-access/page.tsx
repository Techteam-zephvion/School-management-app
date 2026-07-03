import type { Metadata } from "next";
import { ShieldAlert } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { LogoutButton } from "@/components/logout-button";

export const metadata: Metadata = { title: "No access — EduSphere" };

export default function NoAccessPage() {
  return (
    <Card>
      <CardHeader className="items-center text-center">
        <ShieldAlert className="mb-2 size-10 text-muted-foreground" />
        <CardTitle className="text-xl">No school access yet</CardTitle>
        <CardDescription>
          Your account isn&apos;t linked to a school. Ask your school admin to
          invite you, or wait for your invite to be activated.
        </CardDescription>
      </CardHeader>
      <CardContent className="flex justify-center">
        <LogoutButton />
      </CardContent>
    </Card>
  );
}
