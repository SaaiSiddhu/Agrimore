import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/seller_auth_provider.dart';
import '../../providers/seller_order_provider.dart';
import '../../providers/seller_product_provider.dart';
import '../account/help_screen.dart';
import '../account/notification_settings_screen.dart';
import '../account/settings_screen.dart';
import '../ai/seller_ai_chat_screen.dart';
import '../reviews/reviews_screen.dart';
import '../posts/followers_screen.dart';
import '../rfq/seller_rfq_inbox_screen.dart';
import '../storefront/storefront_editor_screen.dart';
import '../account/store_status.dart';
import 'business_details_sheet.dart';
import 'delivery_fee_sheet.dart';
import 'seller_ai_integration_screen.dart';

/// The payout destination as the seller may see it (masked).
@immutable
class PayoutView {
  const PayoutView({required this.available, this.method, this.bankName, this.maskedAccount, this.ifsc, this.upiId});

  factory PayoutView.of(Map<String, dynamic>? d, {required bool readFailed}) {
    if (readFailed) return const PayoutView(available: false);
    String? s(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;
    final account = s(d?['accountNumber']);
    return PayoutView(
      available: true,
      method: s(d?['payoutMethod']),
      bankName: s(d?['bankName']),
      maskedAccount: account == null ? null : AgFormat.maskAccount(account),
      ifsc: s(d?['ifsc']),
      upiId: s(d?['upiId']),
    );
  }

  final bool available;
  final String? method;
  final String? bankName;
  final String? maskedAccount;
  final String? ifsc;
  final String? upiId;

  bool get isEmpty => maskedAccount == null && upiId == null;
}

/// M-01 Account (ADR §10.6, SELLER-UI-1a): who you are, your business and
/// storefront, money, selling tools, app preferences and sign out.
class SellerProfileScreen extends StatefulWidget {
  const SellerProfileScreen({super.key, this.seller, this.payout});

  /// Injected in tests; otherwise loaded.
  final Map<String, dynamic>? seller;
  final PayoutView? payout;

