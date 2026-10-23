# Google Play Console Submission & Compliance Guide
**Application:** Schoolic  
**Package Name / Application ID:** `com.zephvion.schoolic`  
**Publisher:** Zephvion  
**Category:** Education  

This guide provides the exact answers, URLs, and declarations required to complete all sections shown in the Google Play Console checklist.

---

## 1. Summary of Changes Made in Code

| Item | Previous State | Current Implemented State |
| :--- | :--- | :--- |
| **Gradle Namespace** | `com.schoolic.schoolic` | `com.zephvion.schoolic` (`apps/flutter_app/android/app/build.gradle.kts`) |
| **Gradle Application ID** | `com.schoolic.schoolic` | `com.zephvion.schoolic` (`apps/flutter_app/android/app/build.gradle.kts`) |
| **Kotlin MainActivity** | `com.schoolic.schoolic.MainActivity` | `com.zephvion.schoolic.MainActivity` in directory `com/zephvion/schoolic/` |
| **Desktop App Identifiers** | `com.schoolic.schoolic` / `com.schoolic` | `com.zephvion.schoolic` / `com.zephvion` (Linux CMakeLists & Windows Runner.rc) |
| **Privacy Policy Web Endpoint** | None | Public zero-dependency HTML served at `/privacy`, `/data-deletion`, `/api/v1/public/privacy` |
| **Terms of Service Endpoint** | None | Public HTML served at `/terms`, `/api/v1/public/terms` |
| **In-App Legal Screen** | None | `PrivacyPolicyView` with tabs for Privacy Policy, Data Safety, Terms of Service |
| **In-App Legal Routes** | None | `/privacy`, `/terms`, `/data-safety` registered in GoRouter (unauthenticated access permitted) |
| **Login Screen Links** | Tour & Deck only | Clickable `Privacy Policy & Data Safety` and `Terms of Service` links added |
| **Account & Data Deletion** | Portal DSR only | Both in-app DSR erasure workflow and public deletion request instructions with `privacy@zephvion.com` |

---

## 2. Store Listings (Default: English - United States)

### App Details
* **App Name:** `Schoolic` (or `Schoolic - School Management`)
* **Short Description (max 80 chars):**  
  `Modern, unified operating system for school administration, academics & fees.`
* **Full Description:**
```text
Schoolic is a modern, lightweight, and institutional operating system engineered for educational excellence. Built for school administrators, educators, students, and parents, Schoolic streamlines every aspect of institutional management with speed and functional clarity.

CORE CAPABILITIES:
• Student & Guardian Portal: Access digital student ID cards, daily attendance summaries, class timetables, homework assignments, and academic report cards.
• Digital Fee Payments & Ledger: Review fee schedules, due dates, breakdown heads, and complete institutional payments securely via Cashfree Payments with immediate PDF receipt generation.
• Attendance & Leave Management: Real-time student and staff roll calls, biometric device sync integration, and digital leave applications.
• Examinations & Grading: Term management, grading scales, teacher marks entry, automated GPA calculations, and official scholastic transcripts.
• Admissions & Intake: Inquiry lifecycle management, document verification checklist, and one-click student enrollment.
• Privacy & Data Protection: Built-in Data Subject Rights (DSR) under DPDP Act 2023, enabling transparent data access, rectification, and complete erasure requests.

PRIVACY & SAFETY FIRST:
• 100% Ad-Free: Schoolic contains zero advertisements and zero ad-tracking SDKs.
• Data Encryption: All data transmitted between mobile devices and cloud servers is encrypted via TLS 1.3 / HTTPS.
• Student Data Protection: Verifiable parental consent controls and strict role-based access control.

Published by Zephvion. For institutional inquiries or assistance, visit https://schoolic.pages.dev or contact support@zephvion.com.
```

---

## 3. App Content Checklist Answers

### 0. App Access / Sign-In Details (For Google Play Reviewers)
* **Play Console Question:** *Is any part of your app restricted?*
* **Select:** **Yes, all or some functionality is restricted**
* **Click:** **+ Add details** and enter:

#### Primary Reviewer Account (Administrator):
* **Credentials name:** `Schoolic Admin Demo Account`
* **Account name / Email:** `admin@portfolio.schoolic.test`
* **Password:** `Schoolic@2026`
* **Any other instructions:**
```text
This account has full Administrator access to all school modules (attendance, examinations, student registry, fees, operations, and settings). On the login screen, you can also tap the quick "Admin Demo" chip to pre-fill these credentials. No 2-factor authentication or SMS OTP is required.
```

