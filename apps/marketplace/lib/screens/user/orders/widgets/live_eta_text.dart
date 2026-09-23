// lib/screens/user/orders/widgets/live_eta_text.dart
//
// Phase DLV-3B — the ETA line on the order card and order details: the same
// stage-aware estimate as the live tracking screen (D-DLV-ETA), from the
// rider leg and the rider's live point. Replaces the fixed minutes those
// banners showed per order status. With no estimate (not packed yet, no rider,
// finished) it shows the stage message only.
import 'package:flutter/material.dart';
import 'package:agrimore_core/agrimore_core.dart';
import '../../../../services/delivery_tracking_service.dart';

class LiveEtaText extends StatelessWidget {
  const LiveEtaText({
    super.key,
    required this.orderId,
    required this.orderStatus,
    required this.isDark,
    this.titleSize = 15,
  });

  final String orderId;
  final String orderStatus;
  final bool isDark;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    final service = DeliveryTrackingService();
    return StreamBuilder<DeliveryTaskModel?>(
      stream: service.streamTask(orderId),
      builder: (context, taskSnap) {
        final task = taskSnap.data;
        return StreamBuilder<RiderLivePoint?>(
          stream: service.streamLivePoint(orderId),
          builder: (context, liveSnap) {
            final drop = task?.drop;
            final eta = DeliveryEtaCalculator.estimate(
              status: task?.status,
              rider: liveSnap.data,
              pickup: task?.pickup,
              drop: drop,
              now: DateTime.now(),
            );
            final stage = DeliveryTrackingService.stageMessage(task?.status, orderStatus);
            final title = eta == null ? stage : DeliveryEtaCalculator.label(eta);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                if (eta != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    stage,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}
