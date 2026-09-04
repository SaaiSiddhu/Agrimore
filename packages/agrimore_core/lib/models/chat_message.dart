// lib/models/chat_message.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

enum MessageType { user, ai, system, loading, error }

class ChatMessage {
  final String id;
  final String text;
  final String sessionId;
  final MessageType messageType;
  final DateTime timestamp;
  final List<Map<String, dynamic>>? products;
  final List<Map<String, dynamic>>? orders;
  final List<String>? quickReplies;
  final String? replyTo;
  final String category;
  final Map<String, dynamic>? data;
  final int? rating;
  final String? ratingFeedback;
  final bool isBookmarked;
  final Map<String, int>? reactions;
  final String? errorMessage;

  ChatMessage({
    required this.id,
    required this.text,
    required this.sessionId,
    required this.messageType,
    required this.timestamp,
    this.products,
    this.orders,
    this.quickReplies,
    this.replyTo,
    this.category = 'general',
    this.data,
    this.rating,
    this.ratingFeedback,
    this.isBookmarked = false,
    this.reactions,
    this.errorMessage,
  });

  // Factory constructors
  factory ChatMessage.user({
    required String text,
    required String sessionId,
    String? replyTo,
    String category = 'user_query',
  }) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      sessionId: sessionId,
      messageType: MessageType.user,
      timestamp: DateTime.now(),
      replyTo: replyTo,
      category: category,
    );
  }

  factory ChatMessage.ai({
    required String text,
    required String sessionId,
    List<Map<String, dynamic>>? products,
    List<Map<String, dynamic>>? orders,
    List<String>? quickReplies,
    String category = 'ai_response',
    Map<String, dynamic>? data,
  }) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      sessionId: sessionId,
      messageType: MessageType.ai,
      timestamp: DateTime.now(),
      products: products,
      orders: orders,
      quickReplies: quickReplies,
      category: category,
      data: data,
    );
  }

  factory ChatMessage.loading({
    required String sessionId,
    String category = 'system',
  }) {
    return ChatMessage(
      id: 'loading_${DateTime.now().millisecondsSinceEpoch}',
      text: '',
      sessionId: sessionId,
      messageType: MessageType.loading,
      timestamp: DateTime.now(),
      category: category,
    );
  }

  factory ChatMessage.error({
    required String text,
    required String sessionId,
    String? errorMessage,
    String category = 'error',  // ADD DEFAULT PARAMETER
  }) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      sessionId: sessionId,
      messageType: MessageType.error,
      timestamp: DateTime.now(),
      category: category,
      errorMessage: errorMessage,
    );
  }

  // Getters
  bool get isUser => messageType == MessageType.user;
  bool get isAI => messageType == MessageType.ai;
  bool get isError => messageType == MessageType.error;
  bool get isLoading => messageType == MessageType.loading;
  bool get isRated => rating != null;
  bool get hasProducts => products?.isNotEmpty ?? false;
  bool get hasOrders => orders?.isNotEmpty ?? false;
  bool get hasQuickReplies => quickReplies?.isNotEmpty ?? false;
  bool get hasSuggestions => data?['suggestions'] != null;
  int get productCount => products?.length ?? 0;

  String get formattedTime => DateFormat('hh:mm a').format(timestamp);

  // Firestore conversion
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'sessionId': sessionId,
      'messageType': messageType.name,
      'timestamp': Timestamp.fromDate(timestamp),
      'products': products,
      'orders': orders,
      'quickReplies': quickReplies,
      'replyTo': replyTo,
      'category': category,
      'data': data,
      'rating': rating,
      'ratingFeedback': ratingFeedback,
      'isBookmarked': isBookmarked,
      'reactions': reactions,
      'errorMessage': errorMessage,
    };
  }

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return ChatMessage(
      id: data['id'] ?? doc.id,
      text: data['text'] ?? '',
      sessionId: data['sessionId'] ?? '',
      messageType: MessageType.values.firstWhere(
        (e) => e.name == data['messageType'],
        orElse: () => MessageType.system,
      ),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      products: (data['products'] as List?)?.cast<Map<String, dynamic>>(),
      orders: (data['orders'] as List?)?.cast<Map<String, dynamic>>(),
      quickReplies: (data['quickReplies'] as List?)?.cast<String>(),
      replyTo: data['replyTo'],
      category: data['category'] ?? 'general',
      data: data['data'] as Map<String, dynamic>?,
      rating: data['rating'],
      ratingFeedback: data['ratingFeedback'],
      isBookmarked: data['isBookmarked'] ?? false,
      reactions: (data['reactions'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, value as int),
      ),
      errorMessage: data['errorMessage'],
    );
  }

  ChatMessage copyWith({
    String? text,
    List<Map<String, dynamic>>? products,
    List<Map<String, dynamic>>? orders,
    List<String>? quickReplies,
    int? rating,
    String? ratingFeedback,
    bool? isBookmarked,
    Map<String, int>? reactions,
  }) {
    return ChatMessage(
      id: id,
      text: text ?? this.text,
      sessionId: sessionId,
      messageType: messageType,
      timestamp: timestamp,
      products: products ?? this.products,
      orders: orders ?? this.orders,
      quickReplies: quickReplies ?? this.quickReplies,
      replyTo: replyTo,
      category: category,
      data: data,
      rating: rating ?? this.rating,
      ratingFeedback: ratingFeedback ?? this.ratingFeedback,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      reactions: reactions ?? this.reactions,
      errorMessage: errorMessage,
    );
  }
}
