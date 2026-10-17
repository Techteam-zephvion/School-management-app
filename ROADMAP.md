# Schoolic: Comprehensive Product Roadmap & Phased Execution Plan

Schoolic already covers the core: attendance, timetable, homework, exams, fees with Cashfree, admissions, multi-role portal, and AI insights. This roadmap organizes all upcoming improvements, compliance needs, enterprise differentiators, and features into sequential, production-ready phases.

---

## Current Status & Git Baseline

* **Repository Health:**
  * Backend API (`vitest`): 148/149 tests passing (148 passed, 1 live gateway test skipped when unconfigured).
  * Backend Typecheck (`tsc --noEmit`): 0 errors.
  * Flutter App (`flutter analyze`): 0 issues found.
  * Flutter Test Suite (`flutter test`): 106/106 tests passing.
* **Process Status:**
  * **Phase 9 (Foundation Fixes, R2 Storage & Production Hardening):** Fully completed.
  * **Phase 10 (Institutional Onboarding & High-Impact Communication):** Fully completed.
  * **Phase 11 (Enterprise Roles, DPDP Compliance & Financial Depth):** Fully completed.
  * **Phase 12 (School Operations & Daily Differentiators):** Fully completed.
  * **Phase 13 (Academic Depth, Regional Languages & Offline App):** Fully completed.
  * **Phase 14 (Applied AI & Enhanced Institutional UX):** Fully completed.
  * **Phase 15 (Campus Operations Ecosystem):** Fully completed.
  * **Phase 16 (Multi-Campus Federation & Mobile Biometrics):** Fully completed.

---

## Immediate Fixes (Completed)

* [x] **Plaintext Password in Docs:** Redacted hardcoded test passwords in `LAST_UPDATE.md`. Production accounts remain isolated and unexposed.
* [x] **Admission Status Discrepancy:** Standardized across schema, migrations, API, and Flutter frontend to canonical enum: `inquiry` → `applied` → `under_review` → `approved` → `enrolled` (or `rejected`). Obsolete documentation text resolved.
* [x] **API Test Environment Types:** Resolved TypeScript strictness in `CashfreeClient` constructor accepting partial test environments without requiring dummy auth URLs.
* [x] **Cashfree Production Credentials:** Gateway dynamically switches between sandbox and production; production keys configured via Cloudflare Secrets.
* [x] **Admission Documents Storage (Cloudflare R2):** Implemented Cloudflare R2 object storage binding (`DOCUMENTS_BUCKET`), file upload/download/delete API endpoints, schema migration `0011_bright_slyde.sql`, and Flutter file picker UI.

---

## Phase 9: Foundation Fixes, Cloudflare R2 Storage & Production Hardening [COMPLETED]

> **Focus:** Hardening current systems, enabling secure document file uploads, closing security gaps, and preparing Cashfree for live institutional production.

### Deliverables:
1. **Cloudflare R2 Document Storage Engine [COMPLETED]:**
   - Configured R2 bucket binding (`DOCUMENTS_BUCKET`) in `wrangler.jsonc` across development, staging (`schoolic-documents-staging`), and production (`schoolic-documents`).
   - Implemented `DocumentStorage` service with collision-resistant tenant path generation (`schools/{schoolId}/admissions/{applicationId}/{documentId}-{filename}`) and automatic memory fallback for tests/local dev.
   - Database migration `0011_bright_slyde.sql` adding `file_key`, `file_url`, `file_name`, `file_size`, and `mime_type` to `admission_documents`.
   - API endpoints:
     - `POST /api/v1/admin/admissions/applications/:id/documents/:docId/upload` (multipart/raw upload)
     - `GET /api/v1/admin/admissions/applications/:id/documents/:docId/download` (streamed download with proper headers)
     - `DELETE /api/v1/admin/admissions/documents/:id/file` (removes attachment from storage and database)
   - Flutter UI:
     - Integrated `file_picker` in `AdminAdmissionsView` for single-click document file upload.
     - Document checklist item displays filename, file size in KB, view/download button, and remove file button.
