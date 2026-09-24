// lib/auth/rider_account_source.dart
//
// Phase DLV-C1 — the Firebase edges of the rider session, behind two small
// interfaces so the session logic (providers/auth_provider.dart) is tested
// without Firebase (test/auth_session_test.dart).
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// A refused sign-in, with the provider's error code.
class RiderAuthFailure implements Exception {
  const RiderAuthFailure(this.code);
  final String code;
}

/// One read of a profile document.
class ProfileRead {
  const ProfileRead({required this.exists, required this.fromCache, this.data});
  final bool exists;

  /// Answered from the device cache only — a "missing" here is not an answer.
  final bool fromCache;
  final Map<String, dynamic>? data;

  /// Missing on the server (not merely unknown).
  bool get missing => !exists && !fromCache;
}

abstract class RiderAuthGateway {
  /// The signed-in uid, then every change (null = signed out).
  Stream<String?> get uidChanges;
  String? get currentUid;

  /// Throws [RiderAuthFailure].
  Future<void> signIn(String email, String password);
  Future<void> signOut();

  /// Fetches fresh custom claims (after an admin status change).
  Future<void> refreshClaims();

  /// DLV-A1: asks Firebase to email a reset link. Throws [RiderAuthFailure]
  /// only for a malformed email or no connection — an unknown account is
  /// not an error (the reply must not reveal which emails have accounts).
  Future<void> sendPasswordReset(String email);
}

abstract class RiderAccountStore {
  Future<ProfileRead> user(String uid);
  Future<ProfileRead> partner(String uid);
  Stream<ProfileRead> watchPartner(String uid);

  /// users/{uid}.fcmTokens bookkeeping for this device's token.
  Future<void> addToken(String uid, String token);
  Future<void> removeToken(String uid, String token);
}

/// Device push-token operations.
abstract class RiderPushTokens {
  Future<String?> current();
  Stream<String> get refreshed;

  /// Invalidates this device's token (no more pushes to it).
  Future<void> forget();
}

class FirebaseRiderAuthGateway implements RiderAuthGateway {
  FirebaseAuth get _auth => FirebaseAuth.instance;

  @override
  Stream<String?> get uidChanges => _auth.authStateChanges().map((u) => u?.uid);

  @override
  String? get currentUid => _auth.currentUser?.uid;

  @override
  Future<void> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw RiderAuthFailure(e.code);
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> refreshClaims() async {
    try {
      await _auth.currentUser?.getIdToken(true);
    } catch (e) {
      debugPrint('Claims refresh skipped: $e');
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      debugPrint('Password reset: ${e.code}');
      if (e.code == 'invalid-email' || e.code == 'missing-email' || e.code == 'network-request-failed' ||
          e.code == 'too-many-requests') {
        throw RiderAuthFailure(e.code);
      }
      // user-not-found and anything else: same answer as success.
    }
  }
}

class FirestoreRiderAccountStore implements RiderAccountStore {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  ProfileRead _read(DocumentSnapshot<Map<String, dynamic>> s) =>
      ProfileRead(exists: s.exists, fromCache: s.metadata.isFromCache, data: s.data());

  @override
  Future<ProfileRead> user(String uid) async => _read(await _db.collection('users').doc(uid).get());

  @override
  Future<ProfileRead> partner(String uid) async => _read(await _db.collection('delivery_partners').doc(uid).get());

  @override
  Stream<ProfileRead> watchPartner(String uid) =>
      _db.collection('delivery_partners').doc(uid).snapshots().map(_read);

  @override
  Future<void> addToken(String uid, String token) => _db.collection('users').doc(uid).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> removeToken(String uid, String token) async {
    final ref = _db.collection('users').doc(uid);
    final snap = await ref.get();
    await ref.update({
      'fcmTokens': FieldValue.arrayRemove([token]),
      if (snap.data()?['fcmToken'] == token) 'fcmToken': FieldValue.delete(),
    });
  }
}

class FcmPushTokens implements RiderPushTokens {
  @override
  Future<String?> current() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('Push token unavailable: $e');
      return null;
    }
  }

  @override
  Stream<String> get refreshed {
    try {
      return FirebaseMessaging.instance.onTokenRefresh;
    } catch (_) {
      return const Stream.empty();
    }
  }

  @override
  Future<void> forget() async {
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('Push token delete skipped: $e');
    }
  }
}
