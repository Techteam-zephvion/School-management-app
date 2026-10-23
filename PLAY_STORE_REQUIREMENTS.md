# Google Play Store Complete Submission & Compliance Requirements
**Application:** Schoolic  
**Package Name / Application ID:** `com.zephvion.schoolic`  
**Publisher:** Zephvion  
**Category:** Education  
**Date of Compilation:** October 2026 (Updated based on codebase audit & deployment chat)

---

## Executive Summary
This document consolidates all mandatory technical, regulatory, design, and operational requirements demanded by Google Play Console for releasing **Schoolic** to the Google Play Store. It reflects the exact changes made in the Schoolic codebase, live production endpoints, cryptographic keystore configurations, and Play Console declarations.

---

## 1. Technical & Binary Requirements

| Requirement | Play Store Rule | Schoolic Implemented State | Location in Codebase |
| :--- | :--- | :--- | :--- |
| **Package Name / Application ID** | Must be unique, reverse-domain format, consistent across all build types. | `com.zephvion.schoolic` | `apps/flutter_app/android/app/build.gradle.kts` |
| **Release Artifact Format** | New apps must be uploaded as **Android App Bundle (.aab)**. Standalone APKs are rejected. | Built & Signed `.aab` (52.8 MB) | `build_artifacts/schoolic-release.aab` |
| **Target API Level** | Must target API 34 (Android 14) or API 35 (Android 15) for new submissions. | Configured via Flutter SDK (targets API 34+) | `apps/flutter_app/android/app/build.gradle.kts` |
| **Minimum API Level** | Recommended API 21 (Android 5.0) or higher. | Min SDK 21 | `apps/flutter_app/android/app/build.gradle.kts` |
| **App Signing Key** | Must be signed with a permanent upload key; Google Play App Signing re-signs for distribution. | Permanent PKCS12 Keystore (`upload-keystore.jks`), valid until year 2054. | `apps/flutter_app/android/upload-keystore.jks` & `key.properties` |
| **Security of Credentials** | Passwords and keystores must NEVER be committed to Git. | Keystore password in local `key.properties`; added to `.gitignore`. | `.gitignore` |
| **Ad ID Permission (`AD_ID`)** | If the app doesn't serve ads, `com.google.android.gms.permission.AD_ID` must NOT be present. | Omitted from AndroidManifest; Ads declaration set to "No". | `apps/flutter_app/android/app/src/main/AndroidManifest.xml` |
| **Background Location** | Prohibited unless core to app function and strictly approved. | Not requested. | `AndroidManifest.xml` |

---

## 2. Store Listing & Graphical Assets

Google Play enforces strict dimensions, formats, and aspect ratios for store assets.

### 2.1 Text Metadata
* **App Title:** `Schoolic` (max 30 characters)
* **Short Description:** `Modern, unified operating system for school administration, academics & fees.` (max 80 characters)
* **Full Description:** (max 4000 characters)
  > Schoolic is a modern, lightweight, and institutional operating system engineered for educational excellence. Built for school administrators, educators, students, and parents, Schoolic streamlines every aspect of institutional management with speed and functional clarity.
  >
  > **CORE CAPABILITIES:**
  > • Student & Guardian Portal: Access digital student ID cards, daily attendance summaries, class timetables, homework assignments, and academic report cards.  
  > • Digital Fee Payments & Ledger: Review fee schedules, due dates, breakdown heads, and complete institutional payments securely via Cashfree Payments with immediate PDF receipt generation.  
  > • Attendance & Leave Management: Real-time student and staff roll calls, biometric device sync integration, and digital leave applications.  
  > • Examinations & Grading: Term management, grading scales, teacher marks entry, automated GPA calculations, and official scholastic transcripts.  
  > • Admissions & Intake: Inquiry lifecycle management, document verification checklist, and one-click student enrollment.  
  > • Privacy & Data Protection: Built-in Data Subject Rights (DSR) under DPDP Act 2023, enabling transparent data access, rectification, and complete erasure requests.  
  >
  > **PRIVACY & SAFETY FIRST:**
  > • 100% Ad-Free: Schoolic contains zero advertisements and zero ad-tracking SDKs.  
  > • Data Encryption: All data transmitted between mobile devices and cloud servers is encrypted via TLS 1.3 / HTTPS.  
  > • Student Data Protection: Verifiable parental consent controls and strict role-based access control.  
  >
  > Published by Zephvion. For institutional inquiries or assistance, visit https://schoolic.pages.dev or contact support@zephvion.com.

