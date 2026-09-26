// lib/navigation/navigation_launch.dart
//
// Phase DLVMAP2 (21.7 External navigation handoff) -- the shared "open
// external navigation" sequence, used by both rider_route_card.dart's
// _navigate() and active_order_screen.dart's _navigateToAddress(), which
// previously duplicated this with inconsistent failure handling (one
// showed a toast when both launches failed, the other did nothing at
// all). rider_navigation.dart itself stays pure (no Flutter, no plugins,
// per its own file header) -- this lives in its own small file instead.
//
// The mockup's own "Choose Apple Maps / Google Maps" picker (panel 2) is
// NOT built: turnByTurnUri is an Android-only `google.navigation:` intent
// with no iOS equivalent, and this repository has no iOS simulator to
// build or verify that picker against at all -- a platform-coverage
// decision for the owner, not invented around.
import 'package:agrimore_core/agrimore_core.dart' show DeliveryPoint;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:url_launcher/url_launcher.dart';

import '../design_system/design_system.dart';
import '../l10n/app_localizations.dart';
import 'rider_navigation.dart';

enum NavigationLaunchResult { turnByTurn, directions, failed }

/// Matches url_launcher's own launchUrl shape; overridable in tests, since
/// url_launcher has no test-friendly platform channel of its own (the same
/// reasoning as image_picker's injected pickImage in SubmitSupportRequestScreen).
typedef UrlLauncher = Future<bool> Function(Uri uri, LaunchMode mode);

Future<bool> _defaultLaunch(Uri uri, LaunchMode mode) => launchUrl(uri, mode: mode);

/// Turn-by-turn first (Android only), then the universal maps URL --
/// [NavigationLaunchResult.failed] only when NEITHER could be opened.
Future<NavigationLaunchResult> launchExternalNavigation(
  DeliveryPoint dest, {
  UrlLauncher launcher = _defaultLaunch,
}) async {
  if (!kIsWeb) {
    try {
      if (await launcher(turnByTurnUri(dest), LaunchMode.externalApplication)) {
        return NavigationLaunchResult.turnByTurn;
      }
    } catch (_) {
      // Falls through to the universal URL below.
    }
  }
  try {
    if (await launcher(directionsUri(dest), LaunchMode.externalApplication)) {
      return NavigationLaunchResult.directions;
    }
  } catch (_) {
    // Falls through to failed below.
  }
  return NavigationLaunchResult.failed;
}

enum _NavFailedAction { retry, copied, dismissed }

/// Launches, and on total failure shows the retry/copy-coordinates
/// fallback (21.7 panels 3-4) instead of a bare toast or nothing at all.
/// Loops on "Try again" until it opens or the rider dismisses the sheet.
Future<void> launchExternalNavigationWithFallback(
  BuildContext context,
  DeliveryPoint dest, {
  UrlLauncher launcher = _defaultLaunch,
}) async {
  var result = await launchExternalNavigation(dest, launcher: launcher);
  while (result == NavigationLaunchResult.failed) {
    if (!context.mounted) return;
    final action = await _showNavigationFailedSheet(context, dest);
    if (action != _NavFailedAction.retry) return;
    if (!context.mounted) return;
    result = await launchExternalNavigation(dest, launcher: launcher);
  }
}

Future<_NavFailedAction> _showNavigationFailedSheet(BuildContext context, DeliveryPoint dest) async {
  final action = await showModalBottomSheet<_NavFailedAction>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => NavigationFailedSheet(dest: dest),
  );
  return action ?? _NavFailedAction.dismissed;
}

/// Public (not private): directly widget-tested and screenshot-tested
/// without needing to drive a real failing launch through a host screen.
class NavigationFailedSheet extends StatelessWidget {
  const NavigationFailedSheet({super.key, required this.dest});
  final DeliveryPoint dest;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final t = context.text;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        DeliverySpace.page,
        DeliverySpace.xxs,
        DeliverySpace.page,
        MediaQuery.of(context).viewInsets.bottom + DeliverySpace.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.navFailedTitle, style: t.headlineSmall.copyWith(color: c.textPrimary)),
          const SizedBox(height: DeliverySpace.xxs),
          Text(l.navFailedBody, style: t.bodyMedium.copyWith(color: c.textSecondary)),
          const SizedBox(height: DeliverySpace.lg),
          Row(
            children: [
              Expanded(
                child: DeliveryButton.secondary(
                  key: const ValueKey('nav-failed-retry'),
                  label: l.actionRetry,
                  icon: DeliveryIcons.refresh,
                  onPressed: () => Navigator.of(context).pop(_NavFailedAction.retry),
                ),
              ),
              const SizedBox(width: DeliverySpace.sm),
              Expanded(
                child: DeliveryButton.secondary(
                  key: const ValueKey('nav-failed-copy'),
                  label: l.routeCopyCoords,
                  icon: DeliveryIcons.copy,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: '${dest.lat},${dest.lng}'));
                    showDeliveryToast(context, message: l.routeCoordsCopied);
                    Navigator.of(context).pop(_NavFailedAction.copied);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
