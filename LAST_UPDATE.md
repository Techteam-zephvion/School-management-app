# Last Update (October 17, 2026)

## Phase 15: Campus Operations Ecosystem

### Summary
- **Database Schema & Migrations (`0017_polite_wilson_fisk.sql`):**
  - **11 New Tables:**
    - `libraryBooks`: ISBN, title, author, category, total copies, available copies, shelf location.
    - `bookLoans`: borrower type (`student`/`staff`), student/staff ID, checkout date, due date, return date, late fine amount, status (`issued`, `returned`, `lost`).
    - `bookReservations`: reservation queue tracking with status (`active`, `fulfilled`, `cancelled`).
    - `inventoryItems`: asset categories (`lab`, `sports`, `classroom`, `it`, `furniture`, `consumables`), asset tag, serial number, condition (`new`, `good`, `fair`, `maintenance_required`, `under_repair`, `damaged`, `disposed`), location, unit cost, quantity.
    - `assetAllocations`: staff asset checkout/assignment and return condition tracking.
    - `purchaseRequisitions`: procurement requests with estimated cost, urgency, status (`draft`, `pending_approval`, `approved`, `rejected`, `ordered`, `received`), and approval timestamps.
    - `staffSalaryStructures`: basic pay, HRA, special allowances, statutory PF/ESI/TDS deductions, net salary.
    - `payrollRuns`: monthly payroll runs per staff member with payment mode, payout status (`draft`, `approved`, `paid`, `voided`), transaction ref, paid timestamp.
    - `hostelRooms`: block name, room number, room type (`single`, `double`, `triple`, `dormitory`), capacity, occupied count, term fee.
    - `visitorGatePasses`: visitor name, phone, purpose, badge number, entry timestamp, exit timestamp, status (`checked_in`, `checked_out`, `flagged`).
    - `infirmaryVisits`: student triage visit log with symptoms, treatment administered, attending staff ID, parent notification status, follow-up flags.
  - **Medical Emergency Profile Extensions on `students`:**
    - `bloodGroup`: A+, A-, B+, B-, AB+, AB-, O+, O-.
    - `allergies`, `chronicConditions`, `emergencyContactName`, `emergencyContactPhone`, `medicalNotes`.
- **Backend API & Repositories:**
  - 24 high-throughput repository methods in `SchoolRepository` covering all 5 campus operational domains with atomic inventory counters, loan overdue fine calculations (₹5/day default), and reservation fulfillment.
  - 24 authenticated Admin routes in `services/api/src/routes/admin.ts` with granular RBAC (allowing `admin` and `accountant` for payroll operations).
  - Validation schemas in `services/api/src/http/validation.ts`.
  - Comprehensive test suite in `services/api/test/phase15-campus-operations.test.ts`.
- **Flutter Web & Mobile Interface:**
  - `AdminCampusView` (`apps/flutter_app/lib/src/features/admin/views/admin_campus_view.dart`):
    - Subtab 1: **Library & Circulation:** Stat strip (Total Titles, Total Copies, Issued, Active Reservations), quick search by title/author/ISBN, Issue Book and Add Book dialogs.
    - Subtab 2: **Inventory & Assets:** Category filtering, Condition pills, Add Asset dialog, and purchase requisition approval workflow.
    - Subtab 3: **Staff Payroll & Compensation:** Period selector, summary stat strip (Total Disbursed, Approved, Draft, Staff on Payroll), Run Monthly Payroll dialog, and Pay/Disburse action modal.
    - Subtab 4: **Hostel & Gate Passes:** Hostel room blocks overview, Add Room dialog, live Visitor Gate Pass ledger, Issue Pass dialog, and 1-click Check-Out action.
    - Subtab 5: **Student Health & Infirmary:** Medical profiles directory with quick blood group badges, emergency contact chips, Log Infirmary Visit dialog, and daily triage log.
  - Status Indicators:
    - `StatusBadge.payrollStatus`: visual tone and icons for `approved`, `paid`, `voided`, and `draft`.
    - `StatusBadge.inventoryCondition`: visual tone and icons for asset condition tiers.
  - Command Palette Integration:
    - Added `nav:campus` and 5 quick action command palette targets (`action:campus_library`, `action:campus_assets`, `action:campus_payroll`, `action:campus_gatepass`, `action:campus_health`).
- **Verification:**
  - Backend: 14/14 Vitest test suites passing (141 passed, 1 skipped).
  - TypeScript: 0 typecheck errors (`npm run typecheck --prefix services/api`).
  - Frontend: 98/98 Flutter unit/widget tests passing (`flutter test apps/flutter_app`).
  - Lint: 0 analyzer warnings (`flutter analyze apps/flutter_app`).

---

## Phase 14: Applied AI & Enhanced Institutional UX

### Summary
- **Student At-Risk Early Warning System:**
  - Database schema & migration `0016_calm_deathstrike.sql`:
    - `riskLevelEnum`: `'low'`, `'moderate'`, `'high'`, `'critical'`.
    - `riskAlertStatusEnum`: `'active'`, `'acknowledged'`, `'resolved'`.
    - `studentRiskAlerts`: `schoolId`, `studentId`, `academicYearId`, `compositeScore` (0-100), `attendanceScore`, `academicScore`, `feeScore`, `riskLevel`, `factors` (JSON text array of plain explanations), `status`, `interventions` (logged interventions history JSON), `lastEvaluatedAt`.
  - Multi-factor algorithmic evaluation engine (`evaluateStudentRiskScores`):
    - Attendance factor (weight 0.40): flags attendance below 75% or 3+ consecutive unexcused absences.
    - Academic factor (weight 0.35): flags exam scores below 35% or failed subjects.
    - Fee payment factor (weight 0.25): flags outstanding fee balances and overdue invoices.
    - Composite risk level: 80-100 = `critical`, 60-79 = `high`, 40-59 = `moderate`, <40 = `low`.
  - Admin & Teacher endpoints:
    - `POST /api/v1/admin/ai/at-risk/evaluate`: batch risk scoring for students.
    - `GET /api/v1/admin/ai/at-risk`: filtered alerts list by level and status.
    - `GET /api/v1/admin/ai/at-risk/:id`: single student risk breakdown.
    - `POST /api/v1/admin/ai/at-risk/:id/interventions`: logs counselor/teacher intervention notes and action plan.
    - `GET /api/v1/teacher/ai/at-risk`: class-teacher scoped risk alerts for assigned sections.
