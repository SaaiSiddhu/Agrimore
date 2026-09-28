// lib/screens/support/help_support_screen.dart
//
// Phase DLVSUP1 -- "What do you need help with?" (31.4 Support). Three
// buildable topics (Delivery issue / Earnings & payouts / Account &
// documents), each opening SubmitSupportRequestScreen pre-filled with that
// category; "Call support" reuses support_card.dart's openSupportCall
// verbatim; "Immediate danger" reuses the already-standalone
// showEmergencySheet (lib/safety/emergency_sheet.dart), unchanged.
//
// The mockup's own "Help articles" row is NOT built -- no help-article
// content or CMS exists anywhere in this app; a disabled dead-end row would
// be worse than no row at all. The mockup's own bottom nav also assumes
// Support replaces Inbox as a fifth tab; that navigation/IA change was not
// adopted (Inbox is real, live, heavily-built functionality) -- this screen
// is reached from Profile instead. Both are flagged for the owner in this
// phase's ledger row, not decided here.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../account/support_card.dart';
import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import '../../safety/emergency_sheet.dart';
import '../../support/rider_support.dart';
import 'my_support_requests_screen.dart';
import 'submit_support_request_screen.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key, this.backend, this.pickImage});

  /// DLVC4: injectable for tests, forwarded to whichever real screen this
  /// navigates to -- without this, no test could drive the real
  /// HelpSupportScreen -> SubmitSupportRequestScreen/MySupportRequestsScreen
  /// chain with a fake, unlike every sibling entry point in this app that
  /// already forwards its own injection seams. Defaults to the real
  /// callable-backed service, matching every screen this pushes.
  final RiderSupportBackend? backend;

  /// Injectable for tests (image_picker has no test-friendly platform
  /// channel); forwarded to SubmitSupportRequestScreen only.
  final Future<XFile?> Function()? pickImage;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final t = context.text;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: Text(l.profileSupport)),
      body: ListView(
        padding: const EdgeInsets.all(DeliverySpace.page),
        children: [
          Text(
            l.helpSupportSubtitle,
            style: t.bodyMedium.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: DeliverySpace.lg),
          _Topic(
            key: const ValueKey('help-my-requests'),
            icon: DeliveryIcons.document,
            title: l.mySupportRequestsEntry,
            subtitle: '',
            onTap: () => _openMyRequests(context),
          ),
          const SizedBox(height: DeliverySpace.lg),
          Text(
            l.helpSupportQuestion,
            style: t.titleMedium.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: DeliverySpace.sm),
          _Topic(
            key: const ValueKey('help-topic-delivery-issue'),
            icon: DeliveryIcons.truck,
            title: l.helpTopicDeliveryIssue,
            subtitle: l.helpTopicDeliveryIssueSub,
            onTap: () => _openCategory(context, kSupportCategoryDeliveryIssue),
          ),
          const SizedBox(height: DeliverySpace.sm),
          _Topic(
            key: const ValueKey('help-topic-earnings-payouts'),
            icon: DeliveryIcons.earnings,
            title: l.helpTopicEarningsPayouts,
            subtitle: l.helpTopicEarningsPayoutsSub,
            onTap: () => _openCategory(context, kSupportCategoryEarningsPayouts),
          ),
          const SizedBox(height: DeliverySpace.sm),
          _Topic(
            key: const ValueKey('help-topic-account-documents'),
            icon: DeliveryIcons.document,
            title: l.helpTopicAccountDocuments,
            subtitle: l.helpTopicAccountDocumentsSub,
            onTap: () => _openCategory(context, kSupportCategoryAccountDocuments),
          ),
          const SizedBox(height: DeliverySpace.lg),
          _Topic(
            key: const ValueKey('help-call-support'),
            icon: DeliveryIcons.call,
            title: l.supportCall,
            subtitle: '',
            onTap: () => openSupportCall(context),
          ),
          const SizedBox(height: DeliverySpace.sm),
          _Topic(
            key: const ValueKey('help-emergency'),
            icon: DeliveryIcons.emergency,
            title: l.helpImmediateDanger,
            subtitle: l.emergencyTitle,
            tone: DeliveryTone.danger,
            onTap: () => showEmergencySheet(context),
          ),
        ],
      ),
    );
  }

  void _openCategory(BuildContext context, String category) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SubmitSupportRequestScreen(category: category, backend: backend, pickImage: pickImage),
      ),
    );
  }

  void _openMyRequests(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MySupportRequestsScreen(riderId: uid, backend: backend),
      ),
    );
  }
}

class _Topic extends StatelessWidget {
  const _Topic({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.tone,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final DeliveryTone? tone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final pair = tone != null ? c.tone(tone!) : null;
    return DeliveryCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: DeliverySpace.md,
        vertical: DeliverySpace.sm,
      ),
      child: Row(
        children: [
          Icon(icon, size: DeliveryIconSize.lg, color: pair?.text ?? c.textSecondary),
          const SizedBox(width: DeliverySpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.titleSmall.copyWith(color: c.textPrimary)),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: t.bodySmall.copyWith(color: c.textSecondary)),
              ],
            ),
          ),
          Icon(DeliveryIcons.chevronRight, size: DeliveryIconSize.md, color: c.textSecondary),
        ],
      ),
    );
  }
}
