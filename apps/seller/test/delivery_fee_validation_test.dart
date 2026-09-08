// Phase FIX-8B — proves delivery_fee_validation.dart's bounds mirror
// functions/src/customer/deliveryFeeSchedule.ts's own
// parseDeliveryFeeSchedule() exactly. Pure logic, no widget harness
// needed.
import 'package:flutter_test/flutter_test.dart';
import 'package:seller/screens/profile/delivery_fee_validation.dart';

void main() {
  group('validateFlatFee', () {
    test('rejects null (unparseable input)', () {
      expect(validateFlatFee(null), isNotNull);
    });

    test('rejects negative amounts', () {
      expect(validateFlatFee(-1), isNotNull);
    });

    test('accepts 0', () {
      expect(validateFlatFee(0), isNull);
    });

    test('accepts a mid-range amount', () {
      expect(validateFlatFee(50), isNull);
    });

    test('accepts exactly the max (1000)', () {
      expect(validateFlatFee(kMaxFeeRupees.toDouble()), isNull);
    });

    test('rejects just above the max', () {
      expect(validateFlatFee(kMaxFeeRupees.toDouble() + 0.01), isNotNull);
    });

    test('rejects far above the max', () {
      expect(validateFlatFee(5000), isNotNull);
    });
  });

  group('validateSlabSchedule', () {
    test('rejects an empty slab list', () {
      expect(validateSlabSchedule(const []), isNotNull);
    });

    test('rejects more than kMaxSlabs entries', () {
      final tooMany = List<SlabInput>.generate(
        kMaxSlabs + 1,
        (i) => (minOrderValue: i.toDouble(), fee: 10),
      );
      expect(validateSlabSchedule(tooMany), isNotNull);
    });

    test('accepts exactly kMaxSlabs entries (one at 0)', () {
      final atMax = List<SlabInput>.generate(
        kMaxSlabs,
        (i) => (minOrderValue: i.toDouble(), fee: 10),
      );
      expect(validateSlabSchedule(atMax), isNull);
    });

    test('rejects a slab with a null minOrderValue', () {
      expect(
        validateSlabSchedule(const [(minOrderValue: null, fee: 10)]),
        isNotNull,
      );
    });

    test('rejects a slab with a negative minOrderValue', () {
      expect(
        validateSlabSchedule(const [(minOrderValue: -1, fee: 10)]),
        isNotNull,
      );
    });

    test('rejects a slab with a null fee', () {
      expect(
        validateSlabSchedule(const [(minOrderValue: 0, fee: null)]),
        isNotNull,
      );
    });

    test('rejects a slab with a negative fee', () {
      expect(
        validateSlabSchedule(const [(minOrderValue: 0, fee: -1)]),
        isNotNull,
      );
    });

    test('rejects a slab fee above kMaxFeeRupees', () {
      expect(
        validateSlabSchedule([
          (minOrderValue: 0, fee: kMaxFeeRupees.toDouble() + 0.01),
        ]),
        isNotNull,
      );
    });

    test('accepts a slab fee exactly at kMaxFeeRupees', () {
      expect(
        validateSlabSchedule([
          (minOrderValue: 0, fee: kMaxFeeRupees.toDouble()),
        ]),
        isNull,
      );
    });

    test('rejects a schedule with no minOrderValue-0 slab', () {
      expect(
        validateSlabSchedule(const [
          (minOrderValue: 100, fee: 10),
          (minOrderValue: 500, fee: 20),
        ]),
        isNotNull,
      );
    });

    test('accepts a genuine multi-slab schedule with a 0 slab', () {
      expect(
        validateSlabSchedule(const [
          (minOrderValue: 0, fee: 40),
          (minOrderValue: 500, fee: 20),
          (minOrderValue: 1000, fee: 0),
        ]),
        isNull,
      );
    });

    test('accepts a single slab at exactly minOrderValue 0', () {
      expect(
        validateSlabSchedule(const [(minOrderValue: 0, fee: 30)]),
        isNull,
      );
    });
  });
}