- **Natural Language Admin Analytics Engine:**
  - Table `nlAnalyticsQueries`: logs query text, recognized intent, parameters, explanation, and result row count.
  - Query parser & parameterized executor (`executeNaturalLanguageQuery` / `POST /api/v1/admin/ai/natural-language-query`):
    - Supported institutional queries:
      - Fee defaulters: *"List fee defaulters above ₹5,000"* (returns student, class, balance, status).
      - Attendance benchmarks: *"Classes with attendance under 85%"* (returns class, section, rate, absentees).
      - Academic toppers: *"Academic toppers in Class 10"* (returns rank, name, aggregate %, letter grade).
      - Staff on leave: *"Staff on leave with suggested substitutes"* (returns teacher, dates, available substitutes).
      - Cohort strength: *"Cohort enrollment strength by class"* (returns class, active students, capacity).
    - Features: Zero prompt leakage, strictly read-only parameterized queries over Neon Postgres, structured markdown table, natural language summary banner, and suggested follow-up queries.
- **AI Drafting for Teachers:**
  - Report Card Remarks Assistant (`draftReportCardRemarks` / `POST /api/v1/teacher/ai/draft-remarks`):
    - Generates personalized remarks based on student attendance, aggregate percentage, and selected tone (`encouraging`, `constructive`, `formal`).
    - Provides primary draft remark and 2 alternative choices.
  - Homework Rubric Feedback Assistant (`draftHomeworkFeedback` / `POST /api/v1/teacher/ai/draft-homework-feedback`):
    - Generates constructive formative feedback based on assignment score percentage, subject, and rubric criteria.
- **Power UX & Navigation (Flutter Web & Mobile):**
  - Global Command Palette (`CommandPaletteDialog`):
    - Keyboard shortcut: `Cmd/Ctrl + K` global binding via `KeyboardListener` on `SchoolicShell`.
    - Instant search across navigation targets, AI tools, attendance register, exam schedules, and settings.
    - Arrow-key navigation (`↑` / `↓`), `Enter` to execute, `Esc` to close.
    - Top bar "Quick Actions (⌘K)" button on Admin and Teacher dashboard app bars.
  - `AdminInsightsView` Upgrade:
    - Subtab 1: **At-Risk Early Warning** with risk level filter, metric stat strip, risk badges, factors pills, and "Log Intervention" modal.
    - Subtab 2: **Natural Language Queries** with query input, suggested quick pills, zero-leakage badge, and structured results table.
    - Subtab 3: **Attendance AI Synthesis** with class-wise attendance rates and automated alerts.
  - Teacher AI Drafting Modals:
    - `AiDraftRemarksDialog`: Interactive tone picker and 1-click apply to report card remarks.
    - `AiHomeworkFeedbackDialog`: Rubric criteria input and feedback insertion.
  - UI Indicators:
    - `StatusBadge.riskLevel`: Color-coded risk chips with icons (`critical`, `high`, `moderate`, `low`).
- **Verification:**
  - Backend: 13/13 Vitest test suites passing (132 passed, 1 skipped).
  - TypeScript: 0 typecheck errors (`npm run typecheck --prefix services/api`).
  - Frontend: 91/91 Flutter unit/widget tests passing (`flutter test apps/flutter_app`).
  - Lint: 0 analyzer warnings (`flutter analyze apps/flutter_app`).

---

## Phase 13: Academic Depth, Regional Languages & Offline App

### Summary
- **Board-Specific Grading Schemes & Aggregation:**
  - Database schema & migration `0015_demonic_beyonder.sql`:
    - `gradingSchemes`: Board type (`cbse`, `icse`, `state_board`, `cambridge`, `custom`), name, passing percentage, default flag.
    - `gradingScales`: Grade boundary mapping (min mark %, max mark %, letter grade `A1`-`E`, grade point `10.0`-`0.0`, description).
    - `evaluationComponents`: Component definitions (e.g. Periodic Tests, Subject Enrichment, Portfolio, Term Exams, FA1-FA4, SA1-SA2) with weightage percentages and term associations.
    - `studentReportCards`: Official student report cards with aggregated marks, letter grade, grade point, attendance percentage, result status (`promoted`, `passed`, `compartment`, `failed`), teacher remarks, principal remarks, and publication toggle.
    - `offlineAttendanceSyncLogs`: Sync logs tracking client batch ID, synced record count, conflict count, and sync status.
  - Built-in seeder (`seedDefaultBoardGradingSchemes`): One-click initialization of standard CBSE (9-point scale A1-E), ICSE (1-9 scale with 20% internal / 80% board), and State Board CCE (FA1-FA4: 40%, SA1-SA2: 60%).
  - Aggregation engine (`generateReportCards`): Computes weighted component scores, total marks obtained vs maximum, resolves grade scale and points, calculates term attendance percentage, and generates report cards for entire classes/sections in bulk.
  - Endpoints:
    - Admin: `GET/POST /api/v1/admin/academics/grading-schemes`, `POST /api/v1/admin/academics/grading-schemes/seed-defaults`, `GET /api/v1/admin/academics/grading-schemes/:id`, `POST /api/v1/admin/academics/grading-schemes/:id/scales`, `POST /api/v1/admin/academics/grading-schemes/:id/components`, `POST /api/v1/admin/academics/report-cards/generate`, `GET /api/v1/admin/academics/report-cards`, `GET /api/v1/admin/academics/report-cards/:id`, `PUT /api/v1/admin/academics/report-cards/:id/publish`.
    - Portal: `GET /api/v1/portal/academics/report-cards`.
