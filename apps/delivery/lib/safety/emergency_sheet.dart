// lib/safety/emergency_sheet.dart
//
// Phase DLV-S1 — what the SOS button honestly does. It used to show "SOS
// Alert Sent! Live location shared with authorities and admin." and send
// nothing at all. This sheet only hands the rider to the phone's dialer:
// 112 (India's single emergency number, ERSS) and Agrimore support. Opening
// the dialer is not a completed call, so nothing here says anyone was called,
// alerted or sent a location. "Tell the Agrimore team" (DLV-S2) records a
// report on the server and shows its real state (incident_report.dart).
import 'package:agrimore_core/agrimore_core.dart' show AppConstants, DeliveryTiming;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'incident_report.dart';

/// India's single emergency number (Emergency Response Support System).
const String kEmergencyNumber = '112';

/// Opens [uri] in the phone app; true when the dialer was handed the number.
typedef DialLauncher = Future<bool> Function(Uri uri);

Future<bool> _launchDialer(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    debugPrint('Dialer launch failed: $e');
    return false;
  }
}

/// `tel:` URI for [number] with spaces and dashes removed; null if empty.
Uri? dialUri(String? number) {
  final n = (number ?? '').replaceAll(RegExp(r'[\s-]'), '');
  if (n.isEmpty || !RegExp(r'^\+?[0-9]{3,15}$').hasMatch(n)) return null;
  return Uri(scheme: 'tel', path: n);
}

Future<void> showEmergencySheet(
  BuildContext context, {
  DialLauncher? launcher,
  String? supportPhone,
  IncidentReporter? reporter,
  IncidentWatcher? watcher,
  IncidentFix? fix,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => EmergencySheet(
      launcher: launcher ?? _launchDialer,
      supportPhone: supportPhone ?? AppConstants.supportPhone,
      reporter: reporter ?? reportIncidentCallable,
      watcher: watcher ?? watchIncident,
      fix: fix ?? quickIncidentFix,
    ),
  );
}

class EmergencySheet extends StatefulWidget {
  const EmergencySheet({
    super.key,
    required this.launcher,
    this.supportPhone,
    this.reporter,
    this.watcher,
    this.fix,
  });
  final DialLauncher launcher;
  final String? supportPhone;

  /// Null hides "Tell the Agrimore team" (the dial-only sheet).
  final IncidentReporter? reporter;
  final IncidentWatcher? watcher;
  final IncidentFix? fix;

  @override
  State<EmergencySheet> createState() => _EmergencySheetState();
}

class _EmergencySheetState extends State<EmergencySheet> {
  String? _problem;

  // One request id per sheet, reused on retry: a report whose answer was
  // lost is found again by the server, not recorded twice.
  final String _requestId = newIncidentRequestId();
  bool _sending = false;
  String? _reportError;
  Stream<Map<String, dynamic>?>? _record;

  Future<void> _report() async {
    if (_sending || _record != null) return;
    setState(() {
      _sending = true;
      _reportError = null;
    });
    // Position is best effort and bounded: the report must not wait on GPS.
    Map<String, dynamic> fix = const {};
    if (widget.fix != null) {
      try {
        fix = await widget.fix!().timeout(DeliveryTiming.reportFixTimeout);
      } catch (_) {}
    }
    try {
      final id = await widget.reporter!({'requestId': _requestId, 'kind': 'sos', ...fix});
      if (!mounted) return;
      setState(() {
        _sending = false;
        _record = widget.watcher?.call(id).asBroadcastStream() ?? Stream.value(null);
      });
    } on IncidentReportException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _reportError = e.message;
      });
    } catch (e) {
      debugPrint('Incident report failed: $e');
      if (!mounted) return;
      setState(() {
        _sending = false;
        _reportError = incidentErrorMessage('unknown', null);
      });
    }
  }

  Widget _reportSection(ColorScheme cs) {
    if (_record != null) {
      return StreamBuilder<Map<String, dynamic>?>(
        stream: _record,
        builder: (context, snap) {
          final t = incidentStatusText(snap.data);
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(t.detail, style: TextStyle(color: cs.onSurfaceVariant, height: 1.35)),
              ],
            ),
          );
        },
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _sending ? null : _report,
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          icon: _sending
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.report_rounded),
          label: Text(
              _sending ? 'Recording your report…' : (_reportError != null ? 'Try again' : 'Tell the Agrimore team')),
        ),
        const SizedBox(height: 6),
        Text(
          'Records a report for the Agrimore team with your current order and, if the phone has it, your position. '
          'It does not call anyone.',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        if (_reportError != null) ...[
          const SizedBox(height: 8),
          Text(_reportError!, style: TextStyle(color: cs.error, fontWeight: FontWeight.w600)),
        ],
      ],
    );
  }

  Future<void> _dial(Uri uri, String numberShown) async {
    setState(() => _problem = null);
    final opened = await widget.launcher(uri);
    if (!mounted) return;
    if (!opened) {
      setState(() => _problem = "Couldn't open the phone app. Dial $numberShown directly.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final support = dialUri(widget.supportPhone);
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.sos_rounded, color: cs.error, size: 28),
                  const SizedBox(width: 10),
                  const Text('Emergency help', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'If you or someone else is in danger, call $kEmergencyNumber now. '
                'This app does not alert the police or Agrimore by itself.',
                style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _dial(dialUri(kEmergencyNumber)!, kEmergencyNumber),
                style: FilledButton.styleFrom(
                  backgroundColor: cs.error,
                  foregroundColor: cs.onError,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.call_rounded),
                label: const Text('Call $kEmergencyNumber (emergency)', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              if (support != null) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _dial(support, widget.supportPhone!),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  icon: const Icon(Icons.support_agent_rounded),
                  label: const Text('Call Agrimore support'),
                ),
              ],
              if (widget.reporter != null) ...[
                const SizedBox(height: 16),
                _reportSection(cs),
              ],
              if (_problem != null) ...[
                const SizedBox(height: 12),
                Text(_problem!, style: TextStyle(color: cs.error, fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
