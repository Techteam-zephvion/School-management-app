import type { Database } from "@/lib/supabase/database.types";

type Role = Database["public"]["Enums"]["app_role"];

const ROLE_LABELS: Record<Role, string> = {
  super_admin: "Platform Administrator",
  school_admin: "School Administrator",
  teacher: "Teacher",
  parent: "Parent / Guardian",
};

export function roleLabel(role: Role): string {
  return ROLE_LABELS[role] ?? role;
}
