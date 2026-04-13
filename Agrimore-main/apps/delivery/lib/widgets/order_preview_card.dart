// lib/widgets/order_preview_card.dart
import 'package:flutter/material.dart';
import 'package:agrimore_core/agrimore_core.dart';
import '../services/distance_service.dart';

/// Compact order card with distance and earnings preview
class OrderPreviewCard extends StatelessWidget {
  final OrderModel order;
  final double? distanceKm;
  final VoidCallback onTap;

  const OrderPreviewCard({
    super.key,
    required this.order,
    this.distanceKm,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final distance = distanceKm ?? 0;
    final earnings = DistanceService.calculateEarnings(distance);
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outline.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Status bar
            Container(
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary,
                    colorScheme.primary.withOpacity(0.5),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Header Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '#${order.orderNumber.substring(order.orderNumber.length > 6 ? order.orderNumber.length - 6 : 0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          order.deliveryAddress.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '₹${order.total.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Address
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 16,
                        color: Colors.red.shade400,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          order.deliveryAddress.fullAddress,
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Distance & Earnings Row
                  Row(
                    children: [
                      // Distance Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.route_rounded, size: 14, color: Colors.blue.shade600),
                            const SizedBox(width: 4),
                            Text(
                              DistanceService.formatDistance(distance),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      
                      // Earnings Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.currency_rupee_rounded, size: 14, color: Colors.green.shade600),
                            const SizedBox(width: 2),
                            Text(
                              earnings.toStringAsFixed(2),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      
                      // Items count
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${order.items.length} items',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      
                      const Spacer(),
                      
                      // View button
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
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
