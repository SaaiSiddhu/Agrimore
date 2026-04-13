import 'package:flutter/material.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

class EmptyOrders extends StatelessWidget {
  final VoidCallback? onShopNow;

  const EmptyOrders({
    Key? key,
    this.onShopNow,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF2D7D3C).withValues(alpha: 0.1),
                    const Color(0xFF3DA34E).withOpacity(0.05),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF2D7D3C).withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.shopping_bag_outlined,
                size: 50,
                color: Color(0xFF2D7D3C),
              ),
            ),

            const SizedBox(height: 24),

            // Title
            Text(
              'No Orders Yet',
              style: AppTextStyles.headlineSmall.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),

            const SizedBox(height: 12),

            // Subtitle
            Text(
              'You haven\'t placed any orders yet. Start shopping to see your orders here.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            // CTA Button
            if (onShopNow != null)
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF2D7D3C),
                      Color(0xFF3DA34E),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2D7D3C).withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onShopNow,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.shopping_cart_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Start Shopping',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
