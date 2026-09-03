import 'package:flutter/material.dart';
import 'package:agrimore_core/agrimore_core.dart';

/// Renders one AgriMore Product Credit ledger entry with an ACCURATE
/// label and sign for its type — checked against the arithmetic in
/// functions/src/customer/productCreditLedger.ts's applyEntryToProjection
/// (Phase E's mandatory reading), not guessed from the type name alone:
///
///   CREDIT      available += amount              -> earned, "+"
///   REDEMPTION  onHold OR available -= amount     -> spent, "-" either way
///               (settling a hold clears onHold, NOT a second deduction
///               from available — but from a HISTORY perspective this row
///               is still correctly "credit spent on an order")
///   REVERSAL    available += amount               -> refunded, "+"
///   EXPIRY      available -= amount               -> lost (not spent), "-"
///   ADJUSTMENT  available +/- amount per metadata.direction — sign is
///               NEVER inferred from amount's own sign, matching the
///               server's own rule
///   HOLD        available -= amount; onHold += amount  -> NOT a spend,
///               a temporary reservation. Shown NEUTRAL (no +/-), a
///               distinct colour, and a lock icon — coloring this red
///               would misrepresent it as a loss.
///   RELEASE     available += amount; onHold -= amount  -> NOT new money,
///               a reservation being returned. Also shown NEUTRAL.
class ProductCreditLedgerTile extends StatelessWidget {
  final ProductCreditLedgerModel entry;
  final bool isDark;

  const ProductCreditLedgerTile({
    Key? key,
    required this.entry,
    required this.isDark,
  }) : super(key: key);

  static const _amber = Color(0xFFFFA726);
  static const _green = Color(0xFF4CAF50);
  static const _red = Color(0xFFE53935);
  static const _orange = Color(0xFFFF9800);
  static const _blue = Color(0xFF42A5F5);
  static const _teal = Color(0xFF26A69A);

  _TileDisplay _display() {
    switch (entry.type) {
      case ProductCreditLedgerEntryType.credit:
        return _TileDisplay(
          label: 'Product Credit Earned',
          icon: Icons.add_circle_outline,
          color: _green,
          sign: _Sign.positive,
        );
      case ProductCreditLedgerEntryType.redemption:
        return _TileDisplay(
          label: entry.orderId != null && entry.orderId!.isNotEmpty
              ? 'Redeemed on Order'
              : 'Redeemed',
          icon: Icons.shopping_bag_outlined,
          color: _red,
          sign: _Sign.negative,
        );
      case ProductCreditLedgerEntryType.reversal:
        return _TileDisplay(
          label: 'Credit Refunded (Order Cancelled)',
          icon: Icons.replay,
          color: _green,
          sign: _Sign.positive,
        );
      case ProductCreditLedgerEntryType.expiry:
        return _TileDisplay(
          label: 'Credit Expired',
          icon: Icons.event_busy_outlined,
          color: _orange,
          sign: _Sign.negative,
        );
      case ProductCreditLedgerEntryType.hold:
        return _TileDisplay(
          label: 'Reserved for Checkout',
          icon: Icons.lock_clock_outlined,
          color: _amber,
          sign: _Sign.neutral,
        );
      case ProductCreditLedgerEntryType.release:
        return _TileDisplay(
          label: 'Reservation Released',
          icon: Icons.lock_open_outlined,
          color: _teal,
          sign: _Sign.neutral,
        );
      case ProductCreditLedgerEntryType.adjustment:
      default:
        final direction = entry.metadata?['direction'];
        final isDebit = direction == 'debit';
        return _TileDisplay(
          label: 'Balance Correction',
          icon: Icons.build_outlined,
          color: _blue,
          sign: isDebit ? _Sign.negative : _Sign.positive,
        );
    }
  }

  String _formattedAmount(_Sign sign) {
    final formatted = '₹${entry.amount.toStringAsFixed(2)}';
    switch (sign) {
      case _Sign.positive:
        return '+$formatted';
      case _Sign.negative:
        return '-$formatted';
      case _Sign.neutral:
        return formatted;
    }
  }

  // Manual formatting, matching WalletTransactionModel.formattedDate's
  // established style — this app has no direct `intl` dependency.
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formattedDate() {
    final d = entry.createdAt;
    final hour = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final period = d.hour >= 12 ? 'PM' : 'AM';
    final minute = d.minute.toString().padLeft(2, '0');
    return '${_months[d.month - 1]} ${d.day}, $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final display = _display();
    final amountColor = display.sign == _Sign.neutral
        ? (isDark ? Colors.grey[400] : Colors.grey[700])
        : display.color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: display.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(display.icon, color: display.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  display.label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                if (entry.description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    entry.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (entry.orderId != null && entry.orderId!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Order #${entry.orderId}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[500] : Colors.grey[500],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formattedAmount(display.sign),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: amountColor,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _formattedDate(),
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey[500] : Colors.grey[500],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _Sign { positive, negative, neutral }

class _TileDisplay {
  final String label;
  final IconData icon;
  final Color color;
  final _Sign sign;

  const _TileDisplay({
    required this.label,
    required this.icon,
    required this.color,
    required this.sign,
  });
}
