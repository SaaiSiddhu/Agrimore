import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/seller_auth_provider.dart';
import '../../providers/seller_order_provider.dart';
import '../../providers/seller_product_provider.dart';
import '../account/help_screen.dart';
import '../account/policies_screen.dart';
import '../account/notification_settings_screen.dart';
import '../account/settings_screen.dart';
import '../ai/seller_ai_chat_screen.dart';
import '../reviews/reviews_screen.dart';
import '../posts/followers_screen.dart';
import '../rfq/seller_rfq_inbox_screen.dart';
import '../storefront/storefront_editor_screen.dart';
import '../account/store_schedule.dart';
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
      maskedAccount: account == null ? null : SellerFormat.maskAccount(account),
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
      SellerToast.show(context, l10n.accountSaved, tone: SellerToastTone.success);
      await _load();
    } catch (e) {
      debugPrint('Business details save failed: $e');
      if (mounted) SellerToast.show(context, l10n.profileSaveFailed, tone: SellerToastTone.danger);
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
      SellerToast.show(context, next.accepting ? l10n.storeResumed : l10n.storePausedToast, tone: SellerToastTone.success);
      await _load();
    } catch (e) {
      debugPrint('Store status failed: $e');
      if (mounted) SellerToast.show(context, l10n.profileSaveFailed, tone: SellerToastTone.danger);
    }
  }

  void _editSchedule() {
    final uid = _uid;
    if (uid == null) return;
    _push(StoreScheduleScreen(
      initial: StoreSchedule.fromSeller(_seller),
      onSave: (s) async {
        await FirebaseFirestore.instance
            .collection('sellers')
            .doc(uid)
            .update({...s.toUpdate(DateTime.now()), 'updatedAt': FieldValue.serverTimestamp()});
        await _load();
      },
    ));
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
                if (p.upiId != null) l10n.payoutAccountUpi(SellerFormat.maskUpi(p.upiId!)),
                if (p.maskedAccount != null) l10n.payoutAccountBank(p.bankName ?? '', p.maskedAccount!),
                if (p.ifsc != null) l10n.accountIfsc(p.ifsc!),
                l10n.accountPayoutChangeHint,
              ];
    _infoSheet(l10n.payoutAccountTitle, lines);
  }

  void _infoSheet(String title, List<String> lines) {
    showSellerSheet<void>(
      context,
      title: title,
      builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final l in lines) Padding(padding: const EdgeInsets.only(bottom: SellerSpace.s12), child: Text(l, style: ctx.text.bodyLarge)),
      ]),
    );
  }

  Future<void> _signOut() async {
    final l10n = AppLocalizations.of(context);
    final auth = context.read<SellerAuthProvider>();
    final yes = await sellerConfirm(
      context,
      icon: SellerIcons.logOut,
      title: l10n.accountSignOutTitle,
      message: l10n.accountSignOutBody,
      confirmLabel: l10n.accountSignOut,
      cancelLabel: l10n.cancel,
      destructive: true,
    );
    if (yes) await auth.signOut();
  }

  void _push(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  Future<void> _resume() async {
    final l10n = AppLocalizations.of(context);
    final uid = _uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('sellers').doc(uid).update({...const StoreStatus().toUpdate(), 'updatedAt': FieldValue.serverTimestamp()});
      if (!mounted) return;
      SellerToast.show(context, l10n.storeResumed, tone: SellerToastTone.success);
      await _load();
    } catch (e) {
      debugPrint('Resume failed: $e');
      if (mounted) SellerToast.show(context, l10n.profileSaveFailed, tone: SellerToastTone.danger);
    }
  }

  /// Store status card (board 22-01): open (green) · paused (amber, Resume)
  /// · closed today by the schedule (blue, Manage schedule).
  Widget _statusCard(Map<String, dynamic> seller) {
    final l10n = AppLocalizations.of(context);
    final text = context.text;
    final now = DateTime.now();
    final status = StoreStatus.fromSeller(seller);
    final schedule = StoreSchedule.fromSeller(seller);
    if (status.isPaused(now)) {
      return SellerBanner(
        tone: SellerTone.warning,
        icon: SellerIcons.paused,
        title: l10n.storePausedTitle,
        message: status.pausedUntil == null ? l10n.storePausedBody : l10n.storePausedUntil(SellerFormat.date(status.pausedUntil!)),
        actionLabel: l10n.storeResume,
        onAction: _resume,
      );
    }
    final closed = schedule.closedOn(now);
    if (closed != null) {
      return SellerCard(
        tone: SellerCardTone.info,
        onTap: _editSchedule,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SellerIconTile(icon: SellerIcons.calendar, tone: SellerTone.info),
          const SizedBox(width: SellerSpace.s12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l10n.storeClosedTodayTitle, style: text.titleSmall),
              Text(closed == ClosedToday.holiday ? l10n.scheduleClosedHoliday : l10n.scheduleClosedWeeklyOff, style: text.bodyMedium!.copyWith(color: context.colors.textPrimary)),
              const SizedBox(height: SellerSpace.s4),
              Text(l10n.storeManageSchedule, style: text.labelLarge!.copyWith(color: context.colors.info)),
            ]),
          ),
        ]),
      );
    }
    return SellerCard(
      tone: SellerCardTone.success,
      onTap: _editStoreStatus,
      semanticLabel: '${l10n.storeStatusTitle}, ${l10n.storeStatusOpen}',
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: SellerSpace.s6), child: SellerDot(color: context.colors.success)),
        const SizedBox(width: SellerSpace.s12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.storeStatusTitle, style: text.bodyMedium!.copyWith(color: context.colors.textPrimary)),
            Text(l10n.storeStatusOpen, style: text.titleSmall),
            Text(l10n.storeOpenBody, style: text.bodyMedium!.copyWith(color: context.colors.textPrimary)),
          ]),
        ),
        Icon(SellerIcons.chevronRight, color: context.colors.textSecondary),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = context.text;
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
    final city = [seller['city'], seller['state']].whereType<String>().where((s) => s.trim().isNotEmpty).join(', ');

    Widget stat(String label, int value) => Expanded(
          child: SellerCard(
            padding: const EdgeInsets.all(SellerSpace.s12),
            child: MergeSemantics(
              child: Column(children: [
                Text(SellerFormat.count(value), style: text.titleLarge!.tabular),
                Text(label, style: text.bodySmall, textAlign: TextAlign.center),
              ]),
            ),
          ),
        );

    return Scaffold(
      appBar: SellerAppBar.root(context, title: l10n.accountTitle, actions: [
        SellerIconButton(icon: SellerIcons.settings, label: l10n.accountSettings, onPressed: () => _push(const SellerSettingsScreen())),
      ]),
      body: _loading
          ? SellerLoadingView(label: l10n.dsLoading)
          : SellerPage(
                onRefresh: _load,
                gap: SellerSpace.s16,
                children: [
                  if (_loadFailed) SellerBanner(tone: SellerTone.danger, message: l10n.accountLoadFailed),
                  SellerCard(
                    onTap: () => _push(const StorefrontEditorScreen()),
                    child: Row(children: [
                      SellerAvatar(imageUrl: logo, name: name, size: SellerSize.avatarLg),
                      const SizedBox(width: SellerSpace.s12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(name, style: text.titleMedium),
                          Text(city.isEmpty ? l10n.accountStoreHeaderHint : city, style: text.bodyMedium),
                          if ((user?.phone ?? '').isNotEmpty) Text(SellerFormat.maskPhone(user!.phone!), style: text.bodyMedium!.tabular),
                          const SizedBox(height: SellerSpace.s4),
                          Row(children: [
                            Icon(SellerIcons.star, size: SellerIconSize.sm, color: context.colors.warning),
                            const SizedBox(width: SellerSpace.s4),
                            Flexible(
                              child: Text(
                                reviewCount == 0 ? l10n.accountNoRatings : l10n.accountRating(rating.toStringAsFixed(1), reviewCount),
                                style: text.bodyMedium,
                              ),
                            ),
                          ]),
                        ]),
                      ),
                      Icon(SellerIcons.chevronRight, color: context.colors.textTertiary),
                    ]),
                  ),
                  _statusCard(seller),
                  Row(children: [
                    stat(l10n.accountProducts, products.totalProducts),
                    const SizedBox(width: SellerSpace.s8),
                    stat(l10n.kpiOrders, orders.totalOrders),
                    const SizedBox(width: SellerSpace.s8),
                    stat(l10n.accountDelivered, orders.deliveredOrders),
                  ]),
                  SellerMenuGroup(title: l10n.accountSectionBusiness, children: [
                    SellerListRow(
                      icon: SellerIcons.store,
                      title: l10n.storeStatusTitle,
                      subtitle: StoreStatus.fromSeller(seller).isPaused(DateTime.now()) ? l10n.storeStatusPaused : l10n.storeStatusOpen,
                      onTap: _editStoreStatus,
                    ),
                    SellerListRow(icon: SellerIcons.calendarDays, title: l10n.scheduleTitle, subtitle: describeSchedule(StoreSchedule.fromSeller(seller), l10n, DateTime.now()), onTap: _editSchedule),
                    SellerListRow(icon: SellerIcons.business, title: l10n.accountBusinessDetails, subtitle: l10n.accountBusinessDetailsHint, onTap: _editBusiness),
                    SellerListRow(
                      icon: SellerIcons.delivery,
                      title: l10n.accountDeliveryFee,
                      subtitle: describeDeliveryFeeSchedule(seller['deliveryFeeSchedule'] as Map<String, dynamic>?, l10n),
                      onTap: _editDeliveryFee,
                    ),
                    SellerListRow(icon: SellerIcons.image, title: l10n.storefrontMenu, subtitle: l10n.storefrontMenuSubtitle, onTap: () => _push(const StorefrontEditorScreen())),
                    SellerListRow(icon: SellerIcons.star, title: l10n.reviewsMenu, subtitle: l10n.reviewsMenuSubtitle, onTap: () => _push(const SellerReviewsScreen())),
                    SellerListRow(icon: SellerIcons.users, title: l10n.followersTitle, subtitle: l10n.followersMenuSubtitle, onTap: () => _push(const FollowersScreen())),
                  ]),
                  SellerMenuGroup(title: l10n.accountSectionSelling, children: [
                    SellerListRow(icon: SellerIcons.quote, title: l10n.quotesTitle, onTap: () => _push(const SellerRfqInboxScreen())),
                    SellerListRow(icon: SellerIcons.bank, title: l10n.payoutAccountTitle, subtitle: l10n.accountPayoutHint, onTap: _showPayout),
                  ]),
                  SellerMenuGroup(title: l10n.accountSectionAi, children: [
                    SellerListRow(icon: SellerIcons.ai, title: l10n.accountAiAssistant, subtitle: l10n.accountAiAssistantHint, onTap: () => _push(const SellerAiChatScreen())),
                    SellerListRow(icon: SellerIcons.settings, title: l10n.accountAiConnect, subtitle: l10n.accountAiConnectHint, onTap: () => _push(const SellerAiIntegrationScreen())),
                  ]),
                  SellerMenuGroup(title: l10n.accountSectionApp, children: [
                    SellerListRow(icon: SellerIcons.bell, title: l10n.prefTitle, onTap: () => _push(const NotificationSettingsScreen())),
                    SellerListRow(icon: SellerIcons.support, title: l10n.helpTitle, onTap: () => _push(const HelpScreen())),
                    SellerListRow(icon: SellerIcons.settings, title: l10n.settingsTitle, subtitle: l10n.settingsMenuSubtitle, onTap: () => _push(const SellerSettingsScreen())),
                    SellerListRow(icon: SellerIcons.policy, title: l10n.accountLegal, onTap: () => _push(const SellerPoliciesScreen())),
                  ]),
                  SellerButton.dangerOutline(label: l10n.accountSignOut, icon: SellerIcons.logOut, expand: true, onPressed: _signOut),
                ],
              ),
    );
  }
}