2. **Cashfree Production & Webhook Hardening [COMPLETED]:**
   - Environment-driven switch: dynamically toggles between sandbox (`https://sandbox.cashfree.com/pg`) and production (`https://api.cashfree.com/pg`).
   - Webhook replay protection: strict timestamp skew validation (max 5 minutes tolerance) rejecting stale or replayed webhooks.
   - Timing-safe HMAC-SHA256 signature verification.
3. **Security & Technical Hardening [COMPLETED]:**
   - Implemented high-performance sliding window rate limiter middleware (`rateLimiter`).
   - Protected sensitive endpoints:
     - Bootstrap routes (`/api/v1/bootstrap/*`): 10 req/min
     - Cashfree webhooks (`/api/v1/webhooks/*`): 120 req/min
     - Fee payment orders & verification (`/api/v1/portal/fees/orders`, `/api/v1/portal/fees/verify`): 20–30 req/min
   - Verified automated test suite: 7/7 Vitest files passing (65 tests), 57/57 Flutter tests passing.

---

## Phase 10: Institutional Onboarding & High-Impact Communication [COMPLETED]

> **Focus:** Removing school adoption blockers and building essential daily communication channels (WhatsApp, push notifications, and parent-teacher chat).

### Deliverables:
1. **Bulk Data Import & Setup Wizard [COMPLETED]:**
   - Excel / CSV bulk importer for Students, Staff, Classes, and Sections (`/api/v1/admin/imports/preview` & `/api/v1/admin/imports/commit`).
   - Pre-commit data validation preview with inline error correction, Indian phone format validation, duplicate roll number detection.
   - First-run Institutional Onboarding Wizard (`/api/v1/admin/onboarding/status` & `/api/v1/admin/onboarding/wizard`) for atomic creation of Academic Year, Classes, Sections, and setup readiness auditing.
   - Full Flutter UI in `AdminCommunicationsView` with interactive CSV preview table, stats cards, and setup modal dialogs.
2. **Automated Notification Engine (WhatsApp, SMS, Push) [COMPLETED]:**
   - Multi-channel notification dispatcher (`NotificationService`) supporting WhatsApp (Meta Cloud API + dev simulation), SMS, In-App, and Push with fallback delivery logs.
   - Audit trail table (`notifications`) logging delivery status, attempts, error messages, and recipient channels.
   - Automated Absence Alerts (`POST /api/v1/admin/notifications/trigger-absence-alerts`) auto-formatting student attendance registers and dispatching to parents.
   - Automated Pending Fee Reminders (`POST /api/v1/admin/notifications/trigger-fee-reminders`) identifying upcoming and overdue fee allocations.
   - In-app notification inbox for Parent/Student portal (`/api/v1/portal/notifications`).
3. **Parent-Teacher Moderated Messaging [COMPLETED]:**
   - In-app asynchronous messaging channels (`chat_conversations`, `chat_messages`) connecting parents with assigned teachers.
   - Teacher availability hours setting (`teacher_availability_settings`) with day-of-week and time-range protection.
   - Automatic out-of-hours auto-reply generation when parent reaches out outside working hours.
   - Moderated chat thread UI in `TeacherMessagesView` and portal client methods with full verification suite (63 Flutter tests passing).

---

## Phase 11: Enterprise Roles, DPDP Compliance & Financial Depth [COMPLETED]

> **Status: COMPLETED & FULLY VERIFIED (100%)**
> - **Backend:** Granular RBAC (`accountant`, `admissions_officer`, `principal`), section class-teacher assignments, DPDP 2023 tables (`dpdp_consents`, `audit_logs`, `data_subject_requests`), automated PII anonymization on erasure, fee concessions/scholarships, refunds ledger, fee structure heads, late fee calculation helper.
> - **Frontend (Flutter):** `AdminComplianceView` with parental consent capture, DSR resolution modals, audit trail explorer, `AdminFeesView` with Concessions and Refunds tabs & creation dialogs, `AppRole` & `AuthSession` role helpers.
> - **Verification:** 10 backend test files passing (95 passed, 1 skipped), 0 TypeScript errors (`pnpm api:typecheck`), 71/71 Flutter unit/widget tests passing (`flutter test`), 0 analyzer issues (`flutter analyze`).

