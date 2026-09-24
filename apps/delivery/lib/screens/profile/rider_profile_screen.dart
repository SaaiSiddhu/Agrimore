// lib/screens/profile/rider_profile_screen.dart
//
// Phase DLV-A2 — the rider's own profile: what Agrimore holds about them
// (Aadhaar and bank masked), document and payout state, the contact details
// they may edit themselves (updateRiderContact), the reviewed paths for
// everything else, support, sign-out and account deletion.
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../account/rider_account.dart';
import '../../account/support_card.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../registration/rider_application.dart';
import '../auth/rider_registration_screen.dart' show vehicleLabel;
import '../money/money_screen.dart';

String accountFailureText(AppLocalizations l, AccountActionFailure f) => switch (f) {
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
    RiderDocument.aadhaarFront: has(paths['aadhaarFront']) || has(d['aadhaarFrontImage']),
    RiderDocument.aadhaarBack: has(paths['aadhaarBack']) || has(d['aadhaarBackImage']),
    RiderDocument.selfie: has(paths['selfie']) || has(d['selfieImage']),
    RiderDocument.license: has(paths['license']) || has(d['licenseImage']),
  };
}

class RiderProfileScreen extends StatefulWidget {
  const RiderProfileScreen({super.key, this.backend});
  final RiderAccountBackend? backend;

  @override
  State<RiderProfileScreen> createState() => _RiderProfileScreenState();
}

class _RiderProfileScreenState extends State<RiderProfileScreen> {
  late final RiderAccountBackend _backend = widget.backend ?? CallableRiderAccountBackend();
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _partner = FirebaseFirestore.instance
      .collection('delivery_partners')
      .doc(context.read<DeliveryAuthProvider>().user!.uid)
      .snapshots();
  bool _busy = false;

