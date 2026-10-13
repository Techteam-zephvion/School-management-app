# Last Update (October 12, 2026)

## Phase 8.1: Announcements & Communication MVP

### Summary
- Began the Phase 8 roadmap with a connected communication slice rather than a standalone page.
- Added persisted announcements for school-wide notices and class-section updates.
- Administrators can publish whole-school or class-section announcements.
- Teachers can view whole-school announcements plus announcements for their assigned sections, and can publish only to their assigned class sections.
- Added responsive announcement boards to both administrator and teacher workspaces.

### Backend
- Added `announcements` table with audience, priority, class/section target, author, publish time, optional expiry, and tenant-scoped indexes.
- Added validation for announcement audience/target combinations.
- Added API routes:
  - `GET /api/v1/admin/announcements`
  - `POST /api/v1/admin/announcements`
  - `GET /api/v1/teacher/announcements`
  - `POST /api/v1/teacher/announcements`
- Added server-side teacher assignment authorization for class-section announcements.

### Frontend
- Added a shared responsive `AnnouncementsView`.
- Added **Announcements** navigation in the administrator workspace.
- Added **Announcements** navigation in the teacher workspace.
- Added mobile layout coverage for the teacher announcement composer.

### Verification
- `pnpm api:typecheck`: PASS.
- `pnpm api:test`: PASS, 35/35 tests across 4 files.
- `cd apps/flutter_app && flutter analyze --no-fatal-infos`: PASS with one pre-existing non-fatal info in `shortcuts_dialog.dart`.
- `pnpm flutter:test`: PASS, 38/38 tests.

### Deployment
- Not deployed yet.
- Production resources were not touched.

---

## Schoolic Branding — Official `S.` Logo, Favicon & Application Icons

### Summary
- Implemented Schoolic's official minimalist logo mark across the application: uppercase letter `S` followed by a period (`S.`).
- Rendered using the bundled Fontshare Switzer font family (`Switzer-Bold.ttf`, 700 weight) for crisp geometry, optimal optical weight balance with the period, and distinct legibility down to 16x16.
- Created reproducible source assets in `apps/flutter_app/assets/branding/` using mathematical vector outlines from FreeType and high-resolution antialiased rasterization.
- Integrated the official mark into Flutter Web (favicon, PWA icons, maskable icons, Apple touch icon, manifest.json, index.html).
- Integrated official launcher icons into Android (all density mipmaps plus Android 8.0+ adaptive vector icon with centered 52dp mark within the 72dp safe zone).
- Integrated official icon for Linux packaging via the existing desktop entry and pixmap pipeline.
- Prepared multi-resolution Windows icon handoff (`schoolic.ico` containing 16, 24, 32, 48, 64, 128, 256 px frames) and updated Windows runner resources without touching the Windows build or packaging scripts.
- Integrated `SchoolicLogo` shared component into Login, Teacher workspace (header & mobile drawer), and Administrator workspace (sidebar & drawer).
- Preserved application name `Schoolic` everywhere; preserved all staging configurations; zero production modifications.

### Source & Distribution Asset Paths
- **Vector source masters:**
  - `apps/flutter_app/assets/branding/schoolic-logo.svg` (standalone `S.` wordmark, viewBox 0 0 810 712, `#111111`)
  - `apps/flutter_app/assets/branding/schoolic-icon.svg` (application launcher icon, viewBox 0 0 1024 1024, `#000000` rounded square with white `S.`)
- **Raster masters & icon sizes:**
  - `apps/flutter_app/assets/branding/schoolic-icon-1024.png` (1024x1024)
  - `apps/flutter_app/assets/branding/schoolic-icon-512.png` (512x512)
  - `apps/flutter_app/assets/branding/schoolic-icon-256.png` (256x256)
  - `apps/flutter_app/assets/branding/schoolic-icon-192.png` (192x192)
  - `apps/flutter_app/assets/branding/schoolic-icon-180.png` (180x180)
  - `apps/flutter_app/assets/branding/schoolic-icon-48.png` (48x48)
  - `apps/flutter_app/assets/branding/schoolic-icon-32.png` (32x32)
  - `apps/flutter_app/assets/branding/schoolic-icon-16.png` (16x16)
  - `apps/flutter_app/assets/branding/schoolic-logo-black.png` (1620x1424 transparent)
  - `apps/flutter_app/assets/branding/schoolic-logo-white.png` (1620x1424 transparent)
