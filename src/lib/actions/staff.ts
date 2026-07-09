"use server";

import { z } from "zod";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { requireActiveMembership } from "@/lib/auth/session";
import type { ActionState } from "@/lib/actions/auth";
import { functionErrorMessage } from "@/lib/supabase/function-error";

const inviteStaffSchema = z.object({
  fullName: z.string().min(2, { error: "Enter a full name." }),
  email: z.email({ error: "Enter a valid email address." }),
  role: z.enum(["school_admin", "teacher"], { error: "Choose a role." }),
});

export async function inviteStaffMember(
  _prevState: ActionState,
  formData: FormData
): Promise<ActionState> {
  const membership = await requireActiveMembership();
  if (membership.role !== "school_admin") {
    return { error: "Only school admins can invite staff." };
  }

  const parsed = inviteStaffSchema.safeParse({
    fullName: formData.get("fullName"),
    email: formData.get("email"),
    role: formData.get("role"),
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "Invalid input." };
  }

  const supabase = await createClient();
  const { data, error } = await supabase.functions.invoke("invite-user", {
    body: {
      schoolId: membership.schoolId,
      email: parsed.data.email,
      fullName: parsed.data.fullName,
      role: parsed.data.role,
    },
  });

  const inviteError = await functionErrorMessage(data, error, "Could not send invite.");
  if (inviteError) {
    return { error: inviteError };
  }

  revalidatePath("/settings/staff");
  return { error: undefined };
}

export async function removeStaffMember(
  _prevState: ActionState,
  formData: FormData
): Promise<ActionState> {
  const membership = await requireActiveMembership();
  if (membership.role !== "school_admin") {
    return { error: "Only school admins can remove staff." };
  }

  const memberId = formData.get("memberId");
  if (typeof memberId !== "string" || !memberId) {
    return { error: "Missing member ID." };
  }

  const supabase = await createClient();

  // Prevent self-deletion: check if the target belongs to the current user.
  const { data: target } = await supabase
    .from("school_members")
    .select("user_id")
    .eq("id", memberId)
    .eq("school_id", membership.schoolId)
    .maybeSingle();

  if (!target) {
    return { error: "Staff member not found." };
  }

  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (user && target.user_id === user.id) {
    return { error: "You cannot remove yourself." };
  }

  const { error } = await supabase
    .from("school_members")
    .delete()
    .eq("id", memberId)
    .eq("school_id", membership.schoolId);

  if (error) {
    return { error: "Could not remove staff member." };
  }

  revalidatePath("/settings/staff");
  return { error: undefined };
}
