import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme.dart';
import '../../shared/components/feedback_banner.dart';

class FeePaymentSheet extends ConsumerStatefulWidget {
  const FeePaymentSheet({
    required this.allocationId,
    required this.feeName,
    required this.totalAmount,
    required this.paidAmount,
    required this.balanceDue,
    required this.studentName,
    this.admissionNumber,
    this.onPaymentSuccess,
    super.key,
  });

  final String allocationId;
  final String feeName;
  final int totalAmount;
  final int paidAmount;
  final int balanceDue;
  final String studentName;
  final String? admissionNumber;
  final VoidCallback? onPaymentSuccess;

  static Future<void> show(
    BuildContext context, {
    required String allocationId,
    required String feeName,
    required int totalAmount,
    required int paidAmount,
    required int balanceDue,
    required String studentName,
    String? admissionNumber,
    VoidCallback? onPaymentSuccess,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FeePaymentSheet(
        allocationId: allocationId,
        feeName: feeName,
        totalAmount: totalAmount,
        paidAmount: paidAmount,
        balanceDue: balanceDue,
        studentName: studentName,
        admissionNumber: admissionNumber,
        onPaymentSuccess: onPaymentSuccess,
      ),
    );
  }

  @override
  ConsumerState<FeePaymentSheet> createState() => _FeePaymentSheetState();
}

class _FeePaymentSheetState extends ConsumerState<FeePaymentSheet> {
  bool _isFullPayment = true;
  late final TextEditingController _customAmountController;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _selectedPaymentMethod = 'UPI';

  @override
  void initState() {
    super.initState();
    _customAmountController = TextEditingController(text: widget.balanceDue.toString());
  }

  @override
  void dispose() {
    _customAmountController.dispose();
    super.dispose();
  }

  int get _payableAmount {
    if (_isFullPayment) return widget.balanceDue;
    final parsed = int.tryParse(_customAmountController.text.trim()) ?? 0;
    return parsed;
  }

  Future<void> _handlePayment() async {
    final amount = _payableAmount;
    if (amount <= 0) {
      setState(() => _errorMessage = 'Please enter a valid amount greater than ₹0.');
      return;
    }
    if (amount > widget.balanceDue) {
      setState(() => _errorMessage = 'Amount cannot exceed balance due of ₹${widget.balanceDue}.');
      return;
    }

    final session = ref.read(authControllerProvider).session;
    if (session == null) {
      setState(() => _errorMessage = 'User session expired. Please sign in again.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final api = ref.read(apiClientProvider);

      // Step 1: Create Payment Order via Worker API
      final orderRes = await api.createFeePaymentOrder(
        session: session,
        allocationId: widget.allocationId,
        amount: amount,
      );

      final orderId = orderRes['orderId'] as String;
      final isSimulated = (orderRes['isSimulated'] as bool?) ?? false;

      if (!mounted) return;

      // Step 2: Checkout Step (Interactive authorization sheet for simulator or Live PG)
      final authorized = await _showAuthorizationDialog(orderId, amount, isSimulated);
      if (!authorized) {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
            _errorMessage = 'Payment was cancelled.';
          });
        }
        return;
      }

      if (!mounted) return;

      // Step 3: Verify Payment Status with API
      final verifyRes = await api.verifyFeePaymentOrder(
        session: session,
        orderId: orderId,
      );

      final isSuccess = (verifyRes['success'] as bool?) ?? false;
      final receiptNumber = (verifyRes['receiptNumber'] as String?) ?? 'REC-VERIFIED';

