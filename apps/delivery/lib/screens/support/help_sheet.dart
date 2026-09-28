// lib/screens/support/help_sheet.dart
//
// Phase DLVHOME1 — the Home app bar's "?" button opens this sheet instead of
// pushing HelpSupportScreen directly, matching the reference's row layout
// (rounded top corners, title + close, leading icon / title / optional
// subtitle / trailing chevron rows, subtle separators, scrollable and
// safe-area-aware). Every row reuses HelpSupportScreen's own real
// destinations verbatim (openSupportCall, SubmitSupportRequestScreen with
// its existing category constants, MySupportRequestsScreen, the standalone
// showEmergencySheet) — this file does not edit help_support_screen.dart,
// it is a second, sheet-shaped entry point onto the same real actions.
// HelpSupportScreen itself is unchanged and still reachable from Profile.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../account/support_card.dart';
import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import '../../safety/emergency_sheet.dart';
import '../../support/rider_support.dart';
import 'my_support_requests_screen.dart';
import 'submit_support_request_screen.dart';

Future<void> showHelpSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: false,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const HelpSheet(),
  );
}

class HelpSheet extends StatelessWidget {
  const HelpSheet({super.key});

  void _openCategory(BuildContext context, String category) {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SubmitSupportRequestScreen(category: category),
      ),
    );
  }

  void _openMyRequests(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MySupportRequestsScreen(riderId: uid),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final t = context.text;
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
                    l.helpSupportQuestion,
                    style: t.titleLarge.copyWith(color: c.textPrimary),
                  ),
                ),
                IconButton(
                  key: const ValueKey('help-sheet-close'),
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
              padding: const EdgeInsets.symmetric(vertical: DeliverySpace.xs),
              child: Column(
                children: [
                  _Row(
                    valueKey: const ValueKey('help-sheet-my-requests'),
                    icon: DeliveryIcons.document,
                    title: l.mySupportRequestsEntry,
                    onTap: () => _openMyRequests(context),
                  ),
                  _Row(
                    valueKey: const ValueKey('help-sheet-delivery-issue'),
                    icon: DeliveryIcons.truck,
                    title: l.helpTopicDeliveryIssue,
                    subtitle: l.helpTopicDeliveryIssueSub,
                    onTap: () => _openCategory(context, kSupportCategoryDeliveryIssue),
                  ),
                  _Row(
                    valueKey: const ValueKey('help-sheet-earnings-payouts'),
                    icon: DeliveryIcons.earnings,
                    title: l.helpTopicEarningsPayouts,
                    subtitle: l.helpTopicEarningsPayoutsSub,
                    onTap: () => _openCategory(context, kSupportCategoryEarningsPayouts),
                  ),
                  _Row(
                    valueKey: const ValueKey('help-sheet-account-documents'),
                    icon: DeliveryIcons.document,
                    title: l.helpTopicAccountDocuments,
                    subtitle: l.helpTopicAccountDocumentsSub,
                    onTap: () => _openCategory(context, kSupportCategoryAccountDocuments),
                  ),
                  _Row(
                    valueKey: const ValueKey('help-sheet-call-support'),
                    icon: DeliveryIcons.call,
                    title: l.supportCall,
                    onTap: () {
                      Navigator.of(context).pop();
                      openSupportCall(context);
                    },
                  ),
                  _Row(
                    valueKey: const ValueKey('help-sheet-emergency'),
                    icon: DeliveryIcons.emergency,
                    title: l.helpImmediateDanger,
                    subtitle: l.emergencyTitle,
                    tone: DeliveryTone.danger,
                    isLast: true,
                    onTap: () {
                      Navigator.of(context).pop();
                      showEmergencySheet(context);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.valueKey,
    required this.icon,
    required this.title,
    this.subtitle,
    this.tone,
    this.isLast = false,
    required this.onTap,
  });

  final Key valueKey;
  final IconData icon;
  final String title;
  final String? subtitle;
  final DeliveryTone? tone;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final pair = tone != null ? c.tone(tone!) : null;
    return Column(
      children: [
        InkWell(
          key: valueKey,
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
                  decoration: BoxDecoration(
                    color: pair?.container ?? c.surfaceMuted,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: DeliveryIconSize.md, color: pair?.text ?? c.textSecondary),
                ),
                const SizedBox(width: DeliverySpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: t.titleSmall.copyWith(color: c.textPrimary)),
                      if (subtitle != null && subtitle!.isNotEmpty)
                        Text(subtitle!, style: t.bodySmall.copyWith(color: c.textSecondary)),
                    ],
                  ),
                ),
                Icon(DeliveryIcons.chevronRight, size: DeliveryIconSize.md, color: c.textSecondary),
              ],
            ),
          ),
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DeliverySpace.page),
            child: Divider(height: DeliverySize.hairline, color: c.divider),
          ),
      ],
    );
  }
}
