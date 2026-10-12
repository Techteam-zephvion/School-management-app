# Last Update (October 12, 2026)

## Phase 7.0: GitHub Actions Native Build Pipeline

- Added Flutter native platform scaffolding for Android, Windows, and Linux in the existing `apps/flutter_app` project.
- Added manual-only GitHub Actions workflow `.github/workflows/native-builds.yml` for staging native builds.
- Native artifacts produced by the workflow:
  - Android debug APK: `schoolic-android-apk-staging`.
  - Windows release bundle ZIP: `schoolic-windows-staging`.
  - Linux x64 release bundle TAR.GZ: `schoolic-linux-staging`.
- Native builds use the staging API `https://schoolic-api-staging.schoolic-api.workers.dev` and staging Neon Auth URL through the existing Dart define mechanism.
- Staging native builds set `SCHOOLIC_ALLOW_DEV_SIGN_IN=false`; no database URLs, AI keys, bootstrap tokens, or server-only secrets are embedded in Flutter artifacts.
- Added Android internet permission, Schoolic app names for native windows, a native CSV file fallback, and cookie preservation for Neon Auth on non-web clients.
- Local verification before GitHub Actions trigger:
  - `pnpm api:typecheck` passed.
  - `pnpm api:test` passed: 4 files, 32 tests.
  - `cd apps/flutter_app && flutter analyze` passed.
  - `pnpm flutter:test` passed: 15 tests.
- Production frontend, API, database, secrets, DNS, and domain settings were not modified.

---

## 0. Phase 5.5: UX Audit Remediation Complete on Staging

- Addressed all findings from the October 11, 2026 Independent UI/UX Audit & End-to-End Interface Assessment.
- **Environment Isolation & Safety**:
  - All deployments and testing strictly confined to staging.
  - Staging API Worker: `https://schoolic-api-staging.schoolic-api.workers.dev` (Version ID `350162b7-a260-4a6d-a10c-d8073d3687ce`).
  - Staging Pages Frontend: `https://schoolic-staging.pages.dev` (Deployment ID `89843304.schoolic-staging.pages.dev`).
  - Staging Database: Neon project `nameless-dust-81736720`, branch `br-floral-mountain-b5s114go`.
  - Zero modifications to production frontend (`schoolic.pages.dev`), production API, production Neon DB, production DNS, or production secrets.
  - No AI features exposed or added in this remediation phase.
- **P1 — Student Attendance Summary Metrics Fixed** (`student_attendance_dialog.dart`):
  - Fixed parser to read nested `stats` object: `totalSessions`, `present`, `absent`, `late`, `excused`, `attendanceRate` (percentage formatted string).
  - Supports safe null fallbacks and distinct loading, error, empty, and populated states.
  - Supports both `r['date']` and `r['attendanceDate']` record keys.
  - Verified with real nonzero attendance fixture test, empty stats test, and malformed stats test.
- **P2 — Student Roll-Number Clipping Fixed** (`class_roster_dialog.dart`, `teacher_attendance_view.dart`):
  - Replaced fixed 28px width badge with `BoxConstraints(minWidth: 44, minHeight: 28)`, horizontal padding of 6px, `maxLines: 1`, and `softWrap: false`.
  - Roll numbers like `06A-01` now render crisply on a single line without wrapping or clipping across roster modal and attendance register.
- **P2 — Restored Class Context in Operational Attention** (`admin_overview_view.dart`):
  - Cohort labels now format as `Grade 6 - A` and `Grade 6 - B` by combining class name and section name.
  - Preserves pending attendance sessions and unassigned section counts with fallback for missing names.
- **P2 — Enhanced Student Directory** (`admin_students_view.dart`, `school-repository.ts`):
  - Added dedicated "Class & Section" column displaying `$className - $sectionName` (or "Unassigned" fallback).
  - Added Class and Section dropdown filters with live query composition (combining search by name, admission no, roll no, cohort).
  - Backend API query joins active academic year, classes, and sections to prevent duplicate student rows.
- **P2 — Responsive Navigation and Layouts** (`admin_dashboard.dart`, `teacher_dashboard.dart`, `app_table.dart`):
  - Desktop: Preserved existing desktop sidebar and full topbar.
  - Tablet & Mobile: Added responsive breakpoint at 850px. When viewport width < 850px, desktop sidebars convert to an accessible navigation `Drawer` opened via hamburger menu (`Icons.menu`).
  - Teacher navigation on mobile/tablet accessible via Drawer with clean tab switching and sign-out.
  - Topbar user email and actions responsively compress or hide text to prevent horizontal overflow.
  - `AppTable` now includes responsive horizontal scrolling when viewport width is below required column width, preventing column crunching. Table header search and filter actions wrap cleanly on narrow screens.
