# Schoolic Feature Completeness Audit

**Audit date:** 20 October 2026  
**Scope:** Flutter application, API routes, API client bindings, in-app documentation, `ROADMAP.md`, and `LAST_UPDATE.md`  
**Method:** Static code trace from documented user journey → visible navigation/screen → Flutter API call → server route. The supplied staging screenshot was used to confirm the Homework-screen finding.

## Remediation update — 20 October 2026

All **31 confirmed findings are implemented in the working tree**. Local verification is complete; staging deployment and production-like smoke testing remain separate release steps.

| Result | Count |
|---|---:|
| Resolved in Flutter UI and/or API contract | 31 |
| Remaining confirmed implementation gaps | 0 |
| Deployed to staging | 31 |
| Role-authenticated end-to-end smoke verification pending | 31 |

Staging release:

- API Worker version: `7fb53f10-01f1-44fd-98b8-f81447a2bd73`
- Pages deployment: `https://f292ae02.schoolic-staging.pages.dev`
- Canonical staging site: `https://schoolic-staging.pages.dev`
- Database migration 0019 applied to Neon project `schoolic-staging`, branch `main`, after recovery snapshot `snap-hidden-cake-b568pa3s`.
- Health, canonical/preview HTTP responses, CORS, and login-page rendering were smoke-tested successfully.

Resolution coverage:

- **F-01:** Homework cards now open a submission roster with status filters, response/attachment review, marks, editable feedback, and optional AI feedback drafting.
- **F-02–F-15:** A role-aware Services workspace was added to the parent/student portal and an Operations workspace to the teacher dashboard, covering messaging, notifications, privacy requests, leave, calendars, PTM, transport, certificates, report cards, and at-risk interventions.
- **F-16–F-19:** Admin assignment and fee screens now support class-teacher assignment, student concessions, refund lifecycle updates, and fee-head management.
- **F-20–F-26:** Admin operations now cover the transport lifecycle, custom grading and offline-sync logs, inventory allocation/return, purchase requisitions, hostel allocation/vacation, and health profiles.
- **F-27–F-29:** Federation and leave operations now support trust linking, alumni editing, and persisted substitute assignment with an in-app teacher notification and audit event. Migration `0019_steep_risque.sql` adds substitute-assignment persistence.
- **F-30–F-31:** Certificate issue/revoke and exam editing now use the server’s correct endpoint and HTTP method contracts.

Verification completed after remediation:

- Flutter analyzer: no errors (informational style lints only).
- Flutter test suite: **123 passed**.
- API test suite: **148 passed, 1 skipped**.
- API TypeScript type-check: passed.
- Flutter release web build and WebAssembly dry run: passed.

## Original audit executive summary

Schoolic has broad backend coverage, but several workflows marked complete in the roadmap are not complete from the user's point of view.

| Original classification | Count | Meaning |
|---|---:|---|
| Missing user-facing workflows | 15 | Server capability exists, but the relevant role has no screen/action to use it |
| Partially exposed workflows | 14 | Some screens or read operations exist, but the documented lifecycle cannot be completed |
| Broken visible actions | 2 | A visible UI action calls a route or HTTP method the API does not accept |
| **Total confirmed feature gaps** | **31** | Feature-level findings, not individual missing endpoints or buttons |

The most urgent release blockers are:

1. Teachers cannot open, assess, or return homework submissions.
2. Certificate issue and revoke actions call incorrect API paths/methods.
3. Editing an exam sends `PUT`, while the API only exposes `PATCH`.
4. Parent/student messaging is advertised but has no portal interface.
5. The leave, calendar, and PTM workflows are only complete for administrators; teacher and parent legs are missing.

## What “complete” means in this report

A feature is counted as complete only when the intended user can discover it in their workspace, perform the principal action, receive useful success/error feedback, and observe the saved result. A database table or API route by itself is not counted as a completed product feature.

## Findings

### A. Missing user-facing workflows — 15

