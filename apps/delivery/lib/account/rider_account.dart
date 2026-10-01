// lib/account/rider_account.dart
//
// Phase DLV-A2 — account actions shared by the profile and the account-status
// screens: signing out (offline first, so the server stops offering orders),
// editing the rider's own contact details (updateRiderContact), and deleting
// the account (deleteUserData's rider branch, which refuses while an order
// is assigned, customers' cash is held or pay is owed). Covered by
// test/rider_account_test.dart.
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/location_provider.dart';

/// Stops location, marks the rider offline, then signs out (DLV-3A: the
/// foreground service and the server's isOnline would outlive the session).
Future<void> riderSignOut(BuildContext context) async {
  final auth = context.read<DeliveryAuthProvider>();
  final location = context.read<LocationProvider>();
  final uid = auth.user?.uid;
  location.stopTracking();
  if (uid != null) await location.setOnlineStatus(uid, false);
  await auth.signOut();
}

/// Why an account action did not go through. Worded by the screen.
enum AccountActionFailure {
  activeOrder,
  cashHeld,
  payOwed,
  otherBalance,
  invalid,
  network,
  unknown,
}

class AccountActionException implements Exception {
  const AccountActionException(this.failure, [this.problems = const []]);
  final AccountActionFailure failure;
  final List<String> problems;
}

AccountActionFailure accountFailureOf(String code, String? reason) =>
    switch (reason) {
      'rider_active_order' => AccountActionFailure.activeOrder,
      'rider_cash_held' => AccountActionFailure.cashHeld,
      'rider_pay_owed' => AccountActionFailure.payOwed,
      'invalid' => AccountActionFailure.invalid,
      _ => switch (code) {
          // deleteUserData's customer/seller refusals (wallet balance,
          // customer orders, seller settlements) carry no reason.
          'failed-precondition' => AccountActionFailure.otherBalance,
          'unavailable' || 'deadline-exceeded' => AccountActionFailure.network,
          _ => AccountActionFailure.unknown,
        },
    };

/// The callables (fakes in tests).
abstract class RiderAccountBackend {
  Future<void> updateContact(Map<String, dynamic> contact);
  Future<void> deleteAccount();
}

class CallableRiderAccountBackend implements RiderAccountBackend {
  CallableRiderAccountBackend({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance;
  final FirebaseAuth _auth;
  Future<void> _call(String name, Map<String, dynamic> data) async {
    try {
      await FirebaseFunctions.instance.httpsCallable(name).call<dynamic>(data);
    } on FirebaseFunctionsException catch (e) {
      final details = e.details is Map ? e.details as Map : const {};
      debugPrint('$name refused: ${e.code} ${details['reason']}');
      throw AccountActionException(
        accountFailureOf(e.code, details['reason'] as String?),
        (details['problems'] as List?)?.whereType<String>().toList() ??
            const [],
      );
    }
  }

  @override
  Future<void> updateContact(Map<String, dynamic> contact) =>
      _call('updateRiderContact', contact);

  @override
  Future<void> deleteAccount() async {
    final owner = _auth.currentUser?.uid;
    if (owner == null) {
      throw const AccountActionException(AccountActionFailure.unknown);
    }
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('deleteUserData')
          .call<dynamic>({'expectedOwnerId': owner});
      final data = result.data;
      if (data is! Map ||
          data['success'] != true ||
          (_auth.currentUser != null && _auth.currentUser!.uid != owner)) {
        throw const AccountActionException(AccountActionFailure.unknown);
      }
    } on FirebaseFunctionsException catch (e) {
      final details = e.details is Map ? e.details as Map : const {};
      throw AccountActionException(
          accountFailureOf(e.code, details['reason'] as String?));
    } on AccountActionException {
      rethrow;
    } catch (_) {
      throw const AccountActionException(AccountActionFailure.unknown);
    }
  }
}