- **P3 — Usability Improvements**:
  - **Teacher Greeting**: Subtitle displays authenticated teacher's display name (`staff.fullName` or `appUsers.displayName`) with a neutral fallback ("Daily teaching briefing") instead of leaking raw email address.
  - **Duplicate Academic-Year Badge**: Removed duplicate badge from overview `PageHeader`, preserving primary badge in global topbar.
  - **Timetable Weekend Layout**: Omitted empty weekend cards when no Saturday/Sunday lessons are scheduled, rendering 5 balanced Monday–Friday columns without orphaned rows.
  - **Timetable Filter Wording**: Standardized plural labels (`All Classes`, `All Sections`, `All Teachers`, `All Subjects`) and set `isExpanded: true` to eliminate dropdown overflows.
  - **Period Attendance Subject Selection**: Added Subject dropdown in `teacher_attendance_view.dart` for period attendance when taking attendance for sections with multiple subjects.
  - **Accessible Timetable Actions**: Added `Semantics` buttons and descriptive tooltips (`Edit lesson for ...`, `Delete lesson for ...`) to timetable action buttons.
- **Automated Verification**:
  - `pnpm api:typecheck`: 0 errors.
  - `pnpm api:test`: 26/26 tests passed.
  - `flutter analyze`: 0 issues found.
  - `flutter test`: 13/13 tests passed.
- **Browser Verification**:
  - Tested staging deployment at 1440×900, 1280×800, 768×1024, and 390×844 viewports.
  - Verified 0 console errors, 0 failed assets, and responsive layout scaling across all breakpoints.

---


- Promoted the Phase 5.2 Product UX Redesign and Phase 5.3 Timetable & Daily Schedule from staging to production.
- **Release Commit**: `6de84bf` (`feat(timetable): release timetable scheduling workflow`).
- **Production Migration**:
  - Confirmed `database/migrations/0001_harsh_firedrake.sql` is additive timetable schema only.
  - Replaced the older manual Neon snapshot because the project snapshot limit was already reached, then created fresh recovery snapshot `snap-curly-hat-b5woqrcz` on production branch `br-rapid-lake-b5g9wtix`.
  - Applied `0001_harsh_firedrake` to production project `schoolic` (`dark-frost-36120929`), database `neondb`.
  - Verified `timetable_entries`, primary key, unique constraint, teacher/day index, section/day index, and two Drizzle migration history rows.
  - A post-apply Drizzle rerun exited nonzero without a visible error, but direct production verification confirmed no duplicate migration application and exactly two migration records.
- **Production Data**:
  - Seeded eight realistic timetable entries for `Schoolic Portfolio Academy` (`PORTFOLIO`) from existing production teacher assignments.
  - Preserved existing students, staff, enrollments, assignments, and attendance records.
- **Production Deployments**:
  - Deployed Worker `schoolic-api`, version `8739669f-8c95-4a6d-83fb-a5cfc9ab8ee5`.
  - Built production Flutter Web with `https://schoolic-api.schoolic-api.workers.dev` and the production Neon Auth Base URL.
  - Deployed Cloudflare Pages production preview `https://3023752a.schoolic.pages.dev`; canonical frontend remains `https://schoolic.pages.dev`.
- **Verification**:
  - Local checks passed: `pnpm api:typecheck`, `pnpm api:test` (22/22), `cd apps/flutter_app && flutter analyze`, and `cd apps/flutter_app && flutter test` (6/6).
  - Production API health returned `{"ok":true,"service":"schoolic-api"}`.
  - Production Pages canonical and preview returned HTTP 200.
  - Production CORS allows `https://schoolic.pages.dev`.
  - Live auth smoke passed for admin and teacher login; invalid token and development-bypass headers return 401; teacher admin access returns 403.
  - Live timetable smoke passed: admin load, create, conflict rejection, edit, delete; teacher weekly timetable returned authorized rows.
  - Live attendance smoke passed: teacher submitted scheduled period attendance and the saved session persisted in teacher attendance summary.
- **Boundaries**:
  - Hostinger DNS, nameservers, and custom domains were not modified.
  - No staging Auth/database resources were reused for production.
  - No credentials or secret values were written to source or docs.

