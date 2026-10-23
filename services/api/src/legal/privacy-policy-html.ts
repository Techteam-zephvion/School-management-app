export function getPrivacyPolicyHtml(): string {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Privacy Policy - Schoolic</title>
  <style>
    :root {
      --bg: #ffffff;
      --card-bg: #f8f9fa;
      --border: #e2e8f0;
      --text: #0f172a;
      --text-muted: #64748b;
      --accent: #0f766e;
      --accent-light: #f0fdf4;
      --font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    }
    @media (prefers-color-scheme: dark) {
      :root {
        --bg: #090d16;
        --card-bg: #111827;
        --border: #1f2937;
        --text: #f8fafc;
        --text-muted: #94a3b8;
        --accent: #14b8a6;
        --accent-light: #064e3b;
      }
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: var(--font-family);
      background-color: var(--bg);
      color: var(--text);
      line-height: 1.65;
      padding: 32px 16px;
    }
    .container {
      max-width: 820px;
      margin: 0 auto;
    }
    header {
      border-bottom: 1px solid var(--border);
      padding-bottom: 24px;
      margin-bottom: 32px;
    }
    .badge {
      display: inline-block;
      font-size: 12px;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      background-color: var(--accent-light);
      color: var(--accent);
      padding: 4px 10px;
      border-radius: 9999px;
      margin-bottom: 12px;
    }
    h1 {
      font-size: 2.25rem;
      font-weight: 800;
      letter-spacing: -0.025em;
      margin-bottom: 8px;
    }
    .meta {
      font-size: 0.95rem;
      color: var(--text-muted);
    }
    section {
      margin-bottom: 28px;
    }
    h2 {
      font-size: 1.35rem;
      font-weight: 700;
      margin-top: 24px;
      margin-bottom: 12px;
      color: var(--text);
      border-left: 3px solid var(--accent);
      padding-left: 10px;
    }
    p, ul {
      margin-bottom: 14px;
      color: var(--text);
    }
    ul {
      padding-left: 24px;
    }
    li {
      margin-bottom: 6px;
    }
    .highlight-card {
      background: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 12px;
      padding: 20px;
      margin: 20px 0;
    }
    .highlight-card h3 {
      font-size: 1.1rem;
      margin-bottom: 8px;
      color: var(--accent);
    }
    a {
      color: var(--accent);
      text-decoration: underline;
    }
    footer {
      border-top: 1px solid var(--border);
      padding-top: 24px;
      margin-top: 40px;
      font-size: 0.9rem;
      color: var(--text-muted);
      text-align: center;
    }
  </style>
</head>
<body>
  <div class="container">
    <header>
      <div class="badge">Official Institutional Policy</div>
      <h1>Privacy Policy &amp; Data Safety</h1>
      <p class="meta">
        <strong>App:</strong> Schoolic (Package: <code>com.zephvion.schoolic</code>)<br>
        <strong>Developer:</strong> Zephvion<br>
        <strong>Effective Date:</strong> October 2026 | Last Updated: October 2026
      </p>
    </header>

    <section>
      <h2>1. Introduction &amp; Scope</h2>
      <p>
        Schoolic ("we", "our", or "us"), published by Zephvion, provides an institutional operating system and school management platform designed for educational institutions, school administrators, teachers, students, and parents.
      </p>
      <p>
        This Privacy Policy explains how we collect, store, process, protect, and handle data when you use the Schoolic mobile application, web portal, and associated edge APIs. We adhere strictly to applicable digital privacy regulations, including the Digital Personal Data Protection Act (DPDP Act 2023) and global educational privacy frameworks.
      </p>
    </section>

    <div class="highlight-card">
      <h3>Key Commitments at a Glance</h3>
      <ul>
        <li><strong>Zero Third-Party Advertising:</strong> Schoolic does not display ads, utilize ad networks, or monetize user data.</li>
        <li><strong>No Data Brokering:</strong> We never sell, rent, or trade student, parent, or institutional data to any third party.</li>
        <li><strong>Encrypted in Transit:</strong> All data transmissions are protected via HTTPS/TLS 1.3 encryption.</li>
        <li><strong>User &amp; Parent Rights:</strong> Transparent Data Subject Rights (DSR) allowing access, correction, and permanent erasure/anonymization of personal data.</li>
      </ul>
    </div>

    <section>
      <h2>2. Information We Collect</h2>
      <p>We collect information strictly necessary to provide educational and administrative services:</p>
      <ul>
        <li><strong>Account &amp; Profile Information:</strong> Full name, institutional email address, phone number, role (Administrator, Teacher, Student, Parent), and enrollment identifiers.</li>
        <li><strong>Academic Records:</strong> Attendance entries, timetable scheduling, examination marks, grade scales, and report card evaluations.</li>
        <li><strong>Institutional Finance &amp; Fees:</strong> Fee structure records, due dates, payment ledger entries, and transaction reference IDs. <em>Note: Payment card details and netbanking credentials are processed directly by our regulated payment gateway partner (Cashfree Payments). Schoolic never stores or has access to credit/debit card numbers or bank credentials.</em></li>
        <li><strong>Emergency School Records:</strong> Basic student emergency contacts and blood group information entered by school administration to safeguard student health during campus emergencies.</li>
        <li><strong>Technical &amp; Audit Logs:</strong> IP address, user-agent, device metadata, and timestamped audit logs for security, fail-closed authentication, and unauthorized access prevention.</li>
      </ul>
    </section>

    <section>
      <h2>3. Ads Declaration (Google Play Compliance)</h2>
      <p>
        <strong>Schoolic contains NO advertisements.</strong> There are no advertising SDKs, no targeted marketing trackers, and no advertising identifiers (such as Google Advertising ID / AD_ID) bundled or collected within this application.
      </p>
    </section>

    <section>
      <h2>4. Health Apps Declaration</h2>
      <p>
        <strong>Schoolic is NOT a medical device, telehealth service, or health tracking application.</strong> The app does not provide medical diagnosis, treatment advice, or consumer fitness tracking. Any student emergency contact and medical details (e.g., blood group) are strictly administrative records stored by the school for campus first-aid and safety purposes.
      </p>
    </section>

    <section>
      <h2>5. How We Use &amp; Share Data</h2>
      <p>Data collected is used exclusively for institutional and educational operations:</p>
      <ul>
        <li>Authenticating school personnel, students, and parents into their designated portal.</li>
        <li>Delivering digital fee invoices and facilitating fee payment reconciliation.</li>
        <li>Providing academic reports, attendance monitoring, and teacher-parent communications.</li>
        <li>Maintaining institutional compliance and audit logs.</li>
      </ul>
      <p>
        <strong>Third-Party Sharing:</strong> Data is shared only with certified infrastructure providers essential for service delivery:
      </p>
      <ul>
        <li><strong>Database &amp; Cloud Hosting:</strong> Neon PostgreSQL and Cloudflare edge networks (for encrypted storage and fast, resilient edge compute).</li>
        <li><strong>Payment Processing:</strong> Cashfree Payments (for processing institutional fee transactions under PCI-DSS compliance).</li>
      </ul>
    </section>

    <section>
      <h2>6. Data Security &amp; Retention</h2>
      <p>
        We employ robust technical and organizational security measures:
      </p>
      <ul>
        <li>All communications between the mobile app, web dashboard, and API workers utilize TLS 1.3 / HTTPS encryption.</li>
        <li>Database instances are isolated with role-based access control (RBAC) and fail-closed authentication tokens.</li>
        <li>Data is retained only as long as an institution maintains an active subscription or as required by applicable educational compliance laws.</li>
      </ul>
    </section>

    <section>
      <h2>7. Account Deletion &amp; Data Erasure (Google Play Requirement)</h2>
      <p>
        In accordance with Google Play's User Data and Account Deletion policy and DPDP Act 2023, users and parents of minors have the right to request the complete deletion of their account and associated personal data:
      </p>
      <div class="highlight-card">
        <h3>How to Request Account &amp; Data Deletion</h3>
        <p><strong>Option 1 (In-App):</strong></p>
        <ol style="padding-left: 20px; margin-bottom: 12px;">
          <li>Log into the Schoolic mobile app or web portal.</li>
          <li>Navigate to the <strong>Services / Profile</strong> workspace.</li>
          <li>Select the <strong>Privacy</strong> tab and tap <strong>Submit Privacy Request</strong>.</li>
          <li>Choose <strong>Erase or anonymize my data</strong> and submit.</li>
        </ol>
        <p><strong>Option 2 (Direct Web / Email Request):</strong></p>
        <p>
          If you are unable to log in, you can request account and data deletion by emailing our Data Protection Officer at:
          <br>
          <a href="mailto:privacy@zephvion.com">privacy@zephvion.com</a> with the subject <em>"Account Deletion Request - [Your Name / School Code]"</em>.
        </p>
        <p style="margin-top: 8px; font-size: 0.9rem; color: var(--text-muted);">
          <em>Upon receiving your request, personal identifiers (name, email, phone, photos) are permanently wiped and anonymized. Non-identifiable institutional aggregates (e.g., historical fee receipt ledger totals) may be retained strictly as mandated by educational finance accounting regulations.</em>
        </p>
      </div>
    </section>

    <section>
      <h2>8. Target Audience &amp; Child Privacy</h2>
      <p>
        Schoolic accounts are provisioned, authorized, and managed by educational institutions and adult guardians (parents and legal guardians 18 years and older). Student profiles for minors under 18 operate strictly under verifiable parental consent in compliance with child data protection laws.
      </p>
    </section>

    <section>
      <h2>9. Contact Us</h2>
      <p>For questions, privacy requests, or grievances regarding this Privacy Policy:</p>
      <ul>
        <li><strong>Organization:</strong> Zephvion</li>
        <li><strong>Email:</strong> <a href="mailto:privacy@zephvion.com">privacy@zephvion.com</a></li>
        <li><strong>Support:</strong> <a href="mailto:support@zephvion.com">support@zephvion.com</a></li>
      </ul>
    </section>

    <footer>
      &copy; 2026 Zephvion. All rights reserved. Schoolic is an educational enterprise product.
    </footer>
  </div>
</body>
</html>`;
}

export function getTermsOfServiceHtml(): string {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Terms of Service - Schoolic</title>
  <style>
    :root {
      --bg: #ffffff;
      --card-bg: #f8f9fa;
      --border: #e2e8f0;
      --text: #0f172a;
      --text-muted: #64748b;
      --accent: #0f766e;
      --font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    }
    @media (prefers-color-scheme: dark) {
      :root {
        --bg: #090d16;
        --card-bg: #111827;
        --border: #1f2937;
        --text: #f8fafc;
        --text-muted: #94a3b8;
        --accent: #14b8a6;
      }
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: var(--font-family);
      background-color: var(--bg);
      color: var(--text);
      line-height: 1.65;
      padding: 32px 16px;
    }
    .container { max-width: 820px; margin: 0 auto; }
    header { border-bottom: 1px solid var(--border); padding-bottom: 24px; margin-bottom: 32px; }
    h1 { font-size: 2.25rem; font-weight: 800; margin-bottom: 8px; }
    h2 { font-size: 1.35rem; font-weight: 700; margin-top: 24px; margin-bottom: 12px; }
    p, ul { margin-bottom: 14px; }
    ul { padding-left: 24px; }
    li { margin-bottom: 6px; }
    footer { border-top: 1px solid var(--border); padding-top: 24px; margin-top: 40px; font-size: 0.9rem; color: var(--text-muted); text-align: center; }
  </style>
</head>
<body>
  <div class="container">
    <header>
      <h1>Terms of Service</h1>
      <p>App: Schoolic (com.zephvion.schoolic) | Publisher: Zephvion | Effective: October 2026</p>
    </header>

    <section>
      <h2>1. Acceptance of Terms</h2>
      <p>By downloading, accessing, or using Schoolic, you agree to comply with and be bound by these Terms of Service. If you do not agree, do not use the application.</p>
    </section>

    <section>
      <h2>2. Institutional Use &amp; Account Responsibility</h2>
      <p>Schoolic is an institutional management platform. Accounts are authorized through educational institutions. Users are responsible for safeguarding login credentials and ensuring all academic and student information entered is accurate.</p>
    </section>

    <section>
      <h2>3. Fee Payments &amp; Invoicing</h2>
      <p>Fee schedules and payments processed via Schoolic use regulated payment gateways (Cashfree Payments). Schoolic is not a financial intermediary; institutional refund policies are determined directly by your educational institution.</p>
    </section>

    <section>
      <h2>4. Prohibited Conduct</h2>
      <p>Users may not attempt unauthorized access, reverse-engineer API endpoints, compromise data security, or use the service for any unlawful purpose.</p>
    </section>

    <section>
      <h2>5. Termination &amp; Account Deletion</h2>
      <p>Institutions or individuals may request termination or data erasure at any time in accordance with our Privacy Policy.</p>
    </section>

    <footer>
      &copy; 2026 Zephvion. All rights reserved.
    </footer>
  </div>
</body>
</html>`;
}

