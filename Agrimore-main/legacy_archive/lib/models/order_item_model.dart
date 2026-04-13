class OrderItemModel {
  final String productId;
  final String productName;
  final double price;
  final int quantity;
  final String? imageUrl;

  OrderItemModel({
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'price': price,
      'quantity': quantity,
      'imageUrl': imageUrl,
    };
  }

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      productId: json['productId'] ?? '',
      productName: json['productName'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      quantity: json['quantity'] ?? 0,
      imageUrl: json['imageUrl'],
    );
  }

  // Add bracket operator for backward compatibility
  dynamic operator [](String key) {
    switch (key) {
      case 'productId':
        return productId;
      case 'productName':
        return productName;
      case 'price':
        return price;
      case 'quantity':
        return quantity;
      case 'imageUrl':
        return imageUrl;
      default:
        return null;
    }
  }
}