---

## 2. Phase 5.3: Timetable & Daily Schedule Complete on Staging

- Implemented a persisted timetable vertical slice across Neon Postgres, Hono API, and Flutter Web.
- **Database & Migration**:
  - Added `timetable_entries` with academic year, class, section, subject, teacher, day-of-week, time range, optional period number, and label.
  - Added teacher/day and section/day indexes plus a uniqueness guard for duplicate section time blocks.
  - Generated and applied Drizzle migration `0001_harsh_firedrake` to the isolated staging Neon project only.
- **Backend API**:
  - Added validated admin routes: `GET/POST/PUT/DELETE /api/v1/admin/timetable`.
  - Added read-only teacher route: `GET /api/v1/teacher/timetable`.
  - Enforced server-side timetable validation, teacher-assignment validation, tenant scoping, and teacher/class-section overlap rejection.
  - Teachers can view schedules assigned to their authenticated staff identity but cannot create, edit, or delete timetable entries.
- **Administrator Workspace**:
  - Added a Timetable section with class/teacher filtering, weekly schedule cards, tabular scheduled lessons, create/edit dialog, and delete confirmation.
  - Timetable teacher/subject choices are derived from existing teacher assignments.
- **Teacher Workspace**:
  - Added a read-only **My Week** timetable view.
  - Updated **My Day** to prefer real timetable entries for today's schedule and pending attendance queue.
  - Starting attendance from a scheduled period pre-fills date, period number, subject, class, and section while preserving the existing attendance storage model.
- **Staging Deployment & Verification**:
  - Applied migration to staging project `schoolic-staging` (`nameless-dust-81736720`), branch `br-floral-mountain-b5s114go`.
  - Seeded five synthetic timetable entries from the existing staging teacher assignment.
  - Deployed staging API Worker `schoolic-api-staging`, version `e419213f-cd73-4bce-8af7-fc2c4b2815bc`.
  - Built and deployed staging Flutter Web to Cloudflare Pages preview `https://0e1d82bf.schoolic-staging.pages.dev`.
  - Smoke checks passed: API `/health`, Pages HTTP 200, and staging timetable rows verified in Neon.
  - Local checks passed: `pnpm api:typecheck`, `pnpm api:test` (22/22), `cd apps/flutter_app && flutter analyze`, and `cd apps/flutter_app && flutter test` (6/6).
- **Production Guardrails**:
  - Production was not deployed or migrated in Phase 5.3.
  - Hostinger DNS, nameservers, and custom domains were not modified.
  - Existing attendance persistence was preserved; no second attendance system was introduced.

### Promotion
- Promoted to production in Phase 5.4.

---

## 3. Phase 5.2: Product UX Redesign Complete & Verified on Staging

- Executed the complete UX redesign adhering strictly to Schoolic's monochrome Switzer design principles:
  - Strict palette: `#111111` (Ink), `#FFFFFF` (Surface), `#F7F7F7` (Neutral surface), `#E5E5E5` (Borders), `#D4D4D4` (Separators), `#737373` (Secondary text), `#A3A3A3` (Muted), and one interactive accent `#10A37F`.
  - Zero decorative bloat: strictly prohibited gradients, glows, glassmorphism, decorative blobs, colored KPI cards, and emoji icons.
  - Bundled typography tokens using the official local Fontshare Switzer font family.
  - Fast, restrained micro-interactions (`AppMotion`: 120ms/160ms/200ms) with subtle easing and reduced-motion respect.
- **Shared Design System Components (`lib/src/features/shared/components/`)**:
  - `PageHeader`: Clean typographic titles, contextual descriptions, active academic year pill badges, and primary/secondary button bars.
  - `StatStrip`: Integrated high-density typographic statistics replacing colorful dashboard metric cards.
  - `StatusBadge`: Monochromatic and semantic status badges (`Present`, `Absent`, `Late`, `Excused`, `Completed`, `Pending`).
  - `AttendanceStatusGroup`: Ergonomic toggle button group with micro-interactions and explicit selection states.
  - `AppTable`: Information-dense data table with subtle row hover, built-in search/filter, and clean empty states.
  - `FeedbackBanner`: Inline operational feedback banner for successful persist confirmations, warning banners, and error recovery.
  - `AppDialog`: Unified modal dialog wrapper with clear titles and action footers.
  - `EmptyStateView`: Minimalist empty state component for tables and views.
