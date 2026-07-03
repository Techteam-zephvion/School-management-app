"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { getAuthUser } from "@/lib/auth/session";

export async function updateProfile(formData: FormData) {
  const user = await getAuthUser();
  if (!user) return;

  const supabase = await createClient();
  await supabase
    .from("profiles")
    .update({
      full_name: String(formData.get("full_name") ?? ""),
      phone: String(formData.get("phone") ?? "") || null,
    })
    .eq("id", user.id);

  revalidatePath("/settings/profile");
}
