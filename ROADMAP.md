# Schoolic: Comprehensive Product Roadmap & Phased Execution Plan

Schoolic already covers the core: attendance, timetable, homework, exams, fees with Cashfree, admissions, multi-role portal, and AI insights. This roadmap organizes all upcoming improvements, compliance needs, enterprise differentiators, and features into sequential, production-ready phases.

---

## Current Status & Git Baseline

* **Repository Health:**
  * Backend API (`vitest`): 112/113 tests passing (112 passed, 1 live gateway test skipped when unconfigured).
  * Backend Typecheck (`tsc --noEmit`): 0 errors.
  * Flutter App (`flutter analyze`): 0 issues found.
  * Flutter Test Suite (`flutter test`): 75/75 tests passing.
* **Process Status:**
  * **Phase 9 (Foundation Fixes, R2 Storage & Production Hardening):** Fully completed.
  * **Phase 10 (Institutional Onboarding & High-Impact Communication):** Fully completed.
  * **Phase 11 (Enterprise Roles, DPDP Compliance & Financial Depth):** Fully completed.
  * **Phase 12 (School Operations & Daily Differentiators):** Fully completed.
  * **Phase 13 (Academic Depth, Regional Languages & Offline App):** Ready to execute.

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

## Phase 13: Academic Depth, Regional Languages & Offline App

> **Focus:** Curriculum alignment for Indian educational boards, localization, and low-connectivity resilience.

### Deliverables:
1. **Board-Specific Grading Schemes:**
   - Configurable evaluation frameworks:
     - **CBSE:** Periodic tests, Subject Enrichment, Multiple Assessments, Term-end exams.
     - **ICSE:** Internal assessments + external board weightages.
     - **State Boards:** Continuous and Comprehensive Evaluation (CCE) standards.
   - Board-specific report card templates ready for single-click bulk PDF printing.
2. **Regional Language Localization:**
   - Multilingual support for Parent and Student portals:
     - English (default)
     - Kannada (ಕನ್ನಡ)
     - Hindi (हिन्दी)
   - Dynamic locale switcher with RTL/LTR and cultural date formatting.
3. **Offline-First Attendance for Mobile App:**
   - Local SQLite / Hive storage cache on Android and iOS.
   - Offline register marking with automatic background synchronization when connectivity resumes.
   - Conflict resolution for simultaneous attendance edits.

---

## Phase 14: Applied AI & Enhanced Institutional UX

> **Focus:** High-value predictive insights and keyboard-first power tools for staff.

### Deliverables:
1. **Student At-Risk Early Warning System:**
   - Anonymized algorithmic risk indicator combining attendance drops, declining marks, and fee payment stress.
   - Proactive alert banner on Class Teacher dashboard for early intervention.
2. **Natural Language Admin Analytics:**
   - Plain-English administrative queries: *"List fee defaulters in Grade 7 above ₹5,000"* or *"Classes with attendance under 85% this month"*.
   - Read-only parameterized query execution over Neon Postgres with zero prompt leakage.
3. **AI Drafting for Teachers:**
   - Automated report card remarks draft based on attendance and term performance, fully editable by teachers.
   - Rubric-guided homework feedback suggestions.
4. **Power UX & Navigation:**
   - Global Command Palette (`Cmd/Ctrl + K`) for instant search across students, staff, receipts, and applications.
   - Bulk table operations (multi-select for fee reminders, status updates, or exports).
   - Undo capability for non-permanent actions.
   - Parent "Today" dashboard: Unified single-screen timeline per child with instant child switcher.
   - Accessibility compliance pass (WCAG AA contrast audit, focus ring indicators).

---

## Phase 15: Campus Operations Ecosystem (Future Expansion)

> **Focus:** Full institutional enterprise ERP modules.

### Deliverables:
1. **Library Management:** Cataloging, barcode/QR check-out, fine calculations, and book reservation.
2. **Inventory & Asset Management:** Lab equipment, sports gear, classroom assets, and procurement tracking.
3. **Staff Payroll:** Salary structures, deductions (PF/ESI/TDS), payslip PDF generation, and payout tracking.
4. **Hostel & Visitor Management:** Room allocation, mess fees, visitor gate passes with photo capture.
5. **Health & Medical Records:** Encrypted immunization tracking, allergies, campus infirmary visit log with strict confidentiality access policies.

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