- **Redesigned Administrator Workspace (`lib/src/features/admin/`)**:
  - Modularized into responsive views (`AdminOverviewView`, `AdminAttendanceView`, `AdminStudentsView`, `AdminStaffView`, `AdminClassesView`, `AdminAssignmentsView`, `AdminReportsView`, `AdminSettingsView`) coordinated by `AdminDashboard`.
  - Animated collapsible sidebar (240px expanded to 68px collapsed) with monochromatic Lucide-style outline icons.
  - Dynamic **Operational Attention Panel** highlighting incomplete class attendance and pending setup queues using live API data.
  - Compact recent attendance table and operational quick action triggers.
  - Dedicated student attendance profile modal with calculated attendance rates, status breakdowns, and chronological session logs.
  - CWE-1236 CSV spreadsheet sanitization preserved.
- **Rebuilt Teacher Workspace (`lib/src/features/teacher/`)**:
  - Purpose-built teaching workspace with top navigation tabs: **My Day**, **My Classes**, and **Attendance Register**.
  - **My Day**: Daily teaching briefing displaying today's date, active classes, session progress, pending roll calls needing immediate submission, and a clean session list.
  - **My Classes**: Assigned class & section cards displaying enrolled student count, assigned subjects, and quick actions ("Take Attendance", "View Class Roster").
  - **Attendance Register**: High-efficiency roll-call flow with real-time tally counters (Present, Absent, Late, Excused), unsaved changes tracking, "Mark All Present" bulk action, search filter, and verified server-persistence feedback before displaying success confirmations.
  - Roster view modal (`ClassRosterDialog`) to view enrolled students with roll numbers and contact details.
- **Login & Auth Shell Polished (`lib/src/features/auth/login_screen.dart`)**:
  - Streamlined monochrome login card with Switzer typography.
  - Keyboard submission (Enter key) on email and password inputs.
  - Development quick sign-in switchers strictly confined to local development (`AppConfig.isLocalDev`) and hidden in staging and production.
- **Verification & Deployment**:
  - Backend API: `pnpm api:typecheck` clean, `pnpm api:test` 18/18 passing.
  - Flutter Analysis: `flutter analyze` 0 issues.
  - Flutter Tests: `flutter test` 6/6 passing.
  - Staging Build: `pnpm flutter:build:web:staging` compiled with `_redirects` in place.
  - Staging Deployment: Deployed to Cloudflare Pages staging project `schoolic-staging` (`https://schoolic-staging.pages.dev`).
  - Staging Live Verification: Verified HTTP 200, bundle integrity, and rendered login screen in browser.
  - Production Guardrails: Production (`https://schoolic.pages.dev` and `https://schoolic-api.schoolic-api.workers.dev`) was completely untouched and preserved.

### Promotion
- Promoted to production in Phase 5.4.

---

## 4. Phase 5.1: Production Authentication Complete

## 5. Phase 4.2: Production Portfolio Deployment

- Completed the approved default-domain production portfolio deployment.
- Created production Neon recovery snapshot `snap-lucky-star-b5i49wpy` before migration-history changes.
- Fixed production Drizzle migration history by inserting the baseline row for `0000_aspiring_madame_hydra`.
- Verified `pnpm db:migrate` now succeeds against production.
- Added `database/production-demo-seed.sql` and applied realistic synthetic data for `Schoolic Portfolio Academy` (`PORTFOLIO`): academic year, classes, sections, subjects, staff, users, 12 students, enrollments, teacher assignments, and attendance records.
- Preserved existing production database records.
- Created Cloudflare Pages project `schoolic` and deployed the frontend to `https://schoolic.pages.dev`.
- Deployed production Worker `schoolic-api` to `https://schoolic-api.schoolic-api.workers.dev`.
- Configured production Worker secrets `DATABASE_URL` and `BOOTSTRAP_TOKEN` through Wrangler. Secret values were not printed or documented.
- Updated production CORS to `https://schoolic.pages.dev`.
- Updated production Flutter build to use `https://schoolic-api.schoolic-api.workers.dev` and removed old `zephvion.com` production endpoint dependencies.
- Hostinger DNS, nameservers, and `zephvion.com` custom domains were not modified.
- Production Neon Auth remains unconfigured by design for this phase. Login fails closed until production Auth is enabled and `NEON_AUTH_URL` is set to the verified production auth root.
- Verification passed: `pnpm api:typecheck`, `pnpm api:test` (18/18), `cd apps/flutter_app && flutter analyze`, `pnpm flutter:test`, `pnpm flutter:build:web:prod`, live API health, live frontend HTTP 200, CORS preflight from Pages, and production bundle scans.

