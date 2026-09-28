// Phase ADMR-90 — the Dart side of the support-case link-record-type
// contract.
//
// Asserted against test/fixtures/support_link_record_types.json, the SAME
// file functions/scripts/phaseADMR90_support_link_type_parity_test.js
// asserts the TypeScript mirror against. A change to the fixture, the Dart
// constants or the TS mirror alone fails a suite — that is the parity
// guard, the same pattern packages/agrimore_core/test/delivery/
// delivery_enums_test.dart already establishes for the delivery vocabulary.
import 'dart:convert';
import 'dart:io';

import 'package:agrimore_admin/screens/admin/support/support_case_constants.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _fixture() => jsonDecode(
      File('test/fixtures/support_link_record_types.json').readAsStringSync(),
    ) as Map<String, dynamic>;

void main() {
  final fixture = _fixture();
  final fixtureTypes = (fixture['linkRecordTypes'] as List).cast<String>();
  final fixtureCollection =
      (fixture['linkRecordCollection'] as Map).cast<String, String>();

  test('kLinkRecordTypes matches the fixture exactly, in the same order', () {
    expect(kLinkRecordTypes, fixtureTypes);
  });

  test('kLinkRecordCollection has exactly the fixture\'s keys', () {
    expect(kLinkRecordCollection.keys.toSet(), fixtureCollection.keys.toSet());
  });

  for (final type in fixtureTypes) {
    test('kLinkRecordCollection[$type] matches the fixture', () {
      expect(kLinkRecordCollection[type], fixtureCollection[type]);
    });
  }

  test('every fixture type has a non-empty collection entry', () {
    for (final type in fixtureTypes) {
      expect(kLinkRecordCollection[type], isNotNull, reason: type);
      expect(kLinkRecordCollection[type], isNotEmpty, reason: type);
    }
  });

  test('every fixture type has a real label, not a raw fallback to itself', () {
    for (final type in fixtureTypes) {
      expect(linkRecordTypeLabel(type), isNot(type), reason: type);
    }
  });
}
