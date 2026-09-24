// lib/safety/incident_report.dart
//
// Phase DLV-S2 — "Tell the Agrimore team" on the emergency sheet. The report
// goes through reportRiderIncident (functions/src/delivery/riderIncidents.ts),
// which writes rider_incidents/{riderId}_{requestId}; the rider can only read
// it back. What the rider is shown follows the record, never a hope:
//   reported      → recorded; nobody at Agrimore has necessarily seen it yet
//   acknowledged  → a person on the Agrimore team opened it
//   resolved      → closed, with what the team wrote
// None of these means police, an ambulance or anyone else is coming.
//
// The pure parts (request id, status wording, refusal wording) are covered by
// test/incident_report_test.dart.
import 'package:agrimore_core/agrimore_core.dart';
import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../delivery/rider_steps.dart' show fixPayload;

/// A report that did not go through, with a sentence the rider can act on.
class IncidentReportException implements Exception {
  const IncidentReportException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Sends the report; returns the incident id. Throws [IncidentReportException].
typedef IncidentReporter = Future<String> Function(Map<String, dynamic> payload);

/// The incident record as the rider may read it (null until it is known).
typedef IncidentWatcher = Stream<Map<String, dynamic>?> Function(String incidentId);

/// The rider's position right now, as reportRiderIncident expects it, or an
/// empty map. Never asks for permission and never waits long: a report must
/// not be held up by GPS.
typedef IncidentFix = Future<Map<String, dynamic>> Function();

const _idChars = 'abcdefghijklmnopqrstuvwxyz0123456789';

/// A request id for one report (server: 8–64 of [A-Za-z0-9_-]). One per
/// sheet, reused on retry, so a report whose answer was lost is not recorded
/// twice.
String newIncidentRequestId([Random? random]) {
  final r = random ?? Random.secure();
  return List.generate(20, (_) => _idChars[r.nextInt(_idChars.length)]).join();
}

/// A sentence for a refusal from reportRiderIncident (never the raw message).
String incidentErrorMessage(String code, String? reason) {
  switch (reason) {
    case 'too_many':
      return 'Too many reports in a few minutes. Call 112 or Agrimore support.';
    case 'not_a_rider':
      return 'This account cannot report here. Call 112 or Agrimore support.';
  }
  switch (code) {
    case 'unavailable':
    case 'deadline-exceeded':
      return "No connection — the report didn't go through. Try again, or call 112.";
    case 'unauthenticated':
      return 'You are signed out. Call 112 or Agrimore support.';
  }
  return "The report didn't go through. Try again, or call 112.";
}

/// What the rider sees for the record's state: a title and a line under it.
({String title, String detail}) incidentStatusText(Map<String, dynamic>? data) {
  final status = data?['status'];
  if (status == 'resolved') {
    final r = (data?['resolution'] as String?)?.trim() ?? '';
    return (title: 'Closed by the Agrimore team', detail: r.isEmpty ? 'No note was added.' : r);
  }
  if (status == 'acknowledged') {
    return (
      title: 'Seen by the Agrimore team',
      detail: 'A person on the team has opened your report. If you are in danger, call 112.',
    );
  }
  return (
    title: 'Report recorded',
    detail: 'Nobody on the Agrimore team may have seen it yet. If you are in danger, call 112 now.',
  );
}

Future<String> reportIncidentCallable(Map<String, dynamic> payload) async {
  try {
    final r = await FirebaseFunctions.instance
        .httpsCallable('reportRiderIncident', options: HttpsCallableOptions(timeout: DeliveryTiming.incidentCallTimeout))
        .call<Map<String, dynamic>>(payload);
    final id = r.data['incidentId'];
    if (id is String && id.isNotEmpty) return id;
    throw const IncidentReportException("The report didn't go through. Try again, or call 112.");
  } on FirebaseFunctionsException catch (e) {
    final reason = e.details is Map ? (e.details as Map)['reason'] as String? : null;
    debugPrint('reportRiderIncident refused: ${e.code} $reason');
    throw IncidentReportException(incidentErrorMessage(e.code, reason));
  } on IncidentReportException {
    rethrow;
  } catch (e) {
    debugPrint('reportRiderIncident error: $e');
    throw IncidentReportException(incidentErrorMessage('unavailable', null));
  }
}

Stream<Map<String, dynamic>?> watchIncident(String incidentId) => FirebaseFirestore.instance
    .collection('rider_incidents')
    .doc(incidentId)
    .snapshots()
    // A cache-only "missing" is not an answer (web SDK offline after ~10 s).
    .where((s) => s.exists || !s.metadata.isFromCache)
    .map((s) => s.data());

Future<Map<String, dynamic>> quickIncidentFix() async {
  try {
    final p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return {};
    if (!await Geolocator.isLocationServiceEnabled()) return {};
    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: DeliveryTiming.reportFixRequestLimit),
      );
    } catch (_) {
      pos = await Geolocator.getLastKnownPosition();
    }
    if (pos == null) return {};
    final f = fixPayload(lat: pos.latitude, lng: pos.longitude, accuracy: pos.accuracy, isMocked: pos.isMocked);
    f.remove('locationStatus');
    return f;
  } catch (e) {
    debugPrint('Incident fix unavailable: $e');
    return {};
  }
}