### Current Production URLs
- Frontend: `https://schoolic.pages.dev`
- Latest Pages deployment: `https://7e543704.schoolic.pages.dev`
- API Worker: `https://schoolic-api.schoolic-api.workers.dev`

### Remaining Production Blockers
- Production Neon Auth is not configured, so authenticated login is unavailable.
- Production Neon branch `br-rapid-lake-b5g9wtix` is not protected.
- Recurring snapshot schedule and restore drill are still deferred.

---

## 6. Phase 4.1: Production Infrastructure Preparation

- Updated `PRODUCTION_READINESS_AUDIT.md` with Phase 4.1 findings.
- Production is still **not ready** for deployment.
- Reconfirmed production Neon identity: project `schoolic` (`dark-frost-36120929`), branch `main` (`br-rapid-lake-b5g9wtix`), database `neondb`.
- Resolved the previous SQL access blocker using Neon CLI embedded TypeScript `psql`; production schema is queryable.
- Verified expected V1 Schoolic tables, enums, constraints, and `drizzle.__drizzle_migrations` table exist.
- New critical blocker: `drizzle.__drizzle_migrations` contains zero rows while application tables and some existing records are present. Production migrations must not run until the baseline is approved and fixed.
- Recovery controls remain incomplete: no manual snapshots, no automatic snapshot schedule, and the production branch is not protected.
- Production Neon Auth remains unconfigured.
- Production Cloudflare Worker `schoolic-api` and Pages project `schoolic` remain absent in the authenticated account.
- Existing `apps/flutter_app/build/web_prod` remains stale and points at unavailable `zephvion.com` custom domains.
- Local checks passed: `pnpm api:typecheck`, `pnpm api:test` (18/18), `cd apps/flutter_app && flutter analyze`, and `pnpm flutter:test`.
- Production Worker dry run passed as a bundle check, but still uses obsolete production variables.
- No production deployments, production secret writes, production database writes, branch protection changes, snapshots, auth changes, Hostinger DNS changes, nameserver changes, or custom-domain changes were performed.

### Pending Explicit Approvals
- Production branch protection and snapshot/schedule setup.
- Production Drizzle baseline strategy for the existing schema.
- Production Neon Auth enablement and trusted domains.
- Production Worker and Pages resource creation.
- Production secret writes and production config changes away from `zephvion.com`.
- Production artifact rebuild and deployment.

---

## 7. Phase 4.0: Production Readiness Audit

- Created `PRODUCTION_READINESS_AUDIT.md`.
- Production was not ready for deployment.
- Verified production Neon candidate: project `schoolic` (`dark-frost-36120929`), branch `main` (`br-rapid-lake-b5g9wtix`), database `neondb`.
- Initial blockers: production Neon Auth was not configured, production Cloudflare Worker and Pages project did not exist in the authenticated account, production config still targeted unavailable `zephvion.com` custom domains, the existing `web_prod` artifact was stale, production SQL migration-history verification timed out, no production snapshot/schedule was found, and the production Neon branch was not protected.

---

## 8. Phase 3.2: Default-Domain Staging Complete

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

## 9. Phase 2: Security & Authentication Hardening (Summary)
- Neutralized development bypass headers in staging and production.
- Enforced session token verification against Neon Auth with fail-closed behavior.
- Implemented object-level authorization for teachers and enrollment verification for student attendance.
- Neutralized spreadsheet formula injection (CWE-1236) with single-quote escaping on API and Flutter client.
- Restricted CORS to explicit domain whitelists without wildcard credentials.
# Phase 6.1: AI Productization Deployed to Staging

**Date:** 2026-10-12

## Summary

- Extended Teacher Copilot with a classroom document preview and real A4 PDF generation for lesson plans, worksheets, and quizzes.
- Added separate student PDF and teacher answer-key PDF actions for worksheets and quizzes; student exports omit teacher notes/answer keys.
- Added print actions using the same generated document bytes as downloads.
- Added server-side AI usage records, admin usage summary, provider token/latency capture, and configurable generation limits.
- Added an administrator **AI Usage** workspace section for request totals, success/failure counts, token availability, latency, feature/type grouping, and daily activity.

## Database & API

