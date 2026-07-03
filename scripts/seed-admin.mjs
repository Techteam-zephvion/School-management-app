// Dev-only bootstrap: creates the first school_admin for the seeded school
// (supabase/seed.sql), since there is no self-signup flow (doc 01 assumption --
// admins are provisioned, not self-registered). Run after `supabase db reset`:
//   node scripts/seed-admin.mjs
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

const email = "admin@greenwood.edu";
const password = "password123";

const { data: created, error: createError } =
  await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { full_name: "Asha Admin" },
  });

if (createError) {
  console.error("Could not create user:", createError.message);
  process.exit(1);
}

const userId = created.user.id;

const { error: memberError } = await admin.from("school_members").upsert(
  { school_id: SCHOOL_ID, user_id: userId, role: "school_admin", status: "active" },
  { onConflict: "school_id,user_id" }
);

if (memberError) {
  console.error("Could not create membership:", memberError.message);
  process.exit(1);
}

console.log(`Seeded school_admin: ${email} / ${password}`);
