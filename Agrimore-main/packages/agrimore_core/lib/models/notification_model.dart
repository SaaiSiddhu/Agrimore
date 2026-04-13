import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  order,
  promotion,
  system,
  product,
  payment,
  delivery,
}

class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String body;
  final NotificationType type;
  final String? imageUrl;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime createdAt;
  final String? actionUrl;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.imageUrl,
    this.data,
    this.isRead = false,
    required this.createdAt,
    this.actionUrl,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    return NotificationModel(
      id: id,
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.toString() == 'NotificationType.${map['type']}',
        orElse: () => NotificationType.system,
      ),
      imageUrl: map['imageUrl'],
      data: map['data'],
      isRead: map['isRead'] ?? false,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      actionUrl: map['actionUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'body': body,
      'type': type.toString().split('.').last,
      'imageUrl': imageUrl,
      'data': data,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
      'actionUrl': actionUrl,
    };
  }

  // Get type display name
  String get typeDisplayName {
    switch (type) {
      case NotificationType.order:
        return 'Order Update';
      case NotificationType.promotion:
        return 'Promotion';
      case NotificationType.system:
        return 'System';
      case NotificationType.product:
        return 'Product';
      case NotificationType.payment:
        return 'Payment';
      case NotificationType.delivery:
        return 'Delivery';
    }
  }

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    NotificationType? type,
    String? imageUrl,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? createdAt,
    String? actionUrl,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      imageUrl: imageUrl ?? this.imageUrl,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      actionUrl: actionUrl ?? this.actionUrl,
    );
  }
}
