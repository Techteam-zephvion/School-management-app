"use server";

import { z } from "zod";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { getAuthUser } from "@/lib/auth/session";
import type { ActionState } from "@/lib/actions/auth";

const profileSchema = z.object({
  full_name: z.string().trim().min(2, { error: "Enter your full name." }),
  phone: z.string().trim().optional(),
});

export async function updateProfile(
  _prev: ActionState,
  formData: FormData
): Promise<ActionState> {
  const user = await getAuthUser();
  if (!user) return { error: "You are not signed in." };

  const parsed = profileSchema.safeParse({
    full_name: formData.get("full_name"),
    phone: formData.get("phone"),
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "Invalid input." };
  }

  const supabase = await createClient();
  const { error } = await supabase
    .from("profiles")
    .update({
      full_name: parsed.data.full_name,
      phone: parsed.data.phone || null,
    })
    .eq("id", user.id);

  if (error) return { error: "Could not save your changes. Try again." };

  revalidatePath("/settings/profile");
  revalidatePath("/dashboard");
  return { error: undefined };
}
