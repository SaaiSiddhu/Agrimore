// A MaterialApp the rider app's screens can render in: the Workspace delivery
// theme (context.ws) and lib/l10n.
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:delivery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

MaterialApp wsApp({required Widget home, Brightness brightness = Brightness.light}) => MaterialApp(
      theme: WorkspaceTheme.build(WorkspaceBrand.delivery, brightness),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );
