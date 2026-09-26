// lib/screens/profile/rider_profile_screen.dart
//
// Phase DLV-A2 / Phase 31 — the rider's own profile: what Agrimore holds about
// them (Aadhaar and bank masked), document and payout state, the contact
// details they may edit themselves (updateRiderContact), appearance switcher,
// support, sign-out and account deletion.
import 'package:agrimore_core/agrimore_core.dart'
    show OrderModel, VehicleType;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../account/rider_account.dart';
import '../../account/support_card.dart';
import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import '../../money/rider_money.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../registration/rider_application.dart';
import '../auth/rider_registration_screen.dart' show vehicleLabel;
import '../money/money_screen.dart';
import '../orders/active_order_screen.dart';

String accountFailureText(AppLocalizations l, AccountActionFailure f) =>
    switch (f) {
      AccountActionFailure.activeOrder => l.failActiveOrder,
      AccountActionFailure.cashHeld => l.failCashHeld,
      AccountActionFailure.payOwed => l.failPayOwed,
      AccountActionFailure.otherBalance => l.failOtherBalance,
      AccountActionFailure.invalid => l.failInvalid,
      AccountActionFailure.network => l.failNetwork,
      AccountActionFailure.unknown => l.failUnknown,
    };

/// "•••• 1234" for an identifier.
String maskTail(String? raw, {int keep = 4}) {
  final s = (raw ?? '').replaceAll(RegExp(r'\s'), '');
  if (s.isEmpty) return '';
  return s.length <= keep ? s : '•••• ${s.substring(s.length - keep)}';
}

/// Whether each KYC photo is on file (storage path, or an older record's URL).
Map<RiderDocument, bool> documentsOnFile(Map<String, dynamic> d) {
  final paths = d['kycDocuments'] is Map ? d['kycDocuments'] as Map : const {};
  bool has(Object? v) => v is String && v.trim().isNotEmpty;
  return {
    RiderDocument.aadhaarFront:
        has(paths['aadhaarFront']) || has(d['aadhaarFrontImage']),
    RiderDocument.aadhaarBack:
        has(paths['aadhaarBack']) || has(d['aadhaarBackImage']),
    RiderDocument.selfie: has(paths['selfie']) || has(d['selfieImage']),
    RiderDocument.license: has(paths['license']) || has(d['licenseImage']),
  };
}

class RiderProfileScreen extends StatefulWidget {
  const RiderProfileScreen({
    super.key,
    this.backend,
    this.partnerData,
    this.accountSource,
  });
  final RiderAccountBackend? backend;
  final Map<String, dynamic>? partnerData;

  /// DLVP1: injectable for tests; defaults to a real `rider_accounts/{uid}`
  /// read (the same stream `MoneyScreen` already uses), so the proactive
  /// deletion-eligibility check reads cash-held/unsettled-earnings without
  /// a second, ad-hoc query shape.
  final Stream<RiderAccount> Function(String riderId)? accountSource;

  @override
  State<RiderProfileScreen> createState() => _RiderProfileScreenState();
}

class _RiderProfileScreenState extends State<RiderProfileScreen> {
  late final RiderAccountBackend _backend =
      widget.backend ?? CallableRiderAccountBackend();
  late final Stream<Map<String, dynamic>?> _partner = _resolvePartnerStream();
  late final Stream<RiderAccount> _account = _resolveAccountStream();
  bool _busy = false;

  Stream<Map<String, dynamic>?> _resolvePartnerStream() {
    if (widget.partnerData != null) {
      return Stream.value(widget.partnerData);
    }
    try {
      final uid = context.read<DeliveryAuthProvider>().user?.uid;
      if (uid == null) return Stream.value(null);
      return FirebaseFirestore.instance
          .collection('delivery_partners')
          .doc(uid)
          .snapshots()
          .map((s) => s.data());
    } catch (_) {
      return Stream.value(null);
    }
  }