### Deliverables:
1. **Granular Institutional RBAC:**
   - Expanded roles beyond admin/teacher/student/parent:
     - `Accountant`: Dedicated fee allocation, payment collection, receipt issuing, and financial reconciliation access only.
     - `Admissions Officer`: Pipeline, inquiries, document verification, and enrollment workflows only.
     - `Principal`: Global read-only visibility across academics, finance, and attendance.
     - `Class Teacher` vs. `Subject Teacher` distinction: Section model designated with `classTeacherStaffId`.
2. **DPDP Act 2023 (Digital Personal Data Protection) Compliance:**
   - Verifiable parental consent capture for minors under 18 during student enrollment with digital and offline verification tags.
   - Comprehensive Immutable Audit Log (`audit_logs` table): tracks who created, edited, resolved, or accessed student/financial records.
   - Data Subject Rights portal: Automated requests for personal data access and student data erasure/anonymization upon transfer.
3. **Advanced Institutional Fee Management:**
   - Concessions, merit scholarships, and sibling discounts linked to fee structures (`fee_concessions`, `student_fee_concessions`).
   - Automated late fee calculation engine with grace periods and daily/flat penalties (`calculateLateFee`).
   - Official refund recording and status transitions ledger (`fee_refunds`).
   - Head-wise fee breakdown (`fee_structure_heads`: Tuition, Transport, Lab, Examination, etc.).

---

## Phase 12: School Operations & Daily Differentiators [COMPLETED]

> **Status: COMPLETED & FULLY VERIFIED (100%)**
> - **Backend:** Leave management for students and staff with timetable substitute suggestion engine (`suggestStaffLeaveSubstitutes`), school transport management (vehicles, drivers, routes, stops, student transport allocations, live checkpoint logs), verifiable official certificate generator (Transfer Certificate, Bonafide, Conduct) with public verification codes, public inquiries and school profile feeding into admissions with RTE/caste metadata, and institutional calendar & PTM time-slot reservation system.
> - **Frontend (Flutter):** `AdminOperationsView` with 4 operational tabs (Leaves & Substitutes, Transport Fleet, Official Certificates, Calendar & PTM), action modals for leave review, vehicle/route registration, certificate issuance, and PTM slot generation.
> - **Verification:** 11 backend test files passing (112 passed, 1 skipped), 0 TypeScript errors (`tsc --noEmit`), 75/75 Flutter tests passing (`flutter test`), 0 analyzer issues (`flutter analyze`).

### Deliverables:
1. **Student & Staff Leave Management:**
   - Parent portal leave application with reason, medical attachment, and teacher approval flow.
   - Staff leave management with automated timetable substitute suggestions (leveraging existing timetable conflict detection).
2. **School Transport Management:**
   - Route and stop definition with pickup/drop timings.
   - Vehicle and driver assignment.
   - Student bus allocation linked to optional transport fee heads.
   - Real-time / checkpoint transport status for parents in mobile app.
3. **Official PDF Certificate Generator:**
   - Standardized automated PDF generators:
     - Transfer Certificate (TC) with serial tracking and counter-signature fields.
     - Bonafide Certificate.
     - Character & Conduct Certificate.
   - Digital verification QR code printed on certificates.
4. **Public Inquiry & Admission Landing Page:**
   - High-performance, SEO-optimized lightweight web form feeding directly into Schoolic Admissions pipeline.
   - Right to Education (RTE) quota tracking and government reporting categories.
5. **School Calendar & PTM Scheduling:**
   - Master institutional calendar (holidays, exams, sports days).
   - Parent-Teacher Meeting (PTM) time slot reservation system for parents.

---

## Phase 13: Academic Depth, Regional Languages & Offline App [COMPLETED]

