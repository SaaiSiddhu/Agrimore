// lib/app/device_localizations.dart
//
// DLV-P1 — rider strings where there is no BuildContext: notifications built
// in the FCM background isolate and the Android location notice. The device
// language when the app has it, else English.
import 'dart:ui';

import '../l10n/app_localizations.dart';

AppLocalizations deviceLocalizations() {
  final device = PlatformDispatcher.instance.locale;
  final match = AppLocalizations.supportedLocales.where((l) => l.languageCode == device.languageCode);
  return lookupAppLocalizations(match.isNotEmpty ? match.first : const Locale('en'));
}
