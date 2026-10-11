# Schoolic Product Roadmap

Last updated: October 11, 2026

## Current Status

Phase 5.1 authentication is complete and deployed to production.

- Fully implemented and tested: production Neon Auth, trusted production frontend domain, production Worker auth configuration, production Flutter auth configuration, real admin and teacher auth identities mapped to `app_users`, role-based smoke tests, invalid-session rejection, and blocked production development-bypass headers.
- Implemented and deployed: default-domain production frontend and API.
- Completed and verified on staging: Phase 5.2 Product UX Redesign.
- Completed and verified on staging: Phase 5.3 Timetable & Daily Schedule.
- Planned later: homework, academic results, announcements/calendar, and fee management.

## Phase 5.2: Product UX Redesign

Goal: make the existing administrator and teacher interfaces feel like precise operational workspaces while preserving Schoolic's monochrome Switzer design system.

Scope & Deliverables:

- Redesigned administrator overview with typographic statistics, dynamic operational attention items, recent attendance records, and quick actions.
- Rebuilt teacher workspace from the ground up: My Day (daily teaching briefing and pending attendance alerts), My Classes (assigned classes with rosters), and Attendance Register (efficient roll call, real-time counters, bulk marking, verified persistence).
- Established reusable component library in `lib/src/features/shared/components/` (PageHeader, StatStrip, StatusBadge, AttendanceStatusGroup, AppTable, FeedbackBanner, AppDialog, EmptyStateView).
- Polished authentication screen with Switzer typography and keyboard accessibility.
- Deployed and verified on staging (`https://schoolic-staging.pages.dev`).

Status: Complete (deployed to staging, verified with synthetic data; production preserved).

## Phase 5.3: Timetable

Goal: implement a persisted timetable feature across database, API, and Flutter.

Administrator capabilities:

- Define timetable periods.
- Schedule class, section, subject, and teacher combinations by day.
- Review timetables by class and teacher.
- Detect teacher overlaps and class/section schedule conflicts server-side.
- Edit and remove timetable entries safely.

Teacher capabilities:

- View today's schedule.
- View a weekly timetable.
- Open scheduled classes directly.
- Start attendance from the relevant scheduled period.

Required implementation:

- Drizzle schema and migration.
- Validated Hono API routes.
- Repository-layer conflict detection.
- API tests for successful scheduling, conflict rejection, RBAC, and teacher visibility.
- Flutter admin scheduling UI.
- Flutter teacher daily and weekly timetable views.
- Synthetic staging and production portfolio timetable data after migration verification.

Status: Complete on staging. Production migration and deployment intentionally pending explicit approval.

## Later Feature Priorities

1. Homework and assignments: teacher-created assignments for assigned classes with due dates and status.
2. Examinations and results: exams, subject marks, validation, class summaries, and student academic history.
3. Announcements and school calendar: announcements, academic dates, events, and simple read states where identity supports them.
4. Fee management: fee structures, student fee assignments, payment records, outstanding balances, and synthetic portfolio transactions.

## Guardrails

- Preserve production and staging separation.
- Keep Hostinger DNS, nameservers, and custom-domain configuration unchanged.
- Do not delete existing school records.
- Do not introduce public demo bypasses or hardcoded production metrics.
- Apply database changes to staging first, verify, then promote to production.
- Do not record credentials, tokens, or database connection strings in source or docs.
