// Phase FIX-8B — pure validation rules for a seller's delivery fee
// schedule, extracted from delivery_fee_sheet.dart's own form so they can
// be unit-tested without a widget harness (apps/seller/test/
// delivery_fee_validation_test.dart). Every bound here is copied from
// functions/src/customer/deliveryFeeSchedule.ts's own
// parseDeliveryFeeSchedule() — this file must never drift from that one;
// if either changes, change both together.

import 'package:agrimore_core/agrimore_core.dart';

const int kMaxFeeRupees = 1000;
const int kMaxSlabs = 10;
final String _kMaxFeeFormatted = PriceFormatter.formatPriceInt(kMaxFeeRupees.toDouble());

/// One slab row's already-parsed numeric inputs — null means the field
/// could not be parsed as a number (e.g. empty or non-numeric text).
typedef SlabInput = ({double? minOrderValue, double? fee});

/// Validates a flat fee amount. Returns a user-safe error sentence, or
/// null if valid. Mirrors deliveryFeeSchedule.ts's own flat-schedule
/// bounds: 0 <= amount <= kMaxFeeRupees.
String? validateFlatFee(double? amount) {
  if (amount == null || amount < 0) {
    return 'Enter a valid delivery fee (0 or more)';
  }
  if (amount > kMaxFeeRupees) {
    return 'Delivery fee cannot exceed $_kMaxFeeFormatted';
  }
  return null;
}

/// Validates a slab schedule. Returns a user-safe error sentence, or null
/// if valid. Mirrors deliveryFeeSchedule.ts's own slab-schedule bounds:
/// 1-kMaxSlabs entries, each minOrderValue >= 0 and 0 <= fee <=
/// kMaxFeeRupees, and at least one slab with minOrderValue == 0 (so every
/// non-negative subtotal always matches at least one slab).
String? validateSlabSchedule(List<SlabInput> slabs) {
  if (slabs.isEmpty) {
    return 'Add at least one slab';
  }
  if (slabs.length > kMaxSlabs) {
    return 'A maximum of $kMaxSlabs slabs is allowed';
  }
  bool hasZeroSlab = false;
  for (final slab in slabs) {
    final minOrderValue = slab.minOrderValue;
    final fee = slab.fee;
    if (minOrderValue == null || minOrderValue < 0) {
      return 'Every slab needs a valid minimum order value (0 or more)';
    }
    if (fee == null || fee < 0) {
      return 'Every slab needs a valid delivery fee (0 or more)';
    }
    if (fee > kMaxFeeRupees) {
      return 'A slab fee cannot exceed $_kMaxFeeFormatted';
    }
    if (minOrderValue == 0) hasZeroSlab = true;
  }
  if (!hasZeroSlab) {
    return 'One slab must start at a minimum order value of 0, so every order matches a slab';
  }
  return null;
}
