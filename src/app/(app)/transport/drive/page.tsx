import { redirect } from "next/navigation";
import { requireActiveMembership } from "@/lib/auth/session";
import { createClient } from "@/lib/supabase/server";
import { DriveClient } from "./drive-client";

export const metadata = { title: "Driver mode — EduSphere" };

export default async function DrivePage() {
  const membership = await requireActiveMembership();
  if (membership.role === "parent") redirect("/dashboard");
  const supabase = await createClient();
  const { data: routes } = await supabase
    .from("bus_routes")
    .select("id, name")
    .eq("school_id", membership.schoolId)
    .order("name");
  return <DriveClient routes={routes ?? []} />;
}
