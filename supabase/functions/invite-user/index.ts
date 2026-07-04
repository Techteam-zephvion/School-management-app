// Setup type definitions for built-in Supabase Runtime APIs
import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";

// Admin creates an auth user + school_members row + sends an invite email
// (doc 02 §2.4, doc 06 Phase 1 task 6). Privileged: runs with ctx.supabaseAdmin
// (service role) after an application-level authorization check, since this
// mutates auth.users which no client-side RLS policy can guard.
type InviteRole = "school_admin" | "teacher" | "parent";
type InviteBody = {
  schoolId: string;
  email: string;
  fullName: string;
  role: InviteRole;
  phone?: string;
};

const VALID_ROLES: InviteRole[] = ["school_admin", "teacher", "parent"];

const ROLE_LABELS: Record<InviteRole, string> = {
  school_admin: "School Administrator",
  teacher: "Teacher",
  parent: "Parent / Guardian",
};

// Readable one-time password for parent accounts (no ambiguous 0/O/1/l/I).
function generatePassword(length = 10): string {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789";
  const bytes = new Uint8Array(length);
  crypto.getRandomValues(bytes);
  let out = "";
  for (const b of bytes) out += alphabet[b % alphabet.length];
  return out;
}

export default {
  fetch: withSupabase({ auth: "user" }, async (req, ctx) => {
    if (req.method !== "POST") {
      return Response.json({ error: "Method not allowed." }, { status: 405 });
    }

    let body: Partial<InviteBody>;
    try {
      body = await req.json();
    } catch {
      return Response.json({ error: "Invalid JSON body." }, { status: 400 });
    }

    const { schoolId, email, fullName, role, phone } = body;
    if (!schoolId || !email || !fullName || !role) {
      return Response.json(
        { error: "schoolId, email, fullName, and role are required." },
        { status: 400 }
      );
    }
    if (!VALID_ROLES.includes(role)) {
      return Response.json({ error: "Invalid role." }, { status: 400 });
    }

    const callerId = ctx.userClaims?.id;
    if (!callerId) {
      return Response.json({ error: "Unauthorized." }, { status: 401 });
    }

    // Authorization: platform admin, or an active school_admin of this school.
    // Uses ctx.supabase (RLS-scoped to the caller) so this can't be spoofed.
    const { data: profile } = await ctx.supabase
      .from("profiles")
      .select("is_platform_admin")
      .eq("id", callerId)
      .single();

    let authorized = Boolean(profile?.is_platform_admin);
    if (!authorized) {
      const { data: membership } = await ctx.supabase
        .from("school_members")
        .select("role")
        .eq("school_id", schoolId)
        .eq("user_id", callerId)
        .eq("status", "active")
        .eq("role", "school_admin")
        .maybeSingle();
      authorized = Boolean(membership);
    }

    if (!authorized) {
      return Response.json(
        { error: "Not authorized to invite members for this school." },
        { status: 403 }
      );
    }

    const appUrl = Deno.env.get("APP_URL") ?? "http://localhost:3000";

    // School name + role label feed the invite email template (design in
    // school_teacher portal/email_format.png): "{school} invited you to join
    // their academic team as: {role}".
    const { data: school } = await ctx.supabaseAdmin
      .from("schools")
      .select("name")
      .eq("id", schoolId)
      .single();
    const schoolName = school?.name ?? "your school";
    const roleLabel = ROLE_LABELS[role];

    // Re-inviting an existing user (e.g. a teacher moving to a second school)
    // just adds a membership -- they already have credentials to sign in with.
    const { data: existingProfile } = await ctx.supabaseAdmin
      .from("profiles")
      .select("id")
      .eq("email", email)
      .maybeSingle();

    // Parents/guardians live only in the separate React Native app -- they never
    // touch this web portal's accept-invite flow. So instead of a magic link we
    // create a real password-backed, email-confirmed account and email them the
    // credentials (they change the password later in the app). Staff keep the
    // web magic-link invite.
    const isParent = role === "parent";
    let userId: string;

    if (existingProfile) {
      userId = existingProfile.id;
    } else if (isParent) {
      const tempPassword = generatePassword();
      const { data: invited, error: inviteError } =
        await ctx.supabaseAdmin.auth.admin.inviteUserByEmail(email, {
          redirectTo: `${appUrl}/auth/confirm`,
          data: {
            full_name: fullName,
            school_name: schoolName,
            role_label: roleLabel,
            temp_password: tempPassword,
            login_email: email,
          },
        });
      if (inviteError || !invited?.user) {
        return Response.json(
          { error: inviteError?.message ?? "Could not send invite." },
          { status: 400 }
        );
      }
      userId = invited.user.id;
      // Give them a usable password and confirm the email so they can sign into
      // the app immediately with the credentials from the invite email.
      const { error: pwError } = await ctx.supabaseAdmin.auth.admin.updateUserById(
        userId,
        { password: tempPassword, email_confirm: true }
      );
      if (pwError) {
        return Response.json({ error: pwError.message }, { status: 400 });
      }
    } else {
      const { data: invited, error: inviteError } =
        await ctx.supabaseAdmin.auth.admin.inviteUserByEmail(email, {
          redirectTo: `${appUrl}/auth/confirm?next=/accept-invite`,
          data: {
            full_name: fullName,
            school_name: schoolName,
            role_label: roleLabel,
          },
        });
      if (inviteError || !invited?.user) {
        return Response.json(
          { error: inviteError?.message ?? "Could not send invite." },
          { status: 400 }
        );
      }
      userId = invited.user.id;
    }

    const { error: memberError } = await ctx.supabaseAdmin
      .from("school_members")
      .upsert(
        {
          school_id: schoolId,
          user_id: userId,
          // Parents are set up fully here (no web accept step), so they start active.
          status: existingProfile || isParent ? "active" : "invited",
          role,
        },
        { onConflict: "school_id,user_id" }
      );

    if (memberError) {
      return Response.json({ error: memberError.message }, { status: 400 });
    }

    if (phone) {
      await ctx.supabaseAdmin
        .from("profiles")
        .update({ phone })
        .eq("id", userId);
    }

    return Response.json({
      success: true,
      userId,
      alreadyExisted: Boolean(existingProfile),
    });
  }),
};
