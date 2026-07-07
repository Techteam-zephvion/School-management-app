"use server";

import { z } from "zod";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { getProfile } from "@/lib/auth/session";
import type { ActionState } from "@/lib/actions/auth";

async function requirePlatformAdmin(): Promise<true | { error: string }> {
  const profile = await getProfile();
  if (!profile?.is_platform_admin) return { error: "Platform admins only." };
  return true;
}

function slugify(name: string) {
  const base = name.toLowerCase().trim().replace(/[^a-z0-9]+/g, "-").replace(/(^-|-$)/g, "").slice(0, 40);
  return `${base || "school"}-${Math.random().toString(36).slice(2, 6)}`;
}

const createSchema = z.object({
  name: z.string().trim().min(2, { error: "Enter the school name." }),
  adminName: z.string().trim().min(2, { error: "Enter the admin's name." }),
  adminEmail: z.email({ error: "Enter a valid admin email." }),
  city: z.string().trim().optional(),
});

/** Onboard a school end-to-end: create the tenant row, then provision its first
 *  school_admin via invite-user (which authorizes a platform admin caller). */
export async function createSchoolWithAdmin(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const guard = await requirePlatformAdmin();
  if (guard !== true) return guard;

  const parsed = createSchema.safeParse({
    name: formData.get("name"),
    adminName: formData.get("adminName"),
    adminEmail: formData.get("adminEmail"),
    city: formData.get("city") ?? undefined,
  });
  if (!parsed.success) return { error: parsed.error.issues[0]?.message ?? "Invalid input." };

  // Platform onboarding is privileged and must not depend on the edge runtime,
  // so it runs with a service-role client (behind the platform-admin check above).
  const admin = createAdminClient();
  const appUrl = process.env.NEXT_PUBLIC_APP_URL ?? "http://localhost:3000";

  const { data: school, error } = await admin
    .from("schools")
    .insert({ name: parsed.data.name, slug: slugify(parsed.data.name), city: parsed.data.city || null })
    .select("id")
    .single();
  if (error || !school) return { error: error?.message ?? "Could not create the school." };

  async function rollback(reason: string): Promise<{ error: string }> {
    await admin.from("schools").delete().eq("id", school!.id);
    return { error: reason };
  }

  // Provision the first school_admin: reuse an existing account, else invite one.
  const { data: existing } = await admin.from("profiles").select("id").eq("email", parsed.data.adminEmail).maybeSingle();
  let adminUserId: string;
  if (existing) {
    adminUserId = existing.id;
  } else {
    const { data: invited, error: inviteErr } = await admin.auth.admin.inviteUserByEmail(parsed.data.adminEmail, {
      redirectTo: `${appUrl}/auth/confirm?next=/accept-invite`,
      data: { full_name: parsed.data.adminName, school_name: parsed.data.name, role_label: "School Administrator" },
    });
    if (inviteErr || !invited?.user) return rollback(inviteErr?.message ?? "Could not invite the admin.");
    adminUserId = invited.user.id;
  }

  const { error: memberErr } = await admin.from("school_members").upsert(
    { school_id: school.id, user_id: adminUserId, role: "school_admin", status: existing ? "active" : "invited" },
    { onConflict: "school_id,user_id" }
  );
  if (memberErr) return rollback(memberErr.message);

  revalidatePath("/platform/schools");
  return { error: undefined };
}

export async function setSchoolStatus(schoolId: string, status: "active" | "suspended"): Promise<ActionState> {
  const guard = await requirePlatformAdmin();
  if (guard !== true) return guard;
  const supabase = await createClient();
  const { error } = await supabase.from("schools").update({ status }).eq("id", schoolId);
  if (error) return { error: error.message };
  revalidatePath("/platform/schools");
  revalidatePath(`/platform/schools/${schoolId}`);
  return { error: undefined };
}

/** Permanently delete a school and ALL its data (cascades). Only allowed once
 *  the school is suspended, and the caller must confirm the exact name. */
export async function deleteSchool(schoolId: string, confirmName: string): Promise<ActionState> {
  const guard = await requirePlatformAdmin();
  if (guard !== true) return guard;

  const admin = createAdminClient();
  const { data: school } = await admin.from("schools").select("name, status").eq("id", schoolId).maybeSingle();
  if (!school) return { error: "School not found." };
  if (school.status !== "suspended") return { error: "Suspend the school before deleting it." };
  if (confirmName.trim() !== school.name) return { error: "The name you typed doesn't match." };

  // ON DELETE CASCADE removes every dependent row for this tenant.
  const { error } = await admin.from("schools").delete().eq("id", schoolId);
  if (error) return { error: error.message };
  revalidatePath("/platform/schools");
  return { error: undefined };
}
