// lib/screens/auth/rider_registration_screen.dart
//
// Phase DLV-A1 — rider registration on the server-owned contract
// (registration/rider_application.dart → submitRiderApplication). Replaces
// partner_registration_screen.dart, which trimmed the password, named the
// user "<name> Partner", stored public download URLs for Aadhaar and the
// licence, wrote two Firestore documents from the client, deleted the new
// account on any failure and showed raw exception text.
//
// The form keeps everything typed across steps and failures; a resumed
// registration (signed in, no rider record yet) skips the account step.
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../registration/rider_application.dart';

String registrationFailureText(AppLocalizations l, RegistrationFailure f) => switch (f) {
      RegistrationFailure.emailInUse => l.regFailEmailInUse,
      RegistrationFailure.weakPassword => l.regFailWeakPassword,
      RegistrationFailure.invalidEmail => l.regFailInvalidEmail,
      RegistrationFailure.network => l.regFailNetwork,
      RegistrationFailure.uploadFailed => l.regFailUpload,
      RegistrationFailure.invalidDetails => l.regFailInvalid,
      RegistrationFailure.documentsMissing => l.regFailDocuments,
      RegistrationFailure.alreadyRegistered => l.regFailAlreadyRegistered,
      RegistrationFailure.otherAccountRole => l.regFailOtherRole,
      RegistrationFailure.unknown => l.regFailUnknown,
    };

String vehicleLabel(AppLocalizations l, VehicleType v) => switch (v) {
      VehicleType.bicycle => l.vehicleBicycle,
      VehicleType.bike => l.vehicleBike,
      VehicleType.scooter => l.vehicleScooter,
      VehicleType.ev => l.vehicleEv,
      VehicleType.threeWheeler => l.vehicleThreeWheeler,
      VehicleType.car => l.vehicleCar,
      VehicleType.van => l.vehicleVan,
    };

String? fieldErrorText(AppLocalizations l, String key) => switch (key) {
      'email' => l.errEmail,
      'password' => l.errPassword,
      'name' => l.errName,
      'phone' => l.errPhone,
      'altPhone' => l.errAltPhone,
      'address' => l.errAddress,
      'city' => l.errCity,
      'pincode' => l.errPincode,
      'vehicleNumber' => l.errVehicleNumber,
      'licenseNumber' => l.errLicenseNumber,
      'aadhaarNumber' => l.errAadhaarNumber,
      'accountHolderName' => l.errAccountHolder,
      'bankAccountNumber' => l.errAccountNumber,
      'ifscCode' => l.errIfsc,
      'upiId' => l.errUpi,
      _ => null,
    };

/// The step each problem key belongs to (account step = 0).
int stepOfProblem(String key) => switch (key) {
      'email' || 'password' => 0,
      'name' || 'phone' || 'altPhone' || 'address' || 'city' || 'pincode' => 1,
      'vehicleType' || 'vehicleNumber' || 'licenseNumber' => 2,
      'aadhaarNumber' => 3,
      _ when key.startsWith('documents.') => 3,
      _ => 4,
    };

class RiderRegistrationScreen extends StatefulWidget {
  const RiderRegistrationScreen({super.key, this.service, this.pickPhoto, this.initial});

  /// DLV-A2: the rider's existing delivery_partners record, when a pending or
  /// rejected rider corrects and resubmits (null for a new registration).
  final Map<String, dynamic>? initial;

  /// Injected in tests.
  final RegistrationService? service;
  final Future<PickedPhoto?> Function(RiderDocument doc)? pickPhoto;

  @override
  State<RiderRegistrationScreen> createState() => _RiderRegistrationScreenState();
}

class _RiderRegistrationScreenState extends State<RiderRegistrationScreen> {
  late final RegistrationService _service = widget.service ?? RegistrationService();
  final RiderApplicationForm _form = RiderApplicationForm();
  final Map<RiderDocument, PickedPhoto> _photos = {};
  Set<String> _problems = {};
  RegistrationFailure? _failure;
  bool _submitting = false;
  late int _step = _needsAccount ? 0 : 1;

