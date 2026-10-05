// Phase FIX-8B — pure validation rules for a seller's delivery fee
// schedule (unit-tested in apps/seller/test/delivery_fee_validation_test.dart).
// Every bound here is copied from functions/src/customer/
// deliveryFeeSchedule.ts's own parseDeliveryFeeSchedule() — this file must
// never drift from that one; if either changes, change both together.
// Redesign: returns an error CODE; the screen shows the localised sentence.

import '../../l10n/app_localizations.dart';

const int kMaxFeeRupees = 1000;
const int kMaxSlabs = 10;

/// Why a schedule was refused.
enum FeeError { flatInvalid, tooHigh, distanceBase, distanceRate, precision, noLocation, noTiers, tooManyTiers, tierMin, tierFee, noZeroTier }

/// One slab row's already-parsed numeric inputs — null means the field
/// could not be parsed as a number (e.g. empty or non-numeric text).
typedef SlabInput = ({double? minOrderValue, double? fee});

/// Flat fee: 0 <= amount <= kMaxFeeRupees.
FeeError? validateFlatFee(double? amount) {
  if (amount == null || amount < 0) return FeeError.flatInvalid;
  if (amount > kMaxFeeRupees) return FeeError.tooHigh;
  return null;
}

/// Distance fee components are stored as integer paise and must fit the
/// server's safe-money bounds. A positive rate is required; base may be zero.
FeeError? validateDistanceFee({required double? baseRupees, required double? rateRupeesPerKm}) {
  if (baseRupees == null || !baseRupees.isFinite || baseRupees < 0 || baseRupees > kMaxFeeRupees) return FeeError.distanceBase;
  if (rateRupeesPerKm == null || !rateRupeesPerKm.isFinite || rateRupeesPerKm <= 0 || rateRupeesPerKm > kMaxFeeRupees) return FeeError.distanceRate;
  if ((baseRupees * 100 - (baseRupees * 100).round()).abs() > 1e-7 ||
      (rateRupeesPerKm * 100 - (rateRupeesPerKm * 100).round()).abs() > 1e-7) {
    return FeeError.precision;
  }
  return null;
}

/// Slab schedule: 1–kMaxSlabs entries, each minOrderValue >= 0 and
/// 0 <= fee <= kMaxFeeRupees, and one slab with minOrderValue == 0 (so
/// every non-negative subtotal matches a slab).
FeeError? validateSlabSchedule(List<SlabInput> slabs) {
  if (slabs.isEmpty) return FeeError.noTiers;
  if (slabs.length > kMaxSlabs) return FeeError.tooManyTiers;
  var hasZeroSlab = false;
  for (final slab in slabs) {
    final minOrderValue = slab.minOrderValue;
    final fee = slab.fee;
    if (minOrderValue == null || minOrderValue < 0) return FeeError.tierMin;
    if (fee == null || fee < 0) return FeeError.tierFee;
    if (fee > kMaxFeeRupees) return FeeError.tooHigh;
    if (minOrderValue == 0) hasZeroSlab = true;
  }
  return hasZeroSlab ? null : FeeError.noZeroTier;
}

/// The sentence the seller reads for [e].
String feeErrorText(AppLocalizations l10n, FeeError e, String maxFee) => switch (e) {
      FeeError.flatInvalid => l10n.feeErrFlatInvalid,
      FeeError.tooHigh => l10n.feeErrTooHigh(maxFee),
      FeeError.distanceBase => l10n.feeErrDistanceBase,
      FeeError.distanceRate => l10n.feeErrDistanceRate,
      FeeError.precision => l10n.feeErrPaisePrecision,
      FeeError.noLocation => l10n.feeErrShopLocation,
      FeeError.noTiers => l10n.feeErrNoTiers,
      FeeError.tooManyTiers => l10n.feeErrTooManyTiers(kMaxSlabs),
      FeeError.tierMin => l10n.feeErrTierMin,
      FeeError.tierFee => l10n.feeErrTierFee,
      FeeError.noZeroTier => l10n.feeErrNoZeroTier,
    };
