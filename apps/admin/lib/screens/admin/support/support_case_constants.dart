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
