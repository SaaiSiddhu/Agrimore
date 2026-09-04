// lib/screens/admin/coupon/coupon_card.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:agrimore_ui/agrimore_ui.dart';


class CouponCard extends StatelessWidget {
  final CouponModel coupon;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  const CouponCard({
    Key? key,
    required this.coupon,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isExpired = coupon.validTo.isBefore(DateTime.now());
    final usagePercentage = coupon.usageLimit > 0 ? (coupon.usedCount / coupon.usageLimit) * 100 : 0.0;
    final daysUntilExpiry = coupon.validTo.difference(DateTime.now()).inDays;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.95),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header gradient banner area
            Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: 160,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isExpired
                          ? [Colors.red.shade400, Colors.red.shade700]
                          : coupon.isActive
                              ? [AppColors.primary, AppColors.primary.withOpacity(0.7)]
                              : [Colors.grey.shade400, Colors.grey.shade700],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.local_offer_rounded, size: 60, color: Colors.white),
                  ),
                ),
                Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black.withOpacity(0.35), Colors.transparent],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isExpired
                          ? Colors.red.withValues(alpha: 0.9)
                          : coupon.isActive
                              ? Colors.green.withValues(alpha: 0.9)
                              : Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isExpired
                              ? Icons.error_outline_rounded
                              : coupon.isActive
                                  ? Icons.check_circle
                                  : Icons.pause_circle_filled,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isExpired ? 'Expired' : coupon.isActive ? 'Active' : 'Inactive',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Details section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Code row with copy button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        coupon.code,
                        style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary, letterSpacing: 1.3),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: coupon.code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Copied: ${coupon.code}'), duration: const Duration(seconds: 1), behavior: SnackBarBehavior.floating),
                        );
                      },
                      child: const Icon(Icons.copy_rounded, color: Colors.grey, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(coupon.title, style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey.shade800, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(coupon.description, style: AppTextStyles.bodySmall.copyWith(color: Colors.grey.shade600), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 14),

                // Discount chips
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInfoChip(icon: Icons.discount_rounded, label: _getDiscountText(coupon), color: AppColors.primary),
                    if (coupon.minOrderAmount > 0) _buildInfoChip(icon: Icons.shopping_cart_rounded, label: 'Min ₹${coupon.minOrderAmount.toStringAsFixed(0)}', color: Colors.blue),
                    if (coupon.maxDiscountAmount != null) _buildInfoChip(icon: Icons.money_off_rounded, label: 'Max ₹${coupon.maxDiscountAmount!.toStringAsFixed(0)}', color: Colors.orange),
                  ],
                ),

                const SizedBox(height: 14),

                // Stats row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _statItem(Icons.people, 'Used', '${coupon.usedCount}', Colors.blue),
                    _statItem(Icons.inventory_2_rounded, 'Remaining', coupon.usageLimit > 0 ? '${coupon.usageLimit - coupon.usedCount}' : '∞', Colors.green),
                    _statItem(Icons.calendar_today_rounded, 'Days Left', daysUntilExpiry > 0 ? '$daysUntilExpiry' : '0', Colors.orange),
                  ],
                ),

                const SizedBox(height: 16),

                // Toggle + actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Switch(value: coupon.isActive, onChanged: (_) => onToggle(), activeColor: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(coupon.isActive ? 'Enabled' : 'Disabled', style: TextStyle(color: coupon.isActive ? Colors.green : Colors.orange, fontWeight: FontWeight.w600)),
                    ]),
                    Row(children: [
                      Tooltip(message: 'Edit Coupon', child: IconButton(onPressed: onEdit, icon: const Icon(Icons.edit, color: Colors.blueAccent))),
                      Tooltip(message: 'Delete Coupon', child: IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline, color: Colors.redAccent))),
                    ]),
                  ],
                ),

                const SizedBox(height: 10),

                // Expiry container
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isExpired ? Colors.red.shade50 : daysUntilExpiry < 7 ? Colors.orange.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isExpired ? Colors.red.shade200 : daysUntilExpiry < 7 ? Colors.orange.shade200 : Colors.green.shade200),
                  ),
                  child: Row(children: [
                    Icon(isExpired ? Icons.error_rounded : Icons.event_available_rounded, size: 20, color: isExpired ? Colors.red.shade700 : daysUntilExpiry < 7 ? Colors.orange.shade700 : Colors.green.shade700),
                    const SizedBox(width: 8),
                    Expanded(child: Text(isExpired ? 'Expired on ${_formatDate(coupon.validTo)}' : 'Expires on ${_formatDate(coupon.validTo)}', style: AppTextStyles.bodySmall.copyWith(color: isExpired ? Colors.red.shade700 : daysUntilExpiry < 7 ? Colors.orange.shade700 : Colors.green.shade700, fontWeight: FontWeight.w600))),
                  ]),
                ),
              ]),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).moveY(begin: 15, end: 0, curve: Curves.easeOut);
  }

  Widget _buildInfoChip({required IconData icon, required String label, required Color color}) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 6),
      Text(label, style: AppTextStyles.bodySmall.copyWith(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    ]);
  }

  Widget _statItem(IconData icon, String label, String value, Color color) {
    return Column(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(height: 4),
      Text(value, style: AppTextStyles.titleMedium.copyWith(color: color, fontWeight: FontWeight.bold)),
      Text(label, style: AppTextStyles.bodySmall.copyWith(color: Colors.grey.shade600, fontSize: 10)),
    ]);
  }

  String _getDiscountText(CouponModel coupon) {
    switch (coupon.type) {
      case CouponType.percentage:
        return '${coupon.discount.toStringAsFixed(0)}% OFF';
      case CouponType.flat:
        return '₹${coupon.discount.toStringAsFixed(0)} OFF';
      case CouponType.buyOneGetOne:
        return 'BOGO';
    }
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
}