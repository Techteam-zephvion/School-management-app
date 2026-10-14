import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../utils/fee_receipt_pdf.dart';

class FeeReceiptModal extends StatelessWidget {
  const FeeReceiptModal({
    required this.receiptData,
    super.key,
  });

  final FeeReceiptData receiptData;

  static Future<void> show(
    BuildContext context, {
    required FeeReceiptData receiptData,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => FeeReceiptModal(receiptData: receiptData),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.mainBackground,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.rLg,
        side: const BorderSide(color: AppColors.primaryBorder),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          receiptData.schoolName,
                          style: const TextStyle(
                            fontFamily: 'Switzer',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Institutional Fee Receipt',
                          style: TextStyle(
                            fontFamily: 'Switzer',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: AppRadii.rSm,
                      border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                    ),
                    child: const Text(
                      'PAID',
                      style: TextStyle(
                        fontFamily: 'Switzer',
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.primaryBorder),
              const SizedBox(height: 16),

              // Receipt metadata
              _buildDataRow('Receipt No.', receiptData.receiptNumber),
              const SizedBox(height: 8),
              _buildDataRow('Date & Time', receiptData.paidAt),
              const SizedBox(height: 8),
              _buildDataRow('Student Name', receiptData.studentName),
              const SizedBox(height: 8),
              _buildDataRow('Admission No.', receiptData.admissionNumber),
              const SizedBox(height: 8),
              _buildDataRow(
                'Class / Sec',
                receiptData.sectionName.isNotEmpty
                    ? '${receiptData.className} - ${receiptData.sectionName}'
                    : receiptData.className,
              ),
              const SizedBox(height: 8),
              _buildDataRow('Fee Category', receiptData.feeName),
              const SizedBox(height: 8),
              _buildDataRow('Payment Mode', receiptData.paymentMethod.toUpperCase()),
              if (receiptData.transactionReference != null &&
                  receiptData.transactionReference!.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildDataRow('Transaction Ref', receiptData.transactionReference!),
              ],
              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.primaryBorder),
              const SizedBox(height: 16),

              // Total Paid
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Paid',
                    style: TextStyle(
                      fontFamily: 'Switzer',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mutedText,
                    ),
                  ),
                  Text(
                    '₹${receiptData.amountPaid}',
                    style: const TextStyle(
                      fontFamily: 'Switzer',
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryText,
                        side: const BorderSide(color: AppColors.primaryBorder),
                        shape: RoundedRectangleBorder(borderRadius: AppRadii.rMd),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: AppRadii.rMd),
                      ),
                      icon: const Icon(Icons.print, size: 18),
                      label: const Text('Print / PDF'),
                      onPressed: () => printOrShareFeeReceipt(receiptData),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.metadata,
        ),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Switzer',
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
