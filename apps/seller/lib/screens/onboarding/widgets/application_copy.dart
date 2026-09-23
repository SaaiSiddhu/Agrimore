import '../../../l10n/app_localizations.dart';

/// Maps application keys (shared with the server) to localised copy.
abstract final class ApplicationCopy {
  ApplicationCopy._();

  static String category(AppLocalizations l10n, String key) => switch (key) {
        'vegetables' => l10n.category_vegetables,
        'fruits' => l10n.category_fruits,
        'grains' => l10n.category_grains,
        'dairy' => l10n.category_dairy,
        'seeds' => l10n.category_seeds,
        'fertilisers' => l10n.category_fertilisers,
        'equipment' => l10n.category_equipment,
        _ => l10n.category_other,
      };

  static String document(AppLocalizations l10n, String key) => switch (key) {
        'idProof' => l10n.doc_idProof,
        'shopPhoto' => l10n.doc_shopPhoto,
        _ => l10n.doc_gstCertificate,
      };

  static String stepTitle(AppLocalizations l10n, int step) => switch (step) {
        0 => l10n.stepBusiness,
        1 => l10n.stepLocation,
        2 => l10n.stepDocuments,
        3 => l10n.stepPayout,
        _ => l10n.stepReview,
      };

  /// Error copy for a server/client problem key.
  static String problem(AppLocalizations l10n, String key) => switch (key) {
        'gstin' => l10n.errGstin,
        'pincode' => l10n.errPincode,
        'ifsc' => l10n.errIfsc,
        'accountNumber' => l10n.errAccount,
        'upiId' => l10n.errUpi,
        _ when key.startsWith('documents.') => l10n.errDocument,
        _ => l10n.errRequired,
      };
}
