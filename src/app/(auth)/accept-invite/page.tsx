import type { Metadata } from "next";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { AcceptInviteForm } from "./accept-invite-form";

export const metadata: Metadata = { title: "Activate your account — EduSphere" };

export default function AcceptInvitePage() {
  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-xl">Welcome to EduSphere</CardTitle>
        <CardDescription>
          Set your name and a password to finish setting up your account.
        </CardDescription>
      </CardHeader>
      <CardContent>
        <AcceptInviteForm />
      </CardContent>
    </Card>
  );
}
