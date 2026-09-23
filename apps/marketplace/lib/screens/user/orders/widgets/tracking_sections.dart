// lib/screens/user/orders/widgets/tracking_sections.dart
//
// Phase DLV-3B — the parts of the live tracking sheet, Zomato/Swiggy style:
// a stage stepper, the delivery code to share, the rider, how to pay, where
// it is going, what is in it, and help. Plain widgets fed by the screen —
// no Firestore here.
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:agrimore_core/agrimore_core.dart';

const Color kTrackGreen = Color(0xFF2D7D3C);

class TrackingPalette {
  const TrackingPalette(this.isDark);
  final bool isDark;
  Color get card => isDark ? const Color(0xFF1E1E1E) : Colors.white;
  Color get cardBorder => isDark ? const Color(0xFF2E2E2E) : const Color(0xFFEDEDED);
  Color get text => isDark ? Colors.white : const Color(0xFF1C1C1C);
  Color get subtext => isDark ? const Color(0xFFB0B0B0) : const Color(0xFF6B6B6B);
  Color get muted => isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE3E3E3);
  Color get sheet => isDark ? const Color(0xFF121212) : const Color(0xFFF6F6F6);
}

class TrackingCard extends StatelessWidget {
  const TrackingCard({super.key, required this.palette, required this.child, this.padding = const EdgeInsets.all(16)});
  final TrackingPalette palette;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: padding,
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.cardBorder),
        ),
        child: child,
      );
}

/// Order placed → Packed → Picked up → Delivered, with the time each step
/// was reached where the rider leg recorded it.
class TrackingStepper extends StatelessWidget {
  const TrackingStepper({
    super.key,
    required this.palette,
    required this.taskStatus,
    required this.orderStatus,
    required this.stepAt,
    required this.placedAt,
  });

  final TrackingPalette palette;
  final DeliveryTaskStatus? taskStatus;
  final String orderStatus;
  final Map<String, DateTime> stepAt;
  final DateTime? placedAt;

  /// 0 placed, 1 packed (waiting for / with a rider), 2 picked up, 3 delivered.
  static int currentStep(DeliveryTaskStatus? task, String orderStatus) {
    switch (task) {
      case DeliveryTaskStatus.searching:
      case DeliveryTaskStatus.assigned:
      case DeliveryTaskStatus.atPickup:
        return 1;
      case DeliveryTaskStatus.pickedUp:
      case DeliveryTaskStatus.enRoute:
      case DeliveryTaskStatus.atDrop:
      case DeliveryTaskStatus.failedAttempt:
        return 2;
      case DeliveryTaskStatus.delivered:
        return 3;
      default:
        break;
    }
    switch (orderStatus.toLowerCase()) {
      case 'ready_for_pickup':
      case 'delivery_accepted':
      case 'arrived_at_store':
        return 1;
      case 'picked_up':
      case 'shipped':
      case 'out_for_delivery':
        return 2;
      case 'delivered':
        return 3;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = currentStep(taskStatus, orderStatus);
    final labels = ['Order placed', 'Packed', 'Picked up', 'Delivered'];
    final times = <DateTime?>[
      placedAt,
      stepAt['searching'] ?? stepAt['assigned'],
      stepAt['picked_up'] ?? stepAt['en_route'],
      stepAt['delivered'],
    ];
    return TrackingCard(
      palette: palette,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            Expanded(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 3,
                          color: i == 0 ? Colors.transparent : (i <= current ? kTrackGreen : palette.muted),
                        ),
                      ),
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i <= current ? kTrackGreen : palette.card,
                          border: Border.all(color: i <= current ? kTrackGreen : palette.muted, width: 2),
                        ),
                        child: i < current
                            ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                            : i == current
                                ? const Icon(Icons.circle, size: 8, color: Colors.white)
                                : null,
                      ),
                      Expanded(
                        child: Container(
                          height: 3,
                          color: i == labels.length - 1 ? Colors.transparent : (i < current ? kTrackGreen : palette.muted),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: i == current ? FontWeight.w800 : FontWeight.w500,
                      color: i <= current ? palette.text : palette.subtext,
                    ),
                  ),
                  if (i <= current && times[i] != null)
                    Text(
                      TimeOfDay.fromDateTime(times[i]!.toLocal()).format(context),
                      style: TextStyle(fontSize: 11, color: palette.subtext),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The code the customer reads out at the door (DLV-0: from the order's
/// secrets document, which only the customer and admin can read).
class DeliveryCodeCard extends StatelessWidget {
  const DeliveryCodeCard({super.key, required this.palette, required this.code});
  final TrackingPalette palette;
  final String code;

  @override
  Widget build(BuildContext context) => TrackingCard(
        palette: palette,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kTrackGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.lock_outline_rounded, color: kTrackGreen),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Delivery code',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: palette.text)),
                  const SizedBox(height: 2),
                  Text('Share it with your delivery partner only at your door',
                      style: TextStyle(fontSize: 12, color: palette.subtext)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              code.split('').join(' '),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                color: kTrackGreen,
              ),
            ),
          ],
        ),
      );
}

class RiderCard extends StatelessWidget {
  const RiderCard({
    super.key,
    required this.palette,
    required this.partner,
    required this.onCall,
    required this.onMessage,
  });

