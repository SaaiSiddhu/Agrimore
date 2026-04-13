// lib/screens/admin/marketing/add_coupon_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/themes/app_colors.dart';
import '../../../models/coupon_model.dart';
import '../../../providers/coupon_provider.dart';
import '../../../core/utils/snackbar_helper.dart';
import 'widgets/coupon_form.dart';

class AddCouponScreen extends StatefulWidget {
  final CouponModel? coupon;

  const AddCouponScreen({
    Key? key,
    this.coupon,
  }) : super(key: key);

  @override
  State<AddCouponScreen> createState() => _AddCouponScreenState();
}

class _AddCouponScreenState extends State<AddCouponScreen> {
  bool _isSaving = false;

  Future<void> _handleSubmit(BuildContext context, CouponModel coupon) async {
    final couponProvider = Provider.of<CouponProvider>(context, listen: false);

    setState(() => _isSaving = true);
    try {
      if (widget.coupon == null) {
        await couponProvider.addCoupon(coupon);
        if (context.mounted) {
          Navigator.pop(context);
          SnackbarHelper.showSuccess(context, '✅ Coupon created successfully!');
        }
      } else {
        await couponProvider.updateCoupon(coupon);
        if (context.mounted) {
          Navigator.pop(context);
          SnackbarHelper.showSuccess(context, '✅ Coupon updated successfully!');
        }
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarHelper.showError(
          context,
          '❌ Failed to ${widget.coupon == null ? 'create' : 'update'} coupon: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showCouponInfo(BuildContext context) {
    final coupon = widget.coupon;
    if (coupon == null) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        backgroundColor: Colors.white.withOpacity(0.98),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            color: AppColors.primary, size: 28),
                        const SizedBox(width: 10),
                        Text(
                          'Coupon Information',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildInfoRow('Code', coupon.code),
                    _buildInfoRow('Title', coupon.title),
                    _buildInfoRow('Description', coupon.description),
                    _buildInfoRow('Discount', _formatDiscount(coupon)),
                    _buildInfoRow('Type', coupon.type.name.toUpperCase()),
                    _buildInfoRow('Used Count', '${coupon.usedCount}'),
                    _buildInfoRow('Usage Limit',
                        coupon.usageLimit == 0 ? 'Unlimited' : '${coupon.usageLimit}'),
                    _buildInfoRow('Min Order', '₹${coupon.minOrderAmount}'),
                    _buildInfoRow(
                      'Max Discount',
                      coupon.maxDiscountAmount != null
                          ? '₹${coupon.maxDiscountAmount}'
                          : 'N/A',
                    ),
                    _buildInfoRow(
                        'Status', coupon.isActive ? 'Active' : 'Inactive'),
                    _buildInfoRow('Created On', _formatDate(coupon.createdAt)),
                    _buildInfoRow('Valid From', _formatDate(coupon.validFrom)),
                    _buildInfoRow('Valid To', _formatDate(coupon.validTo)),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Close'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 14),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 12,
              top: 12,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 24),
                color: Colors.black54,
                tooltip: 'Close',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDiscount(CouponModel coupon) {
    switch (coupon.type) {
      case CouponType.percentage:
        return '${coupon.discount}% OFF';
      case CouponType.flat:
        return '₹${coupon.discount} OFF';
      case CouponType.buyOneGetOne:
        return 'BOGO';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(widget.coupon == null ? 'Add Coupon' : 'Edit Coupon'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (widget.coupon != null)
            IconButton(
              icon: const Icon(Icons.info_outline_rounded),
              tooltip: 'Coupon Info',
              onPressed: () => _showCouponInfo(context),
            ),
        ],
      ),
      body: Stack(
        children: [
          CouponForm(
            coupon: widget.coupon,
            onSubmit: (newCoupon) => _handleSubmit(context, newCoupon),
          ),
          if (_isSaving)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final formWidget =
              context.findAncestorStateOfType<_AddCouponScreenState>();
          FocusScope.of(context).unfocus();
        },
        backgroundColor: colorScheme.primary,
        icon: const Icon(Icons.save_rounded),
        label: Text(
          widget.coupon == null ? 'Save Coupon' : 'Update Coupon',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}