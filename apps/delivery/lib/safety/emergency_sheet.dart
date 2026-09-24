// lib/safety/emergency_sheet.dart
//
// Phase DLV-S1 — what the SOS button honestly does. It used to show "SOS
// Alert Sent! Live location shared with authorities and admin." and send
// nothing at all. This sheet only hands the rider to the phone's dialer:
// 112 (India's single emergency number, ERSS) and Agrimore support. Opening
// the dialer is not a completed call, so nothing here says anyone was called,
// alerted or sent a location. Reporting an incident to the Agrimore team is
// a separate, server-recorded flow (DLV-S2).
import 'package:agrimore_core/agrimore_core.dart' show AppConstants;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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

Future<void> showEmergencySheet(BuildContext context, {DialLauncher? launcher, String? supportPhone}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => EmergencySheet(
      launcher: launcher ?? _launchDialer,
      supportPhone: supportPhone ?? AppConstants.supportPhone,
    ),
  );
}

class EmergencySheet extends StatefulWidget {
  const EmergencySheet({super.key, required this.launcher, this.supportPhone});
  final DialLauncher launcher;
  final String? supportPhone;

  @override
  State<EmergencySheet> createState() => _EmergencySheetState();
}

class _EmergencySheetState extends State<EmergencySheet> {
  String? _problem;

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
            if (_problem != null) ...[
              const SizedBox(height: 12),
              Text(_problem!, style: TextStyle(color: cs.error, fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }
}
