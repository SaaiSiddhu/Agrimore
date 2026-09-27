// ADMR-62 — shared vocabulary for the support case queue + detail screens,
// mirroring the real server-side constants in
// functions/src/admin/supportCases.ts (SUPPORT_CASE_ACTOR_TYPES,
// SUPPORT_CASE_STATUSES) so the UI can never offer a value the backend
// would refuse.
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
