# Schoolic Production Readiness Audit

Latest audit update: October 11, 2026

Scope note: Phase 4.2 completed the approved production portfolio deployment path using Cloudflare default domains. Hostinger DNS, nameservers, and `zephvion.com` custom domains were not changed. Secret values are intentionally omitted.

## Phase 4.2 Update

Phase 4.2 resolved the production Drizzle migration-history issue, seeded realistic synthetic portfolio data, created production Cloudflare hosting resources, deployed the API and frontend, and verified the live default-domain application.

Production URLs:

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

Schoolic is now deployed for portfolio inspection on Cloudflare default domains, but it is not fully production-ready for authenticated pilot use.

The API and frontend are live, production migration history is repaired, realistic synthetic data exists, and old custom-domain dependencies have been removed from the production build. The remaining primary blocker is production Neon Auth: login cannot work until Neon Auth is enabled for the production branch and `NEON_AUTH_URL` is configured to the verified production auth root.

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
| Recovery snapshot | Verified | Manual snapshot `snap-lucky-star-b5i49wpy` created before Phase 4.2 database changes. |
| Branch protection | Blocked | Production branch is still not protected in Neon metadata. |
| Drizzle migration history | Verified | Baseline row for `0000_aspiring_madame_hydra` is present and `pnpm db:migrate` succeeds. |

## 2. Production Authentication

| Item | Status | Finding |
| --- | --- | --- |
| Production Neon Auth | Blocked | Neon Auth is not configured for branch `br-rapid-lake-b5g9wtix`. |
| Production auth endpoint | Blocked | No production Neon Auth root exists yet. |
| Worker auth variable | Deferred | `NEON_AUTH_URL` is intentionally empty in production until the real production auth root exists. |
| Frontend auth config | Deferred | Production Flutter build intentionally omits `NEON_AUTH_URL`; sign-in displays the existing configuration error rather than using a fake or staging auth endpoint. |
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
| `NEON_AUTH_URL` | Worker variable | Blocked | Empty until production Neon Auth is enabled. |
| `DATABASE_URL` | Worker secret | Verified | Configured through Wrangler; value omitted. |
| `DATABASE_URL_UNPOOLED` | Local migration env | Verified | Present in ignored local env for migration tooling; value omitted. |
| `BOOTSTRAP_TOKEN` | Worker secret | Verified | Configured through Wrangler; value omitted. |

Security separation checks:

- **Verified:** Production/staging code ignores development bypass headers unless `APP_ENV` is `development` or `test`.
- **Verified:** CORS code uses an explicit allowlist and does not allow arbitrary origins in production.
- **Verified:** Flutter production assets do not contain database URLs, staging endpoints, old custom domains, or Neon Auth endpoints.
- **Blocked:** Production API cannot verify real users until production Neon Auth is enabled and `NEON_AUTH_URL` is configured.

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
| Obsolete custom domains | Verified | No `zephvion.com`, `api-school`, or `auth.schoolic` references found in production bundle. |
| Staging references | Verified | No staging API/Pages endpoint references found in production bundle. |
| Database secrets in artifact | Verified | No database URL or Postgres host was found in `web_prod`. |
| Switzer fonts | Verified | Production build includes bundled app font assets. |

## 7. Remaining Blockers

1. **Blocked:** Production Neon Auth is not configured, so real production login is unavailable.
2. **Blocked:** Production branch `br-rapid-lake-b5g9wtix` is not protected.
3. **Deferred:** Recurring production snapshot schedule and restore drill are not configured.
4. **Deferred:** Real pilot user onboarding cannot begin until auth is enabled, trusted domains are configured, and login is verified end to end.

## 8. Safe Next Production Sequence

1. Enable Neon Auth on production project `dark-frost-36120929`, branch `br-rapid-lake-b5g9wtix`.
2. Add trusted auth domain `https://schoolic.pages.dev`.
3. Configure production Worker `NEON_AUTH_URL` to the verified production Neon Auth root.
4. Rebuild production Flutter with the verified `NEON_AUTH_URL`.
5. Redeploy API and frontend.
6. Create or map real production auth users to `app_users.neon_user_id`.
7. Run authenticated live smoke tests for admin and teacher workflows against the synthetic portfolio data.
8. Protect the production Neon branch and configure/test recovery policy before introducing real student data.
