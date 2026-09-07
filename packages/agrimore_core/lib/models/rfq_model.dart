import 'package:cloud_firestore/cloud_firestore.dart';

/// Mirrors the shape functions/src/customer/rfq.ts (Phase RFQ-1) writes to
/// rfqs/{rfqId} — this model is read-only by design: the client never
/// writes an RFQ document directly (firestore.rules: `allow write: if
/// false`, Cloud-Functions-only), so there is deliberately no `toMap()`.
/// Shared here (not app-local) because both apps/marketplace (RFQ-2) and,
/// later, apps/seller (RFQ-2B) need the exact same shape.
enum RfqStatus { pending, negotiating, accepted, rejected }

enum RfqRole { buyer, seller }

DateTime _toDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.now();
}

class RfqOffer {
  final double price;
  final int quantity;
  final RfqRole by;
  final String? notes;

  RfqOffer({required this.price, required this.quantity, required this.by, this.notes});

  factory RfqOffer.fromMap(Map<String, dynamic> map) {
    return RfqOffer(
      price: (map['price'] as num).toDouble(),
      quantity: (map['quantity'] as num).toInt(),
      by: map['by'] == 'seller' ? RfqRole.seller : RfqRole.buyer,
      notes: map['notes'] as String?,
    );
  }
}

class RfqHistoryEntry {
  final RfqRole actor;
  final String action; // 'create' | 'offer' | 'accept' | 'reject'
  final double? price;
  final int? quantity;
  final String? notes;
  final DateTime at;

  RfqHistoryEntry({
    required this.actor,
    required this.action,
    this.price,
    this.quantity,
    this.notes,
    required this.at,
  });

  factory RfqHistoryEntry.fromMap(Map<String, dynamic> map) {
    return RfqHistoryEntry(
      actor: map['actor'] == 'seller' ? RfqRole.seller : RfqRole.buyer,
      action: map['action'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble(),
      quantity: (map['quantity'] as num?)?.toInt(),
      notes: map['notes'] as String?,
      at: _toDate(map['at']),
    );
  }
}

class RfqModel {
  final String id;
  final String buyerId;
  final String sellerId;
  final String productId;
  final RfqStatus status;
  final RfqRole? awaitingResponseFrom;
  final RfqOffer? lastOffer;
  final double? finalPrice;
  final int? finalQuantity;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? acceptedAt;
  final DateTime? rejectedAt;
  final List<RfqHistoryEntry> history;

  RfqModel({
    required this.id,
    required this.buyerId,
    required this.sellerId,
    required this.productId,
    required this.status,
    this.awaitingResponseFrom,
    this.lastOffer,
    this.finalPrice,
    this.finalQuantity,
    required this.createdAt,
    required this.updatedAt,
    this.acceptedAt,
    this.rejectedAt,
    this.history = const [],
  });

  factory RfqModel.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return RfqModel.fromMap(map, doc.id);
  }

  factory RfqModel.fromMap(Map<String, dynamic> map, String id) {
    return RfqModel(
      id: id,
      buyerId: map['buyerId'] as String? ?? '',
      sellerId: map['sellerId'] as String? ?? '',
      productId: map['productId'] as String? ?? '',
      status: _statusFromString(map['status'] as String?),
      awaitingResponseFrom: map['awaitingResponseFrom'] == 'buyer'
          ? RfqRole.buyer
          : map['awaitingResponseFrom'] == 'seller'
              ? RfqRole.seller
              : null,
      lastOffer: map['lastOffer'] != null
          ? RfqOffer.fromMap(Map<String, dynamic>.from(map['lastOffer'] as Map))
          : null,
      finalPrice: (map['finalPrice'] as num?)?.toDouble(),
      finalQuantity: (map['finalQuantity'] as num?)?.toInt(),
      createdAt: _toDate(map['createdAt']),
      updatedAt: _toDate(map['updatedAt']),
      acceptedAt: map['acceptedAt'] != null ? _toDate(map['acceptedAt']) : null,
      rejectedAt: map['rejectedAt'] != null ? _toDate(map['rejectedAt']) : null,
      history: (map['history'] as List<dynamic>? ?? [])
          .map((e) => RfqHistoryEntry.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  static RfqStatus _statusFromString(String? value) {
    switch (value) {
      case 'negotiating':
        return RfqStatus.negotiating;
      case 'accepted':
        return RfqStatus.accepted;
      case 'rejected':
        return RfqStatus.rejected;
      default:
        return RfqStatus.pending;
    }
  }

  /// Whether the given uid may currently act (submit an offer or respond)
  /// on this RFQ — mirrors rfq.ts's own roleOf()/awaitingResponseFrom check,
  /// re-derived client-side ONLY for enabling/disabling UI controls. The
  /// server re-checks this unconditionally on every call; this is display
  /// logic, never a trust boundary.
  RfqRole? roleOf(String uid) {
    if (uid == buyerId) return RfqRole.buyer;
    if (uid == sellerId) return RfqRole.seller;
    return null;
  }

  bool canActNow(String uid) {
    if (status != RfqStatus.pending && status != RfqStatus.negotiating) return false;
    final role = roleOf(uid);
    return role != null && role == awaitingResponseFrom;
  }
}
