import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ChatSystemService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Starts or retrieves an existing chat thread between a customer and a seller.
  Future<String> getOrCreateThread({
    required String customerId,
    required String sellerId,
    required String customerName,
    required String sellerName,
    String? orderId,
  }) async {
    try {
      final threadId = '${customerId}_$sellerId';
      final threadRef = _firestore.collection('threads').doc(threadId);

      final doc = await threadRef.get();
      if (!doc.exists) {
        await threadRef.set({
          'customerId': customerId,
          'sellerId': sellerId,
          'customerName': customerName,
          'sellerName': sellerName,
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'unreadCount': 0,
          'orderId': orderId,
        });
      }
      return threadId;
    } catch (e) {
      debugPrint('Error creating thread: $e');
      rethrow;
    }
  }

  /// Sends a message in a specific thread.
  Future<void> sendMessage({
    required String threadId,
    required String senderId,
    required String text,
    required bool isSeller,
  }) async {
    try {
      final messageRef = _firestore
          .collection('threads')
          .doc(threadId)
          .collection('messages')
          .doc();

      final batch = _firestore.batch();

      // 1. Add message
      batch.set(messageRef, {
        'id': messageRef.id,
        'senderId': senderId,
        'text': text,
        'isSeller': isSeller,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      // 2. Update thread last message
      final threadRef = _firestore.collection('threads').doc(threadId);
      batch.update(threadRef, {
        'lastMessage': text,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount': FieldValue.increment(1),
      });

      await batch.commit();
    } catch (e) {
      debugPrint('Error sending message: $e');
      rethrow;
    }
  }

  /// Streams all messages for a specific thread
  Stream<QuerySnapshot> streamMessages(String threadId) {
    return _firestore
        .collection('threads')
        .doc(threadId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Streams active chat threads for a user (either customer or seller)
  Stream<QuerySnapshot> streamThreads(String userId, {required bool isSeller}) {
    final field = isSeller ? 'sellerId' : 'customerId';
    return _firestore
        .collection('threads')
        .where(field, isEqualTo: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }
}
