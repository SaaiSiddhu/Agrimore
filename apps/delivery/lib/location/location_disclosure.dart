// lib/location/location_disclosure.dart
//
// Phase DLV-3A — the prominent disclosure Google Play requires before an app
// collects location while it is closed or not in use. Shown once, before the
// first location permission prompt; a rider who declines cannot go online
// (orders are offered by distance), and is asked again next time.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'location_policy.dart';

const String _acceptedKey = 'dlv3a_location_disclosure_accepted';

Future<bool> locationDisclosureAccepted() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_acceptedKey) == true;
  } catch (e) {
    debugPrint('Disclosure flag read failed: $e');
    return false;
  }
}

/// True when the rider has accepted (now or before).
Future<bool> ensureLocationDisclosure(BuildContext context) async {
  if (await locationDisclosureAccepted()) return true;
  if (!context.mounted) return false;
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.location_on_rounded, size: 32),
      title: const Text(locationDisclosureTitle),
      content: const SingleChildScrollView(child: Text(locationDisclosureBody)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_acceptedKey, true);
  } catch (e) {
    debugPrint('Disclosure flag write failed: $e');
  }
  return true;
}
