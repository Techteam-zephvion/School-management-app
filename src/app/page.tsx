import { redirect } from "next/navigation";
import { getAuthUser } from "@/lib/auth/session";

export default async function RootPage() {
  const user = await getAuthUser();
  redirect(user ? "/dashboard" : "/login");
}
