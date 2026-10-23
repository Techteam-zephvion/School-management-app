import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../shared/components/schoolic_logo.dart';

enum LegalSection { privacy, dataSafety, terms }

class PrivacyPolicyView extends ConsumerStatefulWidget {
  const PrivacyPolicyView({
    super.key,
    this.initialSection = LegalSection.privacy,
  });

  final LegalSection initialSection;

  @override
  ConsumerState<PrivacyPolicyView> createState() => _PrivacyPolicyViewState();
}

class _PrivacyPolicyViewState extends ConsumerState<PrivacyPolicyView> {
  late LegalSection _activeSection;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _activeSection = widget.initialSection;
  }

  void _copyEmail() {
    Clipboard.setData(const ClipboardData(text: 'privacy@zephvion.com'));
    setState(() => _copied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Contact email privacy@zephvion.com copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider).session;
    final isCompact = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      appBar: AppBar(
        backgroundColor: AppColors.mainBackground,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primaryText),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/login');
            }
          },
          tooltip: 'Back',
        ),
        title: Row(
          children: [
            const SchoolicLogo(size: 20, color: AppColors.primaryText),
            const SizedBox(width: 8),
            Text(
              'Schoolic Legal & Compliance',
              style: AppTypography.sectionHeading.copyWith(fontSize: 16),
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            children: [
              // Navigation tabs
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.secondaryBackground,
                    borderRadius: AppRadii.rMd,
                    border: Border.all(color: AppColors.primaryBorder),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      _tabButton('Privacy Policy', LegalSection.privacy),
                      _tabButton('Data Safety', LegalSection.dataSafety),
                      _tabButton('Terms of Service', LegalSection.terms),
                    ],
                  ),
                ),
              ),

              // Content View
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 16 : 28,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _headerBadge(),
                      const SizedBox(height: 12),
                      if (_activeSection == LegalSection.privacy)
                        _buildPrivacyPolicy(context, session != null)
                      else if (_activeSection == LegalSection.dataSafety)
                        _buildDataSafety(context, session != null)
                      else
                        _buildTermsOfService(),
                      const SizedBox(height: 40),
                      _buildFooter(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabButton(String label, LegalSection section) {
    final active = _activeSection == section;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeSection = section),
        child: AnimatedContainer(
          duration: AppMotion.normal,
          curve: AppMotion.curve,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppColors.mainBackground : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: active ? Border.all(color: AppColors.secondaryBorder) : null,
            boxShadow: active ? AppShadows.ambientSoft : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 13,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              color: active ? AppColors.primaryText : AppColors.secondaryText,
            ),
          ),
        ),
      ),
    );
  }

  Widget _headerBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.brandCyanSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.brandCyanBorder),
      ),
      child: Text(
        'Package: com.zephvion.schoolic • Published by Zephvion',
        style: const TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.brandCyanDark,
        ),
      ),
    );
  }

  Widget _buildPrivacyPolicy(BuildContext context, bool isAuthenticated) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Privacy Policy', style: AppTypography.display.copyWith(fontSize: 26)),
        const SizedBox(height: 6),
        const Text(
          'Effective Date: October 2026 • Aligned with DPDP Act 2023 & Google Play Policies',
          style: AppTypography.bodySecondary,
        ),
        const SizedBox(height: 20),

        _highlightCard(
          title: 'Zero Third-Party Ads Guarantee',
          description:
              'Schoolic is 100% ad-free. We do not use Google Mobile Ads SDK, do not request AD_ID permissions, and never monetize student or institutional data.',
          icon: Icons.verified_user_outlined,
          accentColor: AppColors.statusSuccess,
        ),
        const SizedBox(height: 16),

        _sectionTitle('1. Scope & Educational Nature'),
        _bodyText(
          'Schoolic is an institutional management platform for educational institutions, administrators, educators, students, and parents. We process personal data solely to facilitate school administration, academic reporting, roll-call attendance, homework workflows, and institutional fee payments.',
        ),

        _sectionTitle('2. Information Collected'),
        _bulletPoint('Account Profile: Name, institutional email, phone number, and system role (Admin, Teacher, Student, Parent).'),
        _bulletPoint('Academic Information: Daily attendance, examination marks, grade scales, timetable schedules, and homework submissions.'),
        _bulletPoint('Finance & Payments: Institutional fee structures, due dates, and official payment receipts. Payments are processed securely via Cashfree Payments; Schoolic never stores credit/debit card numbers or bank credentials.'),
        _bulletPoint('Emergency Information: Student emergency contact phone and blood group entered by school administrators for campus safety.'),
        _bulletPoint('Audit & Security: IP address and security timestamps to prevent brute-force attacks and unauthorized access.'),

        _sectionTitle('3. Health Apps Declaration'),
        _bodyText(
          'Schoolic is NOT a medical device, telehealth provider, or health-tracking application. Emergency contact information recorded by the school is purely administrative and not utilized for clinical health monitoring or diagnostic purposes.',
        ),

        _sectionTitle('4. Account Deletion & Data Erasure (Google Play Requirement)'),
        _bodyText(
          'Every user and legal guardian has the right to request the complete deletion of their account and associated personal data under Google Play user data policies and the DPDP Act 2023.',
        ),
        const SizedBox(height: 8),
        _deletionActionCard(isAuthenticated),

        _sectionTitle('5. Data Protection Officer & Grievance Contact'),
        _bodyText(
          'For any privacy inquiries or to file a request, contact Zephvion Data Protection Team:',
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: _copyEmail,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.secondaryBackground,
              borderRadius: AppRadii.rMd,
              border: Border.all(color: AppColors.primaryBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.email_outlined, size: 16, color: AppColors.brandCyanDark),
                const SizedBox(width: 8),
                const Text(
                  'privacy@zephvion.com',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandCyanDark,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(_copied ? Icons.check : Icons.copy, size: 14, color: AppColors.secondaryText),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDataSafety(BuildContext context, bool isAuthenticated) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Google Play Data Safety Disclosures', style: AppTypography.display.copyWith(fontSize: 26)),
        const SizedBox(height: 6),
        const Text(
          'Detailed disclosures regarding data collected, shared, and security practices.',
          style: AppTypography.bodySecondary,
        ),
        const SizedBox(height: 20),

        _dataSafetyTable(),
        const SizedBox(height: 24),

        _sectionTitle('Security Practices'),
        _bulletPoint('Data Encrypted in Transit: All data transfers between the mobile app and edge API use TLS 1.3 / HTTPS encryption.'),
        _bulletPoint('User Account Deletion: Users can request complete account and data erasure via in-app DSR or via email.'),
        _bulletPoint('No Data Sold: We do not sell user data to data brokers or third parties.'),
        _bulletPoint('No Behavioral Ad Tracking: We do not track user activity across third-party apps or websites.'),
      ],
    );
  }

  Widget _buildTermsOfService() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Terms of Service', style: AppTypography.display.copyWith(fontSize: 26)),
        const SizedBox(height: 6),
        const Text('Effective Date: October 2026', style: AppTypography.bodySecondary),
        const SizedBox(height: 20),

        _sectionTitle('1. Acceptance of Terms'),
        _bodyText('By using the Schoolic application or web services provided by Zephvion, you agree to these Terms.'),

        _sectionTitle('2. Authorized Institutional Use'),
        _bodyText('Schoolic accounts are authorized and assigned by participating educational institutions. You agree to maintain accurate information and safeguard your credentials.'),

        _sectionTitle('3. Fee Payments & Invoices'),
        _bodyText('Institutional payments conducted through Cashfree are subject to the financial terms and refund policies established by your educational institution.'),

        _sectionTitle('4. Termination & Deletion'),
        _bodyText('You may request the deletion of your account and personal data at any time in accordance with our Privacy Policy.'),
      ],
    );
  }

  Widget _dataSafetyTable() {
    final rows = [
      {'data': 'Personal Info (Name, Email, Phone)', 'collected': 'Yes', 'shared': 'No', 'purpose': 'App functionality & Account management'},
      {'data': 'Financial Info (Fee payment order ID)', 'collected': 'Yes', 'shared': 'Yes (Cashfree)', 'purpose': 'Fee transactions & Payment reconciliation'},
      {'data': 'Academic & Attendance Records', 'collected': 'Yes', 'shared': 'No', 'purpose': 'Educational progress & institutional records'},
      {'data': 'Emergency Contact & Blood Group', 'collected': 'Yes', 'shared': 'No', 'purpose': 'Campus student safety & first aid'},
      {'data': 'Device / Audit Logs', 'collected': 'Yes', 'shared': 'No', 'purpose': 'Security, Fraud prevention, and Analytics'},
    ];

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primaryBorder),
        borderRadius: AppRadii.rMd,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: AppColors.secondaryBackground,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text('Data Category', style: TextStyle(fontFamily: 'Switzer', fontWeight: FontWeight.w700, fontSize: 12))),
                Expanded(flex: 2, child: Text('Collected / Shared', style: TextStyle(fontFamily: 'Switzer', fontWeight: FontWeight.w700, fontSize: 12))),
                Expanded(flex: 3, child: Text('Primary Purpose', style: TextStyle(fontFamily: 'Switzer', fontWeight: FontWeight.w700, fontSize: 12))),
              ],
            ),
          ),
          ...rows.map((r) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.primaryBorder)),
                ),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Text(r['data']!, style: const TextStyle(fontFamily: 'Switzer', fontSize: 12, fontWeight: FontWeight.w500))),
                    Expanded(flex: 2, child: Text('${r['collected']} / ${r['shared']}', style: const TextStyle(fontFamily: 'Switzer', fontSize: 12, color: AppColors.secondaryText))),
                    Expanded(flex: 3, child: Text(r['purpose']!, style: const TextStyle(fontFamily: 'Switzer', fontSize: 12, color: AppColors.secondaryText))),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _deletionActionCard(bool isAuthenticated) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: AppRadii.rLg,
        border: Border.all(color: AppColors.primaryBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.delete_outline_rounded, color: AppColors.statusError, size: 20),
              SizedBox(width: 8),
              Text(
                'Request Account or Data Deletion',
                style: TextStyle(fontFamily: 'Switzer', fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'In accordance with Google Play store policy, you may initiate permanent erasure of your account and personal data:',
            style: TextStyle(fontFamily: 'Switzer', fontSize: 13, color: AppColors.secondaryText),
          ),
          const SizedBox(height: 12),
          if (isAuthenticated)
            FilledButton.icon(
              onPressed: () {
                context.go('/portal');
              },
              icon: const Icon(Icons.privacy_tip_outlined, size: 16),
              label: const Text('Open In-App Privacy Portal'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryText,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: _copyEmail,
              icon: const Icon(Icons.mail_outline, size: 16),
              label: const Text('Email privacy@zephvion.com to Request Deletion'),
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryText,
        ),
      ),
    );
  }

  Widget _bodyText(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 14,
          height: 1.5,
          color: AppColors.primaryText,
        ),
      ),
    );
  }

  Widget _bulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 14,
                height: 1.45,
                color: AppColors.primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _highlightCard({
    required String title,
    required String description,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: AppRadii.rMd,
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accentColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 13,
                    color: AppColors.secondaryText,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return const Center(
      child: Text(
        '© 2026 Zephvion. All rights reserved. Schoolic is an educational management system.',
        style: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 12,
          color: AppColors.mutedText,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
