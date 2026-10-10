# Last Update (October 10, 2026)

## 1. Phase 3.1: Staging Deployment Execution

### Neon Staging Database
- **Schoolic production reference identified:** Neon project `schoolic` (`dark-frost-36120929`), branch `main` (`br-rapid-lake-b5g9wtix`), endpoint host `ep-polished-silence-b52ozwm7.c-7.us-east-2.aws.neon.tech`.
- **Unrelated Neon project check:** The prohibited `neon-amethyst-pillow` project was not used.
- **Isolation method:** Created a separate empty Neon project for staging instead of branching from `main`, because `main` already contains application records.
- **Staging database:** Neon project `schoolic-staging` (`nameless-dust-81736720`), branch `main` (`br-floral-mountain-b5s114go`), endpoint host `ep-billowing-shadow-b56k9cl2.c-7.us-east-2.aws.neon.tech`.
- **Migration result:** `pnpm db:migrate` completed successfully against the staging database using `DATABASE_URL_UNPOOLED`.
- **Schema verification:** The staging database contains the expected application tables plus `drizzle.__drizzle_migrations`. Follow-up row-count queries intermittently failed with Neon HTTP fetch timeouts from this environment.

### Cloudflare Worker
- **Wrangler authentication:** Confirmed logged in as `vbk.zephvion@gmail.com` under Cloudflare account `5c34da760e86d900ee5274d71ad9191e`.
- **Worker deployment:** Uploaded and deployed Worker `schoolic-api-staging`.
- **Worker secrets:** Configured staging secrets `DATABASE_URL` and `BOOTSTRAP_TOKEN` with Wrangler. Secret values were not written to source or documentation.
- **Worker variables:** Staging deploy uses `APP_ENV=staging`, `CORS_ORIGIN=https://staging.schoolic.zephvion.com`, and `NEON_AUTH_URL=https://staging-auth.schoolic.zephvion.com`.
- **Custom domain blocker:** Cloudflare rejected the `staging-api-school.zephvion.com` custom domain because the `zephvion.com` zone is not available in the authenticated account. The Worker code exists, but the intended API hostname is not attached.
- **workers.dev blocker:** The fallback workers.dev URL is not usable because the account has not registered a workers.dev subdomain; HTTPS checks fail with a TLS handshake error.

### Frontend Artifact & Pages
- **Staging artifact:** `apps/flutter_app/build/web_staging` exists and contains the SPA `_redirects` file.
- **Artifact verification:** The staging bundle references `https://staging-api-school.zephvion.com` and `https://staging-auth.schoolic.zephvion.com`; no localhost, production API, or PostgreSQL URL references were found.
- **Switzer fonts:** Verified in `apps/flutter_app/build/web_staging/assets/FontManifest.json`.
- **Pages blocker:** The authenticated Cloudflare account has no visible Pages project named `schoolic-staging` or `schoolic`. The frontend was not deployed because creating a new Pages project would risk publishing to the wrong resource.

### DNS, HTTPS, Auth, and E2E Status
- **DNS:** `staging.schoolic.zephvion.com`, `staging-api-school.zephvion.com`, and `staging-auth.schoolic.zephvion.com` do not currently resolve from this environment.
- **HTTPS certificates:** Not validatable while DNS does not resolve and Cloudflare custom domains are not attached.
- **Authentication:** Live staging authentication was not verified because the auth hostname does not resolve.
- **End-to-end workflows:** Live attendance, reporting, CSV export, and authorization workflows remain blocked by DNS/custom-domain/Pages availability.

### Repository Updates
- Added `zone_name: "zephvion.com"` to the Worker route entries in `services/api/wrangler.jsonc` so Wrangler can resolve the intended zone when the authenticated account has access.
- Fixed root deploy scripts in `package.json` to call `wrangler deploy` through `pnpm exec`; `pnpm --filter @schoolic/api deploy --env staging` is parsed as pnpm's own deploy command and fails under the current pnpm version.

### Verification Commands
- `pnpm api:typecheck`: passed.
- `pnpm api:test`: 18/18 tests passed.
- `cd apps/flutter_app && flutter analyze`: no issues found.
- `pnpm flutter:test`: passed.

---

## 2. Phase 2: Security & Authentication Hardening (Summary)
- Neutralized development bypass headers in staging and production.
- Enforced session token verification against `NEON_AUTH_URL/auth/session` with fail-closed error handling.
- Implemented object-level authorization for teachers and enrollment verification for student attendance.
- Neutralized spreadsheet formula injection (CWE-1236) with single-quote escaping on API and Flutter client.
- Restricted CORS to explicit domain whitelists without wildcard credentials.
