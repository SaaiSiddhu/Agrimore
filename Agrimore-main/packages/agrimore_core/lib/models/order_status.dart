enum OrderStatus {
  pending,
  confirmed,
  processing,
  shipped,
  outForDelivery,
  delivered,
  cancelled,
  returned,
  refunded,
}

extension OrderStatusExtension on OrderStatus {
  String get displayName {
    switch (this) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.processing:
        return 'Processing';
      case OrderStatus.shipped:
        return 'Shipped';
      case OrderStatus.outForDelivery:
        return 'Out for Delivery';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.returned:
        return 'Returned';
      case OrderStatus.refunded:
        return 'Refunded';
    }
  }

  String toJson() => name;

  static OrderStatus fromJson(String json) {
    return OrderStatus.values.firstWhere(
      (status) => status.name == json,
      orElse: () => OrderStatus.pending,
    );
  }
}
