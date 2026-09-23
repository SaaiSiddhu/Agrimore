import 'package:agrimore_core/agrimore_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// SELLER-STOREFRONT-EDIT-1: what a buyer may see on a seller's storefront.
/// Same rule as the catalogue (database_service.dart filters `p.isActive`;
/// ProductModel reads a missing `isActive` as true, so legacy products stay
/// visible). Hidden and draft products never appear. Pure — unit-tested.
bool isVisibleOnStorefront(ProductModel p) => p.isActive && !p.isDraft;

/// SELLER-OPS-1: the seller paused their store (sellers/{uid}.acceptingOrders
/// false, until pausedUntil if set). SELLER-OPS-2: or today (Indian
/// calendar day) is one of their weekly off days (ISO weekday, 1 = Monday)
/// or holidays ("YYYY-MM-DD"). Same rule as the server's
/// sellerAvailability.sellerClosedReason — checkout refuses these orders.
bool isStorePaused(Map<String, dynamic>? seller, DateTime now) {
  if (seller == null) return false;
  if (seller['acceptingOrders'] == false) {
    final until = seller['pausedUntil'];
    if (until is! Timestamp || until.toDate().isAfter(now)) return true;
  }
  final ist = now.toUtc().add(const Duration(hours: 5, minutes: 30));
  final off = (seller['weeklyOff'] as List?) ?? const [];
  if (off.contains(ist.weekday)) return true;
  final key = '${ist.year.toString().padLeft(4, '0')}-${ist.month.toString().padLeft(2, '0')}-${ist.day.toString().padLeft(2, '0')}';
  return ((seller['holidays'] as List?) ?? const []).contains(key);
}

/// Up to three non-empty highlights from sellers/{uid}.highlights.
List<String> storefrontHighlights(Map<String, dynamic>? seller) => [
      for (final h in (seller?['highlights'] as List?) ?? const [])
        if (h is String && h.trim().isNotEmpty) h.trim(),
    ].take(3).toList();
