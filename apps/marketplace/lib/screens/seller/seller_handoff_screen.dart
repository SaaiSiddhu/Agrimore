import 'package:agrimore_core/agrimore_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/seller_provider.dart';

/// SELLER-AUTH-1 hand-off (ADR §9): selling happens in the AgriMore Seller
/// app. This replaces the marketplace's own legacy seller panel, dashboard
/// and application form — which also no longer worked: since SELLER-AUTH-1b
/// a client may only save a DRAFT sellerRequests document, and submission
/// goes through the submitSellerApplication callable.
class SellerHandoffScreen extends StatelessWidget {
  const SellerHandoffScreen({Key? key}) : super(key: key);

  /// Play Store on Android, the seller web app everywhere else.
  static Uri targetFor({required bool web, required TargetPlatform platform}) {
    if (!web && platform == TargetPlatform.android) return Uri.parse(AppConstants.sellerAppPlayUrl);
    return Uri.parse(AppConstants.sellerWebUrl);
  }

  Future<void> _open(BuildContext context) async {
    final uri = targetFor(web: kIsWeb, platform: defaultTargetPlatform);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open ${uri.host}. Visit ${AppConstants.sellerWebUrl} instead.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final seller = context.watch<SellerProvider>();
    final theme = Theme.of(context);
    final (String title, String body, String cta) = seller.isApproved
        ? (
            'Manage your store in AgriMore Seller',
            'Orders, catalogue, quotes and payments all live in the AgriMore Seller app.',
            'Open AgriMore Seller',
          )
        : seller.isPending
            ? (
                'Your application is being reviewed',
                'Track it and finish any changes in the AgriMore Seller app. Sign in with the same phone number.',
                'Open AgriMore Seller',
              )
            : (
                'Sell on AgriMore',
                'Apply in the AgriMore Seller app: your business details, a few documents and your payout account. '
                    'Sign in with the same phone number you use here.',
                'Get AgriMore Seller',
              );
    return Scaffold(
      appBar: AppBar(title: const Text('Sell on AgriMore')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.storefront_rounded, size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(body, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _open(context),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text(cta),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