#### Secondary Reviewer Account (Teacher):
* **Credentials name:** `Schoolic Teacher Demo Account`
* **Account name / Email:** `teacher-login@portfolio.schoolic.test`
* **Password:** `Schoolic@2026`
* **Any other instructions:**
```text
Educator account with assigned class (=Stage Class A • Mathematics) for attendance taking, homework creation, and grading.
```

---

### A. Privacy Policy
* **Play Console Question:** *Provide a link to your privacy policy.*
* **URL to Submit:**  
  `https://schoolic-api.schoolic-api.workers.dev/privacy`  
  *(or your custom domain / web client: `https://schoolic.pages.dev/#/privacy`)*
* **Account Deletion URL (if requested by Play Console):**  
  `https://schoolic-api.schoolic-api.workers.dev/data-deletion`

---

### B. Ads Declaration
* **Play Console Question:** *Does your app contain ads?*
* **Select:** **No, my app does not contain ads**
* **Verification in Code:**
  - `apps/flutter_app/pubspec.yaml` contains NO Google Mobile Ads or third-party ad libraries.
  - `AndroidManifest.xml` does NOT declare the `com.google.android.gms.permission.AD_ID` permission.

---

### C. Health Apps Declaration
* **Play Console Question:** *Select all options that describe your app’s health features.*
* **Select:** **My app does not provide any health-related features or services**
* *Note:* The campus emergency profile (student blood group and guardian emergency phone) is an administrative school safety record and is not clinical software, telemedicine, or medical device technology.

---

### D. Target Audience and Content
* **Play Console Question:** *Target age groups*
* **Recommended Selection:** **18 and older** (as indicated on your Google Play Console screen)
  - *Why:* Schoolic accounts are provisioned, billed, and managed by school administration, adult teachers, and adult parents/guardians.
* **Appeal to Children:** If asked *"Could your store listing unintentionally appeal to children?"*, select **No** (the store listing uses professional, administrative education branding).

---

### E. Content Rating Questionnaire
* **Category:** Utility, Productivity, Communication, or Education
* **Violence:** No
* **Sexuality:** No
* **Language:** No
* **Controlled Substances:** No
* **User Content Sharing:** Yes (Teachers and students share homework and administrative messages within the closed institution)
* **Digital Purchases:** Yes (Institutional school fee payments)
* **Expected Rating:** Everyone / PEGI 3 / 3+

---

### F. Data Safety Questionnaire (Field-by-Field Mapping)

#### Step 1: Overall Data Collection
* **Does your app collect or share any of the required user data types?** -> **Yes**
* **Is all of the user data collected by your app encrypted in transit?** -> **Yes** (All API communication uses TLS 1.3/HTTPS)
* **Do you provide a way for users to request that their data be deleted?** -> **Yes**
* **Deletion URL:** `https://schoolic-api.schoolic-api.workers.dev/data-deletion`

#### Step 2: Data Types Breakdown

| Data Type | Collected? | Shared? | Purpose | Optional or Required? |
| :--- | :--- | :--- | :--- | :--- |
| **Personal Info > Name** | Yes | No | App functionality, Account management | Required |
| **Personal Info > Email address** | Yes | No | App functionality, Account management | Required |
| **Personal Info > Phone number** | Yes | No | Account management, SMS/WhatsApp notices | Optional / Required by School |
| **Personal Info > User IDs** | Yes | No | App functionality, Analytics | Required |
| **Financial Info > Purchase history** | Yes | Yes (Cashfree) | Institutional fee payment processing & invoicing | Optional (only when paying fees) |
| **Photos and Videos > Photos** | Optional | No | Student/Staff profile photo & ID card issuance | Optional |
| **Health and Fitness > Health info** | Optional | No | School campus emergency first aid (blood group) | Optional |
| **App info and performance > Crash logs** | Yes | No | Analytics & Bug fixing | Required |
| **Device or other IDs** | Yes | No | Security & Fraud prevention | Required |

---

## 4. Store Settings

* **App Category:** **Education** *(Do NOT select Entertainment app)*
* **Tags:** Education, School Management, Productivity
* **Store Listing Contact Details:**
  - **Email:** `support@zephvion.com` (or `privacy@zephvion.com`)
  - **Website:** `https://schoolic.pages.dev`
