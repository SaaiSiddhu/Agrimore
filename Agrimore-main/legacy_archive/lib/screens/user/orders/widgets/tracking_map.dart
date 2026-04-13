import 'package:flutter/material.dart';
import '../../../../app/themes/app_text_styles.dart';

class TrackingMap extends StatelessWidget {
  final String address;
  final String? city;
  final String? state;
  final String? zipCode;

  const TrackingMap({
    Key? key,
    required this.address,
    this.city,
    this.state,
    this.zipCode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // Map placeholder
            Container(
              height: 250,
              color: Colors.grey[100],
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.map_rounded,
                    size: 100,
                    color: Colors.grey[300],
                  ),
                  Positioned(
                    top: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.my_location_rounded,
                            size: 16,
                            color: const Color(0xFF2D7D3C),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Live Tracking',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF2D7D3C),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Address info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 16,
                        color: const Color(0xFF2D7D3C),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Delivery Address',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    address,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (city != null || state != null || zipCode != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        [city, state, zipCode]
                            .where((e) => e != null)
                            .join(', '),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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