  Future<void> _editContact(Map<String, dynamic> d) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ContactEditSheet(initial: d, backend: _backend),
    );
    if (saved == true && mounted) WsToast.show(context, AppLocalizations.of(context).contactSaved, tone: WsToastTone.success);
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final ok = await wsConfirm(context,
        title: l.deleteConfirmTitle, message: l.deleteConfirmBody, confirmLabel: l.deleteConfirm, cancelLabel: l.cancel,
        destructive: true);
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await _backend.deleteAccount();
      if (!mounted) return;
      final auth = context.read<DeliveryAuthProvider>();
      WsToast.show(context, l.deleteDone);
      await auth.signOut();
    } on AccountActionException catch (e) {
      if (mounted) WsToast.show(context, accountFailureText(l, e.failure), tone: WsToastTone.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _row(String label, String value) {
    final t = context.ws;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: WsSpace.s4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 2, child: Text(label, style: text.bodyMedium?.copyWith(color: t.textSecondary))),
        const SizedBox(width: WsSpace.s8),
        Expanded(flex: 3, child: Text(value, style: text.bodyMedium?.copyWith(color: t.textPrimary))),
      ]),
    );
  }

  Widget _section(String title, List<Widget> children) {
    final text = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: WsSpace.s12),
      child: Padding(
        padding: const EdgeInsets.all(WsSpace.s16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: text.titleSmall),
          const SizedBox(height: WsSpace.s8),
          ...children,
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.ws;
    final auth = context.watch<DeliveryAuthProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(l.profileTitle)),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _partner,
        builder: (context, snap) {
          final data = snap.data?.data();
          if (data == null) return const Center(child: CircularProgressIndicator());
          String v(String k) => (data[k] as String?)?.trim() ?? '';
          final notSet = l.profileNotSet;
          final docs = documentsOnFile(data);
          final acct = v('bankAccountNumber');
          final upi = v('upiId');
          return ListView(
            padding: const EdgeInsets.all(WsSpace.page),
            children: [
              Text(v('name'), style: Theme.of(context).textTheme.headlineSmall),
              Text(auth.user?.email ?? '', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: t.textSecondary)),
              const SizedBox(height: WsSpace.s16),
              _section(l.profileDetails, [
                _row(l.profilePhone, v('phone').isEmpty ? notSet : v('phone')),
                _row(l.profileVehicle, vehicleLabel(l, VehicleType.fromWire(data['vehicleType'] as String?))),
                if (v('vehicleNumber').isNotEmpty) _row(l.profileVehicleNumber, v('vehicleNumber')),
                _row(l.profileLicence, v('licenseNumber').isEmpty ? notSet : maskTail(v('licenseNumber'))),
                _row(l.profileAadhaar, v('aadhaarNumber').isEmpty ? notSet : maskAadhaar(v('aadhaarNumber'))),
                const SizedBox(height: WsSpace.s8),
                Text(l.profileLockedNote, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textSecondary)),
              ]),
              _section(l.profileContact, [
                _row(l.profileAltPhone, v('altPhone').isEmpty ? notSet : v('altPhone')),
                _row(l.profileAddress, [v('address'), v('city'), v('pincode')].where((s) => s.isNotEmpty).join(', ')),
                const SizedBox(height: WsSpace.s8),
                OutlinedButton.icon(
                  key: const ValueKey('edit-contact'),
                  onPressed: _busy ? null : () => _editContact(data),
                  icon: const Icon(AgIcons.edit),
                  label: Text(l.profileEditContact),
                ),
              ]),
              _section(l.profileDocuments, [
                for (final e in docs.entries)
                  _row(switch (e.key) {
                    RiderDocument.aadhaarFront => l.docAadhaarFront,
                    RiderDocument.aadhaarBack => l.docAadhaarBack,
                    RiderDocument.selfie => l.docSelfie,
                    RiderDocument.license => l.docLicense,
                  }, e.value ? l.docSubmitted : l.docNotSubmitted),
              ]),
              _section(l.profilePayout, [
                Text(acct.isNotEmpty
                    ? l.payoutBank(maskTail(acct))
                    : (upi.isNotEmpty ? l.payoutUpi(upi) : l.payoutNone)),
                if (acct.isNotEmpty && upi.isNotEmpty) Text(l.payoutUpi(upi)),
                const SizedBox(height: WsSpace.s8),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MoneyScreen(riderId: auth.user!.uid))),
                  child: Text(l.payoutChange),
                ),
              ]),
              _section(l.profileSupport, const [SupportContactButtons()]),
              _section(l.profileAccount, [
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : () => riderSignOut(context),
                  icon: const Icon(AgIcons.logOut),
                  label: Text(l.actionSignOut),
                ),
                const SizedBox(height: WsSpace.s8),
                TextButton.icon(
                  key: const ValueKey('delete-account'),
                  style: TextButton.styleFrom(foregroundColor: t.errorFg),
                  onPressed: _busy ? null : _delete,
                  icon: const Icon(AgIcons.delete),
                  label: Text(l.deleteAccount),
                ),
              ]),
            ],
          );
        },
      ),
    );
  }
}

/// Edits the fields a rider may change themselves.
class ContactEditSheet extends StatefulWidget {
  const ContactEditSheet({super.key, required this.initial, required this.backend});
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
      await widget.backend.updateContact({for (final e in _c.entries) e.key: e.value.text});
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
    final t = context.ws;
    Widget field(String key, String label, {TextInputType? keyboard, int maxLines = 1}) => Padding(
          padding: const EdgeInsets.only(bottom: WsSpace.s12),
          child: TextField(
            key: ValueKey('contact-$key'),
            controller: _c[key],
            keyboardType: keyboard,
            maxLines: maxLines,
            decoration: InputDecoration(
              labelText: label,
              errorMaxLines: 3,
              errorText: _problems.contains(key) ? fieldErrorTextFor(l, key) : null,
            ),
          ),
        );
    return Padding(
      padding: EdgeInsets.fromLTRB(
          WsSpace.page, 0, WsSpace.page, MediaQuery.of(context).viewInsets.bottom + WsSpace.page),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(l.profileEditContact, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: WsSpace.s12),
        field('altPhone', l.fieldAltPhone, keyboard: TextInputType.phone),
        field('address', l.fieldAddress, maxLines: 2),
        field('city', l.fieldCity),
        field('pincode', l.fieldPincode, keyboard: TextInputType.number),
        if (_failure != null && _problems.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: WsSpace.s8),
            child: Text(accountFailureText(l, _failure!),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: t.errorFg)),
          ),
        FilledButton(
          key: const ValueKey('contact-save'),
          onPressed: _saving ? null : _save,
          child: Text(l.save),
        ),
      ]),
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