> **Status: COMPLETED & FULLY VERIFIED (100%)**
> - **Backend:** Board-specific grading schemes engine (CBSE 9-point scale A1-E, ICSE 1-9 scale, State Board CCE FA1-FA4 / SA1-SA2), scholastic & co-scholastic marks aggregation, automatic grade point resolution, bulk report card generator (`generateReportCards`), portal publication workflows, and offline attendance batch sync endpoint with conflict tracking (`syncOfflineAttendance`).
> - **Frontend (Flutter):** Tri-lingual localization engine (`en`, `kn` - ಕನ್ನಡ, `hi` - हिन्दी) with `LanguagePickerDropdown` (compact and standard formats), offline-first attendance persistent cache (`OfflineAttendanceNotifier`) with auto-sync fallback in teacher register, official printable board report card PDF generator (`buildReportCardPdf`) with branding and signatures, enhanced `AdminExamsView` with 3 subtabs (Exams Schedule, Board Schemes & Scales, Official Report Cards), and student/parent portal report card view with instant PDF download.
> - **Verification:** 12 backend test files passing (122 passed, 1 skipped), 0 TypeScript errors (`tsc --noEmit`), 84/84 Flutter tests passing (`flutter test`), 0 analyzer issues (`flutter analyze`).

### Deliverables:
1. **Board-Specific Grading Schemes & Aggregation:**
   - Pre-configured frameworks for CBSE, ICSE, and State Boards with custom passing criteria and letter grade boundaries.
   - Component-wise assessment weightages (Periodic tests, subject enrichment, portfolios, term exams).
   - Single-click bulk report card generator calculating aggregate marks, board letter grades, grade points, attendance rate, and promotion status.
2. **Regional Language Localization:**
   - Trilingual UI support across English, Kannada (ಕನ್ನಡ), and Hindi (हिन्दी) covering all portals.
   - Dynamic in-app locale switcher (`LanguagePickerDropdown`) with persistent user preference storage.
3. **Offline-First Attendance:**
   - Local persistent queue cache (`SharedPreferences`) on mobile and desktop platforms.
   - Offline register marking with automatic offline fallback when connectivity drops.
   - Batch synchronization endpoint (`/api/v1/teacher/attendance/sync`) with upsert logic, version checks, and conflict audit logging.
4. **Official Board Report Card PDF Generator:**
   - Publication-quality printable PDF generator (`pdf` / `printing` engines) formatted according to Indian education board guidelines with institutional branding, scholastic table, co-scholastic grades, remarks, and tri-signature footer.

---

## Phase 14: Applied AI & Enhanced Institutional UX [COMPLETED]

> **Status: COMPLETED & FULLY VERIFIED (100%)**
> - **Backend:** Multi-factor Student At-Risk Early Warning System (`student_risk_alerts` table, composite score 0-100, attendance/academic/fee factors, intervention logger), Natural Language Admin Analytics query engine with parameterized Neon Postgres execution and zero prompt leakage (`nl_analytics_queries`), AI report card remarks assistant (tone selector: encouraging, constructive, formal), and rubric-guided homework feedback generator.
> - **Frontend (Flutter):** Global Command Palette dialog (`CommandPaletteDialog` with `Cmd/Ctrl + K` global shortcut), quick action button in Admin and Teacher dashboard top bars, tri-tab `AdminInsightsView` (At-Risk Early Warning, Natural Language Queries, Attendance AI Synthesis), teacher AI drafting dialogs (`AiDraftRemarksDialog`, `AiHomeworkFeedbackDialog`), `StatusBadge.riskLevel`.
> - **Verification:** 13 backend Vitest files passing (132 passed, 1 skipped), 0 TypeScript errors (`npm run typecheck`), 91/91 Flutter tests passing (`flutter test`), 0 analyzer issues (`flutter analyze`).

### Deliverables:
1. **Student At-Risk Early Warning System [COMPLETED]:**
   - Anonymized algorithmic risk indicator combining attendance drops (< 75% or consecutive absences), failing marks (< 35% or subject failures), and fee payment arrears.
   - Proactive alert cards on Admin Insights and Class Teacher dashboard with composite risk score (0-100), factor tags, and intervention log dialog.
2. **Natural Language Admin Analytics [COMPLETED]:**
   - Plain-English administrative queries: *"List fee defaulters above ₹5,000"*, *"Classes with attendance under 85%"*, *"Academic toppers in Class 10"*, *"Staff on leave with suggested substitutes"*, and *"Cohort enrollment strength"*.
   - Read-only parameterized query execution over Neon Postgres with zero prompt leakage, structured tabular output, explanation banner, and suggested follow-ups.
