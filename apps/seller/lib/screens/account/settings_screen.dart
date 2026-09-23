import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

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
    final text = context.wsText;
    final t = context.ws;
    final settings = context.watch<SellerSettingsProvider>();
    Widget link(IconData icon, String label, VoidCallback onTap) => ListTile(
          leading: Icon(icon, color: t.textSecondary),
          title: Text(label, style: text.bodyLarge),
          trailing: Icon(AgIcons.chevronRight, color: t.textTertiary),
          onTap: onTap,
        );
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.back,
          icon: const Icon(AgIcons.arrowLeft),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(l10n.settingsTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: WsSpace.s16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: WsSpace.page),
            child: Text(l10n.settingsTheme, style: text.labelLarge),
          ),
          const SizedBox(height: WsSpace.s8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: WsSpace.page),
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: ThemeMode.system, label: Text(l10n.settingsThemeSystem), icon: const Icon(AgIcons.settings)),
                ButtonSegment(value: ThemeMode.light, label: Text(l10n.settingsThemeLight), icon: const Icon(AgIcons.lightMode)),
                ButtonSegment(value: ThemeMode.dark, label: Text(l10n.settingsThemeDark), icon: const Icon(AgIcons.darkMode)),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (s) => settings.setThemeMode(s.first),
            ),
          ),
          const Divider(height: WsSpace.s32),
          link(AgIcons.bell, l10n.prefTitle, () {
            Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const NotificationSettingsScreen()));
          }),
          link(AgIcons.help, l10n.helpTitle, () {
            Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const HelpScreen()));
          }),
          link(AgIcons.document, l10n.settingsLicences, () => showLicensePage(context: context, applicationName: l10n.appName)),
          const Divider(height: WsSpace.s32),
          FutureBuilder<String>(
            future: versionOverride != null
                ? Future.value(versionOverride)
                : PackageInfo.fromPlatform().then((i) => l10n.settingsVersionValue(i.version, i.buildNumber)),
            builder: (context, snap) => ListTile(
              leading: Icon(AgIcons.info, color: t.textSecondary),
              title: Text(l10n.settingsVersion, style: text.bodyLarge),
              trailing: Text(snap.data ?? '', style: text.bodyMedium!.copyWith(color: t.textSecondary)),
            ),
          ),
        ],
      ),
    );
  }
}
