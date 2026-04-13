import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../../providers/theme_provider.dart';

class DeliveryInfoWidget extends StatefulWidget {
  final String productId;

  const DeliveryInfoWidget({
    Key? key,
    required this.productId,
  }) : super(key: key);

  @override
  State<DeliveryInfoWidget> createState() => _DeliveryInfoWidgetState();
}

class _DeliveryInfoWidgetState extends State<DeliveryInfoWidget> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('products').doc(widget.productId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState(isDark);
        }

        Map<String, dynamic> productData = {};
        if (snapshot.hasData && snapshot.data!.exists) {
          productData = snapshot.data!.data() as Map<String, dynamic>;
        }

        // Extract delivery data with defaults
        final shippingDays = productData['shippingDays'] ?? '2-3';
        final shippingPrice = productData['shippingPrice'] ?? 0;
        final freeShippingAbove = productData['freeShippingAbove'] ?? 500;
        final isFreeDelivery = productData['isFreeDelivery'] ?? true;
        final expressDelivery = productData['expressDelivery'] ?? false;
        final expressDeliveryDays = productData['expressDeliveryDays'] ?? '1';

        return _buildDeliveryInfo(
          isDark: isDark,
          shippingDays: shippingDays,
          shippingPrice: shippingPrice,
          freeShippingAbove: freeShippingAbove,
          isFreeDelivery: isFreeDelivery,
          expressDelivery: expressDelivery,
          expressDeliveryDays: expressDeliveryDays,
        );
      },
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return _buildCardSection(
      title: 'Delivery Options',
      icon: Icons.local_shipping_outlined,
      isDark: isDark,
      child: Container(
        height: 100, // Placeholder height
        alignment: Alignment.center,
        child: SizedBox(
          width: 24, 
          height: 24, 
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: isDark ? AppColors.primaryLight : AppColors.primary,
          )
        ),
      ),
    );
  }

  Widget _buildDeliveryInfo({
    required bool isDark,
    required String shippingDays,
    required dynamic shippingPrice,
    required dynamic freeShippingAbove,
    required bool isFreeDelivery,
    required bool expressDelivery,
    required String expressDeliveryDays,
  }) {
    final price = shippingPrice is int ? shippingPrice : (shippingPrice is double ? shippingPrice.toInt() : 0);
    final freeAbove = freeShippingAbove is int ? freeShippingAbove : (freeShippingAbove is double ? freeShippingAbove.toInt() : 500);

    // Calculate delivery date
    final deliveryDate = _calculateDeliveryDate(shippingDays);
    final expressDate = expressDelivery ? _calculateDeliveryDate(expressDeliveryDays) : null;

    return _buildCardSection(
      title: 'Delivery Options',
      icon: Icons.local_shipping_outlined,
      isDark: isDark,
      child: Column(
        children: [
          _buildDeliveryOption(
            icon: Icons.local_shipping,
            iconColor: isDark ? Colors.blue[300]! : Colors.blue[700]!,
            title: 'Standard Delivery',
            subtitle: deliveryDate,
            trailing: (isFreeDelivery || shippingPrice == 0)
                ? 'FREE'
                : '₹$price',
            isDark: isDark,
          ),
          if (!isFreeDelivery && shippingPrice > 0)
            Padding(
              padding: const EdgeInsets.only(left: 54, right: 16, bottom: 12, top: 4),
              child: Text(
                'Free delivery on orders above ₹$freeAbove',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
          if (expressDelivery && expressDate != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Divider(color: isDark ? Colors.grey[800] : Colors.grey[200]),
            ),
            _buildDeliveryOption(
              icon: Icons.flash_on_rounded,
              iconColor: isDark ? Colors.orange[300]! : Colors.orange[700]!,
              title: 'Express Delivery',
              subtitle: expressDate,
              trailing: '₹49', // Example price
              isDark: isDark,
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildDeliveryOption({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String trailing,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // You can add logic here if these are selectable
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.grey[400] : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                trailing,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: (trailing == 'FREE')
                      ? (isDark ? Colors.green[300] : Colors.green[700])
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardSection({
    required String title,
    required IconData icon,
    required Widget child,
    required bool isDark,
  }) {
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Row(
              children: [
                Icon(icon, color: accentColor, size: 20),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Divider(color: isDark ? Colors.grey[800]! : Colors.grey[200], height: 1),
          child,
        ],
      ),
    );
  }

  String _calculateDeliveryDate(String daysStr) {
    try {
      int days = int.parse(daysStr.split('-')[0]);
      final now = DateTime.now();
      final deliveryDate = now.add(Duration(days: days));
      
      final formatter = DateFormat('EEEE, d MMMM');
      return formatter.format(deliveryDate);
    } catch (e) {
      return 'In $daysStr business days';
    }
  }
}