3. **AI Drafting for Teachers [COMPLETED]:**
   - Automated report card remarks draft based on attendance and term performance, with tone selector (encouraging, constructive, formal) and 3 variations.
   - Rubric-guided homework feedback suggestions based on score percentage and evaluation criteria.
4. **Power UX & Navigation [COMPLETED]:**
   - Global Command Palette (`Cmd/Ctrl + K`) for instant search across navigation views, administrative tools, and academic actions.
   - Top bar Quick Actions button across Admin and Teacher dashboards.
   - Accessibility compliance pass with responsive keyboard navigation and status badges.

---

## Phase 15: Campus Operations Ecosystem [COMPLETED]

> **Status: COMPLETED & FULLY VERIFIED (100%)**
> - **Backend:** Full enterprise ERP schema & migration `0017_polite_wilson_fisk.sql` (11 tables: `library_books`, `book_loans`, `book_reservations`, `inventory_items`, `asset_allocations`, `purchase_requisitions`, `staff_salary_structures`, `payroll_runs`, `hostel_rooms`, `visitor_gate_passes`, `infirmary_visits`, student medical profiles on `students`). 24 repository methods, 24 admin endpoints mounted with role-based auth (supporting admin and accountant).
> - **Frontend (Flutter):** `AdminCampusView` with 5 dedicated operational subtabs (Library, Inventory & Assets, Staff Payroll, Hostel & Gate Passes, Student Health & Infirmary) featuring live stat strips, data tables with pagination/filters, and interactive create/action dialogs. Integrated with `AdminDashboard` navigation, `CommandPaletteDialog` (`nav:campus` + quick actions), and custom `StatusBadge` formatters for payroll statuses and asset conditions.
> - **Verification:** 14 backend Vitest files passing (141 passed, 1 skipped), 0 TypeScript errors (`npm run typecheck`), 98/98 Flutter tests passing (`flutter test`), 0 analyzer issues (`flutter analyze`).

### Deliverables:
1. **Library & Circulation Management [COMPLETED]:**
   - Book cataloging (ISBN, title, author, category, total copies, available copies, shelf location).
   - Book checkout & return engine with due dates, late return calculations (₹5/day default fine rate), and automatic stock counter adjustments.
   - Advance book reservations queue with auto-fulfillment on return.
2. **Inventory & Asset Management [COMPLETED]:**
   - Multi-category asset ledger (Lab, Sports, Classroom, IT, Furniture, Consumables) with asset tags, serial numbers, condition tracking (`new`, `good`, `fair`, `maintenance_required`, `under_repair`, `damaged`, `disposed`), and purchase values.
   - Staff asset allocation and return workflows.
   - Purchase requisitions workflow (`draft` → `pending_approval` → `approved` → `rejected` → `ordered` → `received`) with estimated cost tracking.
3. **Staff Compensation & Payroll Runs [COMPLETED]:**
   - Granular salary structures (basic, HRA, special allowances, statutory PF/ESI/TDS deductions, net pay calculation).
   - Monthly batch payroll generator for entire active staff rosters.
   - Payout recording (`approved` → `paid` / `voided`) with payment mode, transaction reference, and disbursement timestamp.
4. **Hostel & Security Gate Pass Management [COMPLETED]:**
   - Hostel block & room management (room type, capacity, current occupancy, term fees).
   - Real-time visitor gate pass ledger (visitor name, phone, purpose, badge number, entry timestamp, checkout timestamp, status tracking).
5. **Student Health & Campus Infirmary [COMPLETED]:**
   - Confidential student medical emergency profiles (blood group, allergies, chronic conditions, emergency contact phones, doctor notes).
   - Daily infirmary triage log (symptoms, treatment administered, attending staff, parent notification status, follow-up flags).

---

## Phase 16: Multi-Campus Federation & Enterprise Biometrics [COMPLETED]

