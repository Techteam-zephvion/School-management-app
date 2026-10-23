import 'package:flutter/material.dart';

enum DocCategory {
  academics,
  admissions,
  finance,
  campus,
  enterprise,
  aiProductivity,
  portals;

  String get label => switch (this) {
        DocCategory.academics => 'Core Academics',
        DocCategory.admissions => 'Admissions & Students',
        DocCategory.finance => 'Fees & Cashfree Finance',
        DocCategory.campus => 'Campus Operations',
        DocCategory.enterprise => 'Trust Federation & Biometrics',
        DocCategory.aiProductivity => 'Applied AI & Tools',
        DocCategory.portals => 'Portals & Mobile UX',
      };

  IconData get icon => switch (this) {
        DocCategory.academics => Icons.school_outlined,
        DocCategory.admissions => Icons.how_to_reg_outlined,
        DocCategory.finance => Icons.payments_outlined,
        DocCategory.campus => Icons.domain_outlined,
        DocCategory.enterprise => Icons.hub_outlined,
        DocCategory.aiProductivity => Icons.auto_awesome_outlined,
        DocCategory.portals => Icons.devices_outlined,
      };
}

enum DocRole {
  admin,
  teacher,
  student,
  parent,
  accountant,
  principal;

  String get label => switch (this) {
        DocRole.admin => 'Administrator',
        DocRole.teacher => 'Teacher',
        DocRole.student => 'Student',
        DocRole.parent => 'Parent',
        DocRole.accountant => 'Accountant',
        DocRole.principal => 'Principal',
      };
}

class DocStep {
  const DocStep({
    required this.stepNumber,
    required this.title,
    required this.description,
    this.tip,
    this.actionLabel,
    this.screenshotAssetPath,
  });

  final int stepNumber;
  final String title;
  final String description;
  final String? tip;
  final String? actionLabel;
  final String? screenshotAssetPath;
}

class DocScreenshot {
  const DocScreenshot({
    required this.id,
    required this.featureId,
    required this.fileName,
    this.caption,
    this.base64Data,
    this.networkUrl,
    this.assetPath,
    this.uploadedAt,
  });

  final String id;
  final String featureId;
  final String fileName;
  final String? caption;
  final String? base64Data;
  final String? networkUrl;
  final String? assetPath;
  final DateTime? uploadedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'featureId': featureId,
        'fileName': fileName,
        'caption': caption,
        'base64Data': base64Data,
        'networkUrl': networkUrl,
        'assetPath': assetPath,
        'uploadedAt': uploadedAt?.toIso8601String(),
      };

  factory DocScreenshot.fromJson(Map<String, dynamic> json) {
    return DocScreenshot(
      id: json['id'] as String? ?? '',
      featureId: json['featureId'] as String? ?? '',
      fileName: json['fileName'] as String? ?? 'screenshot.png',
      caption: json['caption'] as String?,
      base64Data: json['base64Data'] as String?,
      networkUrl: json['networkUrl'] as String?,
      assetPath: json['assetPath'] as String?,
      uploadedAt: json['uploadedAt'] != null
          ? DateTime.tryParse(json['uploadedAt'] as String)
          : null,
    );
  }
}

class DocFeature {
  const DocFeature({
    required this.id,
    required this.title,
    required this.category,
    required this.roles,
    required this.summary,
    required this.howToUse,
    this.prerequisites = const [],
    this.keyTips = const [],
    this.defaultScreenshots = const [],
    this.adminNavSection,
  });

  final String id;
  final String title;
  final DocCategory category;
  final List<DocRole> roles;
  final String summary;
  final List<DocStep> howToUse;
  final List<String> prerequisites;
  final List<String> keyTips;
  final List<DocScreenshot> defaultScreenshots;
  final String? adminNavSection;
}