  /// Photos already on file at their fixed paths (a resubmission); an older
  /// URL-only record's photos must be added again.
  final Set<RiderDocument> _onFile = {};

  @override
  void initState() {
    super.initState();
    final d = widget.initial;
    if (d == null) return;
    String v(String k) => (d[k] as String?) ?? '';
    _form
      ..name = v('name')
      ..phone = v('phone')
      ..altPhone = v('altPhone')
      ..vehicleType = VehicleType.fromWire(d['vehicleType'] as String?)
      ..vehicleNumber = v('vehicleNumber')
      ..licenseNumber = v('licenseNumber')
      ..aadhaarNumber = v('aadhaarNumber')
      ..address = v('address')
      ..city = v('city')
      ..pincode = v('pincode')
      ..accountHolderName = v('accountHolderName')
      ..bankAccountNumber = v('bankAccountNumber')
      ..ifscCode = v('ifscCode')
      ..upiId = v('upiId');
    final paths = d['kycDocuments'] is Map ? d['kycDocuments'] as Map : const {};
    for (final doc in RiderDocument.values) {
      if (paths[doc.key] is String) {
        _onFile.add(doc);
        _service.uploaded.add(doc);
      }
    }
  }

  bool get _needsAccount => _service.backend.currentUid == null;

  Future<PickedPhoto?> _defaultPick(RiderDocument doc) async {
    final file = await ImagePicker().pickImage(
      source: doc == RiderDocument.selfie ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (file == null) return null;
    return (bytes: await file.readAsBytes(), contentType: file.mimeType ?? 'image/jpeg');
  }

  Future<void> _pick(RiderDocument doc) async {
    final photo = await (widget.pickPhoto ?? _defaultPick)(doc);
    if (photo == null || !mounted) return;
    setState(() {
      _photos[doc] = photo;
      _service.uploaded.remove(doc); // a new photo must be uploaded again
      _problems.remove('documents.${doc.key}');
    });
  }

  List<String> _problemsForStep(int step) {
    final all = [
      ...accountProblems(_form, needsAccount: _needsAccount),
      ...applicationProblems(_form),
      for (final d in RiderDocument.values)
        if (!_photos.containsKey(d) && !_onFile.contains(d)) 'documents.${d.key}',
    ];
    return all.where((k) => stepOfProblem(k) == step).toList();
  }

  void _next() {
    final problems = _problemsForStep(_step);
    setState(() {
      _problems = {..._problems.where((k) => stepOfProblem(k) != _step), ...problems};
      _failure = null;
    });
    if (problems.isNotEmpty) return;
    if (_step < 4) {
      setState(() => _step++);
    } else {
      _submit();
    }
  }

  Future<void> _submit() async {
    for (var s = _needsAccount ? 0 : 1; s <= 4; s++) {
      final p = _problemsForStep(s);
      if (p.isNotEmpty) {
        setState(() {
          _problems = p.toSet();
          _step = s;
        });
        return;
      }
    }
    setState(() {
      _submitting = true;
      _failure = null;
    });
    try {
      await _service.submitAll(_form, _photos);
      if (!mounted) return;
      final auth = context.read<DeliveryAuthProvider>();
      await auth.registrationSubmitted();
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    } on RegistrationException catch (e) {
      if (!mounted) return;
      setState(() {
        _failure = e.failure;
        _problems = e.problems.toSet();
        if (e.problems.isNotEmpty) _step = e.problems.map(stepOfProblem).reduce((a, b) => a < b ? a : b);
        if (e.failure == RegistrationFailure.documentsMissing) {
          _service.uploaded.clear();
          _onFile.clear();
        }
      });
    } catch (e) {
      debugPrint('Registration failed: $e');
      if (mounted) setState(() => _failure = RegistrationFailure.unknown);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _field(String key, String label, String initial, ValueChanged<String> onChanged,
      {TextInputType? keyboard, bool obscure = false, int maxLines = 1, TextCapitalization caps = TextCapitalization.none}) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: WsSpace.s12),
      child: TextFormField(
        key: ValueKey('field-$key'),
        initialValue: initial,
        keyboardType: keyboard,
        obscureText: obscure,
        maxLines: maxLines,
        textCapitalization: caps,
        onChanged: (v) {
          onChanged(v);
          if (_problems.contains(key)) setState(() => _problems.remove(key));
        },
        decoration: InputDecoration(
          labelText: label,
          errorMaxLines: 3,
          errorText: _problems.contains(key) ? fieldErrorText(l, key) : null,
        ),
      ),
    );
  }