> **Status: COMPLETED & FULLY VERIFIED (100%)**
> - **Backend:** Enterprise trust schema & migration `0018_cute_gargoyle.sql` (9 tables: `educational_trusts`, `campus_transfers`, `biometric_devices`, `biometric_punch_logs`, `course_outcomes`, `exam_questions`, `alumni_profiles`, `transcript_requests`, plus `trust_id` foreign key on `schools`). 20 repository methods with strict optional typing, 20 admin API endpoints mounted with role-based auth (supporting admin and accountant).
> - **Frontend (Flutter):** `AdminFederationView` with 4 operational subtabs (Trust Federation & Campuses, Hardware Biometrics & Gates, Outcome-Based Education, Alumni & Transcripts) featuring live stat strips, responsive campus/device cards, cognitive taxonomy question bank table, and interactive create/action dialogs. Integrated with `AdminDashboard` navigation, `CommandPaletteDialog` (`nav:federation` + quick actions), and custom `StatusBadge` formatters for device statuses, transfer statuses, Bloom taxonomy levels, and transcript states.
> - **Verification:** 15 backend Vitest files passing (148 passed, 1 skipped), 0 TypeScript errors (`npm run typecheck`), 106/106 Flutter tests passing (`flutter test`), 0 analyzer issues (`flutter analyze`).

### Deliverables:
1. **Multi-Campus Trust Federation [COMPLETED]:**
   - Multi-branch educational trust hierarchy (`educationalTrusts`, `schools.trustId`).
   - Inter-campus student and staff transfer workflow (`campusTransfers`) with approval/rejection audit trail.
   - Centralized group reporting: consolidated student count, staff headcount, and cross-campus tuition fees collected/pending.
2. **Hardware Biometrics & Turnstiles [COMPLETED]:**
   - Terminals registry (`biometricDevices`) for facial recognition, fingerprint scanners, and RFID turnstiles.
   - Heartbeat ping mechanism with device status transitions (`online`, `offline`, `maintenance`, `decommissioned`).
   - Raw punch log streaming (`biometricPunchLogs`) with real-time ingress tracking and automated daily attendance reconciliation engine.
3. **Outcome-Based Education (OBE) & Assessment [COMPLETED]:**
   - Course Outcomes matrix (`courseOutcomes`) with Bloom's taxonomy cognitive levels (`remember`, `understand`, `apply`, `analyze`, `evaluate`, `create`) and target attainment percentages.
   - Bloom-tagged exam questions bank (`examQuestions`) with question types, marks, difficulty, and CO mappings.
   - Blueprinted exam paper generator synthesizing questions adhering to customizable cognitive distribution.
4. **Alumni Association & Transcripts [COMPLETED]:**
   - Graduating cohort directory (`alumniProfiles`) with current company, designation, and career mentorship availability flag.
   - Official transcript and migration certificate request ledger (`transcriptRequests`) with fulfillment state machine (`submitted` → `processing` → `ready` → `dispatched` / `rejected`).

---

## Summary Matrix of Phases

| Phase | Title | Primary Beneficiaries | Key Differentiators |
|---|---|---|---|
| **Phase 9** | Foundation Fixes, R2 Storage & Production Hardening | Admin, IT, Parents | Cloudflare R2 file uploads, Cashfree production & idempotency, rate limiting |
| **Phase 10** | Institutional Onboarding & Notifications | Admin, Teachers, Parents | Bulk Excel import wizard, automated WhatsApp/SMS absence & fee alerts, parent chat |
| **Phase 11** | Enterprise Roles, DPDP Compliance & Fees Depth | Principal, Accountant, Legal | Accountant & Admissions roles, DPDP 2023 compliance audit log, concessions & refunds |
| **Phase 12** | School Operations & Daily Differentiators | Staff, Parents, Admin | Leave & substitute suggestions, school bus routes, official TC/Bonafide PDFs |
| **Phase 13** | Academic Depth, Localization & Offline App | Teachers, Parents | CBSE/ICSE grading schemes, Kannada & Hindi UI, offline-first attendance |
| **Phase 14** | Applied AI & Enhanced Institutional UX | Teachers, Leadership | Early-warning student flags, NL queries, Command Palette, parent "Today" view |
| **Phase 15** | Campus Operations Ecosystem | Entire Campus | Library, inventory, payroll, hostel, visitor gate pass |
| **Phase 16** | Multi-Campus Federation & Biometrics | Trust Management, Security | Multi-branch consolidation, biometric turnstile sync, alumni network |
