import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:agrimore_core/agrimore_core.dart';

/// Phase AI-4D — the client-side counterpart to functions/src/seller/
/// aiChatProxy.ts's own `sellerAiChatProxy` (Phase AI-4B). That callable is a
/// thin, stateless relay: it declares 5 tool functions to Gemini
/// (getMySellerProducts, getMySellerProductDetails, getMySellerOrders,
/// getMySellerOrderDetails, getMySellerProfile) but never executes them
/// itself -- when Gemini wants to call one, the callable returns
/// {type: "functionCall", name, args} and expects THIS layer to actually run
/// the query and call it again with a functionResponse turn appended. Before
/// this phase, nothing in the repo did that: apps/seller had no chat screen
/// at all, and the only existing tool-dispatch loop
/// (packages/agrimore_services/lib/ai/ai_chat_service.dart) is hardcoded to
/// the customer-side callable name and the 7 CUSTOMER tool names -- it has no
/// branch for any of these 5 and never calls 'sellerAiChatProxy'.
///
/// Every Firestore read below is scoped to the caller's OWN uid
/// (sellerId == request.auth.uid, or a direct sellers/{uid} doc get), relying
/// entirely on firestore.rules' own EXISTING read grants (orders/{orderId}:
/// resource.data.sellerId == request.auth.uid; sellers/{sellerId}: allow
/// read: if true; products/{productId}: allow read: if true) -- confirmed by
/// reading firestore.rules directly at claim time, not assumed. No rules
/// change is needed or made by this phase.
class SellerAiChatProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final String sessionId = DateTime.now().millisecondsSinceEpoch.toString();
  final List<ChatMessage> _messages = [];
  bool _isSending = false;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isSending => _isSending;

  void seedGreeting() {
    if (_messages.isNotEmpty) return;
    _messages.add(ChatMessage.ai(
      text: '**Hi! I\'m your Agrimore AI Assistant.**\n'
          'Ask me about your products, orders, or profile — for example '
          '"How many orders came in this week?" or "Which of my products are low on stock?"',
      sessionId: sessionId,
      category: 'greeting',
    ));
    notifyListeners();
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isSending) return;

    _messages.add(ChatMessage.user(text: trimmed, sessionId: sessionId));
    _isSending = true;
    notifyListeners();

    try {
      final reply = await _handleGeminiResponse(trimmed);
      _messages.add(reply);
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  /// Re-sends the last question after a failed answer (the error bubble is
  /// removed; the question is asked again).
  Future<void> retryLast() async {
    if (_isSending || _messages.isEmpty || !_messages.last.isError) return;
    _messages.removeLast();
    final index = _messages.lastIndexWhere((m) => m.isUser);
    if (index < 0) return;
    final question = _messages.removeAt(index).text;
    await sendMessage(question);
  }

  List<Map<String, dynamic>> _buildChatHistory() {
    return _messages
        .where((m) => !m.isLoading && !m.isError)
        .map((m) => {
              'role': m.isUser ? 'user' : 'model',
              'parts': [
                {'text': m.text}
              ],
            })
        .toList();
  }

  Future<ChatMessage> _handleGeminiResponse(String msg) async {
    final callable = FirebaseFunctions.instance.httpsCallable('sellerAiChatProxy');

    try {
      final contents = [
        ..._buildChatHistory(),
        {
          'role': 'user',
          'parts': [
            {'text': msg}
          ],
        },
      ];

      final response = await callable.call<Map<String, dynamic>>({'contents': contents});
      final data = response.data;

      if (data['type'] != 'functionCall') {
        final text = data['text'] as String?;
        return ChatMessage.ai(
          text: (text == null || text.isEmpty) ? 'Sorry, no response from AI.' : text,
          sessionId: sessionId,
          category: 'ai_text',
        );
      }

      final name = data['name'] as String;
      final args = Map<String, dynamic>.from(data['args'] as Map? ?? {});
      dev.log('SellerAiChatProvider: function call detected: $name');

      final resultData = await _dispatchTool(name, args, msg);

      final finalContents = [
        ...contents,
        {
          'role': 'model',
          'parts': [
            {
              'functionCall': {'name': name, 'args': args}
            }
          ],
        },
        {
          'role': 'function',
          'parts': [
            {
              'functionResponse': {'name': name, 'response': resultData}
            }
          ],
        },
      ];
      final finalResponse = await callable.call<Map<String, dynamic>>({'contents': finalContents});
      final finalText = finalResponse.data['text'] as String?;

      return ChatMessage.ai(
        text: finalText ?? 'Result from function.',
        sessionId: sessionId,
        category: 'ai_function_response',
        products: resultData['products'] as List<Map<String, dynamic>>?,
        orders: resultData['orders'] as List<Map<String, dynamic>>?,
      );
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'failed-precondition') {
        // "Not connected yet" or "your key was rejected" -- sellerAiChatProxy's
        // own message already says which. Not an error state: AI-4C gives
        // the seller somewhere to connect a provider.
        return ChatMessage.ai(
          text: e.message ?? 'Connect an AI provider in Settings to use the AI Assistant.',
          sessionId: sessionId,
          category: 'ai_offline',
        );
      }
      dev.log('sellerAiChatProxy error: ${e.message}');
      return ChatMessage.error(
        text: 'AI service error: ${e.message}',
        sessionId: sessionId,
        errorMessage: e.message,
      );
    } catch (e, st) {
      dev.log('SellerAiChatProvider: other error', error: e, stackTrace: st);
      return ChatMessage.error(
        text: 'Failed to communicate with AI.',
        sessionId: sessionId,
        errorMessage: e.toString(),
      );
    }
  }

  Future<Map<String, dynamic>> _dispatchTool(
    String name,
    Map<String, dynamic> args,
    String fallbackQuery,
  ) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return {'error': 'Not signed in'};

    switch (name) {
      case 'getMySellerProducts':
        return _getMySellerProducts(
          uid,
          query: args['query'] as String? ?? fallbackQuery,
          limit: (args['limit'] as num?)?.toInt() ?? 10,
        );
      case 'getMySellerProductDetails':
        return _getMySellerProductDetails(uid, args['productId'] as String? ?? '');
      case 'getMySellerOrders':
        return _getMySellerOrders(
          uid,
          limit: (args['limit'] as num?)?.toInt() ?? 5,
          status: args['status'] as String?,
        );
      case 'getMySellerOrderDetails':
        return _getMySellerOrderDetails(uid, args['orderId'] as String? ?? '');
      case 'getMySellerProfile':
        return _getMySellerProfile(uid);
      default:
        dev.log('SellerAiChatProvider: unknown function call: $name');
        return {'error': 'Unknown function'};
    }
  }

  Future<Map<String, dynamic>> _getMySellerProducts(
    String uid, {
    required String query,
    required int limit,
  }) async {
    try {
      final snap = await _firestore
          .collection('products')
          .where('sellerId', isEqualTo: uid)
          .limit(50)
          .get();

      final lowerQuery = query.trim().toLowerCase();
      final matches = snap.docs
          .map((d) => ProductModel.fromMap(d.data(), d.id))
          .where((p) => lowerQuery.isEmpty || p.name.toLowerCase().contains(lowerQuery))
          .take(limit)
          .map((p) => {
                'id': p.id,
                'name': p.name,
                'salePrice': p.salePrice,
                'stock': p.stock,
                // D-AI4D2-SCOPE: stock prediction reuses this threshold
                // rather than a new forecast -- 5 matches inventory.ts's own
                // server-side default (after.lowStockThreshold ?? 5) exactly.
                'lowStockThreshold': p.lowStockThreshold ?? 5,
                'isActive': p.isActive,
                'category': p.categoryName,
              })
          .toList();

      return {'products': matches, 'count': matches.length};
    } catch (e) {
      dev.log('_getMySellerProducts error: $e');
      return {'error': 'Could not load your products right now.'};
    }
  }

  Future<Map<String, dynamic>> _getMySellerProductDetails(String uid, String productId) async {
    if (productId.isEmpty) return {'error': 'No productId given'};
    try {
      final doc = await _firestore.collection('products').doc(productId).get();
      if (!doc.exists) return {'error': 'Product not found'};

      final product = ProductModel.fromMap(doc.data()!, doc.id);
      if (doc.data()!['sellerId'] != uid) {
        // Only ever reachable if Gemini hallucinates a productId that isn't
        // this seller's own -- the tool's own description scopes it to
        // "your own products", but this is the defense-in-depth check that
        // actually enforces that, independent of what Gemini decides to ask.
        return {'error': 'Product not found'};
      }

      return {
        'id': product.id,
        'name': product.name,
        'description': product.description,
        'salePrice': product.salePrice,
        'originalPrice': product.originalPrice,
        'stock': product.stock,
        // D-AI4D2-SCOPE: same server-side default as inventory.ts
        // (after.lowStockThreshold ?? 5), not an invented one.
        'lowStockThreshold': product.lowStockThreshold ?? 5,
        'isActive': product.isActive,
        'category': product.categoryName,
        'rating': product.rating,
        'reviewCount': product.reviewCount,
      };
    } catch (e) {
      dev.log('_getMySellerProductDetails error: $e');
      return {'error': 'Could not load that product right now.'};
    }
  }

  Future<Map<String, dynamic>> _getMySellerOrders(
    String uid, {
    required int limit,
    String? status,
  }) async {
    try {
      Query<Map<String, dynamic>> q =
          _firestore.collection('orders').where('sellerId', isEqualTo: uid);
      if (status != null && status.isNotEmpty) {
        q = q.where('orderStatus', isEqualTo: status);
      }
      final snap = await q.limit(50).get();

      final orders = snap.docs.map((d) => OrderModel.fromMap(d.data(), d.id)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final trimmed = orders
          .take(limit)
          .map((o) => {
                'id': o.id,
                'orderNumber': o.orderNumber,
                'total': o.total,
                'orderStatus': o.orderStatus,
                'paymentStatus': o.paymentStatus,
                'itemCount': o.items.length,
                'createdAt': o.createdAt.toIso8601String(),
              })
          .toList();

      return {'orders': trimmed, 'count': trimmed.length};
    } catch (e) {
      dev.log('_getMySellerOrders error: $e');
      return {'error': 'Could not load your orders right now.'};
    }
  }

  Future<Map<String, dynamic>> _getMySellerOrderDetails(String uid, String orderId) async {
    if (orderId.isEmpty) return {'error': 'No orderId given'};
    try {
      final doc = await _firestore.collection('orders').doc(orderId).get();
      if (!doc.exists) return {'error': 'Order not found'};

      final order = OrderModel.fromMap(doc.data()!, doc.id);
      if (order.sellerId != uid) {
        // Same defense-in-depth as _getMySellerProductDetails above.
        return {'error': 'Order not found'};
      }

      return {
        'id': order.id,
        'orderNumber': order.orderNumber,
        'total': order.total,
        'subtotal': order.subtotal,
        'orderStatus': order.orderStatus,
        'paymentStatus': order.paymentStatus,
        'paymentMethod': order.paymentMethod,
        'items': order.items
            .map((i) => {
                  'productName': i.productName,
                  'quantity': i.quantity,
                  'price': i.price,
                })
            .toList(),
        'createdAt': order.createdAt.toIso8601String(),
      };
    } catch (e) {
      dev.log('_getMySellerOrderDetails error: $e');
      return {'error': 'Could not load that order right now.'};
    }
  }

  Future<Map<String, dynamic>> _getMySellerProfile(String uid) async {
    try {
      final doc = await _firestore.collection('sellers').doc(uid).get();
      if (!doc.exists) return {'error': 'Seller profile not found'};
      final data = doc.data()!;
      return {
        'businessName': data['businessName'],
        'status': data['status'],
        'phone': data['phone'],
        'address': data['address'],
      };
    } catch (e) {
      dev.log('_getMySellerProfile error: $e');
      return {'error': 'Could not load your profile right now.'};
    }
  }
}