- Added Drizzle migration `0003_red_justin_hammer.sql` for `ai_usage_events`.
- Applied pending migrations to staging Neon project `nameless-dust-81736720`, branch `br-floral-mountain-b5s114go`.
- Added admin route `GET /api/v1/admin/ai/usage`.
- Instrumented:
  - `POST /api/v1/admin/ai/attendance-insights`
  - `POST /api/v1/teacher/ai/copilot`
- Staging AI controls:
  - `AI_MAX_OUTPUT_TOKENS=1200`
  - `AI_TIMEOUT_MS=18000`
  - `AI_REQUESTS_PER_USER=20`
  - `AI_REQUEST_WINDOW_MINUTES=60`

## Staging Deployment

- Staging API Worker: `https://schoolic-api-staging.schoolic-api.workers.dev`.
- Worker version ID: `dd215593-769b-4c37-a3bb-053fbac0fc3d`.
- Staging frontend: `https://schoolic-staging.pages.dev`.
- Pages preview: `https://f3b9268f.schoolic-staging.pages.dev`.

## Verification

- `pnpm api:typecheck` passed.
- `pnpm api:test` passed: 4 files, 32 tests.
- `cd apps/flutter_app && flutter analyze` passed.
- `cd apps/flutter_app && flutter test` passed: 15 tests.
- PDF tests create separate student and answer-key documents from fixture content.
- Staging API `/health` returned `{"ok":true,"service":"schoolic-api"}`.
- Canonical staging frontend returned HTTP 200.

## Production Guardrails

- Production frontend was not deployed.
- Production API Worker was not deployed.
- Production database was not migrated.
- Production secrets were not modified; production still lists only `BOOTSTRAP_TOKEN` and `DATABASE_URL`.
- DNS and custom domains were not modified.

# Phase 6.0: AI Features MVP Deployed to Staging

**Date:** 2026-10-12

## Summary

- Implemented **Schoolic Insights** for administrators as a dedicated admin navigation area backed by deterministic attendance aggregation and compact anonymized AI prompts.
- Implemented **Teacher Copilot** for teachers with lesson plan, worksheet, and quiz generation, editable draft workspace, explicit save/update, reopen, and delete workflows.
- Added server-side OpenAI-compatible AI adapter with `AI_FEATURES_ENABLED`, model/base URL/key configuration, timeouts, bounded output, structured Zod validation, and safe user-facing provider errors.
- Added persisted teacher draft storage in PostgreSQL via Drizzle migration `0002_warm_moon_knight.sql`.

## Staging Deployment

- Staging Neon project verified before migration: `nameless-dust-81736720`.
- Staging Neon branch verified before migration: `br-floral-mountain-b5s114go`.
- Applied migration `0002_warm_moon_knight.sql` to staging only.
- Deployed staging API Worker: `https://schoolic-api-staging.schoolic-api.workers.dev`.
- Worker version ID: `367be095-4fbe-4a15-8fdd-00665948e87b`.
- Built Flutter Web staging bundle with staging API/Auth dart-defines.
- Deployed staging Pages preview: `https://744e0bfd.schoolic-staging.pages.dev`.
- Canonical staging frontend: `https://schoolic-staging.pages.dev`.

## AI Configuration

- Staging `AI_FEATURES_ENABLED=true`.
- Staging `AI_PROVIDER=openai-compatible`.
- Staging `AI_MODEL=qwen/qwen3.8-27b`.
- Staging `AI_BASE_URL=https://api.groq.com/openai/v1`.
- Staging `AI_API_KEY` is configured as a Cloudflare Worker secret.
- Production AI variables and secrets were not configured.

## Verification

- `pnpm api:typecheck` passed.
- `pnpm api:test` passed: 4 files, 31 tests.
- `cd apps/flutter_app && flutter analyze` passed.
- `cd apps/flutter_app && flutter test` passed: 13 tests.
- Staging API `/health` returned `{"ok":true,"service":"schoolic-api"}`.
- Canonical staging Pages URL returned HTTP 200.
- Direct Groq provider probe succeeded with `qwen/qwen3.8-27b` and JSON response format.
- Staging API Worker redeployed with Groq configuration as version `941207db-7b71-44b1-82b0-8e0bf02caef4`.

## Production Guardrails

- Production frontend was not deployed.
- Production API Worker was not deployed.
- Production database was not migrated or queried for mutation.
- Production secrets, DNS, custom domains, and Hostinger settings were not modified.