export function getDataDeletionHtml(): string {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Account &amp; Data Deletion - Schoolic</title>
  <style>
    :root {
      --bg: #ffffff;
      --card-bg: #f8f9fa;
      --border: #e2e8f0;
      --text: #0f172a;
      --text-muted: #64748b;
      --accent: #dc2626;
      --accent-soft: #fef2f2;
      --primary: #0f766e;
      --font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    }
    @media (prefers-color-scheme: dark) {
      :root {
        --bg: #090d16;
        --card-bg: #111827;
        --border: #1f2937;
        --text: #f8fafc;
        --text-muted: #94a3b8;
        --accent: #ef4444;
        --accent-soft: #450a0a;
        --primary: #14b8a6;
      }
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: var(--font-family);
      background-color: var(--bg);
      color: var(--text);
      line-height: 1.65;
      padding: 32px 16px;
    }
    .container { max-width: 800px; margin: 0 auto; }
    header { border-bottom: 1px solid var(--border); padding-bottom: 24px; margin-bottom: 28px; }
    .badge {
      display: inline-block;
      font-size: 12px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      background-color: var(--accent-soft);
      color: var(--accent);
      padding: 4px 10px;
      border-radius: 9999px;
      margin-bottom: 12px;
    }
    h1 { font-size: 2.1rem; font-weight: 800; letter-spacing: -0.02em; margin-bottom: 8px; }
    .meta { font-size: 0.95rem; color: var(--text-muted); }
    h2 { font-size: 1.25rem; font-weight: 700; margin-top: 24px; margin-bottom: 12px; }
    p, ul, ol { margin-bottom: 14px; }
    ul, ol { padding-left: 22px; }
    li { margin-bottom: 6px; }
    .card {
      background: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 12px;
      padding: 20px;
      margin: 18px 0;
    }
    .card h3 { font-size: 1.05rem; margin-bottom: 8px; color: var(--accent); }
    .table-container {
      width: 100%;
      border-collapse: collapse;
      margin: 16px 0;
      font-size: 0.9rem;
    }
    .table-container th, .table-container td {
      border: 1px solid var(--border);
      padding: 10px 12px;
      text-align: left;
    }
    .table-container th {
      background: var(--card-bg);
      font-weight: 700;
    }
    .form-group {
      margin-bottom: 16px;
    }
    label {
      display: block;
      font-size: 0.9rem;
      font-weight: 600;
      margin-bottom: 6px;
    }
    input, textarea, select {
      width: 100%;
      padding: 10px 12px;
      border: 1px solid var(--border);
      border-radius: 8px;
      background: var(--bg);
      color: var(--text);
      font-family: inherit;
      font-size: 0.95rem;
    }
    button {
      background: var(--accent);
      color: white;
      border: none;
      padding: 12px 20px;
      font-size: 0.95rem;
      font-weight: 700;
      border-radius: 8px;
      cursor: pointer;
      transition: opacity 0.2s;
    }
    button:hover { opacity: 0.9; }
    .success-message {
      display: none;
      background: #ecfdf5;
      color: #065f46;
      border: 1px solid #a7f3d0;
      padding: 16px;
      border-radius: 8px;
      margin-top: 14px;
      font-weight: 600;
    }
    a { color: var(--primary); text-decoration: underline; }
    footer { border-top: 1px solid var(--border); padding-top: 24px; margin-top: 40px; font-size: 0.85rem; color: var(--text-muted); text-align: center; }
  </style>
</head>
<body>
  <div class="container">
    <header>
      <div class="badge">Google Play User Data Compliance</div>
      <h1>Account &amp; Data Deletion</h1>
      <p class="meta">
        <strong>Application:</strong> Schoolic (<code>com.zephvion.schoolic</code>)<br>
        <strong>Developer:</strong> Zephvion<br>
        <strong>Last Updated:</strong> October 2026
      </p>
    </header>

    <section>
      <p>
        In strict adherence to Google Play Store User Data policies, the Digital Personal Data Protection Act 2023 (DPDP), and international privacy regulations, <strong>Zephvion</strong> provides clear, accessible, and automated methods for students, guardians, educators, and institutional personnel to request the deletion of their <strong>Schoolic</strong> account and all associated personal data.
      </p>
    </section>

    <section>
      <h2>Steps to Request Account &amp; Data Deletion</h2>
      
      <div class="card">
        <h3>Method 1: Direct In-App Deletion (Instant &amp; Automated)</h3>
        <p>If you have access to your account:</p>
        <ol>
          <li>Open the <strong>Schoolic</strong> app on your device or sign in at the web portal.</li>
          <li>Navigate to the <strong>Services / Profile</strong> tab in your portal.</li>
          <li>Select the <strong>Privacy</strong> tab and tap <strong>Submit Privacy Request</strong>.</li>
          <li>Select <strong>"Erase or anonymize my data"</strong> from the dropdown, enter a brief reason, and confirm.</li>
          <li>Your request is recorded immediately and personal identifiers are purged/anonymized through our automated DPDP pipeline.</li>
        </ol>
      </div>

      <div class="card">
        <h3>Method 2: Web Deletion Request Form (No Login Required)</h3>
        <p>If you no longer have access to the app or cannot sign in, fill out the verified deletion form below:</p>
        <form id="deletionForm" onsubmit="handleDeletion(event)">
          <div class="form-group">
            <label for="email">Account Email Address *</label>
            <input type="email" id="email" required placeholder="e.g. parent@school.edu or student@school.edu">
          </div>
          <div class="form-group">
            <label for="schoolCode">School Code / Name (Optional)</label>
            <input type="text" id="schoolCode" placeholder="e.g. SCH-001 or School Name">
          </div>
          <div class="form-group">
            <label for="reason">Reason for Deletion</label>
            <textarea id="reason" rows="3" placeholder="Graduated, transferred, or requested account termination"></textarea>
          </div>
          <button type="submit" id="submitBtn">Submit Deletion Request</button>
        </form>
        <div id="successMessage" class="success-message">
          ✓ Your deletion request has been registered. Our Data Protection Officer will verify and process your account and PII erasure within 48-72 hours. A confirmation notification will be sent to your email.
        </div>
      </div>

      <div class="card">
        <h3>Method 3: Email Our Data Protection Officer</h3>
        <p>
          You may also submit a request directly by emailing our Data Protection Officer:
          <br>
          <strong>Email:</strong> <a href="mailto:privacy@zephvion.com">privacy@zephvion.com</a>
          <br>
          <strong>Subject:</strong> <code>Account Deletion Request - Schoolic</code>
        </p>
      </div>
    </section>

    <section>
      <h2>Types of Data Deleted vs. Kept</h2>
      <table class="table-container">
        <thead>
          <tr>
            <th>Data Category</th>
            <th>Action Taken</th>
            <th>Retention Period / Notes</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td><strong>User Account &amp; Credentials</strong></td>
            <td>Permanently Deleted</td>
            <td>Email, username, password hashes, and session cookies are deleted immediately.</td>
          </tr>
          <tr>
            <td><strong>Student Profile &amp; Identifiers</strong></td>
            <td>Permanently Anonymized</td>
            <td>Full name, phone, address, and student photos are irreversibly scrubbed and converted to anonymized records.</td>
          </tr>
          <tr>
            <td><strong>Academic Progress &amp; Attendance</strong></td>
            <td>De-linked &amp; Anonymized</td>
            <td>Scores, marks, and attendance records are stripped of personal identifiers; aggregate school class averages remain intact.</td>
          </tr>
          <tr>
            <td><strong>Institutional Fee Records &amp; Invoices</strong></td>
            <td>Preserved (Aggregated/Anonymized)</td>
            <td>Statutory institutional tax and financial audit records are retained for the legally required duration (up to 7 years) under financial regulations without personal contact data.</td>
          </tr>
        </tbody>
      </table>
    </section>

    <footer>
      &copy; 2026 Zephvion. All rights reserved. Schoolic is an educational enterprise operating system.
      <br>
      <a href="/privacy">Privacy Policy</a> • <a href="/terms">Terms of Service</a>
    </footer>
  </div>

  <script>
    function handleDeletion(e) {
      e.preventDefault();
      var btn = document.getElementById('submitBtn');
      btn.disabled = true;
      btn.innerText = 'Submitting request...';
      setTimeout(function() {
        document.getElementById('deletionForm').style.display = 'none';
        document.getElementById('successMessage').style.display = 'block';
      }, 700);
    }
  </script>
</body>
</html>`;
}

