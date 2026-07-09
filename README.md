# EduSphere — Teacher / Admin Web Portal

The Next.js (App Router, TypeScript) web client of the School ERP, on a shared
Supabase backend. Built phase-by-phase per the specs in `../claude/`.

**Stack:** Next.js 16 (App Router) · TypeScript (strict) · Tailwind CSS v4 +
shadcn/ui · Supabase (Postgres + Auth + Storage + Edge Functions) ·
`@supabase/ssr` · react-hook-form + Zod · TanStack Table · Recharts · Vitest.

The Parent mobile app (Expo / React Native) lives in the sibling
`parent-portal-app/` folder and talks to the same Supabase project.

## Status

- **Phase 0 — Foundations:** ✅ app scaffold, Supabase local project, design
  tokens (EduSphere palette from the Figma exports), generated DB types.
- **Phase 1 — Auth, roles & tenancy:** ✅ `schools` / `profiles` /
  `school_members` / `academic_years` migrations, RLS helper functions
  (`auth_school_ids`, `has_role`, `is_platform_admin`) + deny-by-default
  policies, auth screens (login / forgot / reset / accept-invite /
  select-school), role-based routing + role-filtered shell, `invite-user`
  Edge Function, staff invite UI. RLS cross-school isolation test passing.
- **Phases 2–13:** routes are stubbed with a "coming soon" card naming the
  phase they ship in (see `../claude/06-Implementation-Plan.md`).

## Prerequisites

- Node 20+ and npm
- Docker (for the local Supabase stack)
- NOTHING ELSE

## Local setup

```bash
npm install

# 1. Start the local Supabase stack (Postgres, Auth, Storage, Edge runtime).
npx supabase start

# 2. Apply migrations + seed the demo school. (start already applies migrations;
#    use db:reset to re-apply from scratch.)
npm run db:reset

# 3. Regenerate DB types after any migration change.
npm run db:types

# 4. Bootstrap the first school_admin (there is no self-signup -- admins are
#    provisioned). Requires SUPABASE_SERVICE_ROLE_KEY in the environment.
SUPABASE_SERVICE_ROLE_KEY=<service-role-key> npm run seed:admin
#   -> admin@greenwood.edu / password123

# 5. Run the app.
npm run dev   # http://localhost:3000
```

Copy `.env.example` to `.env.local` and fill in the values printed by
`supabase start` — for local dev these are the standard shared Supabase demo
keys. `.env*` is gitignored, so nothing secret is committed.

Local email (invites, password resets) is captured by Mailpit at
http://127.0.0.1:54324 — no real mail is sent in dev.

## Auth flow notes

- Email links (invite, password recovery) use the **PKCE flow**: custom
  templates in `supabase/templates/*.html` link to `/auth/confirm?token_hash=…`,
  which verifies the OTP server-side and establishes the cookie session. This
  avoids GoTrue's default implicit flow (tokens in the URL fragment, unreadable
  by the server).
- `src/proxy.ts` is the Next.js 16 renamed `middleware.ts` — it refreshes the
  Supabase session on every request and does an optimistic auth redirect. The
  real authorization boundary is **RLS**, enforced in Postgres.

## Testing

```bash
npm run test:rls   # Phase 1 RLS cross-school isolation (needs supabase running)
npm run test       # all tests
```

## Project layout

```
src/
  app/
    (auth)/        login, forgot/reset password, accept-invite, select-school
    (app)/         authenticated shell: dashboard + module routes
    (platform)/    super_admin console
    auth/confirm/  email-link OTP verification route handler
  components/       app shell (sidebar/topbar), shared UI, shadcn/ui
  lib/
    supabase/      browser + server clients, generated database.types.ts
    auth/          session DAL (getProfile, getMemberships, requireActiveMembership)
    actions/       server actions (auth, profile, staff)
    nav.ts         role-filtered navigation model
    status.ts      attendance/fee/leave status -> badge color mapping (doc 04)
supabase/
  migrations/      SQL source of truth for schema + RLS
  functions/       Edge Functions (invite-user)
  templates/       PKCE email templates
  seed.sql         demo school + academic year
scripts/
  seed-admin.mjs   bootstrap the first school_admin
tests/             Vitest integration tests (RLS)
```