| ID | Priority | Persona | Missing workflow | Evidence | Required outcome |
|---|---|---|---|---|---|
| F-01 | Critical | Teacher | Homework submission review and grading | Submission and grade routes exist in `services/api/src/routes/teacher.ts:123-131`, but `teacher_homework_view.dart` only renders Edit/Delete actions | Add submission counts, roster, response/attachment viewer, marks, feedback, reviewed/resubmission states, and refresh handling |
| F-02 | High | Parent/Student | Start and use moderated teacher chat | Portal chat routes and API-client methods exist, but `student_app_view.dart` has no Messages destination and never invokes them | Add conversation list, teacher selection, thread, send state, working-hours notice, and unread state |
| F-03 | Medium | Parent/Student | Notification inbox | `GET /api/v1/portal/notifications` and `getPortalNotifications()` exist but are unused by feature screens | Add notification center with read state, timestamps, deep links, and empty/error states |
| F-04 | High | Parent/Student | DPDP privacy self-service | Portal DSR/consent routes and client methods exist, but no portal screen invokes them | Add consent history and data-access/correction/erasure request submission and tracking |
| F-05 | High | Teacher | Apply for personal leave | `/teacher/my-leaves` GET/POST exists; teacher navigation has no leave screen | Add leave history and application form with validation and status tracking |
| F-06 | High | Parent/Student | Apply for student leave | `/portal/leaves` GET/POST exists; portal has no leave screen | Add student selection, leave form, optional medical document, and approval status |
| F-07 | High | Teacher | Review assigned students’ leave requests | `/teacher/student-leaves` and status update routes exist; teacher workspace has no review queue | Add pending queue, details, approve/reject, notes, and audit metadata |
| F-08 | High | Teacher | View institutional calendar | `/teacher/calendar` exists; teacher navigation has no calendar surface | Add calendar/list views, filtering, and event details |
| F-09 | High | Parent/Student | View institutional calendar | `/portal/calendar` exists; portal navigation has no calendar surface | Add upcoming events, audience filtering, and event details |
| F-10 | High | Parent | Book or cancel a PTM slot | Portal slot/book/cancel routes exist, but no portal screen invokes them | Add available-slot browser, confirmation, booking state, cancellation, and conflict handling |
| F-11 | High | Teacher | View PTM roster and add notes | Teacher PTM slot and notes routes exist, but no teacher screen invokes them | Add schedule/roster, student-parent context, attendance state, and meeting notes |
| F-12 | Medium | Parent/Student | View assigned transport | `/portal/transport` exists, but the portal does not load or display it | Add vehicle, driver, route, stop, pickup/drop time, and emergency contact view |
| F-13 | Medium | Parent/Student | View issued certificates | `/portal/certificates` exists, but the portal does not load or display it | Add certificate list, status, serial/verification code, and downloadable/printable representation |
| F-14 | High | Teacher | Generate and manage report cards | Teacher report-card list/generate routes exist, but the teacher workspace only exposes marks and a standalone AI remarks dialog | Add eligible classes, generation status, per-student review, remarks, and publish/hand-off rules |
| F-15 | High | Teacher | View and act on at-risk students | Teacher at-risk list/intervention routes exist, but no teacher screen invokes them | Add scoped risk list, factor detail, intervention logging, and follow-up status |

### B. Partially exposed workflows — 14

| ID | Priority | Persona | Incomplete workflow | Current state | Missing completion work |
|---|---|---|---|---|---|
| F-16 | High | Admin | Assign a class teacher to a section | API route and `assignSectionClassTeacher()` exist | No UI invokes the assignment action |
| F-17 | High | Admin | Apply concessions to students and inspect applied concessions | Concession definitions can be listed/created | `applyStudentConcession()` and `listStudentConcessions()` are unused |
| F-18 | High | Admin | Approve/process/reject fee refunds | Refunds can be listed and created | `updateFeeRefundStatus()` is unused, leaving the lifecycle incomplete |
| F-19 | Medium | Admin | Configure fee structure heads | API/client support exists | Head listing and creation methods are unused by the fees screen |
| F-20 | High | Admin | Complete transport setup and daily operation | Routes and stops can be created; vehicles, drivers, allocations, and logs are listed | Vehicle/driver creation, student allocation, and trip-log creation actions are absent |
| F-21 | Medium | Admin | Author custom grading schemes | Schemes can be listed and defaults seeded | Custom scheme, scale, and evaluation-component creation methods are unused |
| F-22 | Medium | Admin | Inspect offline attendance sync conflicts | Teacher offline queue and synchronization work | Admin sync-log API/client exists but no screen presents conflicts or audit history |
| F-23 | High | Admin | Allocate and return inventory assets | Items and purchase requests are listed; items can be created | Allocation and return methods are unused |
| F-24 | High | Admin | Create and process purchase requisitions | Requisitions are listed | Create and status-review methods are unused, despite the documented lifecycle |
| F-25 | High | Admin | Allocate and vacate hostel beds | Rooms and allocations are listed; rooms can be created | Allocation and vacate actions are unused |
| F-26 | High | Admin | Maintain student health profiles | Infirmary visits are supported | Health-profile read/upsert methods are unused, so emergency medical context cannot be maintained in UI |
| F-27 | Medium | Admin | Link the current school to an educational trust | Trust creation, campus views, and transfer flows exist | `linkSchoolToTrust()` is unused |
| F-28 | Medium | Admin | Edit alumni profiles | Profiles can be listed and created | `updateAlumniProfile()` is unused |
| F-29 | High | Admin/Teacher | Assign and notify a suggested substitute | Substitute suggestions can be requested and displayed | No assignment/notification API action or UI completion step exists; the documentation overstates the workflow |

### C. Broken visible actions — 2

