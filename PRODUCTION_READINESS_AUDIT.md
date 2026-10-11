# Schoolic Production Readiness Audit

Latest audit update: October 11, 2026

Scope note: Phase 5.4 promoted the Phase 5.2 UX redesign and Phase 5.3 timetable work to production on the existing Neon Auth / Better Auth architecture. Hostinger DNS, nameservers, and `zephvion.com` custom domains were not changed. Secret values are intentionally omitted.

## Phase 5.4 Update

Phase 5.4 released the redesigned administrator/teacher workspaces and timetable feature to production.

Completed work:

- Release commit: `6de84bf`.
- Created fresh pre-release Neon snapshot `snap-curly-hat-b5woqrcz` on production branch `br-rapid-lake-b5g9wtix`.
- Applied migration `0001_harsh_firedrake` to production and verified `timetable_entries` plus timetable indexes and Drizzle migration history.
- Seeded eight production portfolio timetable entries from existing teacher assignments.
- Deployed production Worker `schoolic-api`, version `8739669f-8c95-4a6d-83fb-a5cfc9ab8ee5`.
- Deployed production Pages preview `https://3023752a.schoolic.pages.dev`; canonical frontend remains `https://schoolic.pages.dev`.

Verification:

- `pnpm api:typecheck`: passed.
- `pnpm api:test`: passed, 22/22 tests.
- `cd apps/flutter_app && flutter analyze`: passed with no issues.
- `cd apps/flutter_app && flutter test`: passed, 6/6 tests.
- Production API health, Pages HTTP 200, and CORS from `https://schoolic.pages.dev` passed.
- Production admin and teacher login smoke tests passed.
- Invalid tokens and development-bypass headers return 401; teacher admin access returns 403.
- Admin timetable create/conflict/edit/delete smoke test passed.
- Teacher timetable visibility and scheduled attendance submission smoke test passed.

Note: The older manual snapshot `snap-lucky-star-b5i49wpy` was deleted because the Neon project snapshot limit had been reached; it was replaced by `snap-curly-hat-b5woqrcz`.

## Phase 5.1 Update

Phase 5.1 enabled production Neon Auth, connected it to the deployed API and Flutter web app, created real production auth identities for the synthetic portfolio admin and teacher users, and verified authenticated production behavior.

Completed work:

- Enabled Neon Auth on production project `schoolic` (`dark-frost-36120929`), branch `main` (`br-rapid-lake-b5g9wtix`), database `neondb`.
- Verified provider status reports Better Auth with Base URL `https://ep-polished-silence-b52ozwm7.neonauth.c-7.us-east-2.aws.neon.tech/neondb/auth`.
- Added trusted domain `https://schoolic.pages.dev`.
- Updated the API and Flutter client to accept Neon Auth values that are either the provider Base URL ending in `/auth` or the parent project auth root.
- Configured production Worker `NEON_AUTH_URL` to the provider-reported production Base URL.
- Rebuilt and redeployed production Flutter with the production API and Auth URLs.
- Created one production administrator auth identity and one production teacher auth identity for the synthetic portfolio school, then mapped their real Neon Auth user IDs into existing `app_users` records.
- Removed production/staging visibility of local development sign-in buttons and prevented local dev sign-in from fabricating a session when the API rejects it.
- Corrected the production Worker `DATABASE_URL` secret formatting so runtime database queries use a valid URL. The value remains omitted.

Authentication verification:

- Admin sign-in succeeds through Neon Auth and `/api/v1/me` returns role `admin`.
- Teacher sign-in succeeds through Neon Auth and `/api/v1/me` returns role `teacher`.
- Admin can load `/api/v1/admin/overview` for `Schoolic Portfolio Academy`.
- Teacher receives 403 on `/api/v1/admin/overview`.
- Teacher can load `/api/v1/teacher/assignments`.
- Invalid bearer token returns 401.
- Production development-bypass headers return 401.
- Local regression checks passed: `pnpm api:typecheck`, `pnpm api:test` (18/18), `cd apps/flutter_app && flutter analyze`, and `pnpm flutter:test`.

Latest production deployment:

- Frontend: `https://schoolic.pages.dev`
- Latest Pages deployment: `https://3023752a.schoolic.pages.dev`
- API Worker: `https://schoolic-api.schoolic-api.workers.dev`

## Phase 4.2 Update

Phase 4.2 resolved the production Drizzle migration-history issue, seeded realistic synthetic portfolio data, created production Cloudflare hosting resources, deployed the API and frontend, and verified the live default-domain application.

Phase 4.2 production URLs:

- Frontend: `https://schoolic.pages.dev`
- Latest Pages deployment: `https://7e543704.schoolic.pages.dev`
- API Worker: `https://schoolic-api.schoolic-api.workers.dev`

Completed work:

