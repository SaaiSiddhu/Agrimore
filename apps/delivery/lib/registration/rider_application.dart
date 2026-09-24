// lib/registration/rider_application.dart
//
// Phase DLV-A1 — the rider application, checked here with the same rules and
// the same problem keys as the server (functions/src/delivery/
// riderApplication.ts validateRiderApplication), so the form can point at the
// field before a round trip. The server re-checks everything; its answer wins.
//
// Registration contract:
//   1. [RegistrationService.ensureAccount] creates the Auth account once;
//      signed in already (a resumed registration) → reuses it. The password
//      is used exactly as typed. The account is never deleted on failure.
//   2. [RegistrationService.upload] writes each photo to its fixed path,
//      delivery_documents/{uid}/{doc} — a retry overwrites, nothing piles up.
//   3. [RegistrationService.submit] calls submitRiderApplication, which
//      writes users + delivery_partners in one transaction.
// Covered by test/rider_application_test.dart.
import 'package:agrimore_core/agrimore_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// The four KYC photos, by the key the server uses.
enum RiderDocument {
  aadhaarFront('aadhaarFront'),
  aadhaarBack('aadhaarBack'),
  selfie('selfie'),
  license('license');

  const RiderDocument(this.key);
  final String key;
  String pathFor(String uid) => 'delivery_documents/$uid/$key';
}

final _phone = RegExp(r'^[6-9]\d{9}$');
final _aadhaar = RegExp(r'^[2-9]\d{11}$');
final _pincode = RegExp(r'^[1-9]\d{5}$');
final _ifsc = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');
final _account = RegExp(r'^\d{9,18}$');
final _upi = RegExp(r'^[a-zA-Z0-9._-]{2,256}@[a-zA-Z]{2,64}$');
final _plate = RegExp(r'^[A-Z0-9]{4,12}$');
final _licence = RegExp(r'^[A-Z0-9-]{6,20}$');
final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// "+91 98765-43210" → "9876543210" (as the server normalises it).
String normPhone(String v) {
  final s = v.trim().replaceAll(RegExp(r'[\s-]'), '');
  return s.replaceFirst(RegExp(r'^(\+91|0091|91(?=\d{10}$)|0(?=\d{10}$))'), '');
}

String _upper(String v) => v.trim().replaceAll(RegExp(r'[\s-]'), '').toUpperCase();

/// Everything the rider types. Mutable: the form edits it in place, so a
/// failed step or submission never loses what was entered.
class RiderApplicationForm {
  String email = '';
  String password = '';
  String name = '';
  String phone = '';
  String altPhone = '';
  VehicleType vehicleType = VehicleType.bike;
  String vehicleNumber = '';
  String licenseNumber = '';
  String aadhaarNumber = '';
  String address = '';
  String city = '';
  String pincode = '';
  String accountHolderName = '';
  String bankAccountNumber = '';
  String ifscCode = '';
  String upiId = '';

  bool get needsPlate => vehicleType != VehicleType.bicycle;

  /// The callable's payload (no email/password — those never leave Auth).
  Map<String, dynamic> toPayload() => {
        'name': name.trim(),
        'phone': phone,
        'altPhone': altPhone,
        'vehicleType': vehicleType.wire,
        'vehicleNumber': needsPlate ? vehicleNumber : '',
        'licenseNumber': licenseNumber,
        'aadhaarNumber': aadhaarNumber,
        'address': address.trim(),
        'city': city.trim(),
        'pincode': pincode.trim(),
        'accountHolderName': accountHolderName.trim(),
        'bankAccountNumber': bankAccountNumber.trim(),
        'ifscCode': ifscCode,
        'upiId': upiId.trim(),
      };
}

/// Account-step problem keys.
List<String> accountProblems(RiderApplicationForm f, {required bool needsAccount}) {
  if (!needsAccount) return const [];
  return [
    if (!_email.hasMatch(f.email.trim())) 'email',
    // Firebase's own minimum; never trimmed.
    if (f.password.length < 6) 'password',
  ];
}

/// Problem keys for the details the server validates (same keys as the server).
List<String> applicationProblems(RiderApplicationForm f) {
  final problems = <String>[];
  final name = f.name.trim();
  if (name.length < 2 || name.length > 80) problems.add('name');
  final phone = normPhone(f.phone);
  if (!_phone.hasMatch(phone)) problems.add('phone');
  if (f.altPhone.trim().isNotEmpty) {
    final alt = normPhone(f.altPhone);
    if (!_phone.hasMatch(alt) || alt == phone) problems.add('altPhone');
  }
  if (f.needsPlate && !_plate.hasMatch(_upper(f.vehicleNumber))) problems.add('vehicleNumber');
  if (!_licence.hasMatch(_upper(f.licenseNumber))) problems.add('licenseNumber');
  if (!_aadhaar.hasMatch(f.aadhaarNumber.replaceAll(RegExp(r'[\s-]'), ''))) problems.add('aadhaarNumber');
  final address = f.address.trim();
  if (address.length < 5 || address.length > 300) problems.add('address');
  final city = f.city.trim();
  if (city.length < 2 || city.length > 60) problems.add('city');
  if (!_pincode.hasMatch(f.pincode.trim())) problems.add('pincode');
  final holder = f.accountHolderName.trim(), account = f.bankAccountNumber.replaceAll(' ', ''), ifsc = _upper(f.ifscCode);
  if (holder.isNotEmpty || account.isNotEmpty || ifsc.isNotEmpty) {
    if (holder.length < 2 || holder.length > 80) problems.add('accountHolderName');
    if (!_account.hasMatch(account)) problems.add('bankAccountNumber');
    if (!_ifsc.hasMatch(ifsc)) problems.add('ifscCode');
  }
  if (f.upiId.trim().isNotEmpty && !_upi.hasMatch(f.upiId.trim())) problems.add('upiId');
  return problems;
}

