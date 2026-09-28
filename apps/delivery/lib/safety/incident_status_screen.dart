// lib/safety/incident_status_screen.dart
//
// Phase DLVC3 -- the rider-facing destination this app's safety reports
// have always been missing: emergency_sheet.dart's own `_reportSection`
// already reads and shows a report's live status (`watchIncident`,
// `incidentStatusText`, both already built and tested), but only as LOCAL
// widget state inside the modal sheet itself -- closing that sheet loses
// it, and there was never any way back to it, from a notification, from
// Profile, or after an app restart. This file adds the missing PERSISTENT
// destination, reusing that same already-correct data-reading logic rather
// than duplicating it: a single report's own status (pinned by its exact
// incidentId, the same by-id precedent identity/bank/document-review
// notifications already use), and a bounded list of a rider's own past
// reports for when more than one exists.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../design_system/design_system.dart';
import '../l10n/app_localizations.dart';
import '../screens/profile/identity_change_screen.dart' show RequestStatusCard;
import 'incident_report.dart';

/// One row of a rider's own past safety reports, for [MyIncidentsScreen].
typedef RiderIncidentsSource = Stream<List<Map<String, dynamic>>> Function(String riderId);

/// Bounded: a rider filing many reports over a long working history must
/// never turn this into an unbounded read. Matches this app's own
/// established "most recent N" convention (RiderInboxSource.kInboxSize).
const int kMyIncidentsLimit = 20;

Stream<List<Map<String, dynamic>>> _defaultIncidentsSource(String riderId) {
  try {
    return FirebaseFirestore.instance
        .collection('rider_incidents')
        .where('riderId', isEqualTo: riderId)
        .orderBy('createdAt', descending: true)
        .limit(kMyIncidentsLimit)
        .snapshots()
        .map((s) => s.docs.map((d) => {...d.data(), 'incidentId': d.id}).toList());
  } catch (e) {
    return Stream.error(e);
  }
}

DateTime? _relevantTimestamp(Map<String, dynamic> data) {
  Timestamp? ts(String key) => data[key] as Timestamp?;
  return (ts('resolvedAt') ?? ts('acknowledgedAt') ?? ts('createdAt'))?.toDate();
}

IconData _statusIcon(Object? status) => switch (status) {
      'resolved' => DeliveryIcons.checkCircle,
      'acknowledged' => DeliveryIcons.clock,
      _ => DeliveryIcons.shield,
    };

class IncidentStatusScreen extends StatelessWidget {
  const IncidentStatusScreen({super.key, required this.incidentId, this.watcher});
  final String incidentId;

  /// Injectable for tests; defaults to the real, already-established
  /// `watchIncident` (the same function `EmergencySheet` itself uses).
  final IncidentWatcher? watcher;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: Text(l.incidentStatusScreenTitle)),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: (watcher ?? watchIncident)(incidentId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // A permission-denied read (not this rider's own report -- the
          // security rule's own job, never re-checked here) and a
          // genuinely deleted/missing report both read as the SAME honest
          // "not available" card, matching DocumentSubmissionScreen's own
          // established reasoning for the identical ambiguity.
          final data = snap.hasError ? null : snap.data;
          if (data == null) {
            return RequestStatusCard(
              icon: DeliveryIcons.close,
              title: l.incidentStatusUnavailable,
              body: l.incidentStatusUnavailableBody,
            );
          }
          final s = incidentStatusText(l, data);
          final when = _relevantTimestamp(data);
          return RequestStatusCard(
            icon: _statusIcon(data['status']),
            title: s.title,
            body: when != null
                ? '${s.detail}\n\n${l.incidentStatusUpdatedOn(DeliveryFormat.dateTime(when.toLocal()))}'
                : s.detail,
          );
        },
      ),
    );
  }
}

class MyIncidentsScreen extends StatelessWidget {
  const MyIncidentsScreen({super.key, required this.riderId, this.incidentsSource, this.watcher});
  final String riderId;

  /// Injectable for tests; defaults to the real, riderId+createdAt-indexed,
  /// bounded query.
  final RiderIncidentsSource? incidentsSource;

  /// Threaded through to each [IncidentStatusScreen] this pushes, so a test
  /// driving this list all the way into a detail push never needs a real
  /// Firebase app either.
  final IncidentWatcher? watcher;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final t = context.text;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: Text(l.myIncidentsTitle)),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: (incidentsSource ?? _defaultIncidentsSource)(riderId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snap.data ?? const <Map<String, dynamic>>[];
          if (rows.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(DeliverySpace.page),
                child: Text(
                  l.myIncidentsEmpty,
                  textAlign: TextAlign.center,
                  style: t.bodyMedium.copyWith(color: c.textSecondary),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(DeliverySpace.page),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: DeliverySpace.sm),
            itemBuilder: (context, i) {
              final data = rows[i];
              final s = incidentStatusText(l, data);
              final when = _relevantTimestamp(data);
              return ListTile(
                key: ValueKey('incident-${data['incidentId']}'),
                tileColor: c.surface,
                shape: RoundedRectangleBorder(borderRadius: DeliveryRadius.rMd),
                leading: Icon(_statusIcon(data['status']), color: c.textSecondary),
                title: Text(s.title, style: t.bodyMedium.copyWith(color: c.textPrimary)),
                subtitle: when != null ? Text(DeliveryFormat.dateTime(when.toLocal())) : null,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => IncidentStatusScreen(incidentId: data['incidentId'] as String, watcher: watcher),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