- **Regional Language Localization (English, Kannada, Hindi):**
  - Trilingual localization engine in `apps/flutter_app/lib/src/core/localization/app_localizations.dart`:
    - `AppLanguage` enum: English (`en`), Kannada (`kn` - ಕನ್ನಡ), Hindi (`hi` - हिन्दी).
    - `AppLocalizations`: Complete dictionary mapping covering navigation, actions, attendance statuses, academics, fees, exams, and error notifications.
    - `LanguagePickerDropdown`: Reusable language picker widget supporting both compact popup button and standard dropdown styling.
    - Wired into root `App` widget (`apps/flutter_app/lib/src/app.dart`) with reactive `Locale` binding.
- **Offline-First Attendance:**
  - Local persistent queue manager in `apps/flutter_app/lib/src/core/offline/offline_attendance_manager.dart`:
    - `OfflineAttendanceRecordItem`: Individual student attendance item serialization.
    - `OfflineAttendanceBatch`: Class-section-date attendance payload with client timestamp and unique batch UUID.
    - `OfflineAttendanceNotifier` & `offlineAttendanceProvider`: `SharedPreferences`-backed persistent queue with automatic queueing, batch synchronization, and queue clearing.
    - Server-side batch sync endpoint (`POST /api/v1/teacher/attendance/sync`): Validates roster, creates/retrieves daily session, upserts attendance records, and audits conflicts.
    - Seamless fallback integrated into `TeacherAttendanceView` on network timeout or failure.
- **Printable Official Board Report Card PDF Generator:**
  - PDF rendering engine in `apps/flutter_app/lib/src/features/admin/utils/report_card_pdf.dart`:
    - Clean, board-compliant printable report card layout built using `pdf` & `printing`.
    - School branding, affiliation details, student demographics (name, admission number, roll number, class, section, term).
    - Scholastic performance table displaying subject-wise periodic tests, subject enrichment, portfolio, term marks, total marks, percentage, letter grade, and grade points.
    - Co-scholastic activities evaluation table (Work Education, Health & Physical Education, Art, Discipline).
    - Aggregate score, attendance percentage, result status badge, teacher remarks, and institutional tri-signature footer.
- **Frontend Views (Flutter):**
  - Enhanced `AdminExamsView`:
    - Subtab 1: **Exams Schedule** with exam title, date, max marks, status, and edit/delete actions.
    - Subtab 2: **Board Schemes & Scales** with board badges, component weightages, grade point scales, and one-click "Seed Board Presets" button.
    - Subtab 3: **Official Report Cards** with aggregate percentage, grade, grade point, portal publish toggle, printable PDF trigger, and "Bulk Generate Report Cards" modal.
  - Enhanced `StudentAppView`:
    - Displays published official board report cards with term, board badge, score, grade, and one-click "Download Official PDF" button.
  - Added 12 API methods in `apps/flutter_app/lib/src/core/api_client.dart`.
- **Verification:**
  - Backend: 12/12 Vitest test suites passing (122 passed, 1 skipped).
  - TypeScript: 0 typecheck errors (`npm run typecheck --prefix services/api`).
  - Frontend: 84/84 Flutter unit/widget tests passing (`flutter test apps/flutter_app`).
  - Lint: 0 analyzer warnings (`flutter analyze apps/flutter_app`).

---

## Phase 12: School Operations & Daily Differentiators

### Summary
- **Student & Staff Leave Management:**
  - `studentLeaves` table: Parent/student leave applications with start/end date, leave type (`sick`, `casual`, `emergency`, `family`), reason, optional medical certificate URL/key, and teacher approval flow (`pending`, `approved`, `rejected`).
  - `staffLeaves` table: Staff leave tracking with approval flow, reason, and substitute assignment.
  - Automated Timetable Substitute Suggestion Engine (`suggestStaffLeaveSubstitutes` / `/api/v1/admin/operations/staff-leaves/suggest-substitutes`): cross-references target teacher's scheduled timetable slots during leave dates against other staff members to identify available teachers with zero period conflicts.
  - Endpoints:
    - Admin: `GET/POST /api/v1/admin/operations/student-leaves`, `PUT /api/v1/admin/operations/student-leaves/:id/status`, `GET/POST /api/v1/admin/operations/staff-leaves`, `PUT /api/v1/admin/operations/staff-leaves/:id/status`, `POST /api/v1/admin/operations/staff-leaves/suggest-substitutes`.
    - Teacher: `GET /api/v1/teacher/student-leaves`, `PUT /api/v1/teacher/student-leaves/:id/status`, `GET/POST /api/v1/teacher/my-leaves`.
    - Portal: `GET/POST /api/v1/portal/leaves`.
- **School Transport Fleet Management:**
  - Fleet management schema & migration `0014_sad_dormammu.sql`:
    - `transportVehicles`: Vehicle number, capacity, vehicle type (`bus`, `van`, `minibus`), GPS tracking device ID, insurance expiry date.
    - `transportDrivers`: Driver name, phone, driving license number, license expiry date, active status.
    - `transportRoutes`: Route name, code, start location, end location, assigned vehicle & driver.
    - `transportStops`: Ordered route stops with pickup & drop-off timings and sequence indexing.
    - `studentTransportAllocations`: Student allocation to routes and specific stops for morning/evening shifts with fee linkages.
    - `transportLogs`: Live vehicle checkpoint logging (checkpoint location, direction, speed, timestamp).
  - Endpoints:
    - Admin: `GET/POST /api/v1/admin/operations/transport/vehicles`, `GET/POST /api/v1/admin/operations/transport/drivers`, `GET/POST /api/v1/admin/operations/transport/routes`, `GET/POST /api/v1/admin/operations/transport/stops`, `GET/POST /api/v1/admin/operations/transport/allocations`, `GET/POST /api/v1/admin/operations/transport/logs`.
    - Portal: `GET /api/v1/portal/transport`.
- **Verifiable Official PDF Certificate Generator:**
  - `issuedCertificates` table: Tracks certificate type (`transfer_certificate`, `bonafide`, `conduct`, `character`, `sports_merit`), unique serial number (`TC-YYYY-XXXXX`), student ID, issue date, metadata (admission date, conduct remarks, counter-signature authority), revocation status (`active`, `revoked`), and unique 12-char digital verification code.
  - Public verification API (`GET /api/v1/public/certificates/verify/:code`): instant public verification of certificate validity without login.
  - Endpoints: `GET/POST /api/v1/admin/operations/certificates`, `PUT /api/v1/admin/operations/certificates/:id/revoke`.
