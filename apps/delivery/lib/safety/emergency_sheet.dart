// lib/safety/emergency_sheet.dart
//
// Phase DLV-S1 / Phase 26 — the emergency sheet opened from the dashboard's
// SOS icon. Dialing 112 and Agrimore support only hands the number to the
// OS phone dialer and never claims anyone has been alerted or sent a
// location. "Tell the Agrimore team" (DLV-S2) records a report on the server
// and shows its real state (incident_report.dart).
import 'package:agrimore_core/agrimore_core.dart' show AppConstants;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design_system/design_system.dart';
import '../l10n/app_localizations.dart';
import 'incident_report.dart';
import 'incident_status_screen.dart';

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
    // DLVHOME1: reskinned to the reference's title + explicit close button;
    // no drag handle competing with that title row.
    showDragHandle: false,
    isScrollControlled: true,
    useSafeArea: true,
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
  String? _incidentId;

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
        fix = await widget.fix!().timeout(DeliveryMotion.locationTimeout);
      } catch (_) {}
    }
    try {
      final id = await widget.reporter!({
        'requestId': _requestId,
        'kind': 'sos',
        ...fix,
      });
      if (!mounted) return;
      setState(() {
        _sending = false;
        _incidentId = id;
        _record =
            widget.watcher?.call(id).asBroadcastStream() ?? Stream.value(null);
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
    final c = context.colors;
    final t = context.text;
    if (_record != null) {
      return StreamBuilder<Map<String, dynamic>?>(
        stream: _record,
        builder: (context, snap) {
          final s = incidentStatusText(l, snap.data);
          return DeliveryCard(
            variant: DeliveryCardVariant.muted,
            padding: const EdgeInsets.all(DeliverySpace.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  DeliveryIcons.shield,
                  size: DeliveryIconSize.md,
                  color: c.brand,
                ),
                const SizedBox(width: DeliverySpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.title,
                        style: t.titleSmall.copyWith(color: c.textPrimary),
                      ),
                      const SizedBox(height: DeliverySpace.xxs),
                      Text(
                        s.detail,
                        style: t.bodyMedium.copyWith(color: c.textSecondary),
                      ),
                      // DLVC3: this card (and its live stream) disappears
                      // the moment this sheet closes -- this is the only
                      // link into the SAME report's persistent status,
                      // reachable afterward from Profile or a notification.
                      if (_incidentId != null) ...[
                        const SizedBox(height: DeliverySpace.xxs),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            key: const ValueKey('incident-view-details'),
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => IncidentStatusScreen(incidentId: _incidentId!),
                              ),
                            ),
                            child: Text(l.incidentViewDetails),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DeliveryButton.secondary(
          label: _sending
              ? l.incidentReportSending
              : (_reportError != null ? l.actionRetry : l.incidentReportAction),
          icon: DeliveryIcons.report,
          isLoading: _sending,
          onPressed: _sending ? null : _report,
        ),
        const SizedBox(height: DeliverySpace.sm),
        Text(
          l.incidentReportHint,
          style: t.bodySmall.copyWith(color: c.textSecondary),
        ),
        if (_reportError != null) ...[
          const SizedBox(height: DeliverySpace.sm),
          DeliveryBanner(
            tone: DeliveryBannerTone.danger,
            body: _reportError!.message(l),
          ),
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

  Widget _actionRow({
    required Key key,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final c = context.colors;
    final t = context.text;
    return InkWell(
      key: key,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DeliverySpace.page,
          vertical: DeliverySpace.md,
        ),
        child: Row(
          children: [
            Container(
              width: DeliverySize.avatarMd,
              height: DeliverySize.avatarMd,
              decoration: BoxDecoration(color: c.danger.container, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Icon(icon, size: DeliveryIconSize.md, color: c.danger.icon),
            ),
            const SizedBox(width: DeliverySpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.titleSmall.copyWith(color: c.textPrimary)),
                  Text(subtitle, style: t.bodySmall.copyWith(color: c.textSecondary)),
                ],
              ),
            ),
            Icon(DeliveryIcons.chevronRight, size: DeliveryIconSize.md, color: c.textSecondary),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final t = context.text;
    final support = dialUri(widget.supportPhone);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DeliverySpace.page,
              DeliverySpace.md,
              DeliverySpace.sm,
              DeliverySpace.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l.emergencyTitle,
                    style: t.titleLarge.copyWith(color: c.textPrimary),
                  ),
                ),
                IconButton(
                  key: const ValueKey('emergency-sheet-close'),
                  tooltip: l.actionClose,
                  icon: Icon(DeliveryIcons.close, color: c.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Divider(height: DeliverySize.hairline, color: c.divider),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: DeliverySpace.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      DeliverySpace.page,
                      DeliverySpace.sm,
                      DeliverySpace.page,
                      0,
                    ),
                    child: Text(
                      l.emergencyIntro(kEmergencyNumber),
                      style: t.bodyMedium.copyWith(color: c.textSecondary),
                    ),
                  ),
                  const SizedBox(height: DeliverySpace.sm),
                  _actionRow(
                    key: const ValueKey('emergency-sheet-call-112'),
                    icon: DeliveryIcons.phone,
                    title: l.emergencyCall(kEmergencyNumber),
                    subtitle: kEmergencyNumber,
                    onTap: () => _dial(dialUri(kEmergencyNumber)!, kEmergencyNumber),
                  ),
                  if (support != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: DeliverySpace.page),
                      child: Divider(height: DeliverySize.hairline, color: c.divider),
                    ),
                    _actionRow(
                      key: const ValueKey('emergency-sheet-call-support'),
                      icon: DeliveryIcons.support,
                      title: l.emergencyCallSupport,
                      subtitle: widget.supportPhone!,
                      onTap: () => _dial(support, widget.supportPhone!),
                    ),
                  ],
                  if (widget.reporter != null) ...[
                    const SizedBox(height: DeliverySpace.lg),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: DeliverySpace.page),
                      child: _reportSection(l),
                    ),
                  ],
                  if (_dialFailedFor != null) ...[
                    const SizedBox(height: DeliverySpace.md),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: DeliverySpace.page),
                      child: DeliveryBanner(
                        tone: DeliveryBannerTone.danger,
                        body: l.emergencyDialFailed(_dialFailedFor!),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
