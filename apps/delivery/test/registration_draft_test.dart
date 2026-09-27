// DLVID4: the on-disk shape of a registration draft. toJson/fromJson is what
// actually crosses the "process died and came back" boundary, so this is
// tested as a real JSON round trip (encode, decode, decode-again-from-a-
// string), not by passing the Dart object straight back to itself.
import 'dart:convert';

import 'package:delivery/registration/registration_draft.dart';
import 'package:delivery/registration/rider_application.dart';
import 'package:agrimore_core/agrimore_core.dart' show VehicleType;
import 'package:flutter_test/flutter_test.dart';

RiderApplicationForm _filledForm() => RiderApplicationForm()
  ..email = 'ravi@example.com'
  ..password = 'super-secret-1234'
  ..name = 'Ravi Kumar'
  ..phone = '9876543210'
  ..altPhone = '9876500000'
  ..vehicleType = VehicleType.scooter
  ..vehicleNumber = 'TN58AB1234'
  ..licenseNumber = 'TN5820200001234'
  ..aadhaarNumber = '234567890123'
  ..address = '12, Main Road'
  ..city = 'Madurai'
  ..pincode = '625020'
  ..accountHolderName = 'Ravi Kumar'
  ..bankAccountNumber = '123456789012'
  ..ifscCode = 'ABCD0123456'
  ..upiId = 'ravi@upi';

void main() {
  group('RegistrationDraft JSON round trip', () {
    test('every field survives a real encode/decode cycle', () {
      final draft = RegistrationDraft(
        step: 3,
        form: _filledForm(),
        photos: const {
          RiderDocument.selfie: DraftPhoto(path: '/tmp/selfie.jpg', contentType: 'image/jpeg'),
          RiderDocument.license: DraftPhoto(path: '/tmp/license.png', contentType: 'image/png'),
        },
        savedAt: DateTime.utc(2026, 9, 27, 10, 30),
      );

      final wire = jsonEncode(draft.toJson());
      final restored = RegistrationDraft.fromJson(jsonDecode(wire));

      expect(restored, isNotNull);
      expect(restored!.step, 3);
      expect(restored.savedAt, DateTime.utc(2026, 9, 27, 10, 30));
      expect(restored.form.email, 'ravi@example.com');
      expect(restored.form.name, 'Ravi Kumar');
      expect(restored.form.phone, '9876543210');
      expect(restored.form.altPhone, '9876500000');
      expect(restored.form.vehicleType, VehicleType.scooter);
      expect(restored.form.vehicleNumber, 'TN58AB1234');
      expect(restored.form.licenseNumber, 'TN5820200001234');
      expect(restored.form.aadhaarNumber, '234567890123');
      expect(restored.form.address, '12, Main Road');
      expect(restored.form.city, 'Madurai');
      expect(restored.form.pincode, '625020');
      expect(restored.form.accountHolderName, 'Ravi Kumar');
      expect(restored.form.bankAccountNumber, '123456789012');
      expect(restored.form.ifscCode, 'ABCD0123456');
      expect(restored.form.upiId, 'ravi@upi');
      expect(restored.photos[RiderDocument.selfie]?.path, '/tmp/selfie.jpg');
      expect(restored.photos[RiderDocument.selfie]?.contentType, 'image/jpeg');
      expect(restored.photos[RiderDocument.license]?.path, '/tmp/license.png');
      expect(restored.photos.containsKey(RiderDocument.aadhaarFront), isFalse);
    });

    test('the password never appears in the encoded wire form at all', () {
      final draft = RegistrationDraft(
        step: 0,
        form: _filledForm(),
        photos: const {},
        savedAt: DateTime.utc(2026, 9, 27),
      );
      final wire = jsonEncode(draft.toJson());
      expect(wire.contains('super-secret-1234'), isFalse);
      expect(wire.contains('password'), isFalse);
      // Restoring from a draft never fills in a password either.
      final restored = RegistrationDraft.fromJson(jsonDecode(wire));
      expect(restored!.form.password, '');
    });

    test('an unrecognisable value reads as no draft, not a crash', () {
      expect(RegistrationDraft.fromJson(null), isNull);
      expect(RegistrationDraft.fromJson('not a map'), isNull);
      expect(RegistrationDraft.fromJson(<String, dynamic>{}), isNull);
      expect(RegistrationDraft.fromJson({'version': 2, 'step': 0, 'form': {}, 'savedAt': DateTime.now().toIso8601String()}), isNull);
      expect(RegistrationDraft.fromJson({'version': 1, 'step': 'three', 'form': {}, 'savedAt': DateTime.now().toIso8601String()}), isNull);
      expect(RegistrationDraft.fromJson({'version': 1, 'step': 1, 'form': 'nope', 'savedAt': DateTime.now().toIso8601String()}), isNull);
      expect(RegistrationDraft.fromJson({'version': 1, 'step': 1, 'form': {}, 'savedAt': 'not-a-date'}), isNull);
    });

    test('a malformed photo entry is skipped, not fatal to the whole draft', () {
      final decoded = {
        'version': 1,
        'step': 3,
        'savedAt': DateTime.utc(2026, 9, 27).toIso8601String(),
        'form': {'name': 'Ravi'},
        'photos': {
          'selfie': {'path': '/tmp/selfie.jpg', 'contentType': 'image/jpeg'},
          'license': {'path': ''}, // missing contentType, empty path
          'aadhaarFront': 'not-even-a-map',
        },
      };
      final restored = RegistrationDraft.fromJson(decoded);
      expect(restored, isNotNull);
      expect(restored!.photos.keys, [RiderDocument.selfie]);
    });

    test('an out-of-range step is clamped into the valid 0-4 window', () {
      Map<String, dynamic> withStep(int s) => {
            'version': 1,
            'step': s,
            'savedAt': DateTime.utc(2026, 9, 27).toIso8601String(),
            'form': <String, dynamic>{},
          };
      expect(RegistrationDraft.fromJson(withStep(-5))!.step, 0);
      expect(RegistrationDraft.fromJson(withStep(99))!.step, 4);
      expect(RegistrationDraft.fromJson(withStep(2))!.step, 2);
    });

    test('an unknown vehicleType wire value falls back sensibly, never throws', () {
      final decoded = {
        'version': 1,
        'step': 2,
        'savedAt': DateTime.utc(2026, 9, 27).toIso8601String(),
        'form': {'vehicleType': 'spaceship'},
      };
      expect(RegistrationDraft.fromJson(decoded)!.form.vehicleType, VehicleType.bike);
    });
  });
}