class DocsCatalog {
  static final List<DocFeature> features = [
    // 1. Overview & Executive Dashboard
    const DocFeature(
      id: 'overview',
      title: 'Institutional Overview & Command Center',
      category: DocCategory.academics,
      roles: [DocRole.admin, DocRole.principal],
      summary:
          'High-altitude command center aggregating total student headcount, active staff, academic classes, real-time daily attendance rates, and quick action shortcuts across the institution.',
      adminNavSection: 'overview',
      prerequisites: [
        'Active Academic Year configured',
        'Enrolled students and assigned staff',
      ],
      keyTips: [
        'Live sync refreshes metrics automatically in the background every 25 seconds.',
        'Use keyboard shortcut Ctrl+K to jump to any section or trigger quick modals.',
      ],
      defaultScreenshots: [
        DocScreenshot(
          id: 'def_overview_1',
          featureId: 'overview',
          fileName: 'add_student_step1_trigger.png',
          caption: 'Executive Dashboard & Quick Actions Header Strip with "+ Add Student" button',
          assetPath: 'assets/docs/screenshots/add_student_step1_trigger.png',
        ),
      ],
      howToUse: [
        DocStep(
          stepNumber: 1,
          title: 'Navigate to Overview',
          description:
              'Click "Overview" in the left navigation sidebar or press Ctrl+K and search for "Overview".',
        ),
        DocStep(
          stepNumber: 2,
          title: 'Monitor Operational Stat Strips',
          description:
              'Review four primary operational metrics: Total Students, Teaching Staff, Active Classes, and Today\'s Attendance Rate.',
        ),
        DocStep(
          stepNumber: 3,
          title: 'Execute Quick Actions',
          description:
              'Use the top-right action buttons ("Add Student", "Add Staff") for zero-click admissions and onboarding dialogs.',
          screenshotAssetPath: 'assets/docs/screenshots/add_student_step1_trigger.png',
        ),
      ],
    ),

    // 2. Student Enrollment & Records (How to Add Student Step-by-Step)
    const DocFeature(
      id: 'students_enrollment',
      title: 'Student Enrollment & Records (How to Add a Student)',
      category: DocCategory.admissions,
      roles: [DocRole.admin, DocRole.principal, DocRole.teacher],
      summary:
          'Step-by-step visual walkthrough for adding and enrolling new students into Schoolic, assigning unique admission numbers, class sections, roll numbers, and verifying active directory records.',
      adminNavSection: 'students',
      prerequisites: [
        'Academic Class and Section configured (e.g. Class 10 A)',
        'Admin or Principal account privileges',
      ],
      keyTips: [
        'Roll numbers are automatically validated per section to eliminate conflicts.',
        'Enrolled students immediately populate daily attendance registers, fee billing ledgers, and digital ID card generators.',
        'Zero-click shortcut: Press Ctrl+K anywhere in the app and select "Add Student" to launch the dialog immediately.',
      ],
      defaultScreenshots: [
        DocScreenshot(
          id: 'def_add_student_1',
          featureId: 'students_enrollment',
          fileName: 'add_student_step1_trigger.png',
          caption: 'Step 1: Click the "+ Add Student" action button in the top navigation bar',
          assetPath: 'assets/docs/screenshots/add_student_step1_trigger.png',
        ),
        DocScreenshot(
          id: 'def_add_student_2',
          featureId: 'students_enrollment',
          fileName: 'add_student_step2_modal.png',
          caption: 'Step 2: The Add Student modal opens with form fields for enrollment data',
          assetPath: 'assets/docs/screenshots/add_student_step2_modal.png',
        ),
        DocScreenshot(
          id: 'def_add_student_3',
          featureId: 'students_enrollment',
          fileName: 'add_student_step3_filled.png',
          caption: 'Step 3: Enter student demographic, academic, and guardian information',
          assetPath: 'assets/docs/screenshots/add_student_step3_filled.png',
        ),
        DocScreenshot(
          id: 'def_add_student_4',
          featureId: 'students_enrollment',
          fileName: 'add_student_step4_directory.png',
          caption: 'Step 4: Student appears immediately in the active Students Directory',
          assetPath: 'assets/docs/screenshots/add_student_step4_directory.png',
        ),
      ],
      howToUse: [
        DocStep(
          stepNumber: 1,
          title: 'Open the Add Student Dialog',
          description:
              'From anywhere in the Institutional Dashboard or Students Directory, locate the header action strip and click the primary "+ Add Student" button. Alternatively, press keyboard shortcut Ctrl+K and type "Add Student".',
          tip: 'The dialog operates as an overlay so you will never lose your place or uncommitted work in other tabs.',
          actionLabel: '+ Add Student',
          screenshotAssetPath: 'assets/docs/screenshots/add_student_step1_trigger.png',
        ),
        DocStep(
          stepNumber: 2,
          title: 'Review the Enrollment Modal & Required Fields',
          description:
              'The enrollment modal presents all required institutional parameters: Full Name, Admission Identifier, target Class, Section, and assigned Roll Number. Sections dynamically load based on the chosen class.',
          tip: 'Use standard institutional formatting for Admission IDs (e.g. ADM-2026-101).',
          screenshotAssetPath: 'assets/docs/screenshots/add_student_step2_modal.png',
        ),
        DocStep(
          stepNumber: 3,
          title: 'Fill Student Details & Submit Registration',
          description:
              'Input the candidate\'s full name (e.g. Aarav Sharma), admission number, target grade (e.g. Class 10 A), roll number (e.g. 101), and emergency guardian contact phone. Click the black "Add Student" button to persist the record.',
          tip: 'If a duplicate admission number or roll number conflict is detected, an inline validation error is shown immediately.',
          actionLabel: 'Submit Registration',
          screenshotAssetPath: 'assets/docs/screenshots/add_student_step3_filled.png',
        ),
        DocStep(
          stepNumber: 4,
          title: 'Verify Student in Active Directory & Rosters',
          description:
              'Navigate to the Students Directory to confirm the student has been enrolled. Their profile badge shows active enrollment, assigned section, and they are immediately available for daily attendance roll calls, timetable scheduling, and institutional fee invoices.',
          tip: 'Click on the student row in the directory at any time to edit profile data or issue official transfer certificates and ID cards.',
          actionLabel: 'View Directory',
          screenshotAssetPath: 'assets/docs/screenshots/add_student_step4_directory.png',
        ),
      ],
    ),

    // 3. Attendance & Roll Call
    const DocFeature(
      id: 'attendance',
      title: 'Daily Attendance & Absence Alerts',
      category: DocCategory.academics,
      roles: [DocRole.admin, DocRole.teacher],
      summary:
          'Rapid roll call register with one-click "Mark All Present", multi-period attendance tracking, spreadsheet injection-sanitized CSV exports, and automated WhatsApp/SMS absence alerts to guardians.',
      adminNavSection: 'attendance',
      prerequisites: [
        'Students assigned to class sections',
        'Academic timetable period active',
      ],
      keyTips: [
        'Use the bulk "Mark All Present" button, then toggle individual absent students to finish roll call in seconds.',
        'Offline attendance works without active internet connectivity and syncs when reconnected.',
      ],
      defaultScreenshots: [
        DocScreenshot(
          id: 'def_attendance_1',
          featureId: 'attendance',
          fileName: 'attendance_register_overview.png',
          caption: 'Attendance Register with Bulk "Mark All Present" & Status Toggles',
          assetPath: 'assets/docs/screenshots/attendance_register_overview.png',
        ),
      ],
      howToUse: [
        DocStep(
          stepNumber: 1,
          title: 'Select Class & Section',
          description:
              'Choose the target Class and Section from the top filter bar. Pick the attendance date.',
        ),
        DocStep(
          stepNumber: 2,
          title: 'Record Student Statuses',
          description:
              'Click status buttons for each student: Present, Absent, Late, or Excused. Or click "Mark All Present" at top.',
          screenshotAssetPath: 'assets/docs/screenshots/attendance_register_overview.png',
        ),
        DocStep(
          stepNumber: 3,
          title: 'Trigger Automated Alerts',
          description:
              'Click "Notify Absent Guardians" to trigger immediate WhatsApp/SMS notifications for flagged absentees.',
        ),
        DocStep(
          stepNumber: 4,
          title: 'Export Audit Logs',
          description:
              'Click "Export CSV" to download an official sanitized attendance record for compliance records.',
        ),
      ],
    ),

    // 4. Admissions & Pipeline
    const DocFeature(
      id: 'admissions',
      title: 'Admissions Pipeline & Document Verification',
      category: DocCategory.admissions,
      roles: [DocRole.admin, DocRole.principal],
      summary:
          'End-to-end admissions funnel managing inquiries, formal applications, birth certificate/transfer certificate uploads via Cloudflare R2, intake capacity bars, and 1-click student enrollment.',
      adminNavSection: 'admissions',
      prerequisites: [
        'Class intake capacities defined',
        'Academic Year configured',
      ],
      keyTips: [
        'Prospective parents can submit inquiries directly from the public landing page (/schools/:code).',
        'Document uploads accept PDF, PNG, JPG, and Word files up to 25MB with Cloudflare R2 cloud storage.',
      ],
      defaultScreenshots: [
        DocScreenshot(
          id: 'def_admissions_1',
          featureId: 'admissions',
          fileName: 'admissions_pipeline_overview.png',
          caption: 'Admissions Funnel Pipeline with Intake Capacity Tracking',
          assetPath: 'assets/docs/screenshots/admissions_pipeline_overview.png',
        ),
      ],
      howToUse: [
        DocStep(
          stepNumber: 1,
          title: 'Review Prospective Inquiries',
          description:
              'Open the Admissions view to inspect new student inquiries and track class capacity limits.',
          screenshotAssetPath: 'assets/docs/screenshots/admissions_pipeline_overview.png',
        ),
        DocStep(
          stepNumber: 2,
          title: 'Advance Application Lifecycle',
          description:
              'Transition applications through stages: Inquiry -> Applied -> Under Review -> Approved.',
        ),
        DocStep(
          stepNumber: 3,
          title: 'Verify & Upload Documents',
          description:
              'Click on an application, verify Birth Certificate, Transfer Certificate, and Address Proof. Upload digital files using the file picker.',
        ),
        DocStep(
          stepNumber: 4,
          title: 'One-Click Enrollment',
          description:
              'Click "Enroll Student" to generate their institutional Student ID, assign Section, Roll Number, and create their student account.',
        ),
      ],
    ),

    // 5. Fees, Billing & Cashfree Payments
    const DocFeature(
      id: 'fees_cashfree',
      title: 'Fees, Billing & Cashfree Payment Gateway',
      category: DocCategory.finance,
      roles: [DocRole.admin, DocRole.accountant, DocRole.parent, DocRole.student],
      summary:
          'Institutional fee structures (monthly, term, annual), student billing ledgers, Cashfree PG integration (UPI QR, cards, netbanking), instant official PDF receipts (REC-YYYY-XXXXX), concessions, and refunds.',
      adminNavSection: 'fees',
      prerequisites: [
        'Cashfree App ID & Secret Key configured',
        'Fee structure heads defined (Tuition, Transport, Lab, etc.)',
      ],
      keyTips: [
        'Supports both full payments and custom partial installment amounts.',
        'Official receipts feature cryptographic verification and can be printed or saved as vector PDFs.',
      ],
      defaultScreenshots: [
        DocScreenshot(
          id: 'def_fees_1',
          featureId: 'fees_cashfree',
          fileName: 'fees_cashfree_overview.png',
          caption: 'Fee Structures, Billing Ledgers & Cashfree Payment Gateway',
          assetPath: 'assets/docs/screenshots/fees_cashfree_overview.png',
        ),
      ],
      howToUse: [
        DocStep(
          stepNumber: 1,
          title: 'Configure Fee Structures',
          description:
              'Define fee structures with frequency (One-time, Term, Monthly, Annual), due dates, and fee head breakdowns.',
        ),
        DocStep(
          stepNumber: 2,
          title: 'Allocate Fees & Scholarships',
          description:
              'Assign fee structures to classes or individual students. Apply merit concessions, sibling discounts, or scholarships.',
        ),
        DocStep(
          stepNumber: 3,
          title: 'Collect Payments via Cashfree',
          description:
              'Parents and students open their portal fee sheet and pay online via UPI, Credit/Debit card, or Netbanking.',
          screenshotAssetPath: 'assets/docs/screenshots/fees_cashfree_overview.png',
        ),
        DocStep(
          stepNumber: 4,
          title: 'Generate Official Invoices & Receipts',
          description:
              'Instantly generate official institutional receipts with sequential receipt numbering and print/download vector PDFs.',
        ),
      ],
    ),

    // 6. Timetable & Academic Scheduling
    const DocFeature(
      id: 'timetable',
      title: 'Timetable & Academic Scheduling',
      category: DocCategory.academics,
      roles: [DocRole.admin, DocRole.teacher],
      summary:
          'Visual interactive master timetable grid spanning 6 days and up to 8 periods per day, featuring real-time room conflict detection and teacher double-booking prevention.',
      adminNavSection: 'timetable',
      prerequisites: [
        'Class and Section rosters setup',
        'Teaching staff and subjects configured',
      ],
      keyTips: [
        'The scheduling engine automatically blocks saving if a teacher is already booked in another section for that same period.',
      ],
      defaultScreenshots: [
        DocScreenshot(
          id: 'def_timetable_1',
          featureId: 'timetable',
          fileName: 'timetable_grid_overview.png',
          caption: 'Master Timetable Grid with Room and Teacher Conflict Detection',
          assetPath: 'assets/docs/screenshots/timetable_grid_overview.png',
        ),
      ],
      howToUse: [
        DocStep(
          stepNumber: 1,
          title: 'Select Class Schedule',
          description:
              'Pick the target Class and Section to view their weekly timetable schedule grid.',
          screenshotAssetPath: 'assets/docs/screenshots/timetable_grid_overview.png',
        ),
        DocStep(
          stepNumber: 2,
          title: 'Assign Period Slots',
          description:
              'Click any period cell to select the Subject, Teacher, Room Number, and Start/End times.',
        ),
        DocStep(
          stepNumber: 3,
          title: 'Conflict Checking',
          description:
              'The system validates teacher and room availability in real-time, displaying conflict warnings before saving.',
        ),
      ],
    ),

    // 7. Examinations, OBE & Report Cards
    const DocFeature(
      id: 'exams_obe',
      title: 'Examinations, OBE Bloom\'s Taxonomy & Report Cards',
      category: DocCategory.academics,
      roles: [DocRole.admin, DocRole.teacher, DocRole.principal],
      summary:
          'Comprehensive evaluation framework covering multi-term exams, CCE grading scales, Bloom\'s taxonomy question bank (Remember to Create), blueprinted paper generation, marks entry, and official CBSE/State report cards.',
      adminNavSection: 'exams',
      prerequisites: [
        'Exam terms defined with max and passing marks',
        'Course Outcomes (CO-PO) configured',
      ],
      keyTips: [
        'The paper blueprint synthesizer balances question cognitive difficulty to match target percentage targets.',
      ],
      defaultScreenshots: [
        DocScreenshot(
          id: 'def_exams_1',
          featureId: 'exams_obe',
          fileName: 'exams_report_cards.png',
          caption: 'Exams, Gradebooks, Term GPA & Official Vector Report Cards',
          assetPath: 'assets/docs/screenshots/exams_report_cards.png',
        ),
      ],
      howToUse: [
        DocStep(
          stepNumber: 1,
          title: 'Create Exam Term',
          description:
              'Define the examination term, academic year, grading scale, and subject maximum marks.',
          screenshotAssetPath: 'assets/docs/screenshots/exams_report_cards.png',
        ),
        DocStep(
          stepNumber: 2,
          title: 'Build Cognitive Question Bank',
          description:
              'Add questions mapped to Bloom\'s cognitive levels (Remember, Understand, Apply, Analyze, Evaluate, Create).',
        ),
        DocStep(
          stepNumber: 3,
          title: 'Enter Student Marks',
          description:
              'Teachers record marks with real-time validation against maximum thresholds and instant grade computation.',
        ),
        DocStep(
          stepNumber: 4,
          title: 'Generate Official Report Cards',
          description:
              'Click "Generate Report Card" to produce board-compliant printable PDF report cards with teacher remarks.',
        ),
      ],
    ),

    // 7. Homework & AI Copilot
    const DocFeature(
      id: 'homework_ai',
      title: 'Homework Studio & AI Grading Copilot',
      category: DocCategory.aiProductivity,
      roles: [DocRole.teacher, DocRole.student],
      summary:
          'Digital homework composer with due dates and attachments, online student submissions, and AI Copilot providing rubric-based homework scoring and personalized encouraging feedback.',
      prerequisites: [
        'Active teacher assignment to the section',
      ],
      keyTips: [
        'AI Copilot drafts grading suggestions and constructive remarks that teachers can review and edit before sending.',
      ],
      howToUse: [
        DocStep(
          stepNumber: 1,
          title: 'Compose Assignment',
          description:
              'Teachers create homework with title, instructions, subject, submission deadline, and max points.',
        ),
        DocStep(
          stepNumber: 2,
          title: 'Submit Student Work',
          description:
              'Students view homework in their portal, type their response or upload attachments, and submit.',
        ),
        DocStep(
          stepNumber: 3,
          title: 'Run AI Grading Copilot',
          description:
              'Click "AI Evaluate" on a submission to generate draft scores, rubric breakdowns, and helpful feedback.',
        ),
        DocStep(
          stepNumber: 4,
          title: 'Publish Review',
          description:
              'Teachers adjust or approve the feedback and publish marks directly into the student\'s portfolio.',
        ),
      ],
    ),

    // 8. Student & Parent Portal
    const DocFeature(
      id: 'student_parent_portal',
      title: 'Student & Parent Unified Portal',
      category: DocCategory.portals,
      roles: [DocRole.student, DocRole.parent],
      summary:
          'Dedicated self-service portal featuring Digital Student ID cards with dynamic QR codes, live fee balances, online Cashfree checkout, timetable, homework submissions, attendance analytics, and moderated teacher chat.',
      prerequisites: [
        'Enrolled student credentials',
      ],
      keyTips: [
        'Parents can link multiple siblings under one portal account to pay combined fees and track grades.',
      ],
      howToUse: [
        DocStep(
          stepNumber: 1,
          title: 'Digital Student ID Card',
          description:
              'Inspect the official student ID card with student photo, roll number, emergency contact, and enlargable QR code.',
        ),
        DocStep(
          stepNumber: 2,
          title: 'Pay Fees Online',
          description:
              'View allocated fee dues, select installment or full balance, and pay instantly via Cashfree Payment Gateway.',
        ),
        DocStep(
          stepNumber: 3,
          title: 'Check Daily Timetable & Homework',
          description:
              'Review daily period schedule, upcoming assignment deadlines, and download teacher feedback.',
        ),
        DocStep(
          stepNumber: 4,
          title: 'Message Assigned Teachers',
          description:
              'Reach out to class and subject teachers within designated working hours for questions or support.',
        ),
      ],
    ),

    // 9. Teacher Workspace & My Day
    const DocFeature(
      id: 'teacher_workspace',
      title: 'Teacher Workspace & "My Day" Assistant',
      category: DocCategory.academics,
      roles: [DocRole.teacher],
      summary:
          'Optimized educator workspace with "My Day" class countdown timer, quick attendance register, lesson planning, marks entry studio, and AI Report Card remarks drafting.',
      prerequisites: [
        'Teacher account with assigned classes and subjects',
      ],
      keyTips: [
        'The "My Day" strip highlights your current or upcoming class, room number, and time remaining.',
      ],
      howToUse: [
        DocStep(
          stepNumber: 1,
          title: 'Check "My Day" Schedule',
          description:
              'Open Teacher Dashboard to view today\'s period sequence, room assignments, and student counts.',
        ),
        DocStep(
          stepNumber: 2,
          title: 'Take Period Attendance',
          description:
              'Click "Take Attendance" on any scheduled class block to mark students present or absent.',
        ),
        DocStep(
          stepNumber: 3,
          title: 'Draft Report Card Remarks with AI',
          description:
              'Use the AI Remark Assistant to craft personalized, constructive term remarks for students based on their grades.',
        ),
      ],
    ),

    // 10. Institutional Onboarding & Bulk Importer
    const DocFeature(
      id: 'onboarding_importer',
      title: 'Bulk Data Importer & Onboarding Wizard',
      category: DocCategory.aiProductivity,
      roles: [DocRole.admin],
      summary:
          'High-speed Excel and CSV bulk data importer with interactive validation preview, Indian mobile phone format checking, duplicate roll number detection, and first-run school onboarding wizard.',
      adminNavSection: 'communications',
      prerequisites: [
        'CSV/Excel file prepared with student or staff data',
      ],
      keyTips: [
        'The pre-commit validation preview flags errors inline before any database records are created.',
      ],
      howToUse: [
        DocStep(
          stepNumber: 1,
          title: 'Select Import Target',
          description:
              'Choose whether you are importing Students, Teaching Staff, Classes, or Sections.',
        ),
        DocStep(
          stepNumber: 2,
          title: 'Upload Spreadsheet',
          description:
              'Drag and drop or select your CSV or Excel file. The system parses all columns automatically.',
        ),
        DocStep(
          stepNumber: 3,
          title: 'Inspect Validation Preview',
          description:
              'Review detected rows, check for warnings or invalid entries, and fix errors directly.',
        ),
        DocStep(
          stepNumber: 4,
          title: 'Commit Import',
          description:
              'Click "Commit Import" to atomically insert all records into the school database.',
        ),
      ],
    ),

    // 11. DPDP Act 2023 Compliance & Security
    const DocFeature(
      id: 'dpdp_compliance',
      title: 'DPDP Act 2023 Compliance & Audit Logs',
      category: DocCategory.enterprise,
      roles: [DocRole.admin, DocRole.principal],
      summary:
          'Full compliance with the Digital Personal Data Protection Act 2023: verifiable parental consent capture for minors under 18, immutable audit logging, and automated Data Subject Requests (access and erasure).',
      adminNavSection: 'compliance',
      prerequisites: [
        'Administrator role credentials',
      ],
      keyTips: [
        'Erasing student records upon transfer automatically anonymizes PII while preserving aggregate financial reports.',
      ],
      howToUse: [
        DocStep(
          stepNumber: 1,
          title: 'Review Parental Consents',
          description:
              'Monitor digital and offline parental consent statuses for all enrolled minor students.',
        ),
        DocStep(
          stepNumber: 2,
          title: 'Inspect Immutable Audit Trail',
          description:
              'Search and filter the audit log to see exactly who accessed, created, or modified student records.',
        ),
        DocStep(
          stepNumber: 3,
          title: 'Resolve Data Subject Requests',
          description:
              'Process parent requests for data summaries or complete data erasure with full regulatory compliance.',
        ),
      ],
    ),

    // 12. Staff & Student Leaves with Timetable Substitutes
    const DocFeature(
      id: 'leaves_substitutes',
      title: 'Leaves & Intelligent Timetable Substitutes',
      category: DocCategory.campus,
      roles: [DocRole.admin, DocRole.teacher],
      summary:
          'Automated leave application and approval workflow for staff and students, linked directly to an intelligent substitute suggestion engine that finds free teachers during impacted periods.',
      adminNavSection: 'operations',
      prerequisites: [
        'Active master timetable configured',
      ],
      keyTips: [
        'The substitute engine only recommends teachers who have a free period during the exact time slot.',
      ],
      howToUse: [
        DocStep(
          stepNumber: 1,
          title: 'Submit or Review Leave Request',
          description:
              'Staff apply for leave with leave type and dates. Admins review pending leave applications.',
        ),
        DocStep(
          stepNumber: 2,
          title: 'Generate Substitute Suggestions',
          description:
              'Click "Suggest Substitutes" to identify free teachers for each period of the teacher\'s schedule.',
        ),
        DocStep(
          stepNumber: 3,
          title: 'Assign & Notify Substitutes',
          description:
              'Assign the substitute teacher with one click; their "My Day" timetable updates automatically.',
        ),
      ],
    ),

    // 13. Transport Fleet & Route Stops
    const DocFeature(
      id: 'transport_fleet',
      title: 'School Transport Fleet & Route Checkpoints',
      category: DocCategory.campus,
      roles: [DocRole.admin],
      summary:
          'School bus and van fleet tracking with vehicle capacity, driver contact details, route stops, student bus assignments, and live checkpoint ingress/egress logs.',
      adminNavSection: 'operations',
      prerequisites: [
        'Vehicles and driver records entered',
      ],
      keyTips: [
        'Ensure route stop sequences match pickup order for optimized journey duration.',
      ],
      howToUse: [
        DocStep(
          stepNumber: 1,
          title: 'Register Vehicles & Drivers',
          description:
              'Add bus registration numbers, total seating capacity, driver name, and emergency phone numbers.',
        ),
        DocStep(
          stepNumber: 2,
          title: 'Configure Routes & Pickup Stops',
          description:
              'Define bus routes with sequenced stops, morning pickup times, and afternoon drop-off times.',
        ),
        DocStep(
          stepNumber: 3,
          title: 'Assign Enrolled Students',
          description:
              'Map students to specific route stops; transport fee heads link automatically to their fee schedule.',
        ),
      ],
    ),

    // 14. Verifiable Official Digital Certificates
    const DocFeature(
      id: 'official_certificates',
      title: 'Verifiable Official Certificates & QR Verification',
      category: DocCategory.campus,
      roles: [DocRole.admin, DocRole.principal],
      summary:
          'Issue tamper-proof Transfer Certificates (TC), Bonafide Certificates, and Conduct Certificates with cryptographic verification codes and public QR scanning validation.',
      adminNavSection: 'operations',
      prerequisites: [
        'Enrolled or graduating student records',
      ],
      keyTips: [
        'Anyone scanning the QR code on a physical certificate is taken to the public verification page to confirm authenticity.',
      ],
      howToUse: [
        DocStep(
          stepNumber: 1,
          title: 'Select Certificate Type',
          description:
              'Choose Transfer Certificate (TC), Bonafide Certificate, or Character/Conduct Certificate.',
        ),
        DocStep(
          stepNumber: 2,
          title: 'Enter Student Details',
          description:
              'Select the student to auto-populate admission ID, dates of attendance, conduct remarks, and reason for issue.',
        ),
        DocStep(
          stepNumber: 3,
          title: 'Issue & Generate Vector PDF',
          description:
              'Click "Issue Certificate" to generate an official PDF complete with school seal, signature lines, and verification QR code.',
        ),
      ],
    ),

    // 15. School Calendar & PTM Booking
    const DocFeature(
      id: 'calendar_ptm',
      title: 'Academic Calendar & Parent-Teacher Meetings (PTM)',
      category: DocCategory.campus,
      roles: [DocRole.admin, DocRole.teacher, DocRole.parent],
      summary:
          'Institutional event calendar and structured Parent-Teacher Meeting (PTM) time-slot management with parent slot reservation, teacher schedules, and automated reminders.',
      adminNavSection: 'operations',
      prerequisites: [
        'Active academic term',
      ],
      keyTips: [
        'Set 15-minute slot intervals to keep PTM days structured and prevent waiting line bottlenecks.',
      ],
      howToUse: [
        DocStep(
          stepNumber: 1,
          title: 'Schedule PTM Event',
          description:
              'Admins create the PTM date, pick target classes, and set time ranges and slot durations.',
        ),
        DocStep(
          stepNumber: 2,
          title: 'Parents Book Time Slots',
          description:
              'Parents log in to their portal and select their preferred meeting window with the class teacher.',
        ),
        DocStep(
          stepNumber: 3,
          title: 'Teacher Schedule View',
          description:
              'Teachers see their confirmed meeting roster with parent names and student notes.',
        ),
      ],
    ),

    // 16. Campus Library & Circulation
    const DocFeature(
      id: 'library_circulation',
      title: 'Library Catalog & Book Circulation',
      category: DocCategory.campus,
      roles: [DocRole.admin, DocRole.teacher, DocRole.student],
      summary:
          'Comprehensive library management with ISBN indexing, student/staff book checkout, automated late fee calculation (default ₹5/day), shelf location tracking, and book reservation queues.',
      adminNavSection: 'campus',
      prerequisites: [
        'Book titles entered in library catalog',
      ],
      keyTips: [
        'Scan ISBN barcodes directly using a connected barcode reader for rapid book checkouts.',
      ],
      howToUse: [
        DocStep(
          stepNumber: 1,
          title: 'Add Books to Catalog',
          description:
              'Enter ISBN, book title, author, category, total copies, and physical shelf/aisle location.',
        ),
        DocStep(
          stepNumber: 2,
          title: 'Issue Book to Student or Staff',
          description:
              'Click "Issue Book", select the borrower, set the due date, and hand over the book.',
        ),
        DocStep(
          stepNumber: 3,
          title: 'Return Book & Collect Fines',
          description:
              'Upon return, the system checks for late days, calculates fines automatically, and increments available copies.',
        ),
      ],
    ),

    // 17. Inventory, Assets & Procurement
    const DocFeature(
      id: 'inventory_assets',
      title: 'Fixed Assets, Inventory & Requisitions',
      category: DocCategory.campus,
      roles: [DocRole.admin, DocRole.principal],
      summary:
          'Asset tracking across lab equipment, classroom furniture, sports kits, and IT hardware with condition statuses, staff asset checkout, and multi-stage procurement requisition approvals.',
      adminNavSection: 'campus',
      prerequisites: [
        'Asset categories and room locations setup',
      ],
      keyTips: [
        'Filter inventory items by condition ("Maintenance Required" or "Damaged") to plan repairs.',
      ],
      howToUse: [
        DocStep(
          stepNumber: 1,
          title: 'Register Fixed Assets',
          description:
              'Enter asset tag, serial number, category, room location, unit cost, and initial condition.',
        ),
        DocStep(
          stepNumber: 2,
          title: 'Allocate Assets to Staff',
          description:
              'Assign laptops or lab tools to teachers and track return condition upon term completion.',
        ),
        DocStep(
          stepNumber: 3,
          title: 'Manage Procurement Requisitions',
          description:
              'Staff request supplies; leadership reviews estimated costs and approves or rejects requisitions.',
        ),
      ],
    ),

    // 18. Staff Salary & Monthly Payroll
    const DocFeature(
      id: 'staff_payroll',
      title: 'Staff Salary Structures & Payroll Runs',
      category: DocCategory.finance,
      roles: [DocRole.admin, DocRole.accountant],
      summary:
          'Configure detailed staff salary components (Basic Pay, HRA, Special Allowance, statutory PF, ESI, TDS deductions) and run monthly payroll batches with approval workflows and disbursement tracking.',
      adminNavSection: 'campus',
      prerequisites: [
        'Staff members registered in system',
      ],
      keyTips: [
        'Salary runs start in "Draft" state, can be reviewed and approved by leadership, then marked as "Paid".',
      ],
      howToUse: [
        DocStep(
          stepNumber: 1,
          title: 'Define Salary Structures',
          description:
              'Set basic pay, allowances, and statutory deduction percentages for each staff member.',
        ),
        DocStep(
          stepNumber: 2,
          title: 'Execute Monthly Payroll Run',
          description:
              'Select the pay period (e.g. October 2026) and generate draft payroll slips for all active staff.',
        ),
        DocStep(
          stepNumber: 3,
          title: 'Approve & Disburse Salaries',
          description:
              'Review total salary expenditure, approve the batch, record payment mode/transaction reference, and mark as paid.',
        ),
      ],
    ),

    // 19. Hostel Rooms & Visitor Gate Passes
    const DocFeature(
      id: 'hostel_gate_pass',
      title: 'Hostel Rooms & Visitor Gate Passes',
      category: DocCategory.campus,
      roles: [DocRole.admin],
      summary:
          'Campus safety and boarding management: hostel room allocations by room type (Single, Double, Dormitory), bed occupancy tracking, and security gate visitor badge issuance with 1-click check-out.',
      adminNavSection: 'campus',
      prerequisites: [
        'Hostel blocks created',
      ],
      keyTips: [
        'Security guards can record visitor badge numbers and check them out instantly from a mobile or tablet.',
      ],
      howToUse: [
        DocStep(
          stepNumber: 1,
          title: 'Setup Hostel Room Blocks',
          description:
              'Create hostel blocks, room numbers, capacities, and term boarding fees.',
        ),
        DocStep(
          stepNumber: 2,
          title: 'Issue Visitor Gate Pass',
          description:
              'Record visitor name, phone number, person to visit, purpose, and assign a physical gate badge number.',
        ),
        DocStep(
          stepNumber: 3,
          title: 'Check Out Visitors',
          description:
              'Click "Check Out" on the active visitor ledger when the visitor leaves campus to record departure time.',
        ),
      ],
    ),

    // 20. Student Health & Infirmary Triage
    const DocFeature(
      id: 'infirmary_health',
      title: 'Student Health & Infirmary Triage',
      category: DocCategory.campus,
      roles: [DocRole.admin, DocRole.teacher],
      summary:
          'Medical emergency directory with student blood groups, allergies, and chronic conditions, coupled with a daily infirmary visit log for symptoms, treatments, and parent notification flags.',
      adminNavSection: 'campus',
      prerequisites: [
        'Emergency contacts and medical notes entered during admission',
      ],
      keyTips: [
        'Blood groups and allergies are highlighted with high-visibility badges for immediate triage reference.',
      ],
      howToUse: [
        DocStep(
          stepNumber: 1,
          title: 'View Emergency Medical Profiles',
          description:
              'Quickly access blood groups, emergency contact phone numbers, and known allergies for any student.',
        ),
        DocStep(
          stepNumber: 2,
          title: 'Log Infirmary Visit',
          description:
              'Record student visit time, symptoms presented, treatment or medication administered, and attending staff.',
        ),
        DocStep(
          stepNumber: 3,
          title: 'Notify Parents',
          description:
              'Toggle "Parent Notified" and add follow-up notes if the student needs to be picked up from campus.',
        ),
      ],
    ),

    // 21. Multi-Campus Federation
    const DocFeature(
      id: 'campus_federation',
      title: 'Educational Trust Federation & Campus Transfers',
      category: DocCategory.enterprise,
      roles: [DocRole.admin, DocRole.principal],
      summary:
          'Enterprise group architecture linking multiple branch campuses under a parent Educational Trust, featuring consolidated financial analytics, cross-campus statistics, and seamless student/staff transfers.',
      adminNavSection: 'federation',
      prerequisites: [
        'Parent Educational Trust created',
        'Multiple campus school instances linked',
      ],
      keyTips: [
        'Trust executives can view aggregated fee collection and student metrics across all branches in one screen.',
      ],
      defaultScreenshots: [
        DocScreenshot(
          id: 'def_federation_1',
          featureId: 'campus_federation',
          fileName: 'federation_biometrics.png',
          caption: 'Educational Trust Multi-Campus Federation & Hardware Biometrics',
          assetPath: 'assets/docs/screenshots/federation_biometrics.png',
        ),
      ],
      howToUse: [
        DocStep(
          stepNumber: 1,
          title: 'Create or Join Educational Trust',
          description:
              'Register your educational society or trust with registration code, headquarters, and chairman details.',
        ),
        DocStep(
          stepNumber: 2,
          title: 'View Consolidated Group Metrics',
          description:
              'Review total campuses, aggregated student population, combined faculty headcount, and total fees collected.',
          screenshotAssetPath: 'assets/docs/screenshots/federation_biometrics.png',
        ),
        DocStep(
          stepNumber: 3,
          title: 'Initiate Inter-Campus Transfer',
          description:
              'Transfer students or teachers between sister campuses with preserved academic history and fee reconciliations.',
        ),
      ],
    ),

    // 22. Biometrics & Turnstile Terminals
    const DocFeature(
      id: 'biometrics_terminals',
      title: 'Hardware Biometrics & Turnstile Gate Sync',
      category: DocCategory.enterprise,
      roles: [DocRole.admin],
      summary:
          'Gate security and automated attendance integration: manage RFID turnstiles, fingerprint scanners, and facial recognition terminals with live heartbeat pinging, raw punch stream, and 1-click attendance reconciliation.',
      adminNavSection: 'federation',
      prerequisites: [
        'Supported biometric device (ZKTeco, Essl, or RFID turnstile) connected to network',
      ],
      keyTips: [
        'Click "Reconcile Attendance" to automatically convert morning turnstile punches into verified classroom attendance records.',
      ],
      defaultScreenshots: [
        DocScreenshot(
          id: 'def_biometrics_1',
          featureId: 'biometrics_terminals',
          fileName: 'federation_biometrics.png',
          caption: 'Hardware Biometrics & Turnstile Gate Live Monitor',
          assetPath: 'assets/docs/screenshots/federation_biometrics.png',
        ),
      ],
      howToUse: [
        DocStep(
          stepNumber: 1,
          title: 'Register Biometric Hardware Terminal',
          description:
              'Add device code, hardware type (Facial Recognition, RFID Turnstile, Fingerprint), IP address, MAC, and physical gate location.',
          screenshotAssetPath: 'assets/docs/screenshots/federation_biometrics.png',
        ),
        DocStep(
          stepNumber: 2,
          title: 'Monitor Live Terminal Heartbeats',
          description:
              'Inspect status badges (Online, Offline, Maintenance) and verify terminal ping connectivity.',
        ),
        DocStep(
          stepNumber: 3,
          title: 'Stream Raw Punch Logs',
          description:
              'View incoming student and staff entry/exit punches with card numbers, timestamp, and verification mode.',
        ),
        DocStep(
          stepNumber: 4,
          title: '1-Click Attendance Reconciliation',
          description:
              'Click "Reconcile Punches" to synchronize the morning punch stream with official class attendance registers.',
        ),
      ],
    ),
  ];

  static DocFeature? findById(String id) {
    try {
      return features.firstWhere((f) => f.id == id);
    } catch (_) {
      return null;
    }
  }

  static List<DocFeature> filter({
    String query = '',
    DocCategory? category,
    DocRole? role,
  }) {
    final cleanQuery = query.trim().toLowerCase();
    return features.where((f) {
      if (category != null && f.category != category) return false;
      if (role != null && !f.roles.contains(role)) return false;
      if (cleanQuery.isEmpty) return true;

      final titleMatch = f.title.toLowerCase().contains(cleanQuery);
      final summaryMatch = f.summary.toLowerCase().contains(cleanQuery);
      final stepsMatch = f.howToUse.any((s) =>
          s.title.toLowerCase().contains(cleanQuery) ||
          s.description.toLowerCase().contains(cleanQuery));

      return titleMatch || summaryMatch || stepsMatch;
    }).toList();
  }
}