  @override
  State<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends State<SellerProfileScreen> {
  Map<String, dynamic>? _seller;
  PayoutView _payout = const PayoutView(available: true);
  bool _loading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    if (widget.seller != null) {
      _seller = widget.seller;
      _payout = widget.payout ?? const PayoutView(available: true);
      _loading = false;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  String? get _uid => context.read<SellerAuthProvider>().currentUser?.uid;

  Future<void> _load() async {
    final uid = _uid;
    if (uid == null) return;
    final db = FirebaseFirestore.instance;
    try {
      final seller = await db.collection('sellers').doc(uid).get();
      // Payout details are a separate, owner-only document that can fail on
      // its own; that must not read as "no bank account" (FIX-2 F-1).
      Map<String, dynamic>? payout;
      var payoutFailed = false;
      try {
        payout = (await db.collection('seller_payout_details').doc(uid).get()).data();
      } catch (e) {
        debugPrint('Payout details load failed: $e');
        payoutFailed = true;
      }
      if (!mounted) return;
      setState(() {
        _seller = seller.data() ?? const {};
        _payout = PayoutView.of(payout, readFailed: payoutFailed);
        _loading = false;
        _loadFailed = false;
      });
    } catch (e) {
      debugPrint('Account load failed: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      }
    }
  }

  Future<void> _editBusiness() async {
    final l10n = AppLocalizations.of(context);
    final edited = await showBusinessDetailsSheet(context, BusinessDetails.fromSeller(_seller));
    final uid = _uid;
    if (edited == null || uid == null || !mounted) return;
    try {
      await FirebaseFirestore.instance
          .collection('sellers')
          .doc(uid)
          .set({...edited.toUpdate(), 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      if (!mounted) return;
      WsToast.show(context, l10n.accountSaved, tone: WsToastTone.success);
      await _load();
    } catch (e) {
      debugPrint('Business details save failed: $e');
      if (mounted) WsToast.show(context, l10n.profileSaveFailed, tone: WsToastTone.error);
    }
  }

  Future<void> _editStoreStatus() async {
    final l10n = AppLocalizations.of(context);
    final next = await showStoreStatusSheet(context, StoreStatus.fromSeller(_seller));
    final uid = _uid;
    if (next == null || uid == null || !mounted) return;
    try {
      await FirebaseFirestore.instance
          .collection('sellers')
          .doc(uid)
          .update({...next.toUpdate(), 'updatedAt': FieldValue.serverTimestamp()});
      if (!mounted) return;
      WsToast.show(context, next.accepting ? l10n.storeResumed : l10n.storePausedToast, tone: WsToastTone.success);
      await _load();
    } catch (e) {
      debugPrint('Store status failed: $e');
      if (mounted) WsToast.show(context, l10n.profileSaveFailed, tone: WsToastTone.error);
    }
  }

  void _editDeliveryFee() {
    final uid = _uid;
    if (uid == null) return;
    showDeliveryFeeSheet(
      context,
      uid: uid,
      initialSchedule: _seller?['deliveryFeeSchedule'] as Map<String, dynamic>?,
      onSaved: _load,
    );
  }

  void _showPayout() {
    final l10n = AppLocalizations.of(context);
    final p = _payout;
    final lines = !p.available
        ? [l10n.accountPayoutUnavailable]
        : p.isEmpty
            ? [l10n.payoutAccountMissingHelp]
            : [
                if (p.upiId != null) l10n.payoutAccountUpi(p.upiId!),
                if (p.maskedAccount != null) l10n.payoutAccountBank(p.bankName ?? '', p.maskedAccount!),
                if (p.ifsc != null) l10n.accountIfsc(p.ifsc!),
                l10n.accountPayoutChangeHint,
              ];
    _infoSheet(l10n.payoutAccountTitle, lines);
  }

  void _showLegal() {
    final l10n = AppLocalizations.of(context);
    _infoSheet(l10n.accountLegal, [l10n.legalAccurate, l10n.legalPackOnTime, l10n.legalPayouts]);
  }

  void _infoSheet(String title, List<String> lines) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        final text = ctx.wsText;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(WsSpace.page, 0, WsSpace.page, WsSpace.s24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: text.titleMedium),
              const SizedBox(height: WsSpace.s12),
              for (final l in lines)
                Padding(padding: const EdgeInsets.only(bottom: WsSpace.s8), child: Text(l, style: text.bodyMedium)),
            ]),
          ),
        );
      },
    );
  }

  Future<void> _signOut() async {
    final l10n = AppLocalizations.of(context);
    final auth = context.read<SellerAuthProvider>();
    final yes = await wsConfirm(
      context,
      title: l10n.accountSignOutTitle,
      message: l10n.accountSignOutBody,
      confirmLabel: l10n.accountSignOut,
      cancelLabel: l10n.cancel,
    );
    if (yes) await auth.signOut();
  }

  void _push(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    final text = context.wsText;
    final seller = _seller ?? const <String, dynamic>{};
    final user = context.watch<SellerAuthProvider>().currentUser;
    final products = context.watch<SellerProductProvider>();
    final orders = context.watch<SellerOrderProvider>();
    final name = [seller['shopName'], seller['businessName'], user?.name]
        .whereType<String>()
        .firstWhere((s) => s.trim().isNotEmpty, orElse: () => l10n.accountTitle);
    final rating = (seller['rating'] as num?)?.toDouble() ?? 0;
    final reviewCount = (seller['reviewCount'] as num?)?.toInt() ?? 0;
    final logo = seller['logoUrl'] as String?;

    Widget section(String title, List<Widget> tiles) => Padding(
          padding: const EdgeInsets.fromLTRB(WsSpace.page, WsSpace.s16, WsSpace.page, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(left: WsSpace.s4, bottom: WsSpace.s8),
              child: Text(title, style: text.labelLarge!.copyWith(color: t.textSecondary)),
            ),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  if (i > 0) const Divider(height: WsSize.hairline, indent: WsSpace.s64),
                  tiles[i],
                ],
              ]),
            ),
          ]),
        );

    Widget tile(IconData icon, String title, String? subtitle, VoidCallback onTap) => ListTile(
          leading: Icon(icon, color: t.primary),
          title: Text(title, style: text.bodyLarge),
          subtitle: subtitle == null ? null : Text(subtitle, style: text.bodySmall),
          trailing: Icon(AgIcons.chevronRight, color: t.textTertiary),
          onTap: onTap,
        );

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: Text(l10n.accountTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.only(bottom: WsSpace.s32),
                children: [
                  if (_loadFailed)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(WsSpace.page, WsSpace.s16, WsSpace.page, 0),
                      child: SaInfoBanner(variant: SaBannerVariant.error, message: l10n.accountLoadFailed),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(WsSpace.page, WsSpace.s16, WsSpace.page, 0),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(WsSpace.s16),
                        child: Row(children: [
                          CircleAvatar(
                            radius: WsSize.avatarLg / 2,
                            backgroundColor: t.primarySubtle,
                            backgroundImage: logo == null || logo.isEmpty ? null : NetworkImage(logo),
                            child: logo == null || logo.isEmpty ? Icon(AgIcons.store, color: t.primary) : null,
                          ),
                          const SizedBox(width: WsSpace.s16),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(name, style: text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                              if ((user?.phone ?? '').isNotEmpty)
                                Text(AgFormat.maskPhone(user!.phone!), style: text.bodySmall!.copyWith(color: t.textSecondary)),
                              const SizedBox(height: WsSpace.s4),
                              Row(children: [
                                Icon(AgIcons.star, size: WsIconSize.supporting, color: t.warningFg),
                                const SizedBox(width: WsSpace.s4),
                                Text(
                                  reviewCount == 0 ? l10n.accountNoRatings : l10n.accountRating(rating.toStringAsFixed(1), reviewCount),
                                  style: text.bodySmall,
                                ),
                              ]),
                            ]),
                          ),
                        ]),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(WsSpace.page, WsSpace.s12, WsSpace.page, 0),
                    child: Row(children: [
                      for (final (label, value) in [
                        (l10n.accountProducts, AgFormat.count(products.totalProducts)),
                        (l10n.kpiOrders, AgFormat.count(orders.totalOrders)),
                        (l10n.accountDelivered, AgFormat.count(orders.deliveredOrders)),
                      ])
                        Expanded(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(WsSpace.s12),
                              child: Column(children: [
                                Text(value, style: text.titleMedium!.copyWith(fontFeatures: WsType.tabularFigures)),
                                Text(label, style: text.bodySmall!.copyWith(color: t.textSecondary)),
                              ]),
                            ),
                          ),
                        ),
                    ]),
                  ),
                  section(l10n.accountSectionBusiness, [
                    tile(
                      AgIcons.store,
                      l10n.storeStatusTitle,
                      StoreStatus.fromSeller(seller).isPaused(DateTime.now()) ? l10n.storeStatusPaused : l10n.storeStatusOpen,
                      _editStoreStatus,
                    ),
                    tile(AgIcons.document, l10n.accountBusinessDetails, l10n.accountBusinessDetailsHint, _editBusiness),
                    tile(AgIcons.store, l10n.storefrontMenu, l10n.storefrontMenuSubtitle, () => _push(const StorefrontEditorScreen())),
                    tile(AgIcons.delivery, l10n.accountDeliveryFee, describeDeliveryFeeSchedule(seller['deliveryFeeSchedule'] as Map<String, dynamic>?, l10n), _editDeliveryFee),
                  ]),
                  section(l10n.accountSectionSelling, [
                    tile(AgIcons.quote, l10n.quotesTitle, null, () => _push(const SellerRfqInboxScreen())),
                    tile(AgIcons.star, l10n.reviewsMenu, l10n.reviewsMenuSubtitle, () => _push(const SellerReviewsScreen())),
                    tile(AgIcons.users, l10n.followersTitle, l10n.followersMenuSubtitle, () => _push(const FollowersScreen())),
                    tile(AgIcons.bank, l10n.payoutAccountTitle, l10n.accountPayoutHint, _showPayout),
                  ]),
                  section(l10n.accountSectionAi, [
                    tile(AgIcons.sparkles, l10n.accountAiAssistant, l10n.accountAiAssistantHint, () => _push(const SellerAiChatScreen())),
                    tile(AgIcons.settings, l10n.accountAiConnect, l10n.accountAiConnectHint, () => _push(const SellerAiIntegrationScreen())),
                  ]),
                  section(l10n.accountSectionApp, [
                    tile(AgIcons.bell, l10n.prefTitle, null, () => _push(const NotificationSettingsScreen())),
                    tile(AgIcons.help, l10n.helpTitle, null, () => _push(const HelpScreen())),
                    tile(AgIcons.settings, l10n.settingsTitle, l10n.settingsMenuSubtitle, () => _push(const SellerSettingsScreen())),
                    tile(AgIcons.shieldCheck, l10n.accountLegal, null, _showLegal),
                  ]),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(WsSpace.page, WsSpace.s24, WsSpace.page, 0),
                    child: OutlinedButton.icon(
                      onPressed: _signOut,
                      icon: const Icon(AgIcons.logOut),
                      label: Text(l10n.accountSignOut),
                      style: OutlinedButton.styleFrom(foregroundColor: t.errorFg),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