- **Public Inquiry & Admission Landing Page + RTE Quota:**
  - Extended `admissionApplications` with `quotaCategory` (`general`, `rte_25`, `management`, `staff_ward`, `sports`) and `casteCategory` (`general`, `obc`, `sc`, `st`, `ews`).
  - Public unauthenticated endpoints:
    - `GET /api/v1/public/schools/:code`: School profile, name, affiliation, contact info for public web visitors.
    - `POST /api/v1/public/inquiries`: Public prospective student and parent inquiry form feeding directly into the Schoolic admissions pipeline.
- **Institutional Calendar & Parent-Teacher Meeting (PTM) Scheduling:**
  - `calendarEvents` table: Master institutional calendar (`holiday`, `examination`, `event`, `sports_day`, `ptm`, `staff_meeting`, `term_start`, `term_end`) with title, description, start/end dates, and public visibility toggle.
  - `ptmSchedules` table: PTM session definition (title, meeting date, start/end time, slot duration in minutes, status).
  - `ptmSlots` table: Auto-generated individual parent-teacher meeting time slots (`available`, `reserved`, `completed`, `cancelled`) with teacher assignment and parent reservation capabilities.
  - Endpoints:
    - Admin: `GET/POST /api/v1/admin/operations/calendar/events`, `DELETE /api/v1/admin/operations/calendar/events/:id`, `GET/POST /api/v1/admin/operations/ptm/schedules`, `POST /api/v1/admin/operations/ptm/schedules/:id/generate-slots`, `GET /api/v1/admin/operations/ptm/schedules/:id/slots`.
    - Teacher: `GET /api/v1/teacher/ptm/slots`, `PUT /api/v1/teacher/ptm/slots/:id/status`.
    - Portal: `GET /api/v1/portal/calendar/events`, `GET /api/v1/portal/ptm/slots`, `POST /api/v1/portal/ptm/slots/:id/reserve`.
- **Frontend (Flutter):**
  - Implemented `AdminOperationsView` in `apps/flutter_app/lib/src/features/admin/views/admin_operations_view.dart`:
    - Tab 1: **Leaves & Substitutes** with stats strip, student/staff leave lists, status badge, review modal, and substitute suggestion engine trigger.
    - Tab 2: **Transport Fleet** with vehicle and driver rosters, route details, and vehicle registration dialog.
    - Tab 3: **Official Certificates** with serial tracking, verification codes, revoke actions, and certificate issuance modal.
    - Tab 4: **Calendar & PTM** with institutional events list, event creation dialog, PTM sessions with automatic slot generation modal.
  - Integrated `AdminNavSection.operations` into `AdminDashboard` with navigation switcher, sidebar item, and operations badge.
  - Added all Phase 12 API methods to `ApiClient`.
- **Verification:**
  - Backend: 11/11 Vitest test suites passing (112 passed, 1 skipped).
  - TypeScript: 0 typecheck errors (`npm run typecheck --prefix services/api`).
  - Frontend: 75/75 Flutter unit/widget tests passing (`flutter test`).
  - Lint: 0 analyzer warnings (`flutter analyze apps/flutter_app`).

---

## Phase 11: Enterprise Roles, DPDP Compliance & Financial Depth

### Summary
- **Granular Institutional RBAC:**
  - Expanded `roleEnum` and Flutter `AppRole` to include `accountant`, `admissions_officer`, and `principal`.
  - Enforced role isolation middleware on `/api/v1/admin/*`:
    - `Accountant`: restricted to fee allocations, concessions, refunds, payments, and receipts.
    - `Admissions Officer`: restricted to admissions applications, document verification, enrollment, and onboarding.
    - `Principal`: granted global read-only visibility across institutional analytics, attendance, academics, and finances.
  - Designated `classTeacherStaffId` on `sections` table with endpoint `PUT /api/v1/admin/sections/:id/class-teacher`.
- **DPDP Act 2023 Compliance:**
  - Database schema & migration `0013_talented_husk.sql`:
    - `dpdp_consents`: Verifiable parental consent tracking for minors with digital (`portal_submission`) and offline (`signed_form`, `sms_otp`) verification records.
    - `audit_logs`: Immutable institutional trail capturing actor, role, action, target resource, and IP address across sensitive modifications.
    - `data_subject_requests`: Data Subject Rights (DSR) lifecycle (`data_access`, `data_rectification`, `data_erasure_anonymization`).
  - Automated Student PII Anonymization: non-destructive erasure stripping student full name, guardian name, and phone while preserving academic, attendance, and fee aggregate totals for regulatory compliance.
  - Endpoints:
    - Admin: `GET/POST /api/v1/admin/dpdp/consents`, `GET/PUT /api/v1/admin/dpdp/dsr`, `GET /api/v1/admin/audit-logs`.
    - Portal: `GET /api/v1/portal/dpdp/consents`, `GET/POST /api/v1/portal/dpdp/dsr`.
- **Advanced Institutional Financial Management:**
  - Concessions & Scholarships (`fee_concessions`, `student_fee_concessions`): supports percentage or flat discounts linked to fee structures.
  - Late fee calculation engine (`calculateLateFee`): automated calculation of grace period and daily/flat penalties.
  - Official Fee Refunds Ledger (`fee_refunds`): tracks refund number, reason, payment mode (`bank_transfer`, `cash`, `gateway_refund`), and status approval workflow (`pending`, `approved`, `processed`, `rejected`).
  - Head-wise fee breakdown (`fee_structure_heads`): Tuition, Transport, Lab, Examination, Sports.
  - Endpoints:
    - `GET/POST /api/v1/admin/fees/concessions`, `POST /api/v1/admin/fees/concessions/apply`, `GET /api/v1/admin/fees/concessions/applied`.
    - `GET/POST /api/v1/admin/fees/refunds`, `PUT /api/v1/admin/fees/refunds/:id/status`.
    - `GET/POST /api/v1/admin/fees/structures/:id/heads`.
