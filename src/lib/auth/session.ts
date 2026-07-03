import "server-only";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { cache } from "react";
import { createClient } from "@/lib/supabase/server";
import type { Database } from "@/lib/supabase/database.types";

export type Role = Database["public"]["Enums"]["app_role"];

export type Membership = {
  schoolId: string;
  schoolName: string;
  role: Role;
};

export const ACTIVE_SCHOOL_COOKIE = "active_school_id";

// cache() memoizes per-request so every Server Component/layout on the tree can
// call this without re-querying (doc 02 §9 DAL pattern).
export const getAuthUser = cache(async () => {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  return user;
});

export const getProfile = cache(async () => {
  const user = await getAuthUser();
  if (!user) return null;
  const supabase = await createClient();
  const { data } = await supabase
    .from("profiles")
    .select("*")
    .eq("id", user.id)
    .single();
  return data;
});

export const getMemberships = cache(async (): Promise<Membership[]> => {
  const user = await getAuthUser();
  if (!user) return [];
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("school_members")
    .select("school_id, role, schools(name)")
    .eq("user_id", user.id)
    .eq("status", "active");

  if (error || !data) return [];
  return data.map((m) => ({
    schoolId: m.school_id,
    role: m.role,
    schoolName: (m.schools as { name: string } | null)?.name ?? "",
  }));
});

/** Resolves the active school for this request: auto-selected if the user has
 * exactly one membership, otherwise read from the `active_school_id` cookie
 * (set by /select-school). Returns null if unresolved. */
export async function getActiveMembership(): Promise<Membership | null> {
  const memberships = await getMemberships();
  if (memberships.length === 0) return null;
  if (memberships.length === 1) return memberships[0];

  const cookieStore = await cookies();
  const activeId = cookieStore.get(ACTIVE_SCHOOL_COOKIE)?.value;
  return memberships.find((m) => m.schoolId === activeId) ?? null;
}

/** Redirects unresolved sessions: no session -> /login, no membership -> a
 * no-access message, multiple schools without a selection -> /select-school. */
export async function requireActiveMembership(): Promise<Membership> {
  const user = await getAuthUser();
  if (!user) redirect("/login");

  const memberships = await getMemberships();
  if (memberships.length === 0) {
    const profile = await getProfile();
    if (profile?.is_platform_admin) redirect("/platform/schools");
    redirect("/no-access");
  }

  const active = await getActiveMembership();
  if (!active) redirect("/select-school");
  return active;
}
