// lib/registration/registration_draft.dart
//
// Phase DLVID4 — local, on-device recovery for an interrupted registration.
// RegistrationService.ensureAccount() only runs inside submitAll() (the
// final step), so for steps 0-3 there is no Firebase Auth UID yet and
// nothing server-side to key a draft by; this is why the draft lives here,
// on-device, rather than as a Firestore document. Keyed by
// currentUid ?? '_pending' so a signed-in rider's draft never leaks to a
// different account on the same device once one exists.
//
// Never persists RiderApplicationForm.password: a stored draft that could
// hand back a rider's login credentials from disk is a bigger risk than
// losing typed text.
import 'dart:convert';

import 'package:agrimore_core/agrimore_core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'rider_application.dart';

const _draftVersion = 1;

/// Where one picked document photo is staged on disk, so it can be re-read
/// without asking the rider to pick it again — unless the file is gone.
class DraftPhoto {
  const DraftPhoto({required this.path, required this.contentType});
  final String path;
  final String contentType;

  Map<String, dynamic> toJson() => {'path': path, 'contentType': contentType};

  static DraftPhoto? fromJson(Object? j) {
    if (j is! Map) return null;
    final path = j['path'];
    final contentType = j['contentType'];
    if (path is! String || path.isEmpty || contentType is! String || contentType.isEmpty) {
      return null;
    }
    return DraftPhoto(path: path, contentType: contentType);
  }
}

/// A snapshot of an in-progress registration, restorable after the process
/// that created it is gone. Never carries the account password.
class RegistrationDraft {
  const RegistrationDraft({
    required this.step,
    required this.form,
    required this.photos,
    required this.savedAt,
  });

  final int step;
  final RiderApplicationForm form;
  final Map<RiderDocument, DraftPhoto> photos;
  final DateTime savedAt;

  Map<String, dynamic> toJson() => {
        'version': _draftVersion,
        'step': step,
        'savedAt': savedAt.toIso8601String(),
        'form': {
          'email': form.email,
          'name': form.name,
          'phone': form.phone,
          'altPhone': form.altPhone,
          'vehicleType': form.vehicleType.wire,
          'vehicleNumber': form.vehicleNumber,
          'licenseNumber': form.licenseNumber,
          'aadhaarNumber': form.aadhaarNumber,
          'address': form.address,
          'city': form.city,
          'pincode': form.pincode,
          'accountHolderName': form.accountHolderName,
          'bankAccountNumber': form.bankAccountNumber,
          'ifscCode': form.ifscCode,
          'upiId': form.upiId,
          // password intentionally omitted -- never persisted.
        },
        'photos': {for (final e in photos.entries) e.key.key: e.value.toJson()},
      };

  /// Rebuilds a draft from stored JSON. Anything that isn't a recognisable
  /// version-1 draft reads as "no draft" — a corrupt or foreign-shaped value
  /// is never treated as a crash.
  static RegistrationDraft? fromJson(Object? decoded) {
    if (decoded is! Map) return null;
    if (decoded['version'] != _draftVersion) return null;
    final step = decoded['step'];
    final formJson = decoded['form'];
    final savedAtRaw = decoded['savedAt'];
    if (step is! int || formJson is! Map || savedAtRaw is! String) return null;
    final savedAt = DateTime.tryParse(savedAtRaw);
    if (savedAt == null) return null;

    String s(String k) => (formJson[k] as String?) ?? '';
    final form = RiderApplicationForm()
      ..email = s('email')
      ..name = s('name')
      ..phone = s('phone')
      ..altPhone = s('altPhone')
      ..vehicleType = VehicleType.fromWire(formJson['vehicleType'] as String?)
      ..vehicleNumber = s('vehicleNumber')
      ..licenseNumber = s('licenseNumber')
      ..aadhaarNumber = s('aadhaarNumber')
      ..address = s('address')
      ..city = s('city')
      ..pincode = s('pincode')
      ..accountHolderName = s('accountHolderName')
      ..bankAccountNumber = s('bankAccountNumber')
      ..ifscCode = s('ifscCode')
      ..upiId = s('upiId');

    final photosJson = decoded['photos'];
    final photos = <RiderDocument, DraftPhoto>{};
    if (photosJson is Map) {
      for (final doc in RiderDocument.values) {
        final p = DraftPhoto.fromJson(photosJson[doc.key]);
        if (p != null) photos[doc] = p;
      }
    }

    return RegistrationDraft(
      step: step < 0 ? 0 : (step > 4 ? 4 : step),
      form: form,
      photos: photos,
      savedAt: savedAt,
    );
  }
}

/// Persists and retrieves a [RegistrationDraft] by key. Injectable so tests
/// never touch real secure storage.
abstract class RegistrationDraftStore {
  Future<RegistrationDraft?> load(String key);
  Future<void> save(String key, RegistrationDraft draft);
  Future<void> clear(String key);
}

/// Real device storage: the OS keychain/keystore via flutter_secure_storage,
/// not shared_preferences — the draft can carry a bank account number and an
/// Aadhaar number, so it gets the same protection level as a credential.
class SecureRegistrationDraftStore implements RegistrationDraftStore {
  SecureRegistrationDraftStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;

  String _storageKey(String key) => 'rider_registration_draft_$key';

  @override
  Future<RegistrationDraft?> load(String key) async {
    final raw = await _storage.read(key: _storageKey(key));
    if (raw == null) return null;
    try {
      return RegistrationDraft.fromJson(jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> save(String key, RegistrationDraft draft) =>
      _storage.write(key: _storageKey(key), value: jsonEncode(draft.toJson()));

  @override
  Future<void> clear(String key) => _storage.delete(key: _storageKey(key));
}