- **Frontend (Flutter):**
  - Built `AdminComplianceView` with 3 dedicated tabs: Parental Consents, Data Subject Rights, and Audit Log Trail.
  - Modal workflows: `Record Parental Consent` and `Resolve Data Subject Request` with automated PII anonymization toggle.
  - Updated `AdminFeesView` with `Concessions & Waivers` tab and `Refunds Ledger` tab, including policy creation and refund issuance modals.
  - Wired `AdminNavSection.compliance` into Admin Dashboard with role-aware navigation and badge.
  - Dev sign-in switches in `providers.dart` supporting all enterprise roles.
- **Verification:**
  - Backend: 10/10 Vitest test suites passing (95 passed, 1 skipped, 0 failed).
  - TypeScript: 0 typecheck errors (`pnpm api:typecheck`).
  - Frontend: 71/71 Flutter unit, widget, and integration tests passing (`flutter test`).
  - Lint: 0 analyzer warnings (`flutter analyze apps/flutter_app`).

---

## Phase 10: Institutional Onboarding, Automated Notifications & Moderated Chat

### Summary
- **Bulk CSV Importer & Academic Setup Wizard:**
  - CSV parsing and validation engine (`BulkImporter`) supporting students, staff, and timetable imports with row-level error reporting.
  - Academic setup wizard (`runOnboardingWizard` / `POST /api/v1/admin/onboarding/wizard`) creating academic years, grades, sections, and subjects in a single atomic transaction.
- **Multi-Channel Notification Dispatcher:**
  - Pluggable notification service (`NotificationService`) with simulated and provider-ready adapters for SMS, WhatsApp, and Email.
  - Automated absence notifications on attendance finalization and fee reminder scheduler (`POST /api/v1/admin/notifications/trigger-fee-reminders`).
  - Institutional notification log table (`notifications`) and portal notification feed.
- **Teacher Working Hours & Moderated Parent Chat:**
  - Teacher availability preferences (`teacher_availability`): configurable active hours, days, auto-reply messages, and vacation toggles.
  - Moderated parent-teacher chat (`chat_conversations`, `chat_messages`) with automatic out-of-hours replies.
- **Frontend:**
  - `AdminCommunicationsView` with Bulk CSV Import, Automated Fee Alerts, and Notification History tabs.
  - `TeacherMessagesView` for direct parent-teacher communications with out-of-hours auto-reply indicators.

---

## Phase 9: Cloudflare R2 Document Storage & Production Hardening

### Summary
- Configured Cloudflare R2 object storage binding (`DOCUMENTS_BUCKET`) in `wrangler.jsonc` across dev, staging (`schoolic-documents-staging`), and production (`schoolic-documents`).
- Implemented `DocumentStorage` service with isolated tenant keys: `schools/{schoolId}/admissions/{applicationId}/{documentId}-{filename}` and test memory fallback.
- Added database migration `0011_bright_slyde.sql` extending `admission_documents` with `file_key`, `file_url`, `file_name`, `file_size`, and `mime_type`.
- Added REST endpoints in `admin.ts`:
  - `POST /api/v1/admin/admissions/applications/:id/documents/:docId/upload`
  - `GET /api/v1/admin/admissions/applications/:id/documents/:docId/download`
  - `DELETE /api/v1/admin/admissions/documents/:id/file`
- Added Cashfree webhook replay protection with timestamp skew validation (< 5 minutes) and timing-safe HMAC-SHA256 verification.
- Added rate limiter middleware (`rateLimiter`) protecting `/api/v1/bootstrap/*`, `/api/v1/webhooks/*`, and `/api/v1/portal/fees/*`.
- Integrated cross-platform `file_picker` in `AdminAdmissionsView` for single-click file uploads with file info, download/view, and delete controls.
- Test Verification:
  - Vitest: 7/7 test suites passing (65 passed, 1 skipped).
  - Flutter: 57/57 tests passing.

---

## Phase 8.6: Cashfree Payment Gateway & Full Production Deployment

### Summary
- Integrated live Cashfree Payment Gateway using provided Sandbox credentials (App ID: `TEST112097243d3d637f11e796a7739842790211`, Secret Key configured securely via Cloudflare Secrets).
- Built complete interactive payment checkout flow in Flutter (`FeePaymentSheet`), offering full balance payment as well as flexible custom installment amounts.
- Multi-channel checkout support: UPI Collect (`testsuccess@gocash`), Cards, Netbanking with real-time feedback and secure SSL badge.
- Instant official institutional receipt generation (`REC-YYYY-XXXXX`), payment history ledger, and printable PDF invoice generation via `printing` and `pdf` packages.
- Added sandbox auto-pay and simulation fallback (`POST /pg/simulate` with `entity: "PAYMENTS"`) ensuring reliable test settlements directly against Cashfree Sandbox servers.
- Embedded Cashfree JS SDK v3 (`https://sdk.cashfree.com/js/v3/cashfree.js`) in Flutter Web.
- Live Deployed:
  - Production API Worker (`schoolic-api`): `https://schoolic-api.schoolic-api.workers.dev`
  - Staging API Worker (`schoolic-api-staging`): `https://schoolic-api-staging.schoolic-api.workers.dev`
  - Production Web (`schoolic` Pages): `https://schoolic.pages.dev`
  - Staging Web (`schoolic-staging` Pages): `https://schoolic-staging.pages.dev`
  - Production Android Release APK (`app-release.apk`, 63.4MB) built and installed on connected physical device (`realme RMX3511`, Android 13).
- Test Verification:
  - Vitest: 60/60 tests passing (including direct live Cashfree Sandbox client tests).
  - Flutter: 54/54 tests passing.
- Push Protection & Security:
  - Purged raw secret string literals from git-tracked test files; secret keys securely managed via Cloudflare Worker secrets (`wrangler secret put CASHFREE_SECRET_KEY`) and local gitignored `.env`/`.dev.vars`.
  - Pushed clean commit (`faf7a8f`) to `main` at `Techteam-zephvion/School-management-app`.

---

## Phase 8.5: Admissions & Operations MVP

