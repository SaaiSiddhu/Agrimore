// lib/safety/emergency_sheet.dart
//
// Phase DLV-S1 — what the SOS button honestly does. It used to show "SOS
// Alert Sent! Live location shared with authorities and admin." and send
// nothing at all. This sheet only hands the rider to the phone's dialer:
// 112 (India's single emergency number, ERSS) and Agrimore support. Opening
// the dialer is not a completed call, so nothing here says anyone was called,
// alerted or sent a location. "Tell the Agrimore team" (DLV-S2) records a
// report on the server and shows its real state (incident_report.dart).
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
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
  /// The number the dialer could not be handed, if any.
  String? _dialFailedFor;

  // One request id per sheet, reused on retry: a report whose answer was
  // lost is found again by the server, not recorded twice.
  final String _requestId = newIncidentRequestId();
  bool _sending = false;
  IncidentReportException? _reportError;
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
        _reportError = e;
      });
    } catch (e) {
      debugPrint('Incident report failed: $e');
      if (!mounted) return;
      setState(() {
        _sending = false;
        _reportError = const IncidentReportException('unknown');
      });
    }
  }

  Widget _reportSection(AppLocalizations l) {
    final t = context.ws;
    final text = Theme.of(context).textTheme;
    if (_record != null) {
      return StreamBuilder<Map<String, dynamic>?>(
        stream: _record,
        builder: (context, snap) {
          final s = incidentStatusText(l, snap.data);
          return Container(
            padding: const EdgeInsets.all(WsSpace.s12),
            decoration: BoxDecoration(color: t.surfaceSunken, borderRadius: BorderRadius.circular(WsRadius.card)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.title, style: text.titleSmall),
                const SizedBox(height: WsSpace.s4),
                Text(s.detail, style: text.bodyMedium?.copyWith(color: t.textSecondary)),
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
          icon: _sending
              ? const SizedBox.square(
                  dimension: WsIconSize.control, child: CircularProgressIndicator(strokeWidth: WsSize.focusRing))
              : const Icon(AgIcons.report),
          label: Text(_sending
              ? l.incidentReportSending
              : (_reportError != null ? l.actionRetry : l.incidentReportAction)),
        ),
        const SizedBox(height: WsSpace.s8),
        Text(l.incidentReportHint, style: text.bodySmall?.copyWith(color: t.textSecondary)),
        if (_reportError != null) ...[
          const SizedBox(height: WsSpace.s8),
          Text(_reportError!.message(l), style: text.bodyMedium?.copyWith(color: t.errorFg)),
        ],
      ],
    );
  }

  Future<void> _dial(Uri uri, String numberShown) async {
    setState(() => _dialFailedFor = null);
    final opened = await widget.launcher(uri);
    if (!mounted) return;
    if (!opened) setState(() => _dialFailedFor = numberShown);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.ws;
    final text = Theme.of(context).textTheme;
    final support = dialUri(widget.supportPhone);
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(WsSpace.page, 0, WsSpace.page, WsSpace.s20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(AgIcons.emergency, color: t.errorFg, size: WsIconSize.feature),
                  const SizedBox(width: WsSpace.s12),
                  Expanded(child: Text(l.emergencyTitle, style: text.titleLarge)),
                ],
              ),
              const SizedBox(height: WsSpace.s8),
              Text(l.emergencyIntro(kEmergencyNumber), style: text.bodyMedium?.copyWith(color: t.textSecondary)),
              const SizedBox(height: WsSpace.s16),
              FilledButton.icon(
                onPressed: () => _dial(dialUri(kEmergencyNumber)!, kEmergencyNumber),
                style: FilledButton.styleFrom(backgroundColor: t.errorFg, foregroundColor: t.surface),
                icon: const Icon(AgIcons.call),
                label: Text(l.emergencyCall(kEmergencyNumber)),
              ),
              if (support != null) ...[
                const SizedBox(height: WsSpace.s12),
                OutlinedButton.icon(
                  onPressed: () => _dial(support, widget.supportPhone!),
                  icon: const Icon(AgIcons.support),
                  label: Text(l.emergencyCallSupport),
                ),
              ],
              if (widget.reporter != null) ...[
                const SizedBox(height: WsSpace.s16),
                _reportSection(l),
              ],
              if (_dialFailedFor != null) ...[
                const SizedBox(height: WsSpace.s12),
                Text(l.emergencyDialFailed(_dialFailedFor!), style: text.bodyMedium?.copyWith(color: t.errorFg)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
