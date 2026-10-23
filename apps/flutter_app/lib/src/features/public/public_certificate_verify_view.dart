import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../shared/components/feedback_banner.dart';
import '../shared/components/schoolic_logo.dart';
import '../shared/components/status_badge.dart';

class PublicCertificateVerifyView extends ConsumerStatefulWidget {
  const PublicCertificateVerifyView({required this.code, super.key});

  final String code;

  @override
  ConsumerState<PublicCertificateVerifyView> createState() =>
      _PublicCertificateVerifyViewState();
}

class _PublicCertificateVerifyViewState
    extends ConsumerState<PublicCertificateVerifyView> {
  final _searchController = TextEditingController();
  bool _loading = true;
  String? _error;
  Map<String, Object?>? _verificationData;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.code;
    _verifyCode(widget.code);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode(String verificationCode) async {
    final cleanCode = verificationCode.trim();
    if (cleanCode.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Please enter a valid verification code.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final client = ref.read(apiClientProvider);
      final res =
          await client.getJson('/api/v1/public/certificates/verify/$cleanCode');
      if (!mounted) return;

      setState(() {
        _verificationData = res;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top branding & verification header
                  _buildHeader(context),
                  const SizedBox(height: 24),

                  // Search bar to verify another certificate
                  _buildSearchBox(context),
                  const SizedBox(height: 24),

                  // Content state
                  if (_loading)
                    _buildLoading(context)
                  else if (_error != null)
                    FeedbackBanner.error(message: _error!)
                  else if (_verificationData != null)
                    _buildVerificationResult(context)
                  else
                    const SizedBox.shrink(),

                  const SizedBox(height: 36),
                  // Trust & Verification Footer
                  _buildFooter(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SchoolicLogo(size: 36),
            SizedBox(width: 12),
            Text(
              'Schoolic',
              style: TextStyle(
                fontFamily: 'Switzer',
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryText,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Institutional Certificate Verification Portal',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryText,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Official registry verification backed by cryptographic seals',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.secondaryText,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBox(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.mainBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          const Icon(
            Icons.qr_code_scanner_rounded,
            color: AppColors.secondaryText,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Enter Verification Code or Certificate ID...',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
              onSubmitted: _verifyCode,
            ),
          ),
          ElevatedButton(
            onPressed: () => _verifyCode(_searchController.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandCyanDark,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Verify',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(strokeWidth: 2.5),
            SizedBox(height: 16),
            Text(
              'Querying institutional registry ledger...',
              style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationResult(BuildContext context) {
    final data = _verificationData!;
    final isVerified = data['verified'] == true;
    final status = (data['status'] as String? ?? '').toLowerCase();
    final isRevoked = status == 'revoked';

    if (!isVerified && !isRevoked) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.secondaryBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.statusWarning),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.statusWarning.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.statusWarning,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Certificate Not Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              data['message'] as String? ??
                  'No certificate record matched this verification code in the institutional database.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.secondaryText),
            ),
          ],
        ),
      );
    }

    final certNumber = data['certificateNumber'] as String? ?? 'N/A';
    final certType = (data['certificateType'] as String? ?? 'Certificate')
        .replaceAll('_', ' ')
        .toUpperCase();
    final studentName = data['studentName'] as String? ?? 'N/A';
    final admissionNumber = data['admissionNumber'] as String? ?? 'N/A';
    final schoolName =
        data['schoolName'] as String? ?? 'Schoolic Partner Institution';
    final schoolCode = data['schoolCode'] as String? ?? '';
    final issueDate = data['issueDate'] as String? ?? 'N/A';

    final Color statusColor =
        isRevoked ? AppColors.statusError : AppColors.statusSuccess;
    final Color statusBg = statusColor.withValues(alpha: 0.08);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.mainBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isRevoked ? AppColors.statusError : AppColors.primaryBorder,
          width: isRevoked ? 1.5 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(19)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isRevoked
                        ? Icons.cancel_outlined
                        : Icons.verified_user_rounded,
                    color: statusColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isRevoked ? 'REVOKED CERTIFICATE' : 'VERIFIED GENUINE',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isRevoked
                            ? 'This certificate was officially invalidated by the school.'
                            : 'Authentic institutional record verified in Schoolic registry.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(
                  label: isRevoked ? 'REVOKED' : 'VALID',
                  tone: isRevoked ? BadgeTone.error : BadgeTone.success,
                ),
              ],
            ),
          ),

          // Detail attributes
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildField('Certificate Type', certType, isHighlight: true),
                const Divider(height: 24),
                _buildField('Certificate Number', certNumber),
                const Divider(height: 24),
                _buildField('Student Name', studentName, isHighlight: true),
                const Divider(height: 24),
                _buildField('Admission Number', admissionNumber),
                const Divider(height: 24),
                _buildField(
                  'Issuing Institution',
                  schoolCode.isNotEmpty ? '$schoolName ($schoolCode)' : schoolName,
                ),
                const Divider(height: 24),
                _buildField('Date of Issue', issueDate),
              ],
            ),
          ),

          // Bottom seal strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: const BoxDecoration(
              color: AppColors.secondaryBackground,
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(19)),
              border: Border(top: BorderSide(color: AppColors.primaryBorder)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.shield_outlined,
                  size: 16,
                  color: AppColors.secondaryText,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Schoolic Registry Verification Hash: ${widget.code}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: AppColors.secondaryText,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.secondaryText,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: isHighlight ? 15 : 13,
              fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
              color: AppColors.primaryText,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return const Column(
      children: [
        Text(
          'Protected by Schoolic Enterprise Cryptographic Registry Protocol',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.secondaryText,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'All records are time-stamped and tamper-evident upon issue.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            color: AppColors.mutedText,
          ),
        ),
      ],
    );
  }
}
