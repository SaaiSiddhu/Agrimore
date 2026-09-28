// ADMR-62 — shared vocabulary for the support case queue + detail screens,
// mirroring the real server-side constants in
// functions/src/admin/supportCases.ts (SUPPORT_CASE_ACTOR_TYPES,
// SUPPORT_CASE_STATUSES) so the UI can never offer a value the backend
// would refuse.
import 'package:uuid/uuid.dart';

/// ADMR-66 — createSupportCase and addSupportCaseNote now require a
/// requestId for server-side idempotency (mirrors the real, already-shipped
/// PayoutReviewScreen convention in apps/employee). Unlike that screen's own
/// immutable, widget-lifetime-scoped id (safe there because its payload —
/// requestedAmount — is a final field that can never change), a create/note
/// dialog's own fields ARE editable across separate submit attempts within
/// the same dialog instance, so reusing one fixed id for the widget's whole
/// lifetime would wrongly bind two DIFFERENT logical actions (e.g. the user
/// fixes a typo and resubmits) to the same id, tripping the server's own
/// request_id_conflict refusal. This tracks the last-submitted payload
/// alongside its id: an unchanged payload (a genuine retry of the same
/// logical action) reuses the same id; a changed payload mints a fresh one.
class SupportRequestIdTracker {
  String? _lastId;
  Object? _lastPayload;

  /// [payload] should be a value with real (Dart records give this
  /// automatically) or overridden equality -- e.g. `(title, category,
  /// actorType, actorId)` or just a `String` for a single-field payload
  /// like a note's own text.
  String forPayload(Object payload) {
    if (_lastPayload == payload) return _lastId!;
    final id = const Uuid().v4();
    _lastId = id;
    _lastPayload = payload;
    return id;
  }
}

const List<String> kSupportCaseActorTypes = [
  'customer',
  'seller',
  'rider',
  'associate',
];

/// Not enforced server-side (createSupportCaseCore only requires a
/// non-empty string) -- a fixed list here keeps real data consistent
/// without inventing a backend validation rule this phase wasn't asked to
/// add.
const List<String> kSupportCaseCategories = [
  'delivery_issue',
  'payment_issue',
  'product_issue',
  'account_issue',
  'seller_issue',
  'other',
];

/// Every status changeSupportCaseStatus will accept. "resolved" is
/// deliberately excluded -- the server refuses it on that command and
/// requires the dedicated resolveSupportCase command instead.
const List<String> kSupportCaseChangeableStatuses = [
  'open',
  'in_progress',
  'waiting',
];

String supportCaseActorLabel(String type) {
  switch (type) {
    case 'customer':
      return 'Customer';
    case 'seller':
      return 'Seller';
    case 'rider':
      return 'Delivery Partner';
    case 'associate':
      return 'Sales Associate';
    default:
      return type;
  }
}

String supportCaseStatusLabel(String status) {
  switch (status) {
    case 'open':
      return 'Open';
    case 'in_progress':
      return 'In Progress';
    case 'waiting':
      return 'Waiting';
    case 'resolved':
      return 'Resolved';
    default:
      return status;
  }
}

String supportCaseCategoryLabel(String category) {
  switch (category) {
    case 'delivery_issue':
      return 'Delivery issue';
    case 'payment_issue':
      return 'Payment issue';
    case 'product_issue':
      return 'Product issue';
    case 'account_issue':
      return 'Account issue';
    case 'seller_issue':
      return 'Seller issue';
    default:
      return 'Other';
  }
}

/// The People-360 route for a case's primaryActor, mirroring
/// AdminRoutes.userDetail/sellerDetail/deliveryPartnerDetail/
/// associateDetail. Empty for an unrecognized type (defensive only --
/// the server's own ACTOR_COLLECTION map covers exactly these four).
String supportCaseActorRoute(String type, String id) {
  switch (type) {
    case 'customer':
      return '/users/$id';
    case 'seller':
      return '/sellers/$id';
    case 'rider':
      return '/delivery-partners/$id';
    case 'associate':
      return '/employees/$id';
    default:
      return '';
  }
}

// ADMR-68 — linkSupportCaseRecord/unlinkSupportCaseRecord's own vocabulary
// (functions/src/admin/supportCases.ts's LINK_RECORD_TYPES), a superset of
// the four actor types above: also covers order and the three per-rider
// operational records that can be linked but never form a case's own
// primaryActor. ADMR-86 adds the three financial-record types the server
// itself gained in ADMR-85 (same LINK_COLLECTION map, nothing new to
// validate — parseLinkedRecord already covers any entry in this list).
const List<String> kLinkRecordTypes = [
  'order',
  'rider_ticket',
  'rider_incident',
  'delivery_exception',
  'user',
  'seller',
  'rider',
  'associate',
  'seller_withdrawal',
  'rider_payout',
  'employee_payout',
];

/// The real collection backing each link type, mirroring
/// supportCases.ts's own LINK_COLLECTION map exactly.
const Map<String, String> kLinkRecordCollection = {
  'order': 'orders',
  'rider_ticket': 'rider_support_tickets',
  'rider_incident': 'rider_incidents',
  'delivery_exception': 'delivery_exceptions',
  'user': 'users',
  'seller': 'sellers',
  'rider': 'delivery_partners',
  'associate': 'employees',
  'seller_withdrawal': 'seller_withdrawals',
  'rider_payout': 'rider_payouts',
  'employee_payout': 'employee_payouts',
};

String linkRecordTypeLabel(String type) {
  switch (type) {
    case 'order':
      return 'Order';
    case 'rider_ticket':
      return 'Rider support ticket';
    case 'rider_incident':
      return 'Rider incident';
    case 'delivery_exception':
      return 'Delivery exception';
    case 'user':
      return 'Customer account';
    case 'seller':
      return 'Seller';
    case 'rider':
      return 'Delivery partner';
    case 'associate':
      return 'Sales associate';
    case 'seller_withdrawal':
      return 'Seller withdrawal';
    case 'rider_payout':
      return 'Rider payout';
    case 'employee_payout':
      return 'Associate payout';
    default:
      return type;
  }
}

/// The real detail route for a link type that has one. Empty for
/// rider_ticket/rider_incident/delivery_exception -- no dedicated
/// per-record detail screen exists anywhere in this codebase for those
/// three (only global list screens), so the UI shows an honest inline
/// summary for them instead of a fabricated or unfiltered-list route.
/// ADMR-86: the three financial types route to the new, read-only
/// FinancialRecordDetailScreen (apps/admin/lib/screens/admin/finance/
/// financial_record_detail_screen.dart) — no prior per-record screen
/// existed for these either, so this is a genuinely new route, not a
/// fabricated path onto something already there.
String linkRecordRoute(String type, String id) {
  switch (type) {
    case 'order':
      return '/orders/$id';
    case 'user':
      return '/users/$id';
    case 'seller':
      return '/sellers/$id';
    case 'rider':
      return '/delivery-partners/$id';
    case 'associate':
      return '/employees/$id';
    case 'seller_withdrawal':
    case 'rider_payout':
    case 'employee_payout':
      return '/finance/records/$type/$id';
    default:
      return '';
  }
}
