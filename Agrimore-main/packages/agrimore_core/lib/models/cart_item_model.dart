import 'package:cloud_firestore/cloud_firestore.dart';

class CartItemModel {
  final String id;
  final String productId;
  final String productName;
  final String productImage;
  final double price;
  final int quantity;
  final String userId;
  final DateTime addedAt;
  
  // Additional fields for enhanced cart
  final String? variant;           // Product variant (size, color, etc)
  final double? originalPrice;     // Original price before discount
  final double discountPercentage; // Discount percentage
  
  // BOGO fields
  final bool isFreeItem;           // Is this a BOGO free item?
  final String? freeItemLabel;     // Label for free item (e.g., "BOGO Free", "Free Gift")
  final String? linkedBuyItemId;   // ID of the buy item this free item is linked to

  CartItemModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productImage,
    required this.price,
    required this.quantity,
    required this.userId,
    required this.addedAt,
    this.variant,
    this.originalPrice,
    this.discountPercentage = 0.0,
    this.isFreeItem = false,
    this.freeItemLabel,
    this.linkedBuyItemId,
  });

  // Calculate subtotal for this item
  double get subtotal => price * quantity;

  // Calculate total discount for this item
  double get totalDiscount {
    if (originalPrice == null) return 0.0;
    return (originalPrice! - price) * quantity;
  }

  // Check if item has discount
  bool get hasDiscount => originalPrice != null && originalPrice! > price;
  
  // Get the image URL (alias for backward compatibility)
  String get imageUrl => productImage;
  
  // ✅ NEW: Generate unique key for cart item (productId + variant)
  String get uniqueKey => variant != null && variant!.isNotEmpty 
      ? '${productId}_$variant' 
      : productId;

  // Factory constructor from Firestore DocumentSnapshot
  factory CartItemModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CartItemModel(
      id: doc.id,
      productId: data['productId'] ?? '',
      productName: data['productName'] ?? '',
      productImage: data['productImage'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      quantity: data['quantity'] ?? 1,
      userId: data['userId'] ?? '',
      addedAt: (data['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      variant: data['variant'],
      originalPrice: data['originalPrice']?.toDouble(),
      discountPercentage: (data['discountPercentage'] ?? 0).toDouble(),
      isFreeItem: data['isFreeItem'] ?? false,
      freeItemLabel: data['freeItemLabel'],
      linkedBuyItemId: data['linkedBuyItemId'],
    );
  }

  // Factory constructor from Map (for nested cart items)
  factory CartItemModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    return CartItemModel(
      id: docId ?? map['id'] ?? '',
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      productImage: map['productImage'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      quantity: map['quantity'] ?? 1,
      userId: map['userId'] ?? '',
      addedAt: map['addedAt'] is Timestamp
          ? (map['addedAt'] as Timestamp).toDate()
          : (map['addedAt'] is DateTime ? map['addedAt'] : DateTime.now()),
      variant: map['variant'],
      originalPrice: map['originalPrice']?.toDouble(),
      discountPercentage: (map['discountPercentage'] ?? 0).toDouble(),
      isFreeItem: map['isFreeItem'] ?? false,
      freeItemLabel: map['freeItemLabel'],
      linkedBuyItemId: map['linkedBuyItemId'],
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'productImage': productImage,
      'price': price,
      'quantity': quantity,
      'userId': userId,
      'addedAt': Timestamp.fromDate(addedAt),
      'variant': variant,
      'originalPrice': originalPrice,
      'discountPercentage': discountPercentage,
      'isFreeItem': isFreeItem,
      'freeItemLabel': freeItemLabel,
      'linkedBuyItemId': linkedBuyItemId,
    };
  }

  // Copy with method for immutability
  CartItemModel copyWith({
    String? id,
    String? productId,
    String? productName,
    String? productImage,
    double? price,
    int? quantity,
    String? userId,
    DateTime? addedAt,
    String? variant,
    double? originalPrice,
    double? discountPercentage,
    bool? isFreeItem,
    String? freeItemLabel,
    String? linkedBuyItemId,
  }) {
    return CartItemModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productImage: productImage ?? this.productImage,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      userId: userId ?? this.userId,
      addedAt: addedAt ?? this.addedAt,
      variant: variant ?? this.variant,
      originalPrice: originalPrice ?? this.originalPrice,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      isFreeItem: isFreeItem ?? this.isFreeItem,
      freeItemLabel: freeItemLabel ?? this.freeItemLabel,
      linkedBuyItemId: linkedBuyItemId ?? this.linkedBuyItemId,
    );
  }

  @override
  String toString() {
    return 'CartItemModel(id: $id, productName: $productName, variant: $variant, quantity: $quantity, price: $price, isFreeItem: $isFreeItem)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CartItemModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