- Created a Neon manual recovery snapshot before production migration-history changes: `snap-lucky-star-b5i49wpy` (`pre-phase-4-2-migration-baseline-20261011`).
- Confirmed the existing production schema matched the repository's initial Drizzle migration.
- Inserted the missing Drizzle baseline history row for `0000_aspiring_madame_hydra`.
- Ran `pnpm db:migrate` successfully against production after baselining.
- Added and applied `database/production-demo-seed.sql` with synthetic portfolio data.
- Created production Cloudflare Pages project `schoolic`.
- Deployed production API Worker `schoolic-api` with `workers_dev` enabled.
- Configured production Worker secrets `DATABASE_URL` and `BOOTSTRAP_TOKEN` through Wrangler. Values were not printed or documented.
- Updated production API CORS to `https://schoolic.pages.dev`.
- Rebuilt `apps/flutter_app/build/web_prod` with `API_BASE_URL=https://schoolic-api.schoolic-api.workers.dev`.
- Deployed the production Flutter web artifact to Cloudflare Pages.
- Removed an unintended temporary Workers-backed `schoolic` deployment created during Cloudflare's Pages delegation attempt.

Production synthetic data summary:

- Added portfolio school `Schoolic Portfolio Academy` (`PORTFOLIO`).
- Added academic year `2026-2027`, 3 classes, 6 sections, 4 subjects, 4 staff records, 2 app users, 12 students, 12 enrollments, 4 teacher assignments, 4 attendance sessions, and 16 attendance records.
- Existing production records were preserved.

Verification:

- `pnpm db:migrate`: passed after baseline row insertion.
- `pnpm api:typecheck`: passed.
- `pnpm api:test`: passed, 18/18 tests.
- `cd apps/flutter_app && flutter analyze`: passed with no issues.
- `pnpm flutter:test`: passed.
- `pnpm flutter:build:web:prod`: passed and produced `apps/flutter_app/build/web_prod`.
- Production frontend `https://schoolic.pages.dev`: HTTP 200 and serves Flutter bootstrap assets.
- Production API health `https://schoolic-api.schoolic-api.workers.dev/health`: HTTP 200 with `{"ok":true,"service":"schoolic-api"}`.
- Production API CORS preflight from `https://schoolic.pages.dev`: allows the Pages origin.
- Production bundle scan: contains the production API Worker URL and does not contain `zephvion.com`, staging API URLs, `neonauth`, or database URLs.
- Protected API routes fail closed: unauthenticated `/api/v1/me` returns 401; invalid bearer token returns `Authentication service misconfigured` because production Neon Auth is not configured.

## Executive Summary

Schoolic is deployed on Cloudflare default domains and production authentication now works for the designated synthetic portfolio administrator and teacher accounts.

The API and frontend are live, production migration history is repaired, realistic synthetic data exists, old custom-domain dependencies have been removed from the production build, authenticated role-based access has been verified, and the UX redesign plus timetable feature are deployed to production.

## Status Key

- **Verified:** Confirmed from repository files, local ignored env inventory, authenticated Neon/Cloudflare control planes, live endpoints, or local checks.
- **Blocked:** Cannot be completed safely because a required resource/configuration remains missing.
- **Deferred:** Explicitly left for a future phase by request.

## 1. Production Neon Project And Database

| Item | Status | Finding |
| --- | --- | --- |
| Intended production project | Verified | Neon project `schoolic`, project ID `dark-frost-36120929`, org `org-small-mouse-93856091`, region `aws-us-east-2`, Postgres 18. |
| Production branch | Verified | Branch `main`, branch ID `br-rapid-lake-b5g9wtix`, primary/default branch, current state `ready`. |
| Production database | Verified | Database `neondb`, owner role `neondb_owner`. |
| Staging separation | Verified | Staging remains separate: `schoolic-staging` / `nameless-dust-81736720` / branch `br-floral-mountain-b5s114go`. |
| Unrelated Neon project | Verified | `neon-amethyst-pillow` was not used. |
| Recovery snapshot | Verified | Manual snapshot `snap-curly-hat-b5woqrcz` created before Phase 5.4 timetable release. |
| Branch protection | Blocked | Production branch is still not protected in Neon metadata. |
| Drizzle migration history | Verified | Baseline row for `0000_aspiring_madame_hydra` and timetable row for `0001_harsh_firedrake` are present. |

## 2. Production Authentication

