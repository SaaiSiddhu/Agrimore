// lib/screens/profile/rider_profile_screen.dart
//
// Phase DLV-A2 / Phase 31 — the rider's own profile: what Agrimore holds about
// them (Aadhaar and bank masked), document and payout state, the contact
// details they may edit themselves (updateRiderContact), appearance switcher,
// support, sign-out and account deletion.
import 'dart:typed_data';

import 'package:agrimore_core/agrimore_core.dart'
    show OrderModel, VehicleType;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../account/rider_account.dart';
import '../../account/support_card.dart';
import '../../design_system/design_system.dart';
import '../../identity/rider_document_review.dart';
import '../../identity/rider_identity.dart' show kIdentityChangeTypeVehicle;
import '../../l10n/app_localizations.dart';
import '../../money/rider_money.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../registration/rider_application.dart';
import '../../safety/incident_status_screen.dart';
import '../auth/rider_registration_screen.dart' show vehicleLabel;
import '../money/money_screen.dart';
import '../orders/active_order_screen.dart';
import '../settings/device_readiness_screen.dart';
import '../support/help_support_screen.dart';
import '../support/my_support_requests_screen.dart';
import 'identity_change_screen.dart';

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
    this.partnerSource,
    this.accountSource,
    this.documentReviewBackend,
    this.pickReplacementPhoto,
  });
  final RiderAccountBackend? backend;

  /// A FIXED test value: when set, the partner section renders exactly this
  /// data, once, never live-bound to auth at all. For a test that wants the
  /// live, uid-rebinding behavior under a controlled fake instead, use
  /// [partnerSource].
  final Map<String, dynamic>? partnerData;

  /// Injectable for tests; defaults to a real `delivery_partners/{uid}`
  /// live read. Takes the CURRENT uid explicitly (mirroring [accountSource]
  /// below) so a fake can be swapped per-uid -- what an account-switch or
  /// late-previous-account test needs that a single fixed [partnerData]
  /// cannot express.
  final Stream<Map<String, dynamic>?> Function(String riderId)? partnerSource;

  /// DLVP1: injectable for tests; defaults to a real `rider_accounts/{uid}`
  /// read (the same stream `MoneyScreen` already uses), so the proactive
  /// deletion-eligibility check reads cash-held/unsettled-earnings without
  /// a second, ad-hoc query shape.
  final Stream<RiderAccount> Function(String riderId)? accountSource;

  /// DLVDOC3: injectable for tests; defaults to the real
  /// staged-upload-then-callable backend (functions/src/delivery/
  /// riderDocumentReview.ts).
  final RiderDocumentReviewBackend? documentReviewBackend;

  /// DLVDOC3: picks a replacement photo for one document; injectable so
  /// tests never touch the real image picker.
  final Future<({Uint8List bytes, String contentType})?> Function(RiderDocument doc)? pickReplacementPhoto;

  @override
  State<RiderProfileScreen> createState() => _RiderProfileScreenState();
}

class _RiderProfileScreenState extends State<RiderProfileScreen> {
  late final RiderAccountBackend _backend =
      widget.backend ?? CallableRiderAccountBackend();
  late final RiderDocumentReviewBackend _documentReviewBackend =
      widget.documentReviewBackend ?? CallableRiderDocumentReviewBackend();
  late final Future<({Uint8List bytes, String contentType})?> Function(RiderDocument doc)
      _pickReplacementPhoto = widget.pickReplacementPhoto ?? _defaultPickReplacementPhoto;
  bool _busy = false;