| ID | Priority | Action | Flutter behavior | API contract | Impact |
|---|---|---|---|---|---|
| F-30 | Critical | Issue/revoke official certificate | Issue calls `POST /admin/certificates`; revoke calls `POST /admin/certificates/:id/revoke` in `api_client.dart:1221-1253` | API requires `POST /admin/certificates/issue` and `PUT /admin/certificates/:id/revoke` in `admin.ts:1126-1148` | Visible certificate actions return route/method errors |
| F-31 | Critical | Edit exam | `admin_exams_view.dart:190-195` sends `PUT /admin/exams/:id` | API exposes `PATCH /admin/exams/:id` in `admin.ts:376-379` | Creating works, but saving edits fails |

## Documentation and roadmap accuracy

The roadmap labels Phases 9–16 as completed, and the in-app documentation describes several end-to-end journeys that are not available end to end.

Confirmed documentation mismatches include:

- “AI Evaluate” and “Publish Review” for homework are described in `docs_data.dart:577-586`, but no submission review surface exists.
- “Message Assigned Teachers” is described in `docs_data.dart:625-629`, but the portal has no messaging navigation or screen.
- “Staff apply for leave” is described in `docs_data.dart:766-770`, but teachers cannot apply from their workspace.
- Parent PTM booking and teacher schedule views are described in `docs_data.dart:881-892`, but only admin PTM management is exposed.
- Substitute assignment and notification are described in `docs_data.dart:772-781`, but only suggestions are implemented.

Until these gaps are resolved, roadmap statuses should distinguish among:

- **Backend complete**
- **Admin UI complete**
- **Cross-role workflow complete**
- **Staging verified**

## Recommended remediation order

### Release gate 1 — repair visible failures

1. F-30 certificate endpoint corrections.
2. F-31 exam edit method correction.
3. Add regression tests that assert Flutter client method/path pairs match server routes.

### Release gate 2 — close the core academic loop

1. F-01 teacher homework submission review and grading.
2. Connect the existing AI homework-feedback assistant to the selected submission as an editable draft.
3. Verify that reviewed marks and feedback appear immediately in the student portal.
4. F-14 teacher report-card workflow and F-15 at-risk intervention surface.

### Release gate 3 — complete cross-role communication

1. F-02 portal messaging and F-03 notifications.
2. F-05–F-07 complete leave workflow.
3. F-08–F-11 complete calendar and PTM workflow.
4. F-04 DPDP self-service.

### Release gate 4 — complete operational lifecycles

Address F-16–F-29 in business-priority order, beginning with fee controls, transport, inventory/procurement, hostel, and health profiles.

## Acceptance criteria for the top three blockers

### F-01 — homework review and grading

**Story:** As a teacher, I want to review each student’s submitted homework and return marks and feedback so that students can understand their performance.

- Given a teacher owns an assignment, when they open it, then they see every enrolled student with Pending, Submitted, Reviewed, or Resubmitted status.
- Given a student submitted text or an attachment, when the teacher opens the submission, then both are available without leaving the assignment context.
- Given valid marks and feedback, when the teacher saves a review, then the submission becomes Reviewed and the student portal shows the result after refresh.
- Given the AI assistant is used, when it returns a suggestion, then the teacher can edit it before saving; AI output is never auto-published.
- Given an unauthorized teacher requests the assignment, then the server rejects access and the UI shows a safe error.
- The workflow must be keyboard accessible and usable at the mobile breakpoint.

### F-30 — certificate actions

**Story:** As an administrator, I expect certificate actions to use the server contract so that certificates can be issued and revoked reliably.

- Issue uses `POST /api/v1/admin/certificates/issue`.
- Revoke uses `PUT /api/v1/admin/certificates/:id/revoke`.
- Successful actions refresh the list and show the resulting status/serial number.
- Validation and API failures display actionable messages.
- API and Flutter tests cover both method/path pairs.

### F-31 — exam editing

**Story:** As an administrator, I want to edit an existing exam so that schedule and configuration corrections are saved.

- Edit uses `PATCH /api/v1/admin/exams/:id`.
- Existing values populate the form without data loss.
- Valid changes persist and appear after reload.
- Invalid max marks/date/status values are rejected with field-level feedback.
- A regression test covers create, edit, reload, and delete.

## Suggested definition of done

A feature should not be marked complete until:

- The intended role can discover and finish the workflow in the UI.
- Authorization is enforced server-side.
- Loading, empty, validation, success, and failure states are present.
- Desktop and phone layouts are verified.
- At least one integration/widget test covers the principal user journey.
- Documentation matches the shipped behavior.
- The workflow is verified on staging with production-like data.

## Limitations

This is a static implementation audit, not a full penetration, accessibility, performance, or production-data audit. Dynamic route construction was manually checked for the principal role workflows, but a staging smoke test should still be run after remediation. The report deliberately counts user-facing capabilities rather than every unused helper or endpoint, so the number is suitable for backlog planning rather than code-coverage measurement.
