import "server-only";
import { createClient } from "@supabase/supabase-js";
import type { Database } from "@/lib/supabase/database.types";

/**
 * Service-role Supabase client for privileged, server-only operations
 * (platform onboarding, etc.). It BYPASSES RLS, so it must only be used behind
 * an application-level authorization check and never imported into a client
 * component (the `server-only` import enforces that at build time).
 */
export function createAdminClient() {
  return createClient<Database>(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    { auth: { autoRefreshToken: false, persistSession: false } }
  );
}
