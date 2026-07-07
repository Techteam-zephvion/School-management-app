// Dev-only bootstrap: creates the first school_admin for the seeded school
// (supabase/seed.sql) plus a platform (super_admin) account, since there is no
// self-signup flow (doc 01 -- admins are provisioned, not self-registered).
// Run after `supabase db reset`:  node scripts/seed-admin.mjs
import { createClient } from "@supabase/supabase-js";

const SUPABASE_URL = process.env.SUPABASE_URL ?? "http://127.0.0.1:54321";
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const SCHOOL_ID = "00000000-0000-0000-0000-000000000001";

if (!SERVICE_ROLE_KEY) {
  console.error("Set SUPABASE_SERVICE_ROLE_KEY in the environment first.");
  process.exit(1);
}

const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

// Create the user, or find + reset it if it already exists (idempotent).
async function ensureUser(email, password, fullName) {
  const { data: created, error } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { full_name: fullName },
  });
  if (!error) return created.user.id;
  if (!/already been registered/i.test(error.message)) throw error;

  const { data: list } = await admin.auth.admin.listUsers({ perPage: 1000 });
  const user = list.users.find((u) => u.email === email);
  if (!user) throw new Error(`Could not find existing user ${email}`);
  await admin.auth.admin.updateUserById(user.id, { password, email_confirm: true });
  return user.id;
}

// ---- school admin ----
const schoolAdminId = await ensureUser("admin@greenwood.edu", "password123", "Asha Admin");
const { error: memberError } = await admin.from("school_members").upsert(
  { school_id: SCHOOL_ID, user_id: schoolAdminId, role: "school_admin", status: "active" },
  { onConflict: "school_id,user_id" }
);
if (memberError) {
  console.error("Could not create membership:", memberError.message);
  process.exit(1);
}
console.log("Seeded school_admin:  admin@greenwood.edu / password123");

// ---- platform (super_admin) ----
const superId = await ensureUser("super@edusphere.dev", "superadmin123", "Platform Owner");
const { error: platErr } = await admin.from("profiles").update({ is_platform_admin: true }).eq("id", superId);
if (platErr) {
  console.error("Could not set platform admin:", platErr.message);
  process.exit(1);
}
console.log("Seeded super_admin:   super@edusphere.dev / superadmin123");
