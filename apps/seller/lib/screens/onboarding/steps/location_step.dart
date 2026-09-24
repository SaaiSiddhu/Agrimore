import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../../design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/seller_application_provider.dart';
import '../application_rules.dart';
import '../application_screen.dart';
import '../widgets/step_footer.dart';

/// Step 2 — shop address, optional map pin, delivery radius.
class LocationStep extends StatefulWidget {
  const LocationStep({super.key});

  @override
  State<LocationStep> createState() => _LocationStepState();
}

class _LocationStepState extends State<LocationStep> {
  static const int _pincodeLength = 6;
  static const int _minRadiusKm = 1;

  final _form = GlobalKey<FormState>();
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _pincode;
  late double _radius;
  double? _lat;
  double? _lng;
  bool _locating = false;
  bool _locationFailed = false;

  @override
  void initState() {
    super.initState();
    final d = context.read<SellerApplicationProvider>().data;
    _address = TextEditingController(text: d['shopAddress'] as String? ?? '');
    _city = TextEditingController(text: d['city'] as String? ?? '');
    _state = TextEditingController(text: d['state'] as String? ?? '');
    _pincode = TextEditingController(text: d['pincode'] as String? ?? '');
    final r = d['deliveryRadiusKm'];
    _radius = (r is num ? r.toDouble() : ApplicationRules.defaultRadiusKm.toDouble())
        .clamp(_minRadiusKm.toDouble(), ApplicationRules.maxRadiusKm.toDouble());
    _lat = (d['latitude'] as num?)?.toDouble();
    _lng = (d['longitude'] as num?)?.toDouble();
  }

  @override
  void dispose() {
    _address.dispose();
    _city.dispose();
    _state.dispose();
    _pincode.dispose();
    super.dispose();
  }

  Future<void> _useLocation() async {
    setState(() {
      _locating = true;
      _locationFailed = false;
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw StateError('denied');
      }
      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
    } catch (_) {
      setState(() => _locationFailed = true);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _continue() async {
    if (!_form.currentState!.validate()) return;
    await context.read<SellerApplicationProvider>().saveAndAdvance({
      'shopAddress': _address.text.trim(),
      'city': _city.text.trim(),
      'state': _state.text.trim(),
      'pincode': _pincode.text.trim(),
      'deliveryRadiusKm': _radius.round(),
      if (_lat != null && _lng != null) 'latitude': _lat,
      if (_lat != null && _lng != null) 'longitude': _lng,
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final app = context.watch<SellerApplicationProvider>();
    String? required(String v) => ApplicationRules.text(v) ? null : l10n.errRequired;
    final city = SellerTextField(
      label: l10n.fieldCity,
      required: true,
      controller: _city,
      textCapitalization: TextCapitalization.words,
      autofillHints: const [AutofillHints.addressCity],
      validator: required,
    );
    final pin = SellerTextField(
      label: l10n.fieldPincode,
      required: true,
      controller: _pincode,
      tabular: true,
      keyboardType: TextInputType.number,
      maxLength: _pincodeLength,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      autofillHints: const [AutofillHints.postalCode],
      validator: (v) => ApplicationRules.pincode.hasMatch(v) ? null : l10n.errPincode,
    );

    return StepBody(
      footer: StepFooter(primaryLabel: l10n.saveContinue, busyLabel: l10n.saving, busy: app.isSaving, onPrimary: _continue, onBack: app.back),
      children: [
        Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SellerButton.secondary(
              label: _lat != null ? l10n.locationCaptured : l10n.useCurrentLocation,
              icon: _lat != null ? SellerIcons.success : SellerIcons.locate,
              loading: _locating,
              onPressed: _useLocation,
            ),
            if (_locationFailed) ...[
              const SizedBox(height: SellerSpace.s8),
              SellerBanner(tone: SellerTone.warning, message: l10n.locationFailed),
            ],
            const SizedBox(height: SellerSpace.s16),
            SellerTextField(
              label: l10n.fieldAddress,
              required: true,
              controller: _address,
              maxLines: 3,
              minLines: 2,
              autofillHints: const [AutofillHints.fullStreetAddress],
              validator: (v) => ApplicationRules.text(v, min: ApplicationRules.addressMin) ? null : l10n.errRequired,
            ),
            const SizedBox(height: SellerSpace.s16),
            if (context.largeText) ...[city, const SizedBox(height: SellerSpace.s16), pin]
            else
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: city),
                const SizedBox(width: SellerSpace.s12),
                Expanded(child: pin),
              ]),
            const SizedBox(height: SellerSpace.s16),
            SellerTextField(
              label: l10n.fieldState,
              required: true,
              controller: _state,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.addressState],
              validator: required,
            ),
            const SizedBox(height: SellerSpace.s24),
            SellerSliderField(
              label: l10n.fieldRadius,
              value: _radius,
              min: _minRadiusKm.toDouble(),
              max: ApplicationRules.maxRadiusKm.toDouble(),
              divisions: ApplicationRules.maxRadiusKm - _minRadiusKm,
              valueLabel: l10n.radiusKm(_radius.round()),
              onChanged: (v) => setState(() => _radius = v),
            ),
          ]),
        ),
      ],
    );
  }
}