- **Windows handoff:**
  - `apps/flutter_app/assets/branding/schoolic.ico` (multi-resolution: 16, 24, 32, 48, 64, 128, 256)
  - `apps/flutter_app/windows/runner/resources/app_icon.ico` (updated)
- **Web PWA & Favicon:**
  - `apps/flutter_app/web/favicon.png` (32x32)
  - `apps/flutter_app/web/icons/Icon-192.png` (192x192)
  - `apps/flutter_app/web/icons/Icon-512.png` (512x512)
  - `apps/flutter_app/web/icons/Icon-maskable-192.png` (192x192 full-bleed safe zone)
  - `apps/flutter_app/web/icons/Icon-maskable-512.png` (512x512 full-bleed safe zone)
  - `apps/flutter_app/web/icons/apple-touch-icon.png` (180x180)
- **Android Launcher:**
  - `apps/flutter_app/android/app/src/main/res/mipmap-mdpi/ic_launcher.png` (48x48)
  - `apps/flutter_app/android/app/src/main/res/mipmap-hdpi/ic_launcher.png` (72x72)
  - `apps/flutter_app/android/app/src/main/res/mipmap-xhdpi/ic_launcher.png` (96x96)
  - `apps/flutter_app/android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png` (144x144)
  - `apps/flutter_app/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png` (192x192)
  - `apps/flutter_app/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` (Adaptive icon)
  - `apps/flutter_app/android/app/src/main/res/values/ic_launcher_background.xml` (`#000000`)
  - `apps/flutter_app/android/app/src/main/res/drawable/ic_launcher_foreground.xml` (Centered white `S.` vector drawable)
- **Asset generation script:**
  - `apps/flutter_app/scripts/generate_branding_assets.py`

