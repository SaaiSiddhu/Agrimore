// HOME-4: proves CategorySectionSlotModel.isWithinSchedule()/scheduleStatus
// behave correctly, and specifically that a slot with neither startsAt nor
// endsAt (every document written before this phase) stays always-eligible --
// the contract's own named regression risk for CategorySectionProvider's
// activeSections filter, which composes isWithinSchedule() straight from
// this model. Pure Dart, no Firebase -- unlike category_provider_test.dart's
// DatabaseService mocking, CategorySectionSlotModel has no Firestore
// dependency in its constructor, so no mock scaffolding is needed here.
import 'package:flutter_test/flutter_test.dart';

import 'package:agrimore_core/agrimore_core.dart';

CategorySectionSlotModel _slot({
  bool isActive = true,
  DateTime? startsAt,
  DateTime? endsAt,
}) {
  return CategorySectionSlotModel(
    id: 's1',
    position: 1,
    sectionName: 'Grocery & Kitchen',
    categoryIds: const ['cat1'],
    isActive: isActive,
    startsAt: startsAt,
    endsAt: endsAt,
  );
}

void main() {
  final now = DateTime(2026, 9, 12, 12, 0);
  final past = now.subtract(const Duration(days: 1));
  final future = now.add(const Duration(days: 1));

  group('CategorySectionSlotModel.isWithinSchedule', () {
    test('neither bound set -- always eligible (every pre-existing slot)', () {
      final slot = _slot();
      expect(slot.isWithinSchedule(now), isTrue);
      expect(slot.scheduleStatus, 'Live');
    });

    test('startsAt in the future -- not yet eligible', () {
      final slot = _slot(startsAt: future);
      expect(slot.isWithinSchedule(now), isFalse);
      expect(slot.scheduleStatus, 'Scheduled');
    });

    test('endsAt in the past -- no longer eligible', () {
      final slot = _slot(endsAt: past);
      expect(slot.isWithinSchedule(now), isFalse);
      expect(slot.scheduleStatus, 'Expired');
    });

    test('now between startsAt and endsAt -- eligible', () {
      final slot = _slot(startsAt: past, endsAt: future);
      expect(slot.isWithinSchedule(now), isTrue);
      expect(slot.scheduleStatus, 'Live');
    });

    test('isActive false -- Disabled regardless of an eligible window', () {
      final slot = _slot(isActive: false, startsAt: past, endsAt: future);
      expect(slot.scheduleStatus, 'Disabled');
    });
  });
}