### 2.2 Graphical Assets Specifications

| Asset | Dimensions / Constraints | Format | Required By Google Play? | Asset Status |
| :--- | :--- | :--- | :--- | :--- |
| **App Icon** | 512 x 512 px, 32-bit color, max 1024 KB | PNG (no alpha/transparency on Play Store) | **Mandatory** | `play_store_assets/icon_512.png` |
| **Feature Graphic** | 1024 x 500 px, max 1024 KB | PNG or JPEG (no alpha) | **Mandatory** | `play_store_assets/feature_graphic.png` |
| **Phone Screenshots** | Min 2, Max 8 screenshots. Min 320px, Max 3840px. 16:9 or 9:16 aspect ratio. | PNG or JPEG | **Mandatory** | `play_store_assets/phone_screens/` |
| **7-Inch Tablet Screenshots** | Min 1 screenshot (16:9 or 9:16). | PNG or JPEG | Optional (Enables 7" tablet listing) | `play_store_assets/tablet_screens/` |
| **10-Inch Tablet Screenshots** | Min 1 screenshot (16:9 or 9:16). | PNG or JPEG | Optional (Enables 10" tablet listing) | `play_store_assets/tablet_screens/` |

---

## 3. Play Console Policy & Compliance Declarations

Every app must pass Google's automated and manual policy review checklists before being published.

### 3.1 App Access / Reviewer Credentials (**Critical Rejection Risk**)
Google Play reviewers will reject the app within 24 hours if they are blocked by a login screen without working credentials.
* **Question:** *Is any part of your app restricted?*
* **Declaration:** **Yes, all or some functionality is restricted**
* **Demo Credentials Provided for Google Reviewers:**
  1. **Administrator Account:**
     - **Email:** `admin@portfolio.schoolic.test`
     - **Password:** `Schoolic@2026`
     - **Notes for Reviewer:** *Full administrator access. Allows inspection of student registry, attendance reports, academic setup, and school ledger. Quick chip on login screen pre-fills credentials.*
  2. **Educator / Teacher Account:**
     - **Email:** `teacher-login@portfolio.schoolic.test`
     - **Password:** `Schoolic@2026`
     - **Notes for Reviewer:** *Teacher account with assigned classes (Grade 6A/6B Mathematics). Can take roll call, assign homework, and enter grades.*
  3. **Student Account:**
     - **Email:** `student@portfolio.schoolic.test`
     - **Password:** `Schoolic@2026`
     - **Notes for Reviewer:** *Student account (Aarav Sharma, Grade 6A). Displays digital ID card, timetable, attendance percentage, fee dues, and report card.*

---

### 3.2 Privacy Policy & Legal Endpoints
Google requires a publicly accessible Privacy Policy that:
1. Is available on an active, public web URL (not behind a login or restricted network).
2. Can be accessed directly inside the app **before** the user logs in.
3. Explicitly details user data collection, retention, and third-party processing (e.g. Cashfree Payments, Cloudflare Workers, Neon Postgres).

* **Public Web Privacy Policy URL:**  
  `https://schoolic-api.schoolic-api.workers.dev/privacy`  
  *(Also mirrored at `https://schoolic.pages.dev/#/privacy`)*
* **Public Terms of Service URL:**  
  `https://schoolic-api.schoolic-api.workers.dev/terms`
* **In-App Navigation:**  
  The login screen features direct clickable buttons to `Privacy Policy & Data Safety` and `Terms of Service` without requiring authentication (`PrivacyPolicyView` via `/privacy` route).

---

### 3.3 Account & Data Deletion Requirement (Effective Dec 2023)
Google Play's Data Safety policy mandates that if an app allows account creation, it must allow users to request account and data deletion both:
1. **Within the app:** Implemented via DPDP / DSR Request tab under user settings (`POST /api/v1/dsr/requests` with type `erasure`).
2. **From a public web URL (outside the app):**
   * **Account & Data Deletion URL:**  
     `https://schoolic-api.schoolic-api.workers.dev/data-deletion`
   * **Contact for Manual Deletion:** `privacy@zephvion.com`

---

### 3.4 Data Safety Questionnaire Mapping
When completing the Google Play Console Data Safety form, answer with the following mapping:

| Data Category | Specific Data Type | Collected? | Shared? | Purpose | Handling |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Personal Info** | Name | Yes | No | App functionality, user identity | Encrypted in transit (TLS 1.3), Deletion eligible |
| **Personal Info** | Email address | Yes | No | Account authentication, notifications | Encrypted in transit (TLS 1.3), Deletion eligible |
| **Personal Info** | Phone number | Yes | No | SMS notifications, emergency guardian contact | Encrypted in transit, Optional/School required |
| **Personal Info** | User IDs | Yes | No | Account management, role-based access | Encrypted in transit, Deletion eligible |
| **Financial Info** | Payment history | Yes | Yes (Cashfree) | Institutional fee billing, transaction receipts | Transmitted via Cashfree PCI-DSS certified gateway |
| **Photos & Videos** | Profile photos | Optional | No | Digital Student/Staff ID badge generation | Encrypted in transit, user optional |
| **Health Info** | Blood group / emergency contact | Optional | No | Campus emergency first aid record | Encrypted in transit, school records only |
| **App Performance**| Crash logs & diagnostics | Yes | No | Reliability, bug fixes, offline sync troubleshooting | Ephemeral / aggregated |
| **Device Identifiers**| Biometric device ID / push token | Optional | No | School turnstile attendance sync & push alerts | Encrypted in transit |

* **Is all user data encrypted in transit?** -> **Yes** (Strict HTTPS / TLS 1.3 on Cloudflare Workers and Neon Auth).
* **Do you provide a way for users to request data deletion?** -> **Yes** (`/data-deletion`).

---

### 3.5 Advertising & Financial Declarations
* **Contains Ads:** Select **No** (Zero ad networks or tracking SDKs).
* **Financial Features:** Select **Institutional Education Fee Management**. Payment processing is powered by RBI-authorized payment aggregator (Cashfree Payments). No loans, crypto, or personal credit features.
* **Health Features:** Select **My app does not provide any health-related features or services** (Student blood group is an administrative record, not medical diagnosis).
* **Government Representation:** Select **No** (Independent educational software).
* **Target Audience:** Select **18 and older** (Schoolic is administered and purchased by adult educational administrators, teachers, and parents).

---

## 4. Testing Tracks & The 20-Tester Requirement

If publishing from a **personal** Google Play Console developer account created after November 13, 2023, Google enforces a mandatory closed testing gate:

1. **Closed Testing Mandate:**
   * You must recruit at least **20 testers**.
   * Testers must be opted into your closed test track for at least **14 consecutive days**.
   * Testers must download/install the app from Google Play and actively test it.
2. **Post-Testing Application:**
   * After 14 continuous days, an application button will unlock in Google Play Console: **"Apply for production"**.
   * Google will ask questionnaire questions about testing feedback and bug remediation before granting production publishing rights.
3. **Enterprise / Organization Accounts Exception:**
   * Verified Organization / Company Google Play developer accounts with D-U-N-S numbers are exempt from the 20-tester / 14-day rule and can publish to Production directly.

---

## 5. Submission Checklist for Release

- [x] Application ID updated to `com.zephvion.schoolic` across Gradle, Kotlin package, and desktop configs.
- [x] Release Android App Bundle (`schoolic-release.aab`) built with production dart defines (`API_BASE_URL` and `NEON_AUTH_URL`).
- [x] Permanent PKCS12 upload keystore (`upload-keystore.jks`) generated and configured in `key.properties`.
- [x] Public Privacy Policy (`/privacy`), Terms (`/terms`), and Data Deletion (`/data-deletion`) deployed to Cloudflare Workers and Pages.
- [x] In-app legal viewer accessible from login screen before authentication.
- [x] Production database seeded with active demo credentials for Google reviewers (Admin, Teacher, Student).
- [ ] 512x512 app icon uploaded to Play Console.
- [ ] 1024x500 feature graphic uploaded to Play Console.
- [ ] Phone screenshots (at least 4) uploaded to Play Console.
- [ ] Complete Content Rating Questionnaire.
- [ ] Complete Data Safety Questionnaire using Section 3.4 above.
- [ ] Create Closed Testing Release and invite 20 testers (if personal account) or release directly to Production (if organization account).