### Summary
- Implemented complete Admissions & Operations pipeline for Schoolic.
- Administrators can record prospective inquiries, manage formal admissions applications, verify submitted certificates/documents, track grade-level seat capacity, and enroll approved candidates with a single click.
- Live pipeline metrics: Total Pipeline, Under Review, Approved for Intake, and Successfully Enrolled in the administrator workspace.
- Document verification checklist: birth certificates, previous school report/transfer certificates, address proofs, and photos with staff verification tracking.
- Class intake capacity tracker: calculates nominal intake (40 seats/class), enrolled count, and remaining vacancies with visual progress bars.
- One-click student enrollment: automatically creates an active student profile, enrolls into the target classroom section, assigns a student admission ID, and transitions application status to `enrolled`.

### Backend
- Added database schema (`services/api/src/db/schema.ts`):
  - Enums: `admission_status` (`inquiry`, `applied`, `under_review`, `approved`, `enrolled`, `rejected`), `document_status` (`pending`, `submitted`, `verified`, `rejected`).
  - Tables: `admission_applications`, `admission_documents` with cascade foreign keys, tenant scoping, and academic year indexing.
- Generated Drizzle migration `0009_zippy_shard.sql`.
- Added validation schemas (`services/api/src/http/validation.ts`): `createAdmissionApplicationSchema`, `updateAdmissionApplicationSchema`, `enrollApplicantSchema`, `admissionQuerySchema`, `addAdmissionDocumentSchema`, `updateAdmissionDocumentSchema`.
- Implemented repository methods (`services/api/src/repositories/school-repository.ts`):
  - `admissionSummary`: Aggregates total pipeline, status counts, conversion rate, and class capacity breakdown.
  - `listAdmissionApplications`: Filterable by academic year, class, status, and search string (applicant, parent, phone, application number).
  - `getAdmissionApplication`: Returns application with joined verification documents.
  - `createAdmissionApplication`: Generates `APP-YYYY-XXXX`, creates application, initializes default verification checklist documents.
  - `updateAdmissionApplication`: Updates applicant details, notes, decision dates, and pipeline status.
  - `deleteAdmissionApplication`: Deletes application and associated documents.
  - `enrollApplicant`: Creates record in `students`, adds enrollment in `studentEnrollments`, assigns student admission number, marks application as enrolled.
  - `listAdmissionDocuments`, `addAdmissionDocument`, `updateAdmissionDocument`, `deleteAdmissionDocument`: Document checklist management with staff verification audit.
- Admin admission routes (`services/api/src/routes/admin.ts`):
  - `GET /api/v1/admin/admissions/summary`
  - `GET /api/v1/admin/admissions/applications`
  - `POST /api/v1/admin/admissions/applications`
  - `GET /api/v1/admin/admissions/applications/:id`
  - `PATCH /api/v1/admin/admissions/applications/:id`
  - `DELETE /api/v1/admin/admissions/applications/:id`
  - `POST /api/v1/admin/admissions/applications/:id/enroll`
  - `GET /api/v1/admin/admissions/applications/:id/documents`
  - `POST /api/v1/admin/admissions/applications/:id/documents`
  - `PATCH /api/v1/admin/admissions/documents/:id`
  - `DELETE /api/v1/admin/admissions/documents/:id`

### Frontend
- Added **Admissions & Operations** workspace to administrator dashboard (`AdminDashboard`, `AdminAdmissionsView`):
  - Typographic `StatStrip`: Total Pipeline, Under Review, Approved for Intake, Successfully Enrolled.
  - Subtab navigation: "Applications Pipeline", "Inquiries & Leads", "Class Capacity & Seats".
  - Search and filter bar (by applicant name, parent name, phone, application number, target class, pipeline status).
  - Action dialogs:
    - `_NewApplicationDialog`: Captures applicant name, DOB, gender, parent contact details, previous school, address, notes.
    - `_ApplicationDetailDialog`: Status updater, notes review, and interactive document verification checklist.
    - `_EnrollApplicantDialog`: Assigns section, admission ID, and roll number.
  - Strict compliance with monochrome Switzer design (`AppColors`, `AppTypography`, `AppRadii`, `StatusBadge`, `StatStrip`, `PageHeader`, `EmptyStateView`).

### Verification
- `pnpm api:typecheck`: PASS (0 errors).
- `pnpm api:test`: PASS (54/54 tests across 4 files).
- `flutter analyze`: PASS (0 issues found).
- `flutter test`: PASS (46/46 tests across 3 files).

### Deployment
- Not deployed yet.

## Phase 8.4: Fees & Finance MVP

### Summary
- Implemented complete Fees & Finance management for Schoolic.
- Administrators can define fee structures (with custom amount, frequency, and due dates), allocate fees to enrolled students, record collected payments, and generate official receipts.
- Live billing metrics: Total Billed, Total Collected, Outstanding Due, and Overdue Dues in the administrator workspace.
- Multi-channel payment recording: Cash, UPI / QR, Card, Bank Transfer (NEFT/IMPS), and Cheque with transaction reference notes.
- Printable / viewable formal digital receipt ledger with auto-generated receipt serial numbers (`REC-YYYYMMDD-XXXX`).
- Student and Parent Portal integration: parents and students can review fee structures, payment status badges (PAID, PARTIAL, OVERDUE, PENDING), and historical payment receipts for linked students.

### Backend
- Added database schema (`schema.ts`):
  - Enums: `fee_frequency` (`one_time`, `term`, `monthly`, `annual`), `fee_allocation_status` (`pending`, `partial`, `paid`, `overdue`), `fee_payment_method` (`cash`, `upi`, `card`, `bank_transfer`, `cheque`).
  - Tables: `fee_structures`, `student_fee_allocations`, `fee_payments` with cascade foreign keys, tenant scoping, and academic year indexing.