  final TrackingPalette palette;
  final DeliveryPartnerModel partner;
  final VoidCallback onCall;
  final VoidCallback onMessage;

  String get _vehicle {
    final t = partner.vehicleType.toLowerCase();
    final kind = t == 'ev' ? 'EV' : t.isEmpty ? 'Bike' : '${t[0].toUpperCase()}${t.substring(1)}';
    return partner.vehicleNumber.isEmpty ? kind : '$kind · ${partner.vehicleNumber}';
  }

  @override
  Widget build(BuildContext context) => TrackingCard(
        palette: palette,
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: kTrackGreen.withValues(alpha: 0.12),
              backgroundImage: partner.photoUrl != null && partner.photoUrl!.isNotEmpty
                  ? CachedNetworkImageProvider(partner.photoUrl!)
                  : null,
              child: partner.photoUrl == null || partner.photoUrl!.isEmpty
                  ? Text(
                      partner.name.isEmpty ? '?' : partner.name[0].toUpperCase(),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kTrackGreen),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(partner.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: palette.text)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 15, color: Color(0xFFFFB300)),
                      const SizedBox(width: 2),
                      Text(partner.formattedRating,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: palette.text)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(_vehicle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: palette.subtext)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _RoundAction(icon: Icons.chat_bubble_outline_rounded, tooltip: 'Message', onTap: onMessage),
            const SizedBox(width: 8),
            _RoundAction(icon: Icons.call_rounded, tooltip: 'Call', onTap: onCall, filled: true),
          ],
        ),
      );
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.icon, required this.tooltip, required this.onTap, this.filled = false});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: filled ? kTrackGreen : kTrackGreen.withValues(alpha: 0.12),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(11),
              child: Icon(icon, size: 20, color: filled ? Colors.white : kTrackGreen),
            ),
          ),
        ),
      );
}

/// Waiting for a rider: what is happening instead of an empty rider card.
class RiderPendingCard extends StatelessWidget {
  const RiderPendingCard({super.key, required this.palette, required this.message});
  final TrackingPalette palette;
  final String message;

  @override
  Widget build(BuildContext context) => TrackingCard(
        palette: palette,
        child: Row(
          children: [
            const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: kTrackGreen)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(message, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: palette.text)),
            ),
          ],
        ),
      );
}

bool isCashOnDelivery(String method) {
  final m = method.toLowerCase();
  return m == 'cod' || m == 'cash_on_delivery' || m.contains('cash');
}

String rupees(double v) => '₹${v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2)}';

class OrderSummaryCard extends StatelessWidget {
  const OrderSummaryCard({
    super.key,
    required this.palette,
    required this.order,
    this.showAddress = true,
    this.delivered = false,
  });
  final TrackingPalette palette;
  final OrderModel order;
  final bool showAddress;

  /// Past tense once the order has arrived (the receipt view).
  final bool delivered;

  @override
  Widget build(BuildContext context) {
    final cod = isCashOnDelivery(order.paymentMethod);
    final a = order.deliveryAddress;
    return TrackingCard(
      palette: palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showAddress) ...[
            _row(Icons.home_rounded, '${delivered ? 'Delivered' : 'Delivering'} to ${a.name}', a.fullAddress),
            Divider(height: 24, color: palette.cardBorder),
          ],
          _row(
            cod ? Icons.payments_rounded : Icons.verified_rounded,
            cod
                ? (delivered ? 'Paid ${rupees(order.total)} in cash' : 'Pay ${rupees(order.total)} in cash')
                : 'Paid ${rupees(order.total)}',
            cod
                ? (delivered ? 'Cash on delivery' : 'Keep the exact amount ready if you can')
                : 'Paid online · ${order.paymentMethod.toUpperCase()}',
            highlight: cod && !delivered,
          ),
          Divider(height: 24, color: palette.cardBorder),
          Text('Order #${order.orderNumber}',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: palette.text)),
          const SizedBox(height: 8),
          for (final item in order.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      border: Border.all(color: palette.muted),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('${item.quantity}×',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: palette.subtext)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(item.productName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: palette.text)),
                  ),
                  Text(rupees(item.price * item.quantity), style: TextStyle(fontSize: 13, color: palette.subtext)),
                ],
              ),
            ),
          Divider(height: 20, color: palette.cardBorder),
          Row(
            children: [
              Text('Total', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: palette.text)),
              const Spacer(),
              Text(rupees(order.total),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: palette.text)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String title, String subtitle, {bool highlight = false}) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: highlight ? const Color(0xFFE65100) : kTrackGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: highlight ? const Color(0xFFE65100) : palette.text)),
                const SizedBox(height: 2),
                Text(subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: palette.subtext)),
              ],
            ),
          ),
        ],
      );
}

class HelpCard extends StatelessWidget {
  const HelpCard({super.key, required this.palette, required this.onTap});
  final TrackingPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: TrackingCard(
            palette: palette,
            child: Row(
              children: [
                const Icon(Icons.support_agent_rounded, color: kTrackGreen),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Need help with this order?',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: palette.text)),
                ),
                Icon(Icons.chevron_right_rounded, color: palette.subtext),
              ],
            ),
          ),
        ),
      );
}