| Item | Status | Finding |
| --- | --- | --- |
| Production Neon Auth | Verified | Neon Auth is enabled for branch `br-rapid-lake-b5g9wtix`. |
| Production auth endpoint | Verified | Provider-reported Base URL is `https://ep-polished-silence-b52ozwm7.neonauth.c-7.us-east-2.aws.neon.tech/neondb/auth`. |
| Trusted production frontend domain | Verified | `https://schoolic.pages.dev` is registered. |
| Worker auth variable | Verified | Production Worker `NEON_AUTH_URL` is configured to the verified provider Base URL. |
| Frontend auth config | Verified | Production Flutter build includes the verified production Auth Base URL. |
| Auth identities | Verified | Synthetic admin and teacher auth users are mapped to existing `app_users` records. |
| Auth safety | Verified | Protected API routes fail closed; no public demo mode or auth bypass was introduced. |

## 3. Cloudflare Production Infrastructure

| Item | Status | Finding |
| --- | --- | --- |
| Cloudflare account | Verified | Wrangler is authenticated as `vbk.zephvion@gmail.com`, account ID `5c34da760e86d900ee5274d71ad9191e`. |
| `zephvion.com` zone | Verified missing | Cloudflare API query for `zephvion.com` returned zero zones in the authenticated account. Hostinger DNS remains unchanged. |
| Production Worker | Verified | Worker `schoolic-api` deployed at `https://schoolic-api.schoolic-api.workers.dev`. |
| Production Worker secrets | Verified | Secret names `DATABASE_URL` and `BOOTSTRAP_TOKEN` were configured through Wrangler; values omitted. |
| Production Pages project | Verified | Pages project `schoolic` created and deployed at `https://schoolic.pages.dev`. |
| Hostinger DNS | Verified | No DNS, nameserver, or custom-domain changes were made. |

## 4. Required Environment And Secret Configuration

| Name | Type | Status | Current Production State |
| --- | --- | --- | --- |
| `APP_ENV` | Worker variable | Verified | `production`. |
| `CORS_ORIGIN` | Worker variable | Verified | `https://schoolic.pages.dev`. |
| `NEON_AUTH_URL` | Worker variable | Verified | Configured to the verified production Neon Auth Base URL. |
| `DATABASE_URL` | Worker secret | Verified | Configured through Wrangler; value omitted. |
| `DATABASE_URL_UNPOOLED` | Local migration env | Verified | Present in ignored local env for migration tooling; value omitted. |
| `BOOTSTRAP_TOKEN` | Worker secret | Verified | Configured through Wrangler; value omitted. |

Security separation checks:

- **Verified:** Production/staging code ignores development bypass headers unless `APP_ENV` is `development` or `test`.
- **Verified:** CORS code uses an explicit allowlist and does not allow arbitrary origins in production.
- **Verified:** Flutter production assets do not contain database URLs, staging endpoints, old custom domains, or Neon Auth endpoints.
- **Verified:** Production API verifies real Neon Auth users and enforces role authorization.

## 5. Database Migration And Recovery Assessment

Local migration inventory:

- One migration exists: `database/migrations/0000_aspiring_madame_hydra.sql`.
- Migration creates the V1 schema, enums, tables, uniqueness constraints, and foreign keys.
- Drizzle journal contains one entry for that migration.
- No destructive follow-up migrations are present in the repository.

Production verification:

- **Verified:** Direct SQL access works through Neon CLI embedded TypeScript `psql`.
- **Verified:** The production schema has the expected V1 Schoolic tables, enums, primary keys, unique constraints, foreign keys, and not-null/default definitions.
- **Verified:** Baseline migration metadata was inserted with the Drizzle SHA-256 hash for `0000_aspiring_madame_hydra` and journal timestamp `1791573209289`.
- **Verified:** `pnpm db:migrate` now applies cleanly.
- **Verified:** Existing rows were preserved; synthetic portfolio rows were added.

Remaining recovery work:

- Protect the production branch before real pilot data is introduced.
- Decide whether to configure a recurring snapshot schedule and test restore into a non-production branch.

## 6. Production Release Artifacts

| Item | Status | Finding |
| --- | --- | --- |
| Production artifact | Verified | `apps/flutter_app/build/web_prod` was rebuilt for production default domains. |
| API endpoint in artifact | Verified | Artifact targets `https://schoolic-api.schoolic-api.workers.dev`. |
| Auth endpoint in artifact | Verified | Artifact targets the production Neon Auth Base URL. |
| Obsolete custom domains | Verified | No `zephvion.com`, `api-school`, or `auth.schoolic` references found in production bundle. |
| Staging references | Verified | No staging API/Pages endpoint references found in production bundle. |
| Database secrets in artifact | Verified | No database URL or Postgres host was found in `web_prod`. |
| Switzer fonts | Verified | Production build includes bundled app font assets. |

## 7. Remaining Blockers

1. **Deferred:** Recurring production snapshot schedule and restore drill are not configured.
2. **Out of scope for Phase 5:** Production branch protection work.

## 8. Safe Next Production Sequence

1. Keep production and staging data/auth separation intact.
2. Configure/test recovery policy before introducing real student data.
3. Continue with the next product feature only after production monitoring remains healthy.
