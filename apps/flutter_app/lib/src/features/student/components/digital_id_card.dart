import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme.dart';

class DigitalIdCard extends StatelessWidget {
  const DigitalIdCard({
    required this.schoolName,
    required this.schoolCode,
    required this.fullName,
    required this.admissionNumber,
    required this.rollNumber,
    required this.className,
    required this.sectionName,
    required this.academicYear,
    this.guardianName,
    this.guardianPhone,
    this.qrPayload,
    super.key,
  });

  final String schoolName;
  final String schoolCode;
  final String fullName;
  final String admissionNumber;
  final String rollNumber;
  final String className;
  final String sectionName;
  final String academicYear;
  final String? guardianName;
  final String? guardianPhone;
  final String? qrPayload;

  String get _qrData {
    if (qrPayload != null && qrPayload!.isNotEmpty) {
      return qrPayload!;
    }
    return jsonEncode({
      'app': 'Schoolic',
      'type': 'STUDENT_DIGITAL_ID',
      'schoolCode': schoolCode,
      'admissionNumber': admissionNumber,
      'fullName': fullName,
      'className': className,
      'sectionName': sectionName,
      'academicYear': academicYear,
    });
  }

  void _showExpandedQr(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadii.rLg),
        backgroundColor: AppColors.mainBackground,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                fullName,
                style: AppTypography.sectionHeading,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Admission No: $admissionNumber • Class: $className-$sectionName',
                style: AppTypography.bodySecondary,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppRadii.rMd,
                  border: Border.all(color: AppColors.primaryBorder),
                ),
                child: QrImageView(
                  data: _qrData,
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Scan for campus roll-call, library lending, and security gate entry.',
                style: AppTypography.metadata,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initials = fullName
        .split(' ')
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s[0].toUpperCase())
        .join();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryText, // High-contrast sleek dark card
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Subtle watermark design element
            Positioned(
              right: -30,
              bottom: -30,
              child: Icon(
                Icons.school,
                size: 160,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Card Header: School Name, Code, and Chip
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              schoolName.toUpperCase(),
                              style: const TextStyle(
                                fontFamily: 'Switzer',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Code: $schoolCode • Academic Year $academicYear',
                              style: TextStyle(
                                fontFamily: 'Switzer',
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified, size: 12, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'STUDENT ID',
                              style: TextStyle(
                                fontFamily: 'Switzer',
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Middle Section: Photo/Avatar + Details + QR Code
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Avatar Monogram
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            initials.isEmpty ? 'ST' : initials,
                            style: const TextStyle(
                              fontFamily: 'Switzer',
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Student Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullName,
                              style: const TextStyle(
                                fontFamily: 'Switzer',
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Adm: $admissionNumber  •  Roll: $rollNumber',
                              style: TextStyle(
                                fontFamily: 'Switzer',
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Class: $className  •  Section: $sectionName',
                              style: TextStyle(
                                fontFamily: 'Switzer',
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Scannable Mini QR with Tap to Expand
                      GestureDetector(
                        onTap: () => _showExpandedQr(context),
                        child: Tooltip(
                          message: 'Tap to view full QR code',
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                QrImageView(
                                  data: _qrData,
                                  version: QrVersions.auto,
                                  size: 60,
                                  backgroundColor: Colors.white,
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'SCAN',
                                  style: TextStyle(
                                    fontFamily: 'Switzer',
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Divider
                  Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                  const SizedBox(height: 10),

                  // Footer: Emergency Contact & Validity
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          guardianPhone != null && guardianPhone!.isNotEmpty
                              ? 'Emergency Contact: $guardianPhone'
                              : 'Guardian: ${guardianName ?? "On Record"}',
                          style: TextStyle(
                            fontFamily: 'Switzer',
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.65),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _showExpandedQr(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.fullscreen, size: 13, color: Colors.white),
                        label: const Text(
                          'Enlarge QR',
                          style: TextStyle(
                            fontFamily: 'Switzer',
                            fontSize: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
