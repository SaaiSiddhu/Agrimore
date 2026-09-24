import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/seller_settings_provider.dart';
import 'help_screen.dart';
import 'notification_settings_screen.dart';

/// M-11 Settings (ADR §10.6, SELLER-ACCOUNT-1b): theme, notifications, help,
/// licences and the app version (SELLER-RELEASE-1: from package_info_plus,
/// so it always matches pubspec.yaml).
class SellerSettingsScreen extends StatelessWidget {
  const SellerSettingsScreen({super.key, this.versionOverride});

  /// Fixed version for tests (the platform channel is absent there).
  final String? versionOverride;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = context.text;
    final settings = context.watch<SellerSettingsProvider>();
    final hint = switch (settings.themeMode) {
      ThemeMode.light => l10n.settingsThemeLightHint,
      ThemeMode.dark => l10n.settingsThemeDarkHint,
      ThemeMode.system => l10n.settingsThemeSystemHint,
    };
    return Scaffold(
      appBar: SellerAppBar.detail(context, title: l10n.settingsTitle),
      body: SellerPage(
        gap: SellerSpace.s16,
        children: [
          SellerCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SellerSectionHeader(title: l10n.settingsAppearance),
              SellerSegmented<ThemeMode>(
                semanticLabel: l10n.settingsTheme,
                showCheck: true,
                segments: [
                  SellerSegment(ThemeMode.system, l10n.settingsThemeSystem, icon: SellerIcons.systemTheme),
                  SellerSegment(ThemeMode.light, l10n.settingsThemeLight, icon: SellerIcons.sun),
                  SellerSegment(ThemeMode.dark, l10n.settingsThemeDark, icon: SellerIcons.moon),
                ],
                selected: settings.themeMode,
                onChanged: settings.setThemeMode,
              ),
              const SizedBox(height: SellerSpace.s8),
              Semantics(liveRegion: true, child: Text(hint, style: text.bodyMedium)),
            ]),
          ),
          SellerMenuGroup(children: [
            SellerListRow(
              icon: SellerIcons.bell,
              title: l10n.prefTitle,
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const NotificationSettingsScreen())),
            ),
            SellerListRow(
              icon: SellerIcons.support,
              title: l10n.helpTitle,
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const HelpScreen())),
            ),
            SellerListRow(
              icon: SellerIcons.licences,
              title: l10n.settingsLicences,
              onTap: () => showLicensePage(context: context, applicationName: l10n.appName),
            ),
          ]),
          FutureBuilder<String>(
            future: versionOverride != null
                ? Future.value(versionOverride)
                : PackageInfo.fromPlatform().then((i) => l10n.settingsVersionValue(i.version, i.buildNumber)),
            builder: (context, snap) => SellerMenuGroup(children: [
              SellerListRow(icon: SellerIcons.info, title: l10n.settingsVersion, value: snap.data ?? '', showChevron: false),
            ]),
          ),
        ],
      ),
    );
  }
}