- Generated Drizzle migration `0008_useful_talos.sql`.
- Added validation schemas (`validation.ts`): `createFeeStructureSchema`, `updateFeeStructureSchema`, `createFeeAllocationSchema`, `recordFeePaymentSchema`, `feeAllocationQuerySchema`, `feePaymentQuerySchema`.
- Implemented repository methods (`school-repository.ts`):
  - `feeSummary`: Aggregates total billed, total collected, total outstanding, and overdue counts.
  - `listFeeStructures`, `createFeeStructure`, `updateFeeStructure`, `deleteFeeStructure`.
  - `listFeeAllocations`: Dynamic balance calculation and overdue detection against current date.
  - `createFeeAllocation`: Enforces tenant bounds, prevents duplicate active allocations.
  - `recordFeePayment`: Issues unique receipt numbers, tracks partial/complete fulfillment, updates allocation status automatically.
  - `listFeePayments`: Audit ledger of all recorded receipts.
  - `portalFeeSummary`: Scoped strictly to linked students for parent/student portal users.
- Admin fee routes:
  - `GET /api/v1/admin/fees/summary`
  - `GET /api/v1/admin/fees/structures`
  - `POST /api/v1/admin/fees/structures`
  - `PATCH /api/v1/admin/fees/structures/:id`
  - `DELETE /api/v1/admin/fees/structures/:id`
  - `GET /api/v1/admin/fees/allocations`
  - `POST /api/v1/admin/fees/allocations`
  - `GET /api/v1/admin/fees/payments`
  - `POST /api/v1/admin/fees/payments`
- Portal fee route:
  - `GET /api/v1/portal/fees` (requires student/parent role, tenant-scoped, student validation).

### Frontend
- Added **Fees & Finance** section to administrator dashboard (`AdminDashboard`, `AdminFeesView`):
  - Typographic `StatStrip`: Total Billed, Total Collected, Outstanding Due, Overdue Dues.
  - Subtab navigation: "Student Dues & Allocations", "Fee Structures", "Receipts Ledger".
  - Search and filter bar (by student name/admission number, class, payment status).
  - Modals: `_AddStructureModal`, `_AssignFeeModal`, `_RecordPaymentModal`, `_ReceiptModal`.
  - Respects strict monochrome design system (`AppColors`, `AppTypography`, `AppRadii`, `StatusBadge`, `FeedbackBanner`, `AppDialog`).
- Added **Fees & Payments** panel to student & parent portal (`PortalDashboard`):
  - Metrics breakdown: Billed, Paid, Balance Due.
  - Allocations list with status badges (`PAID`, `PARTIAL`, `OVERDUE`, `PENDING`).
  - Historical receipts list with receipt number, amount, payment method, and timestamp.
  - Responsive layout support in both stacked (mobile) and side-by-side (desktop) views.

### Verification
- `pnpm api:typecheck`: PASS (0 errors).
- `pnpm api:test`: PASS (47/47 tests across 4 files).
- `cd apps/flutter_app && flutter analyze --no-fatal-infos`: PASS (0 issues).
- `pnpm flutter:test`: PASS (43/43 tests across 3 files).

### Deployment
- Not deployed yet.
- Production resources remain completely untouched.

---

# Last Update (October 12, 2026)

## Phase 8.3: Exams, Marks & Report Cards MVP

### Summary
- Added the first examination workflow for Schoolic.
- Administrators can create and manage exams for class sections.
- Teachers can view assigned exams and enter marks for students in their authorized class sections.
- Students and parents can view published exam results and overall report-card summary in the portal.

### Backend
- Added `exam_status`, `exams`, and `exam_marks`.
- Added admin exam routes:
  - `GET /api/v1/admin/exams`
  - `POST /api/v1/admin/exams`
  - `PATCH /api/v1/admin/exams/:id`
  - `DELETE /api/v1/admin/exams/:id`
- Added teacher mark-entry routes:
  - `GET /api/v1/teacher/exams`
  - `GET /api/v1/teacher/exams/:id/roster`
  - `POST /api/v1/teacher/exam-marks`
- Added portal report route:
  - `GET /api/v1/portal/report-card`
- Teacher mark entry is restricted to assigned sections. Portal report cards are restricted to linked students and published exams.

### Frontend
- Added **Exams** area in the administrator workspace.
- Added **Marks** area in the teacher workspace.
- Added **Report Card** panel to the student and parent portal.

### Verification
- `pnpm api:typecheck`: PASS.
- `pnpm api:test`: PASS, 42/42 tests across 4 files.
- `cd apps/flutter_app && flutter analyze --no-fatal-infos`: PASS with one pre-existing non-fatal info in `shortcuts_dialog.dart`.
- `pnpm flutter:test`: PASS, 40/40 tests.

### Deployment
- Not deployed yet.
- Production resources were not touched.

---

## Phase 8.0: Homework & Assignments MVP

### Summary
- Added persisted homework assignments as the first academic workflow in the Phase 8 roadmap.
- Teachers can create, edit, publish, draft, archive, and delete homework for their assigned class sections.
- Students and parents can see published homework in the portal for the selected linked student.
- Homework is connected to existing class, section, subject, academic year, teacher assignment, and portal authorization rules.

### Backend
- Added `homework_status` enum and `homework_assignments` table.
- Added validation for homework title, instructions, due date, estimated time, status, and class context.
- Added teacher API routes:
  - `GET /api/v1/teacher/homework`
  - `POST /api/v1/teacher/homework`
  - `PATCH /api/v1/teacher/homework/:id`
  - `DELETE /api/v1/teacher/homework/:id`
- Added portal API route:
  - `GET /api/v1/portal/homework`
- Teacher homework writes are restricted to assigned class sections. Portal reads are restricted to linked students and published homework only.

### Frontend
- Added **Homework** navigation in the teacher workspace.
- Added a responsive teacher homework composer and assignment list.
- Added homework visibility in the student and parent portal.
- Added mobile layout coverage for the teacher homework composer.

### Verification
- `pnpm api:typecheck`: PASS.
- `pnpm api:test`: PASS, 40/40 tests across 4 files.
- `cd apps/flutter_app && flutter analyze --no-fatal-infos`: PASS with one pre-existing non-fatal info in `shortcuts_dialog.dart`.
- `pnpm flutter:test`: PASS, 40/40 tests.

### Deployment
- Not deployed yet.
- Production resources were not touched.

---

## Phase 8.2: Student & Parent Portal MVP

### Summary
- Added a read-only student and parent portal for linked accounts.
- Student and parent roles now route to a dedicated portal instead of teacher/admin workspaces.
- The portal shows linked student context, attendance summary, weekly timetable, and relevant announcements.
- Parent accounts can be linked to one or more students; student accounts can be linked directly to a student record.

