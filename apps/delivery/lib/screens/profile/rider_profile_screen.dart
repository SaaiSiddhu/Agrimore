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
import '../auth/rider_registration_screen.dart' show vehicleLabel;
import '../money/money_screen.dart';
import '../orders/active_order_screen.dart';
import '../settings/device_readiness_screen.dart';
import '../support/help_support_screen.dart';
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
    this.accountSource,
    this.documentReviewBackend,
    this.pickReplacementPhoto,
  });
  final RiderAccountBackend? backend;
  final Map<String, dynamic>? partnerData;

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
  late final Stream<Map<String, dynamic>?> _partner = _resolvePartnerStream();
  late final Stream<RiderAccount> _account = _resolveAccountStream();
  late final RiderDocumentReviewBackend _documentReviewBackend =
      widget.documentReviewBackend ?? CallableRiderDocumentReviewBackend();
  late final Future<({Uint8List bytes, String contentType})?> Function(RiderDocument doc)
      _pickReplacementPhoto = widget.pickReplacementPhoto ?? _defaultPickReplacementPhoto;
  bool _busy = false;

  Future<({Uint8List bytes, String contentType})?> _defaultPickReplacementPhoto(RiderDocument doc) async {
    final file = await ImagePicker().pickImage(
      source: doc == RiderDocument.selfie ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (file == null) return null;
    return (bytes: await file.readAsBytes(), contentType: file.mimeType ?? 'image/jpeg');
  }

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
                  DeliveryButton.secondary(
                    key: const ValueKey('device-readiness'),
                    label: l.readinessOpen,
                    icon: DeliveryIcons.bell,
                    onPressed: () => Navigator.of(context).push(
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
                  DeliveryButton.secondary(
                    key: const ValueKey('get-help'),
                    label: l.profileGetHelp,
                    icon: DeliveryIcons.document,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const HelpSupportScreen(),
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
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: DeliverySpace.xxs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                        color: review.status == DocumentReviewStatus.rejected ? c.danger.icon : c.textPrimary,
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