  /// `RiderMoneyService.account()` is itself deferred to first subscription
  /// (`Stream.multi`), so a test that never needs the real account (e.g.
  /// testing sign-out alone) never touches Firebase just because this
  /// screen was built.
  Stream<RiderAccount> _resolveAccountStream() {
    final own = widget.accountSource;
    final uid = context.read<DeliveryAuthProvider>().user?.uid;
    if (uid == null) return const Stream.empty();
    if (own != null) return own(uid);
    return RiderMoneyService(uid).account();
  }

  Future<void> _editContact(Map<String, dynamic> d) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ContactEditSheet(initial: d, backend: _backend),
    );
    if (saved == true && mounted) {
      showDeliveryToast(
        context,
        message: AppLocalizations.of(context).contactSaved,
        tone: DeliveryBannerTone.success,
      );
    }
  }

  Future<void> _signOut() async {
    final l = AppLocalizations.of(context);
    final ok = await showDeliveryConfirmDialog(
      context: context,
      title: l.signOutConfirmTitle,
      body: l.signOutConfirmBody,
      confirmLabel: l.actionSignOut,
      cancelLabel: l.cancel,
    );
    if (ok && mounted) await riderSignOut(context);
  }

  /// Checks the SAME three reasons `riderDeletionRefusal` enforces
  /// server-side (active order / cash held / pay owed), proactively and
  /// before any deletion attempt, so a blocked rider learns why — and can
  /// go straight to the thing blocking them — instead of confirming a
  /// generic dialog first only to be refused after. The server check
  /// remains the actual safety net for a race between this read and the
  /// real attempt.
  Future<void> _delete(List<OrderModel> activeOrders, RiderAccount? account) async {
    final l = AppLocalizations.of(context);
    if (activeOrders.isNotEmpty) {
      final view = await showDeliveryConfirmDialog(
        context: context,
        title: l.deleteBlockedTitle,
        body: l.failActiveOrder,
        confirmLabel: l.deleteBlockedViewDelivery,
        cancelLabel: l.cancel,
      );
      if (view && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ActiveOrderScreen(order: activeOrders.first),
          ),
        );
      }
      return;
    }
    if (account != null &&
        (account.cashHeld > 0.005 || account.earningsUnsettled > 0.005)) {
      final view = await showDeliveryConfirmDialog(
        context: context,
        title: l.deleteBlockedTitle,
        body: account.cashHeld > 0.005 ? l.failCashHeld : l.failPayOwed,
        confirmLabel: l.deleteBlockedViewEarnings,
        cancelLabel: l.cancel,
      );
      if (view && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MoneyScreen(
              riderId: context.read<DeliveryAuthProvider>().user!.uid,
            ),
          ),
        );
      }
      return;
    }
    final ok = await showDeliveryConfirmDialog(
      context: context,
      title: l.deleteConfirmTitle,
      body: l.deleteConfirmBody,
      confirmLabel: l.deleteConfirm,
      cancelLabel: l.cancel,
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await _backend.deleteAccount();
      if (!mounted) return;
      final auth = context.read<DeliveryAuthProvider>();
      showDeliveryToast(context, message: l.deleteDone);
      await auth.signOut();
    } on AccountActionException catch (e) {
      if (mounted) {
        showDeliveryToast(
          context,
          message: accountFailureText(l, e.failure),
          tone: DeliveryBannerTone.danger,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _row(String label, String value) {
    final c = context.colors;
    final t = context.text;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DeliverySpace.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: t.bodyMedium.copyWith(color: c.textSecondary),
            ),
          ),
          const SizedBox(width: DeliverySpace.sm),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: t.bodyMedium.copyWith(color: c.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    final c = context.colors;
    final t = context.text;
    return Padding(
      padding: const EdgeInsets.only(bottom: DeliverySpace.md),
      child: DeliveryCard(
        padding: const EdgeInsets.all(DeliverySpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: t.titleSmall.copyWith(color: c.textPrimary),
            ),
            const SizedBox(height: DeliverySpace.sm),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final t = context.text;
    final auth = context.watch<DeliveryAuthProvider>();
    final appearance = DeliveryAppearanceScope.maybeOf(context);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: Text(l.profileTitle)),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: _partner,
        builder: (context, snap) {
          final data = snap.data;
          if (data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          String v(String k) => (data[k] as String?)?.trim() ?? '';
          final notSet = l.profileNotSet;
          final docs = documentsOnFile(data);
          final acct = v('bankAccountNumber');
          final upi = v('upiId');
          return ListView(
            padding: const EdgeInsets.all(DeliverySpace.page),
            children: [
              Text(
                v('name'),
                style: t.headlineSmall.copyWith(color: c.textPrimary),
              ),
              Text(
                auth.user?.email ?? '',
                style: t.bodyMedium.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: DeliverySpace.lg),
              _section(
                l.profileDetails,
                [
                  _row(l.profilePhone, v('phone').isEmpty ? notSet : v('phone')),
                  _row(
                    l.profileVehicle,
                    vehicleLabel(
                      l,
                      VehicleType.fromWire(data['vehicleType'] as String?),
                    ),
                  ),
                  if (v('vehicleNumber').isNotEmpty)
                    _row(l.profileVehicleNumber, v('vehicleNumber')),
                  _row(
                    l.profileLicence,
                    v('licenseNumber').isEmpty
                        ? notSet
                        : maskTail(v('licenseNumber')),
                  ),
                  _row(
                    l.profileAadhaar,
                    v('aadhaarNumber').isEmpty
                        ? notSet
                        : maskAadhaar(v('aadhaarNumber')),
                  ),
                  const SizedBox(height: DeliverySpace.sm),
                  Text(
                    l.profileLockedNote,
                    style: t.bodySmall.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
              _section(
                l.profileContact,
                [
                  _row(
                    l.profileAltPhone,
                    v('altPhone').isEmpty ? notSet : v('altPhone'),
                  ),
                  _row(
                    l.profileAddress,
                    [v('address'), v('city'), v('pincode')]
                        .where((s) => s.isNotEmpty)
                        .join(', '),
                  ),
                  const SizedBox(height: DeliverySpace.sm),
                  DeliveryButton.secondary(
                    key: const ValueKey('edit-contact'),
                    label: l.profileEditContact,
                    icon: DeliveryIcons.edit,
                    onPressed: _busy ? null : () => _editContact(data),
                  ),
                ],
              ),
              _section(
                l.profileDocuments,
                [
                  for (final e in docs.entries)
                    _row(
                      switch (e.key) {
                        RiderDocument.aadhaarFront => l.docAadhaarFront,
                        RiderDocument.aadhaarBack => l.docAadhaarBack,
                        RiderDocument.selfie => l.docSelfie,
                        RiderDocument.license => l.docLicense,
                      },
                      e.value ? l.docSubmitted : l.docNotSubmitted,
                    ),
                ],
              ),
              _section(
                l.profilePayout,
                [
                  Text(
                    acct.isNotEmpty
                        ? l.payoutBank(maskTail(acct))
                        : (upi.isNotEmpty ? l.payoutUpi(upi) : l.payoutNone),
                    style: t.bodyMedium.copyWith(color: c.textPrimary),
                  ),
                  if (acct.isNotEmpty && upi.isNotEmpty)
                    Text(
                      l.payoutUpi(upi),
                      style: t.bodyMedium.copyWith(color: c.textPrimary),
                    ),
                  const SizedBox(height: DeliverySpace.sm),
                  DeliveryButton.secondary(
                    label: l.payoutChange,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => MoneyScreen(riderId: auth.user!.uid),
                      ),
                    ),
                  ),
                ],
              ),
              if (appearance != null)
                _section(
                  l.profileAppearanceHeading,
                  [
                    ListenableBuilder(
                      listenable: appearance,
                      builder: (context, _) => DeliverySegmented<ThemeMode>(
                        selected: appearance.mode,
                        onSelected: appearance.setMode,
                        options: [
                          DeliverySegmentOption(
                            value: ThemeMode.system,
                            label: l.profileThemeSystem,
                          ),
                          DeliverySegmentOption(
                            value: ThemeMode.light,
                            label: l.profileThemeLight,
                          ),
                          DeliverySegmentOption(
                            value: ThemeMode.dark,
                            label: l.profileThemeDark,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              _section(l.profileSupport, const [SupportContactButtons()]),
              _section(
                l.profileAccount,
                [
                  DeliveryButton.secondary(
                    key: const ValueKey('sign-out'),
                    label: l.actionSignOut,
                    icon: DeliveryIcons.logout,
                    onPressed: _busy ? null : _signOut,
                  ),
                  const SizedBox(height: DeliverySpace.sm),
                  StreamBuilder<RiderAccount>(
                    stream: _account,
                    builder: (context, accountSnap) => DeliveryButton.ghost(
                      key: const ValueKey('delete-account'),
                      label: l.deleteAccount,
                      icon: DeliveryIcons.delete,
                      onPressed: _busy
                          ? null
                          : () => _delete(
                                context.read<DeliveryOrderProvider>().activeOrders,
                                accountSnap.data,
                              ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Edits the fields a rider may change themselves.
class ContactEditSheet extends StatefulWidget {
  const ContactEditSheet({
    super.key,
    required this.initial,
    required this.backend,
  });
  final Map<String, dynamic> initial;
  final RiderAccountBackend backend;

  @override
  State<ContactEditSheet> createState() => _ContactEditSheetState();
}

class _ContactEditSheetState extends State<ContactEditSheet> {
  late final Map<String, TextEditingController> _c = {
    for (final k in ['altPhone', 'address', 'city', 'pincode'])
      k: TextEditingController(text: (widget.initial[k] as String?) ?? ''),
  };
  Set<String> _problems = {};
  AccountActionFailure? _failure;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _failure = null;
      _problems = {};
    });
    try {
      await widget.backend.updateContact({
        for (final e in _c.entries) e.key: e.value.text,
      });
      if (mounted) Navigator.of(context).pop(true);
    } on AccountActionException catch (e) {
      if (mounted) {
        setState(() {
          _failure = e.failure;
          _problems = e.problems.toSet();
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final t = context.text;
    Widget field(
      String key,
      String label, {
      TextInputType? keyboard,
      int maxLines = 1,
    }) =>
        Padding(
          padding: const EdgeInsets.only(bottom: DeliverySpace.md),
          child: TextField(
            key: ValueKey('contact-$key'),
            controller: _c[key],
            keyboardType: keyboard,
            maxLines: maxLines,
            decoration: InputDecoration(
              labelText: label,
              errorMaxLines: 3,
              errorText:
                  _problems.contains(key) ? fieldErrorTextFor(l, key) : null,
            ),
          ),
        );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        DeliverySpace.page,
        0,
        DeliverySpace.page,
        MediaQuery.of(context).viewInsets.bottom + DeliverySpace.page,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.profileEditContact,
            style: t.titleMedium.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: DeliverySpace.md),
          field('altPhone', l.fieldAltPhone, keyboard: TextInputType.phone),
          field('address', l.fieldAddress, maxLines: 2),
          field('city', l.fieldCity),
          field('pincode', l.fieldPincode, keyboard: TextInputType.number),
          if (_failure != null && _problems.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: DeliverySpace.sm),
              child: Text(
                accountFailureText(l, _failure!),
                style: t.bodyMedium.copyWith(color: c.danger.text),
              ),
            ),
          DeliveryButton.primary(
            key: const ValueKey('contact-save'),
            label: l.save,
            isLoading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}

String? fieldErrorTextFor(AppLocalizations l, String key) => switch (key) {
      'altPhone' => l.errAltPhone,
      'address' => l.errAddress,
      'city' => l.errCity,
      'pincode' => l.errPincode,
      _ => null,
    };