  // DLVC3: _partner/_account used to be `late final`, resolved from
  // DeliveryAuthProvider.user exactly once, the first time each field was
  // read. Firebase's own uidChanges listener fires as a microtask, not
  // synchronously with construction, so the FIRST build of this screen
  // could run before it fired -- permanently capturing a stream derived
  // from a null uid (this screen's own connected test caught this exact
  // race: a stuck spinner that never recovered even once auth resolved
  // moments later, since the stale stream had already emitted its one-shot
  // null value and closed). _UidBoundStream fixes this at the root: it
  // re-derives itself from whatever uid didChangeDependencies observes,
  // every time DeliveryAuthProvider actually changes (a real account
  // switch, a real sign-out, auth finishing initial resolution) -- and
  // leaves an unrelated rebuild (a theme change, an unrelated provider
  // notifying) alone, since the uid-equality guard short-circuits when
  // nothing about auth itself changed. StreamBuilder's own behavior when
  // handed a NEW stream instance (cancel the old subscription, subscribe to
  // the new one) is what actually disposes a superseded account's
  // subscription and discards any event still in flight from it -- nothing
  // from an old uid can ever reach a StreamBuilder that has already moved
  // on to a new stream instance for a new uid.
  final _partnerBinding = _UidBoundStream<Map<String, dynamic>?>();
  final _accountBinding = _UidBoundStream<RiderAccount>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rebindAuthDependentStreams();
  }

  void _rebindAuthDependentStreams() {
    final auth = context.read<DeliveryAuthProvider>();
    if (auth.isLoading) return; // nothing to bind to yet; build() shows the auth-resolving state
    final uid = auth.user?.uid;
    if (widget.partnerData == null) {
      _partnerBinding.rebind(uid, widget.partnerSource ?? _defaultPartnerSource);
    }
    // RiderMoneyService.account() is itself deferred to first subscription
    // (Stream.multi), so a test that never needs the real account (e.g.
    // testing sign-out alone) never touches Firebase just because this
    // screen was built.
    _accountBinding.rebind(uid, widget.accountSource ?? _defaultAccountSource, whenNull: const Stream.empty());
  }

  /// A bare `FirebaseFirestore.instance` throws SYNCHRONOUSLY (not as a
  /// stream error) when no Firebase app exists at all -- caught here so
  /// that reaches this screen's own read-failure state instead of crashing
  /// the whole widget tree build (confirmed by `delivery_shell_test.dart`,
  /// whose own fixtures never initialize a real Firebase app: the original
  /// `try { ... } catch (_) { ... }` this replaces existed for exactly this
  /// reason).
  Stream<Map<String, dynamic>?> _defaultPartnerSource(String uid) {
    try {
      return FirebaseFirestore.instance
          .collection('delivery_partners')
          .doc(uid)
          .snapshots()
          .map((s) => s.data());
    } catch (e) {
      return Stream.error(e);
    }
  }

  Stream<RiderAccount> _defaultAccountSource(String uid) => RiderMoneyService(uid).account();

  /// A Firestore stream does not resume itself after delivering an error --
  /// an explicit retry needs a genuinely new subscription for the SAME uid,
  /// not just a rebuild of the same (now-dead) stream.
  void _retryPartner() {
    final uid = context.read<DeliveryAuthProvider>().user?.uid;
    if (uid == null) return;
    setState(() => _partnerBinding.forceRebind(uid, widget.partnerSource ?? _defaultPartnerSource));
  }

  Future<({Uint8List bytes, String contentType})?> _defaultPickReplacementPhoto(RiderDocument doc) async {
    final file = await ImagePicker().pickImage(
      source: doc == RiderDocument.selfie ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (file == null) return null;
    return (bytes: await file.readAsBytes(), contentType: file.mimeType ?? 'image/jpeg');
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
    final auth = context.read<DeliveryAuthProvider>();
    final owner = auth.sessionUid;
    final session = auth.sessionVersion;
    final l = AppLocalizations.of(context);
    final ok = await showDeliveryConfirmDialog(
      context: context,
      title: l.signOutConfirmTitle,
      body: l.signOutConfirmBody,
      confirmLabel: l.actionSignOut,
      cancelLabel: l.cancel,
    );
    if (ok && mounted &&
        identical(context.read<DeliveryAuthProvider>(), auth) &&
        auth.isCurrentSession(owner, session)) {
      await riderSignOut(context);
    }
  }

  /// Checks the SAME three reasons `riderDeletionRefusal` enforces
  /// server-side (active order / cash held / pay owed), proactively and
  /// before any deletion attempt, so a blocked rider learns why — and can
  /// go straight to the thing blocking them — instead of confirming a
  /// generic dialog first only to be refused after. The server check
  /// remains the actual safety net for a race between this read and the
  /// real attempt.
  Future<void> _delete(List<OrderModel> activeOrders, RiderAccount? account) async {
    final auth = context.read<DeliveryAuthProvider>();
    final owner = auth.sessionUid;
    final session = auth.sessionVersion;
    if (owner == null || !auth.isCurrentSession(owner, session)) return;
    bool current({bool allowSignedOut = false}) => mounted &&
        identical(context.read<DeliveryAuthProvider>(), auth) &&
        auth.isCurrentSession(owner, session, allowSignedOut: allowSignedOut);
    final l = AppLocalizations.of(context);
    if (activeOrders.isNotEmpty) {
      final view = await showDeliveryConfirmDialog(
        context: context,
        title: l.deleteBlockedTitle,
        body: l.failActiveOrder,
        confirmLabel: l.deleteBlockedViewDelivery,
        cancelLabel: l.cancel,
      );
      if (view && mounted && current()) {
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
      if (view && mounted && current()) {
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
    if (!ok || !mounted || !current()) return;
    setState(() => _busy = true);
    try {
      await _backend.deleteAccount();
      if (!mounted || !current(allowSignedOut: true)) return;
      showDeliveryToast(context, message: l.deleteDone);
      if (auth.isCurrentSession(owner, session)) await auth.signOut();
    } on AccountActionException catch (e) {
      if (mounted && current()) {
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

  /// DLVHOME1 Profile redesign: a comfortable label/value row, matching the
  /// reference's row rhythm. Kept as a thin wrapper over the canonical
  /// [DeliveryKeyValueRow] rather than a bespoke Row -- same call shape
  /// every existing call site already uses, so this is a styling change
  /// only, not a rewrite of what each section says.
  Widget _row(String label, String value) => DeliveryKeyValueRow(label: label, value: value);

  /// DLVHOME1 Profile redesign: a grouped card with a [DeliverySectionHeader]
  /// title (was a plain `Text`) -- the "clear grouped cards" + "consistent
  /// icon/label/chevron rows" hierarchy the reference uses, built from the
  /// app's own existing canonical components, not a new parallel style.
  Widget _section(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DeliverySpace.md),
      child: DeliveryCard(
        padding: const EdgeInsets.all(DeliverySpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DeliverySectionHeader(
              title: title,
              padding: const EdgeInsets.only(bottom: DeliverySpace.sm),
            ),
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
      // DLVHOME1 Profile redesign: matches the identity header card's own
      // fill (c.surface) directly below it, per the owner's own follow-up --
      // the app bar and that first card now read as one continuous surface
      // instead of two different tones meeting at a seam.
      appBar: AppBar(
        title: Text(l.profileTitle),
        backgroundColor: c.surface,
      ),
      body: _body(auth, l, c, t, appearance),
    );
  }

  /// DLVC3: auth-resolving / signed-out / data-loading / missing-record /
  /// read-failure are now distinct, rather than collapsing everything that
  /// is not yet a loaded map into one spinner (the bug that made a
  /// genuinely-stuck stream indistinguishable from an ordinary loading
  /// moment).
  Widget _body(
    DeliveryAuthProvider auth,
    AppLocalizations l,
    DeliveryColors c,
    DeliveryType t,
    DeliveryAppearanceController? appearance,
  ) {
    if (widget.partnerData != null) {
      return _loaded(widget.partnerData!, auth, l, c, t, appearance);
    }
    if (auth.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (auth.user == null) {
      return Center(
        child: Text(l.profileSignedOut, style: t.bodyMedium.copyWith(color: c.textSecondary)),
      );
    }
    final stream = _partnerBinding.current;
    if (stream == null) {
      // auth.user is non-null here, so _rebindAuthDependentStreams should
      // already have bound a real stream -- defensive only, never expected.
      return const Center(child: CircularProgressIndicator());
    }
    return StreamBuilder<Map<String, dynamic>?>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(DeliverySpace.page),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l.profileLoadFailed,
                    textAlign: TextAlign.center,
                    style: t.bodyMedium.copyWith(color: c.textPrimary),
                  ),
                  const SizedBox(height: DeliverySpace.sm),
                  DeliveryButton.secondary(
                    key: const ValueKey('profile-retry'),
                    label: l.actionRetry,
                    fullWidth: false,
                    onPressed: _retryPartner,
                  ),
                ],
              ),
            ),
          );
        }
        final data = snap.data;
        if (data == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(DeliverySpace.page),
              child: Text(
                l.profileRecordMissing,
                textAlign: TextAlign.center,
                style: t.bodyMedium.copyWith(color: c.textSecondary),
              ),
            ),
          );
        }
        return _loaded(data, auth, l, c, t, appearance);
      },
    );
  }

  Widget _loaded(
    Map<String, dynamic> data,
    DeliveryAuthProvider auth,
    AppLocalizations l,
    DeliveryColors c,
    DeliveryType t,
    DeliveryAppearanceController? appearance,
  ) {
    String v(String k) => (data[k] as String?)?.trim() ?? '';
          final notSet = l.profileNotSet;
          final docs = documentsOnFile(data);
          final acct = v('bankAccountNumber');
          final upi = v('upiId');
          // Owner follow-up: the identity card scrolls away with the rest
          // of the content, not pinned above a separately-scrolling list --
          // one single ListView, the card as its own first (full-bleed, no
          // horizontal padding) item, everything else wrapped in one Padding
          // so its spacing is unchanged from before this card existed.
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              _identityHeader(v, notSet, auth, c, t),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  DeliverySpace.page,
                  DeliverySpace.lg,
                  DeliverySpace.page,
                  DeliverySpace.page,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                  const SizedBox(height: DeliverySpace.sm),
                  DeliveryButton.secondary(
                    key: const ValueKey('request-vehicle-change'),
                    label: l.profileRequestVehicleChange,
                    icon: DeliveryIcons.edit,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => IdentityChangeScreen(
                          riderId: auth.user!.uid,
                          changeType: kIdentityChangeTypeVehicle,
                          currentVehicleType: VehicleType.fromWire(
                            data['vehicleType'] as String?,
                          ),
                          currentVehicleNumber: v('vehicleNumber'),
                        ),
                      ),
                    ),
                  ),
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
                  DeliveryButton.secondary(
                    key: const ValueKey('request-name-change'),
                    label: l.profileRequestNameChange,
                    icon: DeliveryIcons.edit,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => IdentityChangeScreen(
                          riderId: auth.user!.uid,
                          currentName: v('name'),
                        ),
                      ),
                    ),
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
                    _DocumentPreviewTile(
                      key: ValueKey('doc-${e.key.key}'),
                      docKey: e.key.key,
                      doc: e.key,
                      label: switch (e.key) {
                        RiderDocument.aadhaarFront => l.docAadhaarFront,
                        RiderDocument.aadhaarBack => l.docAadhaarBack,
                        RiderDocument.selfie => l.docSelfie,
                        RiderDocument.license => l.docLicense,
                      },
                      onFile: e.value,
                      // DLVDOC1: a rider's own already-uploaded document is a
                      // pure read -- storage.rules grants it unconditionally,
                      // independent of application status. DLVDOC3: a
                      // REPLACEMENT (which riderKycEditable() deliberately
                      // refuses on this live path directly) goes through the
                      // separate staging-path + review flow below instead of
                      // ever writing here directly.
                      storagePath: e.key.pathFor(auth.user!.uid),
                      riderId: auth.user!.uid,
                      reviewBackend: _documentReviewBackend,
                      pickReplacementPhoto: _pickReplacementPhoto,
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
              _section(
                l.profileReadinessHeading,
                [
                  DeliveryListTile(
                    key: const ValueKey('device-readiness'),
                    title: l.readinessOpen,
                    leadingIcon: DeliveryIcons.bell,
                    showChevron: true,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const DeviceReadinessScreen(),
                      ),
                    ),
                  ),
                ],
              ),
              _section(
                l.profileSupport,
                [
                  DeliveryListTile(
                    key: const ValueKey('get-help'),
                    title: l.profileGetHelp,
                    leadingIcon: DeliveryIcons.document,
                    showChevron: true,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const HelpSupportScreen(),
                      ),
                    ),
                  ),
                  // DLVHOME1 Profile redesign: previously reachable only by
                  // opening Help & support first, then its own nested "My
                  // requests" row -- the owner's IA explicitly lists this as
                  // its own top-level Profile row, matching the reference's
                  // "Support tickets" row. Help & support keeps its own
                  // nested entry too (unchanged, still real, not removed).
                  DeliveryListTile(
                    key: const ValueKey('my-support-requests'),
                    title: l.mySupportRequestsEntry,
                    leadingIcon: DeliveryIcons.statement,
                    showChevron: true,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => MySupportRequestsScreen(riderId: auth.user!.uid),
                      ),
                    ),
                  ),
                  // DLVC3: the persistent entry point back to a rider's own
                  // past safety reports -- reopenable any time, including
                  // after the emergency sheet that filed one has long since
                  // closed and after an app restart.
                  DeliveryListTile(
                    key: const ValueKey('my-safety-reports'),
                    title: l.myIncidentsEntry,
                    leadingIcon: DeliveryIcons.shield,
                    showChevron: true,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => MyIncidentsScreen(riderId: auth.user!.uid),
                      ),
                    ),
                  ),
                  const SizedBox(height: DeliverySpace.sm),
                  const SupportContactButtons(),
                ],
              ),
              _section(
                l.profileAccount,
                [
                  DeliveryButton.secondary(
                    key: const ValueKey('sign-out'),
                    label: l.actionSignOut,
                    icon: DeliveryIcons.logout,
                    onPressed: _busy ? null : _signOut,
                  ),
                  const SizedBox(height: DeliverySpace.md),
                  StreamBuilder<RiderAccount>(
                    stream: _accountBinding.current,
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
                ),
              ),
            ],
          );
  }

  /// DLVHOME1 Profile redesign: a "strong identity header" per the
  /// reference -- a full-bleed card, flush with the app bar above and
  /// curved only at the bottom, distinct from the plain background below
  /// it (matching the reference's own rounded identity card, not the flat
  /// text block this used to be). Content stays strictly real: initials
  /// avatar (never a reused KYC photo), name, email -- no invented rider
  /// ID/rating/partner tier/score, no global "Edit profile" affordance.
  Widget _identityHeader(
    String Function(String) v,
    String notSet,
    DeliveryAuthProvider auth,
    DeliveryColors c,
    DeliveryType t,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        DeliverySpace.page,
        DeliverySpace.lg,
        DeliverySpace.page,
        DeliverySpace.xxl,
      ),
      // c.surfaceMuted (sunken) is literally black-on-black in dark mode
      // (sunken == background == #000000 there) -- invisible, no matter the
      // border radius. c.surface + a border is the SAME pair every other
      // card on this screen (DeliveryCard's own standard variant) already
      // uses for exactly this reason: a real fill difference where dark
      // mode has one (surface != background), a visible border where light
      // mode does not (surface == background there too).
      decoration: BoxDecoration(
        color: c.surface,
        // Bottom edge only -- the top would sit right where this card
        // meets the app bar, now the SAME c.surface fill as this card, so a
        // top border would just draw a stray line across one continuous
        // surface instead of separating two different ones.
        border: Border(bottom: BorderSide(color: c.border, width: DeliverySize.hairline)),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(DeliveryRadius.dialog)),
        boxShadow: DeliveryElevation.card(c.shadow),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          DeliveryAvatar(
            name: v('name').isEmpty ? notSet : v('name'),
            size: DeliverySize.avatarXl,
          ),
          const SizedBox(width: DeliverySpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  v('name').isEmpty ? notSet : v('name'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.headlineSmall.copyWith(color: c.textPrimary),
                ),
                if ((auth.user?.email ?? '').isNotEmpty)
                  Text(
                    auth.user!.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyMedium.copyWith(color: c.textSecondary),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// DLVC3: a stream re-derived from whatever uid it is [rebind]-ed to, and
/// only when that uid genuinely differs from the last one -- an unrelated
/// rebuild that calls [rebind] again with the SAME uid is a no-op, so a
/// widget can safely call it from `didChangeDependencies` (which can fire
/// for reasons that have nothing to do with auth) without tearing down and
/// recreating a live subscription every time. [current] becoming a NEW
/// stream instance is what actually lets `StreamBuilder` dispose the
/// previous subscription and ignore anything still in flight from it --
/// this class only decides WHEN that should happen, `StreamBuilder`'s own
/// widget lifecycle does the disposing.
class _UidBoundStream<T> {
  String? _boundUid;
  Stream<T>? current;

  void rebind(String? uid, Stream<T> Function(String uid) source, {Stream<T>? whenNull}) {
    if (uid == _boundUid) return;
    _boundUid = uid;
    current = uid == null ? whenNull : source(uid);
  }

  /// Re-derives the stream for the SAME uid -- for an explicit retry after
  /// a read failure, where the uid has not changed but the previous
  /// subscription is dead (a Firestore stream does not resume itself after
  /// delivering an error) and a genuinely new one is needed.
  void forceRebind(String? uid, Stream<T> Function(String uid) source, {Stream<T>? whenNull}) {
    _boundUid = uid;
    current = uid == null ? whenNull : source(uid);
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

/// DLVDOC1 -- a document row with a "View" action when it is on file.
/// Read-only: resolves a short-lived download URL only, the same lazy
/// pattern `rider_review_sheet.dart`'s own `_KycTile` (admin) and
/// `admin_order_details_screen.dart`'s `_DeliveryProofTile` (ADMR-39)
/// already use for the identical "owner-readable Storage path" shape.
///
/// DLVDOC3 adds the per-document review status (distinct from the
/// whole-application status shown elsewhere on this screen, and from an
/// identity/vehicle change request) and a "Replace" action: staging the new
/// photo (a path riderKycEditable() never gates) and submitting it for
/// review, rather than ever writing to the live path directly.
class _DocumentPreviewTile extends StatefulWidget {
  const _DocumentPreviewTile({
    super.key,
    required this.docKey,
    required this.doc,
    required this.label,
    required this.onFile,
    required this.storagePath,
    required this.riderId,
    required this.reviewBackend,
    required this.pickReplacementPhoto,
  });

  /// The document's own stable identifier ('aadhaarFront', ...) -- used for
  /// the View button's key, deliberately never the localized [label], which
  /// would make the key locale-dependent.
  final String docKey;
  final RiderDocument doc;
  final String label;
  final bool onFile;
  final String storagePath;
  final String riderId;
  final RiderDocumentReviewBackend reviewBackend;
  final Future<({Uint8List bytes, String contentType})?> Function(RiderDocument doc) pickReplacementPhoto;

  @override
  State<_DocumentPreviewTile> createState() => _DocumentPreviewTileState();
}

class _DocumentPreviewTileState extends State<_DocumentPreviewTile> {
  Future<String>? _url;
  bool _replacing = false;

  Future<String> _resolve() async {
    try {
      return await FirebaseStorage.instance.ref(widget.storagePath).getDownloadURL();
    } catch (e) {
      debugPrint('Document preview unavailable (${widget.label}): $e');
      return '';
    }
  }

  Future<void> _view() async {
    _url ??= _resolve();
    final url = await _url!;
    if (!mounted) return;
    if (url.isEmpty) {
      final l = AppLocalizations.of(context);
      showDeliveryToast(context, message: l.docPreviewUnavailable, tone: DeliveryBannerTone.warning);
      return;
    }
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => _DocumentPreviewDialog(label: widget.label, url: url),
    );
  }

  Future<void> _replace() async {
    final l = AppLocalizations.of(context);
    final photo = await widget.pickReplacementPhoto(widget.doc);
    if (photo == null || !mounted) return;
    setState(() => _replacing = true);
    try {
      await widget.reviewBackend.submitReplacement(
        docType: widget.docKey,
        bytes: photo.bytes,
        contentType: photo.contentType,
      );
      if (mounted) {
        showDeliveryToast(context, message: l.docReplaceSubmitted, tone: DeliveryBannerTone.success);
      }
    } on DocumentReplacementException catch (e) {
      if (!mounted) return;
      final message = switch (e.failure) {
        DocumentReplacementFailure.alreadyPending => l.docReplaceAlreadyPending,
        DocumentReplacementFailure.network => l.docReplaceNetworkError,
        _ => l.docReplaceFailed,
      };
      showDeliveryToast(context, message: message, tone: DeliveryBannerTone.warning);
    } finally {
      if (mounted) setState(() => _replacing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final t = context.text;
    return StreamBuilder<Map<String, DocumentReview>>(
      stream: widget.reviewBackend.reviewsFor(widget.riderId),
      builder: (context, snap) {
        final review = snap.data?[widget.docKey] ?? DocumentReview.none;
        final pending = review.status == DocumentReviewStatus.pending;
        final statusText = switch (review.status) {
          DocumentReviewStatus.pending => l.docReviewPending,
          DocumentReviewStatus.rejected => l.docReviewRejected,
          _ => widget.onFile ? l.docSubmitted : l.docNotSubmitted,
        };
        // DLVHOME1 Profile redesign: a leading icon circle per document,
        // matching the rest of the screen's row language ("consistent
        // icon/label/chevron rows") -- purely a visual addition, no change
        // to the status text, keys, or the StreamBuilder-driven logic above.
        final rejected = review.status == DocumentReviewStatus.rejected;
        final docIcon = switch (widget.doc) {
          RiderDocument.aadhaarFront || RiderDocument.aadhaarBack => DeliveryIcons.idCard,
          RiderDocument.selfie => DeliveryIcons.camera,
          RiderDocument.license => DeliveryIcons.document,
        };
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: DeliverySpace.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: DeliverySize.avatarSm,
                    height: DeliverySize.avatarSm,
                    decoration: BoxDecoration(
                      color: rejected ? c.danger.container : c.surfaceMuted,
                      borderRadius: DeliveryRadius.rSm,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      docIcon,
                      size: DeliveryIconSize.sm,
                      color: rejected ? c.danger.icon : c.textSecondary,
                    ),
                  ),
                  const SizedBox(width: DeliverySpace.sm),
                  Expanded(
                    flex: 2,
                    child: Text(widget.label, style: t.bodyMedium.copyWith(color: c.textSecondary)),
                  ),
                  const SizedBox(width: DeliverySpace.sm),
                  Expanded(
                    flex: 3,
                    child: Text(
                      statusText,
                      style: t.bodyMedium.copyWith(
                        color: rejected ? c.danger.icon : c.textPrimary,
                      ),
                    ),
                  ),
                  if (widget.onFile)
                    TextButton(
                      key: ValueKey('view-${widget.docKey}'),
                      onPressed: _view,
                      child: Text(l.docPreviewAction),
                    ),
                ],
              ),
              if (review.status == DocumentReviewStatus.rejected && review.rejectionReason != null)
                Padding(
                  padding: const EdgeInsets.only(top: DeliverySpace.xxs),
                  child: Text(
                    review.rejectionReason!,
                    style: t.bodySmall.copyWith(color: c.danger.icon),
                  ),
                ),
              if (widget.onFile)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    key: ValueKey('replace-${widget.docKey}'),
                    onPressed: pending || _replacing ? null : _replace,
                    child: Text(_replacing ? l.docReplaceSubmitting : l.docReplaceAction),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DocumentPreviewDialog extends StatelessWidget {
  const _DocumentPreviewDialog({required this.label, required this.url});
  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final t = context.text;
    return Dialog.fullscreen(
      backgroundColor: c.mediaViewerBackground,
      child: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: Image.network(
                url,
                errorBuilder: (context, error, stackTrace) => Text(
                  l.docPreviewUnavailable,
                  style: t.bodyMedium.copyWith(color: c.onMediaViewer),
                ),
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : CircularProgressIndicator(color: c.onMediaViewer),
              ),
            ),
          ),
          Positioned(
            top: DeliverySpace.md,
            right: DeliverySpace.md,
            child: SafeArea(
              child: IconButton(
                key: const ValueKey('close-document-preview'),
                icon: Icon(DeliveryIcons.close, color: c.onMediaViewer),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          Positioned(
            top: DeliverySpace.md,
            left: DeliverySpace.md,
            child: SafeArea(
              child: Text(label, style: t.bodyMedium.copyWith(color: c.onMediaViewer)),
            ),
          ),
        ],
      ),
    );
  }
}