  Widget _photoTile(RiderDocument doc, String label) {
    final l = AppLocalizations.of(context);
    final t = context.ws;
    final photo = _photos[doc];
    final onFile = _onFile.contains(doc) && photo == null;
    final missing = _problems.contains('documents.${doc.key}');
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        key: ValueKey('photo-${doc.key}'),
        onTap: _submitting ? null : () => _pick(doc),
        borderRadius: BorderRadius.circular(WsRadius.card),
        child: Container(
          width: WsSize.thumbLg + WsSize.thumbMd,
          padding: const EdgeInsets.all(WsSpace.s8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(WsRadius.card),
            border: Border.all(color: missing ? t.errorFg : t.inputBorder, width: WsSize.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: WsSize.thumbLg,
                width: double.infinity,
                child: photo == null
                    ? Icon(onFile ? AgIcons.success : AgIcons.camera,
                        color: onFile ? t.successFg : t.textTertiary, size: WsIconSize.feature)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(WsRadius.small),
                        child: Image.memory(photo.bytes, fit: BoxFit.cover),
                      ),
              ),
              const SizedBox(height: WsSpace.s4),
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              Text(
                missing ? l.docMissing : (photo == null && !onFile ? l.docAdd : l.docChange),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: missing ? t.errorFg : t.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.ws;
    final f = _form;
    final steps = <Step>[
      Step(
        title: Text(l.regStepAccount),
        isActive: _step == 0,
        state: _needsAccount ? StepState.indexed : StepState.complete,
        content: _needsAccount
            ? Column(children: [
                _field('email', l.fieldEmail, f.email, (v) => f.email = v, keyboard: TextInputType.emailAddress),
                _field('password', l.fieldPassword, f.password, (v) => f.password = v, obscure: true),
              ])
            : const SizedBox.shrink(),
      ),
      Step(
        title: Text(l.regStepAbout),
        isActive: _step == 1,
        content: Column(children: [
          _field('name', l.fieldName, f.name, (v) => f.name = v, caps: TextCapitalization.words),
          _field('phone', l.fieldPhone, f.phone, (v) => f.phone = v, keyboard: TextInputType.phone),
          _field('altPhone', l.fieldAltPhone, f.altPhone, (v) => f.altPhone = v, keyboard: TextInputType.phone),
          _field('address', l.fieldAddress, f.address, (v) => f.address = v, maxLines: 2),
          _field('city', l.fieldCity, f.city, (v) => f.city = v, caps: TextCapitalization.words),
          _field('pincode', l.fieldPincode, f.pincode, (v) => f.pincode = v, keyboard: TextInputType.number),
        ]),
      ),
      Step(
        title: Text(l.regStepVehicle),
        isActive: _step == 2,
        content: Column(children: [
          Padding(
            padding: const EdgeInsets.only(bottom: WsSpace.s12),
            child: DropdownButtonFormField<VehicleType>(
              key: const ValueKey('field-vehicleType'),
              initialValue: f.vehicleType,
              decoration: InputDecoration(labelText: l.fieldVehicleType),
              items: [
                for (final v in VehicleType.values) DropdownMenuItem(value: v, child: Text(vehicleLabel(l, v))),
              ],
              onChanged: (v) => setState(() => f.vehicleType = v ?? f.vehicleType),
            ),
          ),
          if (f.needsPlate)
            _field('vehicleNumber', l.fieldVehicleNumber, f.vehicleNumber, (v) => f.vehicleNumber = v,
                caps: TextCapitalization.characters),
          _field('licenseNumber', l.fieldLicenseNumber, f.licenseNumber, (v) => f.licenseNumber = v,
              caps: TextCapitalization.characters),
        ]),
      ),
      Step(
        title: Text(l.regStepDocuments),
        isActive: _step == 3,
        content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _field('aadhaarNumber', l.fieldAadhaarNumber, f.aadhaarNumber, (v) => f.aadhaarNumber = v,
              keyboard: TextInputType.number),
          Wrap(spacing: WsSpace.s8, runSpacing: WsSpace.s8, children: [
            _photoTile(RiderDocument.aadhaarFront, l.docAadhaarFront),
            _photoTile(RiderDocument.aadhaarBack, l.docAadhaarBack),
            _photoTile(RiderDocument.selfie, l.docSelfie),
            _photoTile(RiderDocument.license, l.docLicense),
          ]),
          const SizedBox(height: WsSpace.s8),
          Text(l.docsPrivacy, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textSecondary)),
        ]),
      ),
      Step(
        title: Text(l.regStepPayout),
        isActive: _step == 4,
        content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(bottom: WsSpace.s12),
            child: Text(l.payoutHint, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textSecondary)),
          ),
          _field('accountHolderName', l.fieldAccountHolder, f.accountHolderName, (v) => f.accountHolderName = v,
              caps: TextCapitalization.words),
          _field('bankAccountNumber', l.fieldAccountNumber, f.bankAccountNumber, (v) => f.bankAccountNumber = v,
              keyboard: TextInputType.number),
          _field('ifscCode', l.fieldIfsc, f.ifscCode, (v) => f.ifscCode = v, caps: TextCapitalization.characters),
          _field('upiId', l.fieldUpi, f.upiId, (v) => f.upiId = v, keyboard: TextInputType.emailAddress),
        ]),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l.regTitle)),
      body: Column(children: [
        if (!_needsAccount)
          Container(
            width: double.infinity,
            color: t.infoBg,
            padding: const EdgeInsets.symmetric(horizontal: WsSpace.page, vertical: WsSpace.s8),
            child: Text(widget.initial != null ? l.regResubmitNote : l.regResumeNote, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.infoFg)),
          ),
        if (_failure != null)
          Semantics(
            liveRegion: true,
            child: Container(
              key: const ValueKey('registration-failure'),
              width: double.infinity,
              color: t.errorBg,
              padding: const EdgeInsets.symmetric(horizontal: WsSpace.page, vertical: WsSpace.s12),
              child: Text(registrationFailureText(l, _failure!),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: t.errorFg)),
            ),
          ),
        Expanded(
          child: Stepper(
            currentStep: _step,
            onStepTapped: _submitting ? null : (s) => setState(() => _step = (s == 0 && !_needsAccount) ? 1 : s),
            onStepContinue: _submitting ? null : _next,
            onStepCancel: _submitting || _step <= (_needsAccount ? 0 : 1) ? null : () => setState(() => _step--),
            controlsBuilder: (context, details) => Padding(
              padding: const EdgeInsets.only(top: WsSpace.s8),
              // Workspace buttons are full-width: stacked, never in a Row.
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                FilledButton(
                  key: ValueKey('registration-continue-${details.stepIndex}'),
                  onPressed: details.onStepContinue,
                  child: Text(_step == 4 ? (_submitting ? l.regSubmitting : l.regSubmit) : l.regNext),
                ),
                if (details.onStepCancel != null)
                  TextButton(onPressed: details.onStepCancel, child: Text(l.regBack)),
              ]),
            ),
            steps: steps,
          ),
        ),
      ]),
    );
  }
}
