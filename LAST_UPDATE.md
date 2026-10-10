# Last Update (October 10, 2026)

## 1. Phase 3.2: Default-Domain Staging Complete

### Hosting URLs
- **Frontend:** `https://schoolic-staging.pages.dev`
- **Latest Pages deployment:** `https://40e7852c.schoolic-staging.pages.dev`
- **API Worker:** `https://schoolic-api-staging.schoolic-api.workers.dev`
- **Authentication root:** `https://ep-billowing-shadow-b56k9cl2.neonauth.c-7.us-east-2.aws.neon.tech/neondb`
- **Neon Auth base URL:** `https://ep-billowing-shadow-b56k9cl2.neonauth.c-7.us-east-2.aws.neon.tech/neondb/auth`

### Neon Staging
- **Staging database project:** `schoolic-staging` (`nameless-dust-81736720`).
- **Staging branch:** `main` (`br-floral-mountain-b5s114go`).
- **Staging database endpoint:** `ep-billowing-shadow-b56k9cl2.c-7.us-east-2.aws.neon.tech`.
- **Auth provider:** Neon Managed Auth / Better Auth enabled on the staging branch.
- **Trusted auth domains:** `https://schoolic-staging.pages.dev`, `https://cd72e398.schoolic-staging.pages.dev`, and `https://40e7852c.schoolic-staging.pages.dev`.
- **Unrelated Neon project check:** `neon-amethyst-pillow` was not used.

### Cloudflare Staging
- **Wrangler account:** `vbk.zephvion@gmail.com`, account `5c34da760e86d900ee5274d71ad9191e`.
- **Worker:** `schoolic-api-staging`, deployed to the default `workers.dev` hostname with staging-only variables.
- **Pages project:** `schoolic-staging`, production branch `staging`, deployed to the default `pages.dev` hostname.
- **Secrets:** Staging `DATABASE_URL` and `BOOTSTRAP_TOKEN` are configured through Wrangler. Secret values are not stored in source or docs.
- **Hostinger DNS:** Not modified. No `zephvion.com` nameserver, DNS, or custom-domain changes were made.

### Auth Fix
- Updated the API to verify Neon Auth JWTs from `/auth/token` using the branch JWKS.
- Updated Flutter Web sign-in to use credentialed Neon Auth calls, then request `/auth/token` and send that JWT to the Schoolic API.
- Sign-out now calls Neon Auth `/auth/sign-out` before clearing local session state.

### Verification
- **HTTPS/DNS:** Canonical `pages.dev`, `workers.dev`, and `neonauth` hostnames resolve and present trusted provider-managed certificates.
- **CORS:** `https://schoolic-staging.pages.dev` is allowed; `https://example.com` receives no `access-control-allow-origin`.
- **Frontend bundle:** Verified default API/auth endpoints, no localhost references, no production API/auth references, no old staging custom domains, and no PostgreSQL URLs.
- **Local checks:** `pnpm api:typecheck`, `pnpm api:test` (18/18), `cd apps/flutter_app && flutter analyze`, and `pnpm flutter:test` all pass.
- **Live E2E:** Passed with synthetic staging records under school code `STAGE-1791645656627`:
  - unauthenticated protected request returns 401;
  - development headers cannot authenticate staging users;
  - invalid sessions are rejected;
  - admin and teacher sessions authenticate through Neon Auth JWTs;
  - teacher is denied admin access with 403;
  - admin overview, students, staff, classes, subjects, and assignments load;
  - teacher assigned roster loads and unassigned roster is denied;
  - daily and period attendance save and persist;
  - attendance filters return the saved sessions;
  - CSV export includes the filtered result set and escapes formula-leading values;
  - student attendance history returns persisted records.

---

## 2. Phase 2: Security & Authentication Hardening (Summary)
- Neutralized development bypass headers in staging and production.
- Enforced session token verification against Neon Auth with fail-closed behavior.
- Implemented object-level authorization for teachers and enrollment verification for student attendance.
- Neutralized spreadsheet formula injection (CWE-1236) with single-quote escaping on API and Flutter client.
- Restricted CORS to explicit domain whitelists without wildcard credentials.