### Backend
- Extended `role` support to `student` and `parent`.
- Added `students.user_id` for direct student account links.
- Added `student_guardians` table for parent/guardian-to-student links.
- Added portal API routes:
  - `GET /api/v1/portal/profile`
  - `GET /api/v1/portal/announcements`
  - `GET /api/v1/portal/attendance`
  - `GET /api/v1/portal/timetable`
- Added admin provisioning support:
  - student creation can include `userId`;
  - `POST /api/v1/admin/students/guardian-links` links parent/guardian accounts to student records.
- Portal endpoints enforce student/parent roles and only return data for linked students in the current school.

### Frontend
- Added `PortalDashboard` for the student and parent experience.
- Added routing for `student` and `parent` roles.
- Added local-development sign-in buttons for parent and student roles.
- Added responsive mobile coverage for the portal shell.

### Verification
- `pnpm api:typecheck`: PASS.
- `pnpm api:test`: PASS, 38/38 tests across 4 files.
- `cd apps/flutter_app && flutter analyze --no-fatal-infos`: PASS with one pre-existing non-fatal info in `shortcuts_dialog.dart`.
- `pnpm flutter:test`: PASS, 39/39 tests.

### Deployment
- Not deployed yet.
- Production resources were not touched.

---

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

---

# Phase 8.0 – 8.5: End-to-End Roadmap Implementation & Staging Deployment

## Overview
Implemented the full institutional roadmap scope across backend schema, API routes, repositories, validations, and the Flutter Web/Mobile frontend, followed by complete live deployment to staging and end-to-end browser verification.

### Roadmap Phases Implemented
- **8.0 Homework & Assignments**: Class assignments, due dates, instructions, workload minutes estimation, publication status, linked into teacher workflow and student portal.
- **8.1 Announcements & Communication**: Central institutional announcements, targeted classes/sections, priority badges, integrated in admin sidebar, teacher top navigation, and student portal.
- **8.2 Student & Parent Portal**: Dedicated portal shell and views for attendance, timetables, homework, report cards, fees, and announcements with role-based route guard.
- **8.3 Exams, Marks & Report Cards**: Institutional exam creation, grading schedules, subject marks entry, and report card generation.
- **8.4 Fees & Finance Management**: Dynamic fee structures, student fee allocations, payment receipts, collection metrics, overdue tracking, and student portal fee statements.
- **8.5 Admissions & School Operations**: Admissions pipeline (Inquiry, Applied, Under Review, Approved, Enrolled, Rejected), document verification checklist, and direct student enrollment.

---

## Staging Deployment Execution

1. **Staging Database Migration & Backup**:
   - Pre-migration backup branch created: `backup-pre-8-5` (`br-lively-shadow-b5cslh7o`) on Neon staging project `nameless-dust-81736720`.
   - Applied migrations to staging branch `main` (`br-floral-mountain-b5s114go`):
     - `0008_useful_talos.sql` (Fees & Finance: structures, allocations, payments).
     - `0009_zippy_shard.sql` (Admissions: applications, documents, pipeline).

2. **Cloudflare Workers API Deployment**:
   - Worker: `schoolic-api-staging`
   - Deployment version: `16e08fb4-10bc-426b-98b9-6e0b0a025285`
   - URL: `https://schoolic-api-staging.schoolic-api.workers.dev`

3. **Flutter Web Staging Bundle Compilation**:
   - Compiled release bundle with staging dart-defines:
     - `API_BASE_URL=https://schoolic-api-staging.schoolic-api.workers.dev`
     - `NEON_AUTH_URL=https://ep-billowing-shadow-b56k9cl2.neonauth.c-7.us-east-2.aws.neon.tech/neondb`
   - Output: `apps/flutter_app/build/web_staging`

4. **Cloudflare Pages Staging Deployment**:
   - Preview deployment: `https://25840539.schoolic-staging.pages.dev`
   - Canonical staging site: `https://schoolic-staging.pages.dev`

---

## Live Browser Verification & Visual Evidence

- **Admin Admissions Pipeline (Phase 8.5)**:
  - Verified live at `/#/admin` -> Admissions tab.
  - Interactive pipeline stage tabs, application intake form, document checklist, and metrics cards.
  - Artifact: `deployed_admin_admissions_1791899333075.png`.

- **Admin Fees & Finance (Phase 8.4)**:
  - Verified live at `/#/admin` -> Fees tab.
  - Fee structures table, student fee allocations, payment recording modal, and collections metrics.
  - Artifact: `deployed_admin_fees_1791899350162.png`.

- **Admin Exams & Grading (Phase 8.3)**:
  - Verified live at `/#/admin` -> Exams tab.
  - Exam creation, schedules, grading system configuration, marks entry register.
  - Artifact: `deployed_admin_exams_1791899368179.png`.

- **Teacher Homework & Assignments (Phase 8.0)**:
  - Authenticated as `teacher-login@portfolio.schoolic.test` / `[REDACTED]`.
  - Verified live at `/#/teacher` -> Homework navigation tab.
  - Assignment form with class selector (`=Stage Class A • Mathematics`), due date, estimated minutes, status, title, instructions, and list container.
  - Artifact: `deployed_teacher_homework_1791899976451.png`.

- **Role-Based Portal Routing & Auth Guards (Phase 8.2)**:
  - Tested routing to `/#/portal`: strictly guarded by role; unauthenticated users redirect to login, teacher/admin users redirect to their respective workspaces.

---

## Automated Test Suite
- `pnpm api:typecheck`: PASS (0 errors).
- `pnpm api:test`: PASS (4 test files, 54 tests passing).
- `cd apps/flutter_app && flutter test`: PASS (3 test suites, 46 tests passing).

---

## Production Isolation Guarantee
- All migrations and operations executed solely against isolated staging Neon project `nameless-dust-81736720` and staging Worker `schoolic-api-staging`.
- Zero changes, deployments, or database writes made to production (`dark-frost-36120929`, `schoolic-api`, `schoolic.pages.dev`).

