// ADMR-15 — hyperlocal GPS radius truthfulness.
//
// PROBLEM, confirmed by reading both the admin screen and the backend
// directly: location_settings_screen.dart's "Hyperlocal GPS Settings"
// section claimed, in three separate places, that a GPS-radius product
// filter existed and was tunable here ("how far users can see products
// from their GPS location", "users only see products within the set
// radius", "users cannot view products if they are beyond this radius") —
// but isHyperlocalEnabled/maxRadiusKm are read nowhere in this codebase
// (grepped fresh across every app and functions/src). The real
// serviceability check, LocationSettingsProvider.isServiceable()
// (apps/marketplace), is a plain city-name-string match against
// activeLocations — no radius or GPS-distance calculation exists anywhere.
// An admin reading this screen had every reason to believe a working
// geofencing system existed and was tunable here.
//
// FIX: a disclosure banner plus corrected toggle/slider captions that no
// longer assert the false GPS-filtering behaviour. The toggle and slider
// themselves, and the four genuinely-wired fields (activeLocations,
// defaultEtaText, unserviceableText, cityEtaOverrides), are unchanged.
//
// This project has no Firebase-mocking test setup
// (LocationSettingsScreen's own direct FirebaseFirestore.instance calls
// would need a real Firebase app), so — matching this repo's other
// Firebase-free guards — this test asserts the committed source directly.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ADMR-15 hyperlocal radius truthfulness guards', () {
    late String source;

    setUpAll(() async {
      source = await File(
        '${Directory.current.path}/lib/screens/admin/settings/location_settings_screen.dart',
      ).readAsString();
    });

    test('no false claim of GPS-radius product filtering remains', () {
      for (final falseClaim in [
        'how far users can see products from their GPS location',
        'users only see products within the set radius',
        'Users cannot view products if they are beyond this radius',
      ]) {
        expect(
          source.contains(falseClaim),
          isFalse,
          reason:
              '"$falseClaim" is back in location_settings_screen.dart — this '
              'claims a GPS-radius product filter exists and is tunable '
              'here. isHyperlocalEnabled/maxRadiusKm are read nowhere in '
              'this codebase; real serviceability '
              '(LocationSettingsProvider.isServiceable) is a plain '
              'city-name match against activeLocations, not a radius '
              'calculation. If GPS-radius filtering is actually being '
              'built, this guard should be removed deliberately once the '
              'feature is real, not silently defeated by reverting the copy.',
        );
      }
    });

    test('the section discloses that the toggle/slider are not yet '
        'connected to live behaviour', () {
      expect(
        source.contains('Not yet connected to live behaviour'),
        isTrue,
        reason: 'the disclosure banner is missing — an admin toggling '
            'Hyperlocal Mode or dragging the radius slider again has no '
            'way to know saving them changes nothing a customer sees.',
      );
    });

    test('the toggle, slider, and the four genuinely-wired fields are all '
        'still present — this phase corrects copy, it does not remove '
        'functionality', () {
      for (final needle in [
        '_isHyperlocalEnabled',
        '_maxRadiusKm',
        'activeLocations',
        'defaultEtaText',
        'unserviceableText',
        'cityEtaOverrides',
      ]) {
        expect(source.contains(needle), isTrue,
            reason: '"$needle" is missing — this phase only corrects the '
                'misleading copy on the hyperlocal section, it must not '
                'remove any field, wired or not.');
      }
    });
  });
}
