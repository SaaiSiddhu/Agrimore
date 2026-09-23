// lib/screens/user/orders/widgets/delivered_view.dart
//
// Phase DLV-3B — once the order is delivered the map goes away (nothing is
// moving any more) and the screen becomes a receipt, Zomato/Swiggy style: a
// confirmation, when it arrived, who brought it, a prompt to rate, and the
// bill. A cancelled order gets the same shape without the celebration.
import 'package:flutter/material.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'tracking_sections.dart';

class DeliveredView extends StatefulWidget {
  const DeliveredView({
    super.key,
    required this.palette,
    required this.order,
    required this.cancelled,
    required this.deliveredAt,
    required this.onRate,
    required this.onHelp,
    required this.onDone,
  });

  final TrackingPalette palette;
  final OrderModel order;
  final bool cancelled;
  final DateTime? deliveredAt;
  final VoidCallback onRate;
  final VoidCallback onHelp;
  final VoidCallback onDone;

  @override
  State<DeliveredView> createState() => _DeliveredViewState();
}

class _DeliveredViewState extends State<DeliveredView> with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..forward();

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final partner = widget.order.deliveryPartner;
    final color = widget.cancelled ? const Color(0xFF9E9E9E) : kTrackGreen;
    final when = widget.deliveredAt;
    return Scaffold(
      backgroundColor: p.sheet,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 8, 20, 28),
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: widget.onDone,
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      tooltip: 'Back',
                    ),
                  ),
                  ScaleTransition(
                    scale: CurvedAnimation(parent: _pop, curve: Curves.elasticOut),
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: Icon(
                        widget.cancelled ? Icons.close_rounded : Icons.check_rounded,
                        size: 52,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.cancelled ? 'Order cancelled' : 'Order delivered',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.cancelled
                        ? 'Order #${widget.order.orderNumber}'
                        : when == null
                            ? 'Order #${widget.order.orderNumber}'
                            : 'Delivered at ${TimeOfDay.fromDateTime(when.toLocal()).format(context)} · #${widget.order.orderNumber}',
                    style: const TextStyle(fontSize: 14, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (!widget.cancelled)
                  TrackingCard(
                    palette: p,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          partner == null
                              ? 'How was your order?'
                              : '${partner.name} delivered your order',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: p.text),
                        ),
                        const SizedBox(height: 4),
                        Text('Your rating helps us and the store get better',
                            style: TextStyle(fontSize: 13, color: p.subtext)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            for (var i = 0; i < 5; i++)
                              IconButton(
                                onPressed: widget.onRate,
                                tooltip: 'Rate ${i + 1}',
                                icon: const Icon(Icons.star_outline_rounded, size: 30, color: Color(0xFFFFB300)),
                              ),
                          ],
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: widget.onRate,
                            style: FilledButton.styleFrom(
                              backgroundColor: kTrackGreen,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Rate your order',
                                style: TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ],
                    ),
                  ),
                OrderSummaryCard(palette: p, order: widget.order, delivered: !widget.cancelled),
                HelpCard(palette: p, onTap: widget.onHelp),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
