import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design_system/design_system.dart';
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

/// "HH:mm" (24 h) ↔ [TimeOfDay]. Older free-text values that don't parse
/// are shown as typed until the seller picks a new time.
TimeOfDay? parseShopTime(String v) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(v.trim());
  if (m == null) return null;
  final h = int.parse(m[1]!), min = int.parse(m[2]!);
  return h < 24 && min < 60 ? TimeOfDay(hour: h, minute: min) : null;
}

String formatShopTime(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Business details screen (board 22-05); returns the edited values or null.
Future<BusinessDetails?> showBusinessDetailsSheet(BuildContext context, BusinessDetails initial) {
  return Navigator.of(context).push<BusinessDetails>(
    MaterialPageRoute(builder: (_) => BusinessDetailsSheet(initial: initial)),
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
  final _scope = GlobalKey<SellerFormScopeState>();
  late final _name = TextEditingController(text: widget.initial.businessName);
  late final _phone = TextEditingController(text: widget.initial.phone);
  late final _gstin = TextEditingController(text: widget.initial.gstin);
  late final _city = TextEditingController(text: widget.initial.city);
  late final _state = TextEditingController(text: widget.initial.state);
  late final _radius = TextEditingController(text: '${widget.initial.deliveryRadiusKm}');
  late String _open = widget.initial.openingTime;
  late String _close = widget.initial.closingTime;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _phone, _gstin, _city, _state, _radius]) {
      c.addListener(() {
        if (!_dirty) setState(() => _dirty = true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _gstin, _city, _state, _radius]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickTime(bool opening) async {
    final current = parseShopTime(opening ? _open : _close) ?? TimeOfDay(hour: opening ? 9 : 18, minute: 0);
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked == null || !mounted) return;
    setState(() {
      if (opening) {
        _open = formatShopTime(picked);
      } else {
        _close = formatShopTime(picked);
      }
      _dirty = true;
    });
  }

  String _timeLabel(String v) {
    final t = parseShopTime(v);
    if (t != null) return MaterialLocalizations.of(context).formatTimeOfDay(t);
    return v.trim().isEmpty ? AppLocalizations.of(context).accountTimeNotSet : v;
  }

  void _save() {
    if (!_form.currentState!.validate()) {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) => _scope.currentState?.focusFirstInvalid());
      return;
    }
    _dirty = false;
    Navigator.of(context).pop(BusinessDetails(
      businessName: _name.text,
      phone: _phone.text,
      gstin: _gstin.text,
      city: _city.text,
      state: _state.text,
      openingTime: _open,
      closingTime: _close,
      deliveryRadiusKm: int.parse(_radius.text.trim()),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget pair(Widget a, Widget b) => context.largeText
        ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [a, const SizedBox(height: SellerSpace.s16), b])
        : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: a),
            const SizedBox(width: SellerSpace.s12),
            Expanded(child: b),
          ]);
    final invalid = _scope.currentState?.invalidLabels ?? const <String>[];
    return SellerDiscardGuard(
      hasChanges: _dirty,
      child: Scaffold(
        appBar: SellerAppBar.detail(context, title: l10n.accountBusinessDetails),
        body: SellerFormScope(
          key: _scope,
          child: Form(
            key: _form,
            child: SellerPage(
              gap: SellerSpace.s16,
              footer: SellerButtonBar(children: [
                SellerButton.secondary(label: l10n.cancel, onPressed: () => Navigator.of(context).maybePop()),
                SellerButton(label: l10n.accountSave, icon: SellerIcons.check, onPressed: _save),
              ]),
              children: [
                if (invalid.isNotEmpty) SellerFormErrorSummary(labels: invalid, onSelect: (l) => _scope.currentState?.focusLabel(l)),
                SellerTextField(
                  fieldKey: const ValueKey('bizName'),
                  label: l10n.accountBusinessName,
                  required: true,
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => v.trim().isEmpty ? l10n.accountBusinessNameRequired : null,
                ),
                SellerTextField(
                  label: l10n.accountPhone,
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  prefixIcon: SellerIcons.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                ),
                SellerTextField(
                  fieldKey: const ValueKey('bizGstin'),
                  label: l10n.accountGstin,
                  controller: _gstin,
                  helper: l10n.accountGstinOptionalHelp,
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) {
                    final g = v.trim().toUpperCase();
                    return g.isEmpty || ApplicationRules.gstin.hasMatch(g) ? null : l10n.errGstin;
                  },
                ),
                pair(
                  SellerTextField(label: l10n.accountCity, controller: _city, textCapitalization: TextCapitalization.words),
                  SellerTextField(label: l10n.accountState, controller: _state, textCapitalization: TextCapitalization.words),
                ),
                pair(
                  SellerPickerField(label: l10n.accountOpens, icon: SellerIcons.clock, value: _timeLabel(_open), onTap: () => _pickTime(true)),
                  SellerPickerField(label: l10n.accountCloses, icon: SellerIcons.clock, value: _timeLabel(_close), onTap: () => _pickTime(false)),
                ),
                SellerTextField(
                  fieldKey: const ValueKey('bizRadius'),
                  label: l10n.accountRadius,
                  required: true,
                  controller: _radius,
                  tabular: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    final n = int.tryParse(v.trim());
                    return n != null && n >= 1 && n <= BusinessDetails.kMaxDeliveryRadiusKm
                        ? null
                        : l10n.accountRadiusInvalid(BusinessDetails.kMaxDeliveryRadiusKm);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
