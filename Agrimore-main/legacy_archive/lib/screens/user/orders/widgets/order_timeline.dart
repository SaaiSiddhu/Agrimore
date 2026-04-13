import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../models/order_timeline_model.dart';
import '../../../../app/themes/app_text_styles.dart';

class OrderTimeline extends StatelessWidget {
  final List<OrderTimelineModel> timeline;

  const OrderTimeline({
    Key? key,
    required this.timeline,
  }) : super(key: key);

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFFFA500);
      case 'confirmed':
        return const Color(0xFF2196F3);
      case 'processing':
        return const Color(0xFF9C27B0);
      case 'shipped':
        return const Color(0xFF00BCD4);
      case 'outfordelivery':
        return const Color(0xFF00BCD4);
      case 'delivered':
        return const Color(0xFF4CAF50);
      case 'cancelled':
        return const Color(0xFFF44336);
      case 'returned':
        return const Color(0xFFFF9800);
      case 'refunded':
        return const Color(0xFFFF6F00);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (timeline.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'No timeline events yet',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: timeline.length,
      itemBuilder: (context, index) {
        final event = timeline[index];
        final isLast = index == timeline.length - 1;
        final color = _getStatusColor(event.status.name);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline line
            Column(
              children: [
                // Circle
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.8)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                // Line
                if (!isLast)
                  Container(
                    width: 3,
                    height: 60,
                    color: color.withValues(alpha: 0.3),
                  ),
              ],
            ),

            const SizedBox(width: 16),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      event.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      DateFormat('MMM dd, yyyy • hh:mm a')
                          .format(event.timestamp),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (!isLast) const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