### Verification Results
- `cd apps/flutter_app && flutter analyze --no-fatal-infos`: PASS, 0 issues found.
- `cd apps/flutter_app && flutter test`: PASS, 33/33 tests passed (including safe area and SchoolicLogo tests).
- `pnpm api:typecheck`: PASS, 0 issues found.
- `pnpm api:test`: PASS, 32/32 tests passed across 4 files.
- `pnpm flutter:build:web:staging`: PASS, compiled into `build/web_staging`.
- `flutter build apk --release` (staging configuration): PASS, compiled `app-release.apk` (60.6MB), aapt verified label `Schoolic` and icon `@mipmap/ic_launcher`.
- GitHub Actions Native Staging Builds: [Run 38279140837](https://github.com/Techteam-zephvion/School-management-app/actions/runs/38279140837) PASS (4/4 jobs passed: Validate, Linux, Android, Windows).
  - Staging APK artifact: `schoolic-android-apk-staging` (`schoolic-staging-release.apk`)
  - APK SHA-256: `65390bee5cc0c14d15154c7f2df7dc66e7fb03c59fc7074e0f0e2709eee7e476`
  - Local verified copy: `/tmp/schoolic-branding-apk/schoolic-staging-release.apk`
  - Linux artifacts: `schoolic-linux-deb-staging`, `schoolic-linux-staging`
  - Windows artifacts: `schoolic-windows-installer-staging`, `schoolic-windows-staging`

---

## Phase 7.3: Mobile UX Adaptation

### Summary
- Adapted the existing Flutter experience for Android phone widths while preserving desktop layouts.
- Added Teacher Copilot to the teacher workspace navigation so the Phase 6 AI workflow is reachable from desktop tabs and the mobile drawer.
- Refined narrow-width layouts for login, shared page headers, dialogs, attendance status controls, teacher My Day, My Week, My Classes, Attendance Register, and Teacher Copilot.
- Kept the existing visual system intact: Switzer typography, monochrome surfaces, subtle borders, restrained accent color, and no decorative AI styling.
- No backend, auth, database, secret, DNS, or production configuration changes were made.

### Mobile Coverage Added
- Added `apps/flutter_app/test/mobile_layout_test.dart` covering:
  - shared page header action wrapping at 360px;
  - teacher timetable mobile lesson list;
  - teacher class card action wrapping;
  - attendance register controls at 430px;
  - Teacher Copilot stacked form/editor at 360px.

### Local Verification
- `pnpm api:typecheck`: PASS.
- `pnpm api:test`: PASS, 32/32 tests across 4 files.
- `cd apps/flutter_app && flutter analyze --no-fatal-infos`: PASS, no issues found.
- `pnpm flutter:test`: PASS, 29/29 tests.

### Native Build
- Ready for the existing staging-only `Native Staging Builds` GitHub Actions workflow.
- Expected Android artifact: `schoolic-android-apk-staging`.
- Production frontend, production API, production database, production secrets, DNS, and domains remain untouched.

## Phase 7.2: Staging Account Provisioning & Native Login Completion

### Summary
- Resolved the remaining staging authentication blocker by provisioning real Neon Auth identities into Schoolic application-user mappings on the verified staging Neon project `nameless-dust-81736720`, branch `br-floral-mountain-b5s114go`.
- Reused the existing synthetic staging school instead of creating another tenant:
  - School: `Schoolic Synthetic Staging`
  - Code: `STAGE-1791645656627`
  - School ID: `a2cc33fd-7791-494f-8db5-c66ff1a8e12f`
- Preserved the staging `BOOTSTRAP_TOKEN` protection and did not read, print, rotate, bypass, or weaken it.
- Production resources were not touched.

### Provisioned Staging Accounts
- Administrator:
  - Email: `admin@portfolio.schoolic.test`
  - Neon Auth user ID: `9b1195a5-7910-4eca-bf86-60ed91ce8ee1`
  - Schoolic app user ID: `48137d9b-cdc3-4ac6-b7b1-77df96292f50`
  - Role: `admin`
- Teacher:
  - Email: `teacher-login@portfolio.schoolic.test`
  - Neon Auth user ID: `8e419083-745c-4719-8d7f-51cc31655cdc`
  - Schoolic app user ID: `618755fb-71b1-4a01-a0b7-58bc1fb77038`
  - Staff ID: `21358f00-c0e2-4d4f-8d69-b8164c8e88c9`
  - Role: `teacher`
  - Assignment: existing synthetic academic year `2026-2027`, class `=Stage Class`, section `A`, subject `Mathematics`, daily attendance enabled.
- No passwords, session cookies, JWTs, database URLs, bootstrap tokens, or Cloudflare/Neon credentials were committed or documented.

### Live Staging Verification
- Administrator real auth flow:
  - Neon Auth email/password sign-in: PASS.
  - `/auth/token` JWT issuance: PASS.
  - `GET /api/v1/me`: PASS, returned `admin`.
  - `GET /api/v1/admin/overview`: PASS.
- Teacher real auth flow:
  - Neon Auth email/password sign-in: PASS.
  - `/auth/token` JWT issuance: PASS.
  - `GET /api/v1/me`: PASS, returned `teacher` with linked `staffId`.
  - `GET /api/v1/teacher/assignments`: PASS, returned one authorized assignment.
  - `GET /api/v1/teacher/roster` for assigned section: PASS, returned two synthetic students.
  - `GET /api/v1/teacher/roster` for unassigned section: PASS, denied with HTTP 403.
  - `GET /api/v1/admin/overview` as teacher: PASS, denied with HTTP 403.
- Negative authorization checks:
  - Invalid credentials rejected by Neon Auth with HTTP 401: PASS.
  - Authenticated but unmapped Neon Auth user denied by Schoolic API with HTTP 403: PASS.
  - Staging development-bypass headers rejected with HTTP 401: PASS.
- Native APK physical login:
  - BLOCKED: `adb devices` showed no connected Android device or emulator in the current environment.
  - The same native auth transport path remains covered by `apps/flutter_app/test/auth_test.dart`, and live HTTP verification confirmed the deployed staging auth/API flow.

### Test Results
- `pnpm api:typecheck`: PASS.
- `pnpm api:test`: PASS, 32/32 tests across 4 files.
- `cd apps/flutter_app && flutter analyze --no-fatal-infos`: PASS, no issues found.
- `pnpm flutter:test`: PASS, 24/24 tests.

### Safety & Guardrails
- Verified staging project before database operations: `schoolic-staging` / `nameless-dust-81736720`.
- Verified staging branch before database operations: `main` / `br-floral-mountain-b5s114go`.
- Did not use the repository `.neon` file for staging work because it points at the production project `dark-frost-36120929`.
- Did not modify production Neon project `dark-frost-36120929`, production Worker `schoolic-api`, production Pages site `schoolic.pages.dev`, production secrets, DNS, or domains.

## Phase 7.1: Distribution Packages & Native Authentication Fix

### Summary
- Produced distribution-ready staging packages for Android (optimized release APK and App Bundle), Windows (Inno Setup installer and portable ZIP), and Linux (Debian `.deb` package and portable TAR.GZ bundle).
- Investigated and diagnosed the Android APK login failure displaying **"Invalid email and password."**
- Hardened Flutter native authentication transport, cookie preservation, Ed25519 token handling, and error discrimination.
- Validated all 6 native distribution packages via GitHub Actions workflow run `38244528532` (`https://github.com/Techteam-zephvion/School-management-app/actions/runs/38244528532`) at commit `947a843`.
- Retained strict environment isolation: zero production mutations, no secrets in source/logs, and all native targets configured strictly for staging.

### Authentication Investigation & Fix
1. **Diagnosis & Root Cause:**
   - The compiled APK was verified to point strictly to staging endpoints: API `https://schoolic-api-staging.schoolic-api.workers.dev` and Neon Auth `https://ep-billowing-shadow-b56k9cl2.neonauth.c-7.us-east-2.aws.neon.tech/neondb`.
   - Neon Auth returns HTTP 401 `{"message":"Invalid email or password","code":"INVALID_EMAIL_OR_PASSWORD"}` when the credentials do not exist in the staging Neon Auth instance (`ep-billowing-shadow-b56k9cl2`).
   - Synthetic demo accounts (`admin@portfolio.schoolic.test`, `teacher@portfolio.schoolic.test`) exist in production (`br-rapid-lake-b5g9wtix` via `production-demo-seed.sql`), but not in staging Neon Auth with known passwords.
   - When a new account is registered in staging Neon Auth (e.g. `teacher@portfolio.schoolic.test`), the native HTTP flow successfully completes credential authentication, receives the session cookie, mints an Ed25519 JWT from `/auth/token`, and sends it to the Schoolic API.
   - The Schoolic API validates the JWT signature against the staging JWKS, but returns HTTP 403 `{"error":"User is not provisioned for this pilot"}` because `appUsers` in the isolated staging database (`nameless-dust-81736720`, branch `br-floral-mountain-b5s114go`) lacks a mapping for that `neonUserId`.
   - The staging bootstrap endpoint (`POST /api/v1/bootstrap/school`) is protected by `BOOTSTRAP_TOKEN` (stored in Cloudflare Workers secrets, not locally accessible). Per guidelines, bootstrap tokens are not bypassed or invented.
2. **Native Transport & Error Discrimination Fixes:**
   - `auth_transport_stub.dart`:
     - Added cookie attribute stripping (`Expires`, `Max-Age`, `Path`, `Domain`, `SameSite`, `Secure`, `HttpOnly`, `Partitioned`) to prevent attributes from being parsed as cookie names.
     - Added safe JSON decoding to handle non-JSON responses (e.g. gateway HTML errors) without throwing `FormatException`.
     - Added distinct error discrimination: HTTP 401 returns user-friendly credential errors; HTTP 403 preserves the exact API message (e.g. `"User is not provisioned for this pilot"`); HTTP 500+ returns service unavailable. Errors are never disguised.
     - Added `clearAuthCookies()` to purge stale session tokens before initiating sign-in.
   - `api_client.dart`:
     - Normalized email (`trim().toLowerCase()`).
     - Added client-side validation for empty email and password.
     - Added network exception handling (`http.ClientException`, `SocketException`) mapped to HTTP 503 `ApiException`.
     - Added constructor overrides `neonAuthUrlOverride` and `apiBaseUrlOverride` for dependency injection and testing.
   - `providers.dart`:
     - Hardened `AuthController` to clear session on failure so the login UI cleanly renders `FeedbackBanner` error feedback without getting stuck in loading.
3. **Automated Test Suite:**
   - Created `apps/flutter_app/test/auth_test.dart` with 9 unit tests covering:
     - URL composition and trailing slash normalization.
     - Local validation for empty email/password and unconfigured auth URLs.
     - 401 invalid credential discrimination.
     - 403 unprovisioned pilot error preservation without disguising as bad credentials.
     - 500/502 gateway HTML error safety without `FormatException`.
     - Network failure mapping to 503.
     - End-to-end native session flow: cookie extraction, cookie forwarding without attribute leakage, token retrieval, and user session mapping.
     - Session cookie purging via `clearAuthCookies()`.
   - Test results:
     - `pnpm api:typecheck`: 0 errors.
     - `pnpm api:test`: 32/32 tests passed across 4 files.
     - `flutter analyze --no-fatal-infos`: 0 issues found.
     - `pnpm flutter:test`: 24/24 tests passed across `auth_test.dart` and `widget_test.dart`.

### Staging Distribution Artifacts (GitHub Actions Run 38244528532)
- **Workflow Run:** `https://github.com/Techteam-zephvion/School-management-app/actions/runs/38244528532`
- **Commit:** `947a843`
- **Artifacts:**
  1. **Android Release APK (`schoolic-android-apk-staging`):**
     - File: `schoolic-staging-release.apk`
     - Size: 53,605,503 bytes (51.12 MiB)
     - SHA-256: `3fd18d5d9955bbe6a4cd365875359192deba12985a62ae1e3a18eb8824a2e8f6`
     - Signing: development-signed fallback (keystore secret not configured in repository)
     - Package: `com.schoolic.schoolic`, Version: `1.0.0+6.947a843`
     - Verification: Universal AOT release build with `arm64-v8a`, `armeabi-v7a`, `x86_64` native code; no debug `kernel_blob.bin`; staging API embedded.
  2. **Android App Bundle (`schoolic-android-aab-staging`):**
     - File: `schoolic-staging-release.aab`
     - Size: 52,913,669 bytes (50.46 MiB)
     - SHA-256: `433e5d80639dbf71ce69e5dfdc05edfd75385a85f85bd5e5177c9e64603e6a01`
     - Signing: development-signed fallback
  3. **Windows Installer (`schoolic-windows-installer-staging`):**
     - File: `schoolic-windows-staging-setup.exe`
     - Size: 12,783,601 bytes (12.19 MiB)
     - SHA-256: `0634a0fdbd2946ff229134005005dd8ff566dcd3c47da38a8654fd5d2c298881`
     - Signing: unsigned installer
     - Inno Setup configuration: installs to `{localappdata}\Programs\Schoolic Staging` without requiring UAC admin elevation; Start Menu shortcut; silent install/uninstall tested on `windows-latest`.
  4. **Windows ZIP (`schoolic-windows-staging`):**
     - File: `schoolic-windows-staging.zip`
     - Size: 15,299,529 bytes (14.59 MiB)
     - SHA-256: `9ebc5228537bf41c6a198be7f241b3a82dd9e62ee4e98c1c1e41e208b4db6cc8`
     - Contents: `schoolic.exe`, `flutter_windows.dll`, `pdfium.dll`, `printing_plugin.dll`, Flutter assets, Switzer fonts, README.txt.
  5. **Linux DEB Package (`schoolic-linux-deb-staging`):**
     - File: `schoolic-linux-staging.deb`
     - Size: 10,698,088 bytes (10.20 MiB)
     - SHA-256: `bf8e7ffcc58a28e53a620c6595457752bebaa2ef1df6acd44db8d26cc710d942`
     - Architecture: `amd64`
     - Dependencies: `libc6, libstdc++6, libgtk-3-0t64 | libgtk-3-0, libglib2.0-0t64 | libglib2.0-0, liblzma5`
     - Verification: Installed and removed cleanly via `dpkg`/`apt` on `ubuntu-latest`; desktop entry at `/usr/share/applications/schoolic-staging.desktop`.
  6. **Linux TAR.GZ (`schoolic-linux-staging`):**
     - File: `schoolic-linux-staging.tar.gz`
     - Size: 13,106,231 bytes (12.50 MiB)
     - SHA-256: `a24e7b42a4eb04914b0550d845f2a67632afda0e7727db19baae34dc9fbd10ba`
     - Contents: `schoolic`, Flutter runtime libraries, printing/pdf libraries, Flutter assets, Switzer fonts, README.txt.

### Safety & Guardrails
- **Production Isolation**: Zero modifications to production Cloudflare Worker (`schoolic-api`), production Pages (`schoolic.pages.dev`), production database (`dark-frost-36120929`), DNS, or custom domains.
- **Secrets & Credentials**: No passwords, tokens, API keys, database URLs, or signing secrets were committed or exposed.
- **Fail-Closed Security**: `SCHOOLIC_ALLOW_DEV_SIGN_IN=false` remains enforced on all staging native builds.

---

## Phase 7.0: GitHub Actions Native Build Pipeline

- Added Flutter native platform scaffolding for Android, Windows, and Linux in the existing `apps/flutter_app` project.
- Added manual-only GitHub Actions workflow `.github/workflows/native-builds.yml` for staging native builds.
- Successful GitHub Actions run: `38228984470` (`https://github.com/Techteam-zephvion/School-management-app/actions/runs/38228984470`).
- Native artifacts produced by the workflow, retained for 14 days:
  - Android debug APK: `schoolic-android-apk-staging` (`schoolic-staging-debug.apk`, 162,950,060 bytes downloaded; artifact archive 80.07 MiB).
  - Windows release bundle ZIP: `schoolic-windows-staging` (`schoolic-windows-staging.zip`, 15,293,006 bytes downloaded; artifact archive 14.57 MiB).
  - Linux x64 release bundle TAR.GZ: `schoolic-linux-staging` (`schoolic-linux-staging.tar.gz`, 13,104,210 bytes downloaded; artifact archive 12.47 MiB).
- Native builds use the staging API `https://schoolic-api-staging.schoolic-api.workers.dev` and staging Neon Auth URL through the existing Dart define mechanism.
- Staging native builds set `SCHOOLIC_ALLOW_DEV_SIGN_IN=false`; no database URLs, AI keys, bootstrap tokens, or server-only secrets are embedded in Flutter artifacts.
- Added Android internet permission, Schoolic app names for native windows, a native CSV file fallback, and cookie preservation for Neon Auth on non-web clients.
- Android scaffold uses package ID `com.schoolic.schoolic`, JDK 17, Gradle wrapper `9.3.1`, and Android Gradle Plugin `9.1.1`.
- Local verification before GitHub Actions trigger:
  - `pnpm api:typecheck` passed.
  - `pnpm api:test` passed: 4 files, 32 tests.
  - `cd apps/flutter_app && flutter analyze` passed.
  - `pnpm flutter:test` passed: 15 tests.
- GitHub Actions verification:
  - Validate API and Flutter: passed in 1m01s.
  - Linux TAR.GZ: passed in 2m00s.
  - Android APK: passed in 4m33s.
  - Windows ZIP: passed in 3m18s.
- Spot-checked downloaded artifacts:
  - Android APK contains Flutter assets and the staging API URL.
  - Windows ZIP contains `schoolic.exe`, `flutter_windows.dll`, `pdfium.dll`, `printing_plugin.dll`, Flutter assets, Switzer fonts, and README.
  - Linux TAR.GZ contains `schoolic`, Flutter runtime libraries, printing/pdf libraries, Flutter assets, Switzer fonts, and README.
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
