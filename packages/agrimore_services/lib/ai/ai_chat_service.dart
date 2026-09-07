// lib/services/ai_chat_service.dart
import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:agrimore_core/agrimore_core.dart';

class AIChatService {
  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;

  String currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
  final List<ChatMessage> context = [];
  Map<String, dynamic>? userProfileCache;

  // Phase AI-2: the seven tool declarations that used to live here (as
  // google_generative_ai Tool/FunctionDeclaration/Schema objects passed
  // straight into a client-side GenerativeModel) now live server-side, as
  // the source of truth, in functions/src/customer/aiChatProxy.ts's TOOLS
  // constant — never client-supplied, per the codebase's standing rule that
  // nothing the client sends is trusted as authoritative. Keep the two in
  // sync by hand; there is no shared schema between the Dart and TypeScript
  // copies of "which seven functions the assistant may call."

  void startNewSession() {
    currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
    context.clear();
    userProfileCache = null;
    dev.log('startNewSession: $currentSessionId');
  }

  Future<void> saveMessage(ChatMessage message) async {
    context.add(message);
    final user = auth.currentUser;
    if (user == null) return;

    try {
      await firestore
          .collection('users')
          .doc(user.uid)
          .collection('chats')
          .doc(currentSessionId)
          .collection('messages')
          .doc(message.id)
          .set(message.toMap(), SetOptions(merge: true));
    } catch (e, st) {
      dev.log('saveMessage: error', error: e, stackTrace: st);
    }
  }

  Future<List<ChatMessage>> loadSessionHistory(String sessionId) async {
    final user = auth.currentUser;
    if (user == null) return [];

    currentSessionId = sessionId;
    try {
      final snap = await firestore
          .collection('users')
          .doc(user.uid)
          .collection('chats')
          .doc(sessionId)
          .collection('messages')
          .orderBy('timestamp')
          .get();

      final messages = snap.docs.map((d) {
        try {
          return ChatMessage.fromFirestore(d);
        } catch (e) {
          dev.log('loadSessionHistory: parse error for ${d.id}', error: e);
          return ChatMessage.error(
            text: 'Data error, unable to display message.',
            sessionId: sessionId,
          );
        }
      }).toList();

      context.clear();
      context.addAll(messages);
      userProfileCache = null;
      await primeCaches();
      return messages;
    } catch (e, st) {
      dev.log('loadSessionHistory: error', error: e, stackTrace: st);
      return [];
    }
  }

  Future<ChatMessage> processUserMessage(
    String msg, {
    List<ChatMessage>? conversationHistory,
  }) async {
    try {
      return await handleGeminiResponse(msg, conversationHistory);
    } catch (e, st) {
      dev.log('processUserMessage: error', error: e, stackTrace: st);
      return ChatMessage.error(
        text: 'Error encountered while processing.',
        sessionId: currentSessionId,
      );
    }
  }