/// "XXXX XXXX 0123" — the Aadhaar number as shown back to the rider.
String maskAadhaar(String raw) {
  final d = raw.replaceAll(RegExp(r'\D'), '');
  if (d.length < 4) return d;
  return 'XXXX XXXX ${d.substring(d.length - 4)}';
}

/// Why a registration step failed. Worded by the screen.
enum RegistrationFailure {
  emailInUse,
  weakPassword,
  invalidEmail,
  network,
  uploadFailed,
  invalidDetails,
  documentsMissing,
  alreadyRegistered,
  otherAccountRole,
  unknown,
}

class RegistrationException implements Exception {
  const RegistrationException(this.failure, [this.problems = const []]);
  final RegistrationFailure failure;
  final List<String> problems;
}

/// The Firebase side of registration (fakes in tests).
abstract class RegistrationBackend {
  String? get currentUid;
  Future<String> createAccount(String email, String password);
  Future<void> uploadPhoto(String path, Uint8List bytes, String contentType);
  Future<void> submit(Map<String, dynamic> payload);
}

class FirebaseRegistrationBackend implements RegistrationBackend {
  @override
  String? get currentUid => FirebaseAuth.instance.currentUser?.uid;

  @override
  Future<String> createAccount(String email, String password) async {
    try {
      final c = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
      return c.user!.uid;
    } on FirebaseAuthException catch (e) {
      debugPrint('Account creation refused: ${e.code}');
      throw RegistrationException(switch (e.code) {
        'email-already-in-use' => RegistrationFailure.emailInUse,
        'weak-password' => RegistrationFailure.weakPassword,
        'invalid-email' => RegistrationFailure.invalidEmail,
        'network-request-failed' => RegistrationFailure.network,
        _ => RegistrationFailure.unknown,
      });
    }
  }

  @override
  Future<void> uploadPhoto(String path, Uint8List bytes, String contentType) async {
    try {
      await FirebaseStorage.instance.ref(path).putData(bytes, SettableMetadata(contentType: contentType));
    } on FirebaseException catch (e) {
      debugPrint('Photo upload failed: ${e.code}');
      throw RegistrationException(
          e.code == 'retry-limit-exceeded' ? RegistrationFailure.network : RegistrationFailure.uploadFailed);
    }
  }

  @override
  Future<void> submit(Map<String, dynamic> payload) async {
    try {
      await FirebaseFunctions.instance.httpsCallable('submitRiderApplication').call<Map<String, dynamic>>(payload);
    } on FirebaseFunctionsException catch (e) {
      final details = e.details is Map ? e.details as Map : const {};
      final reason = details['reason'] as String?;
      final problems = (details['problems'] as List?)?.whereType<String>().toList() ?? const <String>[];
      debugPrint('Application refused: ${e.code} $reason');
      throw RegistrationException(
        switch (reason) {
          'invalid' => RegistrationFailure.invalidDetails,
          'documents' => RegistrationFailure.documentsMissing,
          'already_registered' => RegistrationFailure.alreadyRegistered,
          'other_account_role' => RegistrationFailure.otherAccountRole,
          _ => e.code == 'unavailable' ? RegistrationFailure.network : RegistrationFailure.unknown,
        },
        problems,
      );
    }
  }
}

/// One photo chosen by the rider.
typedef PickedPhoto = ({Uint8List bytes, String contentType});

/// Runs the three steps. Every step can be retried: the account is reused,
/// photos overwrite their fixed paths, the submission updates one record.
class RegistrationService {
  RegistrationService([RegistrationBackend? backend]) : backend = backend ?? FirebaseRegistrationBackend();
  final RegistrationBackend backend;

  /// Photos already uploaded in this attempt (skipped on retry).
  final Set<RiderDocument> uploaded = {};

  Future<String> ensureAccount(RiderApplicationForm f) async {
    final existing = backend.currentUid;
    if (existing != null) return existing;
    return backend.createAccount(f.email.trim(), f.password);
  }

  Future<void> submitAll(RiderApplicationForm f, Map<RiderDocument, PickedPhoto> photos) async {
    final uid = await ensureAccount(f);
    for (final doc in RiderDocument.values) {
      if (uploaded.contains(doc)) continue;
      final photo = photos[doc];
      if (photo == null) throw const RegistrationException(RegistrationFailure.documentsMissing);
      await backend.uploadPhoto(doc.pathFor(uid), photo.bytes, photo.contentType);
      uploaded.add(doc);
    }
    await backend.submit(f.toPayload());
  }
}
