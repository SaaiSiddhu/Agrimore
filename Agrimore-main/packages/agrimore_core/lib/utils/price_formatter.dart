import 'package:intl/intl.dart';

class PriceFormatter {
  static const String currencySymbol = '₹';
  static const String currencyCode = 'INR';
  
  // Format price with currency symbol (e.g., ₹1,234.56)
  static String formatPrice(double price) {
    final formatter = NumberFormat('#,##,##0.00', 'en_IN');
    return '$currencySymbol${formatter.format(price)}';
  }
  
  // Format price without decimals (e.g., ₹1,234)
  static String formatPriceInt(double price) {
    final formatter = NumberFormat('#,##,##0', 'en_IN');
    return '$currencySymbol${formatter.format(price)}';
  }
  
  // Format price without currency symbol
  static String formatPriceWithoutSymbol(double price) {
    final formatter = NumberFormat('#,##,##0.00', 'en_IN');
    return formatter.format(price);
  }
  
  // Format price in compact form (e.g., ₹1.2K, ₹1.5M)
  static String formatPriceCompact(double price) {
    if (price >= 10000000) {
      return '$currencySymbol${(price / 10000000).toStringAsFixed(2)}Cr';
    } else if (price >= 100000) {
      return '$currencySymbol${(price / 100000).toStringAsFixed(2)}L';
    } else if (price >= 1000) {
      return '$currencySymbol${(price / 1000).toStringAsFixed(1)}K';
    } else {
      return formatPriceInt(price);
    }
  }
  
  // Calculate discount percentage
  static int calculateDiscountPercentage(double originalPrice, double salePrice) {
    if (originalPrice <= 0) return 0;
    final discount = ((originalPrice - salePrice) / originalPrice * 100);
    return discount.round();
  }
  
  // Format discount percentage
  static String formatDiscount(double originalPrice, double salePrice) {
    final percentage = calculateDiscountPercentage(originalPrice, salePrice);
    return '$percentage% OFF';
  }
  
  // Calculate discount amount
  static double calculateDiscountAmount(double originalPrice, double salePrice) {
    return originalPrice - salePrice;
  }
  
  // Format discount amount
  static String formatDiscountAmount(double originalPrice, double salePrice) {
    final discount = calculateDiscountAmount(originalPrice, salePrice);
    return 'Save ${formatPrice(discount)}';
  }
  
  // Apply discount percentage to price
  static double applyDiscount(double price, int discountPercentage) {
    return price * (100 - discountPercentage) / 100;
  }
  
  // Calculate tax amount
  static double calculateTax(double price, double taxPercentage) {
    return price * taxPercentage / 100;
  }
  
  // Format tax
  static String formatTax(double price, double taxPercentage) {
    final tax = calculateTax(price, taxPercentage);
    return formatPrice(tax);
  }
  
  // Calculate final price with tax
  static double calculatePriceWithTax(double price, double taxPercentage) {
    return price + calculateTax(price, taxPercentage);
  }
  
  // Format price with tax
  static String formatPriceWithTax(double price, double taxPercentage) {
    final finalPrice = calculatePriceWithTax(price, taxPercentage);
    return formatPrice(finalPrice);
  }
  
  // Calculate total from items
  static double calculateTotal(List<double> prices) {
    return prices.fold(0.0, (sum, price) => sum + price);
  }
  
  // Format cart total
  static String formatCartTotal(List<double> prices) {
    final total = calculateTotal(prices);
    return formatPrice(total);
  }
  
  // Calculate average price
  static double calculateAverage(List<double> prices) {
    if (prices.isEmpty) return 0.0;
    return calculateTotal(prices) / prices.length;
  }
  
  // Format price range
  static String formatPriceRange(double minPrice, double maxPrice) {
    return '${formatPrice(minPrice)} - ${formatPrice(maxPrice)}';
  }
  
  // Check if price is valid
  static bool isValidPrice(double price) {
    return price >= 0;
  }
  
  // Round price to nearest rupee
  static double roundPrice(double price) {
    return price.roundToDouble();
  }
  
  // Round price up
  static double roundPriceUp(double price) {
    return price.ceilToDouble();
  }
  
  // Round price down
  static double roundPriceDown(double price) {
    return price.floorToDouble();
  }
  
  // Format price for input field
  static String formatForInput(double price) {
    return price.toStringAsFixed(2);
  }
  
  // Parse price from string
  static double? parsePrice(String priceString) {
    try {
      // Remove currency symbol and commas
      final cleanString = priceString
          .replaceAll(currencySymbol, '')
          .replaceAll(',', '')
          .trim();
      return double.parse(cleanString);
    } catch (e) {
      return null;
    }
  }
  
  // Calculate price per unit
  static double calculatePricePerUnit(double totalPrice, int quantity) {
    if (quantity <= 0) return 0.0;
    return totalPrice / quantity;
  }
  
  // Format price per unit
  static String formatPricePerUnit(double totalPrice, int quantity) {
    final pricePerUnit = calculatePricePerUnit(totalPrice, quantity);
    return '${formatPrice(pricePerUnit)}/unit';
  }
  
  // Calculate final checkout price
  static double calculateCheckoutTotal({
    required double subtotal,
    required double discount,
    required double deliveryCharge,
    double tax = 0.0,
  }) {
    return subtotal - discount + deliveryCharge + tax;
  }
  
  // Format checkout breakdown
  static Map<String, String> formatCheckoutBreakdown({
    required double subtotal,
    required double discount,
    required double deliveryCharge,
    double tax = 0.0,
  }) {
    final total = calculateCheckoutTotal(
      subtotal: subtotal,
      discount: discount,
      deliveryCharge: deliveryCharge,
      tax: tax,
    );
    
    return {
      'subtotal': formatPrice(subtotal),
      'discount': formatPrice(discount),
      'deliveryCharge': formatPrice(deliveryCharge),
      'tax': formatPrice(tax),
      'total': formatPrice(total),
    };
  }
  
  // Check if delivery is free
  static bool isFreeDelivery(double orderAmount, double freeDeliveryThreshold) {
    return orderAmount >= freeDeliveryThreshold;
  }
  
  // Calculate amount needed for free delivery
  static double amountNeededForFreeDelivery(
    double currentAmount,
    double freeDeliveryThreshold,
  ) {
    final needed = freeDeliveryThreshold - currentAmount;
    return needed > 0 ? needed : 0;
  }
  
  // Format free delivery message
  static String formatFreeDeliveryMessage(
    double currentAmount,
    double freeDeliveryThreshold,
  ) {
    if (isFreeDelivery(currentAmount, freeDeliveryThreshold)) {
      return 'You have free delivery!';
    }
    
    final needed = amountNeededForFreeDelivery(
      currentAmount,
      freeDeliveryThreshold,
    );
    return 'Add ${formatPrice(needed)} more for free delivery';
  }
}