  // Phase AI-2: this method used to instantiate a GenerativeModel directly
  // with GeminiConfig.apiKey (empty and dormant since Phase 21, finding
  // 19-B: that key was committed to git and shipped in every Play build).
  // It now calls the aiChatProxy Cloud Function, which holds the caller's
  // OWN connected key server-side (AI-1) and does the actual Gemini REST
  // call. The two-call function-calling sequence (initial message -> maybe
  // a function call -> function result -> final text) is unchanged in
  // SHAPE; only WHERE the outbound Gemini call happens has moved. Every
  // handleXxx Firestore lookup below is untouched — those were never the
  // exposed secret, only the API key was.
  Future<ChatMessage> handleGeminiResponse(
    String msg,
    List<ChatMessage>? history,
  ) async {
    final callable = FirebaseFunctions.instance.httpsCallable('aiChatProxy');

    try {
      final chatHistory = await buildChatHistory(history);
      final contents = [
        ...chatHistory,
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
        if (text == null || text.isEmpty) {
          return ChatMessage.ai(
            text: 'Sorry, no response from AI.',
            sessionId: currentSessionId,
            category: 'ai_empty',
          );
        }
        return ChatMessage.ai(
          text: text,
          sessionId: currentSessionId,
          category: 'ai_text',
        );
      }

      dev.log('Function call detected: ${data['name']}');
      final name = data['name'] as String;
      final args = Map<String, dynamic>.from(data['args'] as Map? ?? {});

      // Helper for safe type casting
      String? getString(Object? obj) => obj == null ? null : obj.toString();
      int? getInt(Object? obj) {
        if (obj == null) return null;
        if (obj is int) return obj;
        if (obj is String) return int.tryParse(obj);
        return null;
      }

      Map<String, dynamic> resultData = {};
      switch (name) {
        case 'searchProducts':
          final query = getString(args['query']) ?? msg;
          final categoryId = getString(args['categoryId']);
          final limit = getInt(args['limit']) ?? 10;
          resultData = await handleProductSearch(query, categoryId: categoryId, limit: limit);
          break;
        case 'getProductDetails':
          final productId = getString(args['productId']) ?? '';
          resultData = await handleProductDetails(productId);
          break;
        case 'getOrders':
          final limit = getInt(args['limit']) ?? 5;
          final status = getString(args['status']);
          resultData = await handleGetOrders(limit: limit, status: status);
          break;
        case 'getOrderDetails':
          final orderId = getString(args['orderId']) ?? '';
          resultData = await handleOrderDetails(orderId);
          break;
        case 'getUserProfile':
          resultData = await handleUserProfile();
          break;
        case 'getCategories':
          resultData = await handleGetCategories();
          break;
        case 'getAvailableCoupons':
          resultData = await handleGetCoupons();
          break;
        default:
          dev.log('Unknown function call: $name');
          resultData = {'error': 'Unknown function'};
      }

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
        sessionId: currentSessionId,
        category: 'ai_function_response',
        products: resultData['products'] ?? null,
        orders: resultData['orders'] ?? null,
        quickReplies: suggestReplies(name, resultData),
      );
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'failed-precondition') {
        // Covers both "not connected yet" and "your key was rejected" —
        // aiChatProxy.ts's own message already says which. Not an error:
        // this is the expected state before AI-3 gives the user somewhere
        // to connect a provider.
        return ChatMessage.ai(
          text: e.message ?? 'Connect an AI provider in Settings to use the AI Assistant.',
          sessionId: currentSessionId,
          category: 'ai_offline',
        );
      }
      dev.log('aiChatProxy error: ${e.message}');
      return ChatMessage.error(
        text: 'AI service error: ${e.message}',
        sessionId: currentSessionId,
        errorMessage: e.message,
      );
    } catch (e, st) {
      dev.log('Other error', error: e, stackTrace: st);
      return ChatMessage.error(
        text: 'Failed to communicate with AI.',
        sessionId: currentSessionId,
        errorMessage: e.toString(),
      );
    }
  }

  // Phase AI-2: buildSystemPrompt() was removed from here — aiChatProxy.ts
  // rebuilds the same prompt server-side (it needs to, since it is the one
  // making the actual Gemini call now), so keeping a second, unused copy
  // client-side would just be dead code inviting drift.

  /// Gemini-native `{role, parts:[{text}]}` shape, matching what
  /// functions/src/customer/aiChatProxy.ts's `contents` parameter expects —
  /// replaces the google_generative_ai SDK's `List<Content>` return type
  /// from before Phase AI-2, since that SDK type cannot cross a Cloud
  /// Functions callable boundary.
  Future<List<Map<String, dynamic>>> buildChatHistory(List<ChatMessage>? history) async {
    final List<Map<String, dynamic>> content = [];
    final messages = (history ?? context)
        .where((m) => m.text.trim().isNotEmpty && m.messageType != MessageType.loading)
        .toList();

    for (var m in messages) {
      content.add({
        'role': m.isUser ? 'user' : 'model',
        'parts': [
          {'text': m.text}
        ],
      });
    }
    return content;
  }

  Future<Map<String, dynamic>> handleProductSearch(String query, {String? categoryId, int limit = 10}) async {
    try {
      // Fetch products and filter by name containing query (case-insensitive)
      Query queryRef = firestore.collection('products').where('isActive', isEqualTo: true);
      if (categoryId != null && categoryId.isNotEmpty) {
        queryRef = queryRef.where('categoryId', isEqualTo: categoryId);
      }

      final snap = await queryRef.limit(50).get(); // Get more to filter locally
      
      List<Map<String, dynamic>> products = [];
      final lowerQuery = query.toLowerCase().trim();
      
      for (var d in snap.docs) {
        final data = d.data() as Map<String, dynamic>;
        final name = (data['name'] ?? '').toString().toLowerCase();
        final description = (data['description'] ?? '').toString().toLowerCase();
        
        // Match if query is empty (show all) or name/description contains query
        if (lowerQuery.isEmpty || name.contains(lowerQuery) || description.contains(lowerQuery)) {
          products.add({
            'id': d.id,
            'name': data['name'] ?? 'Unnamed',
            'price': (data['salePrice'] as num?)?.toDouble() ?? (data['price'] as num?)?.toDouble() ?? 0,
            'salePrice': (data['salePrice'] as num?)?.toDouble() ?? 0,
            'originalPrice': (data['originalPrice'] as num?)?.toDouble() ?? (data['mrp'] as num?)?.toDouble() ?? 0,
            'imageUrl': (data['images'] as List?)?.isNotEmpty == true ? (data['images'] as List).first : '',
            'images': data['images'] ?? [],
            'description': data['description'] ?? '',
            'category': data['categoryId'] ?? '',
            'inStock': (data['stock'] ?? 0) > 0,
          });
          
          if (products.length >= limit) break;
        }
      }
      
      // If no results from query, try showing featured products
      if (products.isEmpty && lowerQuery.isNotEmpty) {
        final featuredSnap = await firestore.collection('products')
            .where('isActive', isEqualTo: true)
            .limit(limit)
            .get();
            
        for (var d in featuredSnap.docs) {
          final data = d.data();
          products.add({
            'id': d.id,
            'name': data['name'] ?? 'Unnamed',
            'price': (data['salePrice'] as num?)?.toDouble() ?? (data['price'] as num?)?.toDouble() ?? 0,
            'salePrice': (data['salePrice'] as num?)?.toDouble() ?? 0,
            'originalPrice': (data['originalPrice'] as num?)?.toDouble() ?? (data['mrp'] as num?)?.toDouble() ?? 0,
            'imageUrl': (data['images'] as List?)?.isNotEmpty == true ? (data['images'] as List).first : '',
            'images': data['images'] ?? [],
            'description': data['description'] ?? '',
            'category': data['categoryId'] ?? '',
            'inStock': (data['stock'] ?? 0) > 0,
          });
        }
      }
      
      return {'products': products, 'totalCount': products.length};
    } catch (e) {
      dev.log('handleProductSearch error', error: e);
      return {'error': 'Product search failed.'};
    }
  }

  Future<Map<String, dynamic>> handleProductDetails(String productId) async {
    try {
      final doc = await firestore.collection('products').doc(productId).get();
      if (!doc.exists) return {'error': 'Product not found'};
      final data = doc.data() as Map<String, dynamic>;
      return {
        'product': {
          'id': doc.id,
          'name': data['name'] ?? 'Unnamed',
          'description': data['description'] ?? '',
          'price': (data['salePrice'] as num?)?.toDouble() ?? 0,
          'images': data['images'] ?? [],
          'category': data['categoryId'] ?? '',
          'inStock': (data['stock'] ?? 0) > 0,
        }
      };
    } catch (e) {
      dev.log('handleProductDetails error', error: e);
      return {'error': 'Failed to get product details'};
    }
  }

  Future<Map<String, dynamic>> handleGetOrders({int limit = 5, String? status}) async {
    final user = auth.currentUser;
    if (user == null) return {'error': 'Please log in to view orders'};
    try {
      Query q = firestore.collection('orders').where('userId', isEqualTo: user.uid).orderBy('createdAt', descending: true);
      if (status != null && status.isNotEmpty) q = q.where('orderStatus', isEqualTo: status);
      final snap = await q.limit(limit).get();
      final orders = snap.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        // Try multiple possible field names for status
        final orderStatus = data['status'] ?? data['orderStatus'] ?? 'pending';
        // Try multiple possible field names for total
        final totalAmount = (data['totalAmount'] as num?)?.toDouble() 
            ?? (data['grandTotal'] as num?)?.toDouble() 
            ?? (data['total'] as num?)?.toDouble() 
            ?? 0.0;
        return {
          'id': d.id,
          'orderNumber': data['orderNumber'] ?? d.id,
          'status': orderStatus,
          'orderStatus': orderStatus,  // For card renderer
          'total': totalAmount,
          'totalAmount': totalAmount,  // For card renderer
          'createdAt': (data['createdAt'] as Timestamp?)?.toDate().toIso8601String(),
        };
      }).toList();
      return {'orders': orders, 'totalCount': orders.length};
    } catch (e) {
      dev.log('handleGetOrders error', error: e);
      return {'error': 'Failed to get orders'};
    }
  }

  Future<Map<String, dynamic>> handleOrderDetails(String orderId) async {
    try {
      final doc = await firestore.collection('orders').doc(orderId).get();
      if (!doc.exists) return {'error': 'Order not found'};
      final data = doc.data() as Map<String, dynamic>;
      return {
        'order': {
          'id': doc.id,
          'status': data['orderStatus'] ?? 'unknown',
          'total': (data['total'] as num?)?.toDouble() ?? 0,
          'items': data['items'] ?? [],
          'createdAt': (data['createdAt'] as Timestamp?)?.toDate().toIso8601String(),
        }
      };
    } catch (e) {
      dev.log('handleOrderDetails error', error: e);
      return {'error': 'Failed to get order details'};
    }
  }

  Future<Map<String, dynamic>> handleUserProfile() async {
    final user = auth.currentUser;
    if (user == null) return {'error': 'Not logged in'};
    if (userProfileCache != null) return userProfileCache!;
    try {
      final doc = await firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return {'error': 'User profile not found'};
      final data = doc.data() as Map<String, dynamic>;
      userProfileCache = {
        'name': data['name'] ?? 'User',
        'email': data['email'] ?? user.email ?? 'N/A',
        'phone': data['phone'] ?? 'Not provided',
      };
      return userProfileCache!;
    } catch (e) {
      dev.log('handleUserProfile error', error: e);
      return {'error': 'Failed to get profile'};
    }
  }

  Future<Map<String, dynamic>> handleGetCategories() async {
    try {
      final snap = await firestore.collection('categories').where('isActive', isEqualTo: true).get();
      final categories = snap.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        return {
          'id': d.id,
          'name': data['name'] ?? 'Unnamed',
        };
      }).toList();
      return {'categories': categories};
    } catch (e) {
      dev.log('handleGetCategories error', error: e);
      return {'error': 'Failed to get categories'};
    }
  }

  Future<Map<String, dynamic>> handleGetCoupons() async {
    try {
      final now = DateTime.now();
      final snap = await firestore.collection('coupons').where('isActive', isEqualTo: true).where('validTo', isGreaterThan: now).get();
      final coupons = snap.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        return {
          'code': data['code'] ?? 'N/A',
          'description': data['description'] ?? '',
          'discount': data['discount'] ?? 0,
        };
      }).toList();
      return {'coupons': coupons};
    } catch (e) {
      dev.log('handleGetCoupons error', error: e);
      return {'error': 'Failed to get coupons'};
    }
  }

  List<String> suggestReplies(String functionName, Map<String, dynamic> data) {
    if (data.containsKey('error')) {
      return ['Try again', 'Help'];
    }
    switch (functionName) {
      case 'searchProducts':
        return ['Show more', 'Filter', 'Sort'];
      case 'getOrders':
        return ['Track order', 'Order history'];
      default:
        return ['Help', 'Main menu'];
    }
  }

  Future<void> primeCaches() async {
    try {
      await handleUserProfile();
    } catch (e) {
      dev.log('primeCaches error', error: e);
    }
  }

  Future<List<Map<String, dynamic>>> getAllSessions() async {
    final user = auth.currentUser;
    if (user == null) return [];
    try {
      final snap = await firestore.collection('users').doc(user.uid).collection('chats').get();
      return snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();
    } catch (e) {
      dev.log('getAllSessions error', error: e);
      return [];
    }
  }

  Future<void> deleteSession(String id) async {
    final user = auth.currentUser;
    if (user == null) return;
    try {
      await firestore.collection('users').doc(user.uid).collection('chats').doc(id).delete();
    } catch (e) {
      dev.log('deleteSession error', error: e);
    }
  }

  Map<String, int> getSessionStats() {
    int productCount = 0;
    for (var m in context) {
      if (m.products?.isNotEmpty ?? false) {
        productCount += m.products!.length;
      }
    }
    return {
      'userMessages': context.where((m) => m.isUser).length,
      'aiMessages': context.where((m) => m.isAI).length,
      'totalMessages': context.length,
      'productViews': productCount,
    };
  }
}