      if (mounted) {
        setState(() => _isSubmitting = false);
        Navigator.of(context).pop();

        widget.onPaymentSuccess?.call();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: isSuccess ? const Color(0xFF0F5132) : Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                Icon(
                  isSuccess ? Icons.check_circle : Icons.error_outline,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isSuccess
                        ? 'Payment Successful! Receipt: $receiptNumber'
                        : 'Payment verification failed.',
                    style: const TextStyle(
                      fontFamily: 'Switzer',
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<bool> _showAuthorizationDialog(String orderId, int amount, bool isSimulated) async {
    return (await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => AlertDialog(
            backgroundColor: AppColors.secondaryBackground,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadii.rLg,
              side: const BorderSide(color: AppColors.primaryBorder),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: AppRadii.rSm,
                  ),
                  child: const Icon(Icons.shield_outlined, color: Colors.green, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Cashfree Secure PG',
                    style: TextStyle(
                      fontFamily: 'Switzer',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order ID: $orderId',
                  style: AppTypography.metadata,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.mainBackground,
                    borderRadius: AppRadii.rMd,
                    border: Border.all(color: AppColors.primaryBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Amount to Authorize',
                        style: TextStyle(
                          fontFamily: 'Switzer',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.mutedText,
                        ),
                      ),
                      Text(
                        '₹$amount',
                        style: const TextStyle(
                          fontFamily: 'Switzer',
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Payment Method: $_selectedPaymentMethod',
                  style: const TextStyle(
                    fontFamily: 'Switzer',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isSimulated
                      ? 'Sandbox Simulator: Click "Authorize Payment" to complete the transaction and generate your official school receipt.'
                      : 'You will be prompted to authenticate with your bank/UPI application.',
                  style: AppTypography.bodySecondary,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                child: const Text('Cancel', style: TextStyle(color: AppColors.mutedText)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: AppRadii.rSm),
                ),
                onPressed: () => Navigator.of(dialogCtx).pop(true),
                child: const Text('Authorize Payment'),
              ),
            ],
          ),
        )) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final keyboardSpace = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + keyboardSpace),
      decoration: const BoxDecoration(
        color: AppColors.mainBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: AppColors.primaryBorder)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.primaryBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Fee Payment Checkout',
                        style: TextStyle(
                          fontFamily: 'Switzer',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.feeName} • ${widget.studentName}',
                        style: AppTypography.bodySecondary,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_errorMessage != null) ...[
              FeedbackBanner(
                message: _errorMessage!,
                tone: FeedbackTone.error,
              ),
              const SizedBox(height: 14),
            ],

            // Statement summary box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.secondaryBackground,
                borderRadius: AppRadii.rMd,
                border: Border.all(color: AppColors.primaryBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Billed', style: AppTypography.metadata),
                        const SizedBox(height: 2),
                        Text(
                          '₹${widget.totalAmount}',
                          style: const TextStyle(
                            fontFamily: 'Switzer',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 32, color: AppColors.primaryBorder),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Paid So Far', style: AppTypography.metadata),
                          const SizedBox(height: 2),
                          Text(
                            '₹${widget.paidAmount}',
                            style: const TextStyle(
                              fontFamily: 'Switzer',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(width: 1, height: 32, color: AppColors.primaryBorder),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Balance Due', style: AppTypography.metadata),
                          const SizedBox(height: 2),
                          Text(
                            '₹${widget.balanceDue}',
                            style: const TextStyle(
                              fontFamily: 'Switzer',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Select Payment Option',
              style: TextStyle(
                fontFamily: 'Switzer',
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),

            // Option 1: Full Payment
            InkWell(
              onTap: () => setState(() => _isFullPayment = true),
              borderRadius: AppRadii.rMd,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _isFullPayment
                      ? AppColors.secondaryBackground
                      : AppColors.mainBackground,
                  borderRadius: AppRadii.rMd,
                  border: Border.all(
                    color: _isFullPayment ? Colors.blueAccent : AppColors.primaryBorder,
                    width: _isFullPayment ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isFullPayment ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: _isFullPayment ? Colors.blueAccent : AppColors.mutedText,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pay Full Balance Due',
                            style: TextStyle(
                              fontFamily: 'Switzer',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Clear the complete outstanding balance',
                            style: AppTypography.metadata,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '₹${widget.balanceDue}',
                      style: const TextStyle(
                        fontFamily: 'Switzer',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Option 2: Custom Partial Payment
            InkWell(
              onTap: () => setState(() => _isFullPayment = false),
              borderRadius: AppRadii.rMd,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: !_isFullPayment
                      ? AppColors.secondaryBackground
                      : AppColors.mainBackground,
                  borderRadius: AppRadii.rMd,
                  border: Border.all(
                    color: !_isFullPayment ? Colors.blueAccent : AppColors.primaryBorder,
                    width: !_isFullPayment ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          !_isFullPayment ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: !_isFullPayment ? Colors.blueAccent : AppColors.mutedText,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Pay Custom Partial Amount',
                                style: TextStyle(
                                  fontFamily: 'Switzer',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Pay an installment or flexible sum',
                                style: AppTypography.metadata,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (!_isFullPayment) ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: _customAmountController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          prefixText: '₹ ',
                          labelText: 'Enter amount to pay',
                          hintText: 'e.g. 5000',
                          filled: true,
                          fillColor: AppColors.mainBackground,
                          border: OutlineInputBorder(
                            borderRadius: AppRadii.rSm,
                            borderSide: const BorderSide(color: AppColors.primaryBorder),
                          ),
                          helperText: 'Maximum allowed: ₹${widget.balanceDue}',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Payment Methods Selector
            const Text(
              'Select Payment Channel',
              style: TextStyle(
                fontFamily: 'Switzer',
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildMethodChip('UPI', Icons.qr_code),
                const SizedBox(width: 8),
                _buildMethodChip('Cards', Icons.credit_card),
                const SizedBox(width: 8),
                _buildMethodChip('NetBanking', Icons.account_balance),
              ],
            ),
            const SizedBox(height: 24),

            // Action Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: AppRadii.rMd),
                ),
                onPressed: _isSubmitting ? null : _handlePayment,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Proceed to Pay ₹$_payableAmount',
                        style: const TextStyle(
                          fontFamily: 'Switzer',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock, size: 12, color: AppColors.mutedText),
                  const SizedBox(width: 4),
                  Text(
                    'Secured by Cashfree Payments 256-bit SSL',
                    style: AppTypography.metadata,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodChip(String label, IconData icon) {
    final isSelected = _selectedPaymentMethod == label;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedPaymentMethod = label),
        borderRadius: AppRadii.rSm,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.accent.withValues(alpha: 0.1)
                : AppColors.secondaryBackground,
            borderRadius: AppRadii.rSm,
            border: Border.all(
              color: isSelected ? AppColors.accent : AppColors.primaryBorder,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? AppColors.accent : AppColors.mutedText,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Switzer',
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.accent : AppColors.primaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
