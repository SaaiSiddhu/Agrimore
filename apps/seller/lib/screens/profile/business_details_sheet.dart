import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../onboarding/application_rules.dart';

/// The owner-editable business fields (firestore.rules
/// ownerEditsOnlyStorefrontFields). `gstin` is canonical; `gstNumber` is
/// written alongside for legacy readers (SELLER-ACCOUNT-1a).
@immutable
class BusinessDetails {
  const BusinessDetails({
    this.businessName = '',
    this.phone = '',
    this.gstin = '',
    this.city = '',
    this.state = '',
    this.openingTime = '',
    this.closingTime = '',
    this.deliveryRadiusKm = kDefaultDeliveryRadiusKm,
  });

  static const int kDefaultDeliveryRadiusKm = 10;
  static const int kMaxDeliveryRadiusKm = 100;

  factory BusinessDetails.fromSeller(Map<String, dynamic>? d) {
    String s(Object? v) => v is String ? v : '';
    final radius = d?['deliveryRadiusKm'];
    return BusinessDetails(
      businessName: s(d?['businessName']).isNotEmpty ? s(d?['businessName']) : s(d?['name']),
      phone: s(d?['phone']),
      gstin: s(d?['gstin']).isNotEmpty ? s(d?['gstin']) : s(d?['gstNumber']),
      city: s(d?['city']),
      state: s(d?['state']),
      openingTime: s(d?['openingTime']),
      closingTime: s(d?['closingTime']),
      deliveryRadiusKm: radius is num ? radius.round() : kDefaultDeliveryRadiusKm,
    );
  }

  final String businessName;
  final String phone;
  final String gstin;
  final String city;
  final String state;
  final String openingTime;
  final String closingTime;
  final int deliveryRadiusKm;

  Map<String, Object> toUpdate() => {
        'businessName': businessName.trim(),
        'phone': phone.trim(),
        'gstin': gstin.trim().toUpperCase(),
        'gstNumber': gstin.trim().toUpperCase(),
        'city': city.trim(),
        'state': state.trim(),
        'openingTime': openingTime.trim(),
        'closingTime': closingTime.trim(),
        'deliveryRadiusKm': deliveryRadiusKm,
      };
}

/// Edit sheet for business details; returns the edited values or null.
Future<BusinessDetails?> showBusinessDetailsSheet(BuildContext context, BusinessDetails initial) {
  return showModalBottomSheet<BusinessDetails>(
    context: context,
    isScrollControlled: true,
    builder: (_) => BusinessDetailsSheet(initial: initial),
  );
}

class BusinessDetailsSheet extends StatefulWidget {
  const BusinessDetailsSheet({super.key, required this.initial});
  final BusinessDetails initial;

  @override
  State<BusinessDetailsSheet> createState() => _BusinessDetailsSheetState();
}

class _BusinessDetailsSheetState extends State<BusinessDetailsSheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial.businessName);
  late final _phone = TextEditingController(text: widget.initial.phone);
  late final _gstin = TextEditingController(text: widget.initial.gstin);
  late final _city = TextEditingController(text: widget.initial.city);
  late final _state = TextEditingController(text: widget.initial.state);
  late final _open = TextEditingController(text: widget.initial.openingTime);
  late final _close = TextEditingController(text: widget.initial.closingTime);
  late final _radius = TextEditingController(text: '${widget.initial.deliveryRadiusKm}');

  @override
  void dispose() {
    for (final c in [_name, _phone, _gstin, _city, _state, _open, _close, _radius]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    Navigator.of(context).pop(BusinessDetails(
      businessName: _name.text,
      phone: _phone.text,
      gstin: _gstin.text,
      city: _city.text,
      state: _state.text,
      openingTime: _open.text,
      closingTime: _close.text,
      deliveryRadiusKm: int.parse(_radius.text.trim()),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = context.wsText;
    Widget gap() => const SizedBox(height: WsSpace.s12);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(WsSpace.page, 0, WsSpace.page, WsSpace.s24),
          child: Form(
            key: _form,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(l10n.accountBusinessDetails, style: text.titleMedium),
              gap(),
              TextFormField(
                key: const ValueKey('bizName'),
                controller: _name,
                decoration: InputDecoration(labelText: l10n.accountBusinessName),
                validator: (v) => (v ?? '').trim().isEmpty ? l10n.accountBusinessNameRequired : null,
              ),
              gap(),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: l10n.accountPhone),
              ),
              gap(),
              TextFormField(
                key: const ValueKey('bizGstin'),
                controller: _gstin,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(labelText: l10n.accountGstin, helperText: l10n.accountGstinHelp),
                validator: (v) {
                  final g = (v ?? '').trim().toUpperCase();
                  return g.isEmpty || ApplicationRules.gstin.hasMatch(g) ? null : l10n.errGstin;
                },
              ),
              gap(),
              Row(children: [
                Expanded(child: TextFormField(controller: _city, decoration: InputDecoration(labelText: l10n.accountCity))),
                const SizedBox(width: WsSpace.s12),
                Expanded(child: TextFormField(controller: _state, decoration: InputDecoration(labelText: l10n.accountState))),
              ]),
              gap(),
              Row(children: [
                Expanded(child: TextFormField(controller: _open, decoration: InputDecoration(labelText: l10n.accountOpens))),
                const SizedBox(width: WsSpace.s12),
                Expanded(child: TextFormField(controller: _close, decoration: InputDecoration(labelText: l10n.accountCloses))),
              ]),
              gap(),
              TextFormField(
                key: const ValueKey('bizRadius'),
                controller: _radius,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(labelText: l10n.accountRadius),
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim());
                  return n != null && n >= 1 && n <= BusinessDetails.kMaxDeliveryRadiusKm
                      ? null
                      : l10n.accountRadiusInvalid(BusinessDetails.kMaxDeliveryRadiusKm);
                },
              ),
              const SizedBox(height: WsSpace.s24),
              FilledButton(onPressed: _save, child: Text(l10n.accountSave)),
              const SizedBox(height: WsSpace.s8),
              TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
            ]),
          ),
        ),
      ),
    );
  }
}
