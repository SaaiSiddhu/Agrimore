import 'package:delivery/design_system/design_system.dart';
import 'package:delivery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// MaterialApp wrapper for delivery widget tests with [AppLocalizations] and
/// the burnt-orange [DeliveryTheme] installed.
Widget wsApp({
  required Widget home,
  Brightness brightness = Brightness.light,
}) {
  return MaterialApp(
    theme: DeliveryTheme.of(brightness),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}
