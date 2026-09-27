// lib/screens/auth/rider_registration_screen.dart
//
// Phase DLV-A1 / Phase 16 — rider registration on the server-owned contract
// (registration/rider_application.dart → submitRiderApplication).
// The form keeps everything typed across steps and failures; a resumed
// registration (signed in, no rider record yet) skips the account step.
import 'dart:async';
import 'dart:io';

import 'package:agrimore_core/agrimore_core.dart' show VehicleType;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../registration/registration_draft.dart';
import '../../registration/rider_application.dart';

String registrationFailureText(AppLocalizations l, RegistrationFailure f) =>
    switch (f) {
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
  const RiderRegistrationScreen({
    super.key,
    this.service,
    this.pickPhoto,
    this.initial,
    this.draftStore,
    this.resolveDraftPhoto,
    this.deleteStagedFile,
  });

  /// DLV-A2: the rider's existing delivery_partners record, when a pending or
  /// rejected rider corrects and resubmits (null for a new registration).
  final Map<String, dynamic>? initial;

  /// Injected in tests.
  final RegistrationService? service;
  final Future<PickedPhoto?> Function(RiderDocument doc)? pickPhoto;

  /// DLVID4: injected in tests; defaults to on-device secure storage.
  final RegistrationDraftStore? draftStore;

  /// DLVID4: reads a photo staged by an earlier attempt back into memory, or
  /// null if it's gone -- injected in tests so they never touch real disk
  /// I/O (flutter_test's fake-async zone can stall a real dart:io read
  /// triggered from inside a post-frame callback's continuation).
  final Future<PickedPhoto?> Function(DraftPhoto stored)? resolveDraftPhoto;

  /// DLVID5: deletes one staged-photo cache file by path, on the same
  /// real-disk-I/O-must-be-injectable basis as [resolveDraftPhoto] above.
  final Future<void> Function(String path)? deleteStagedFile;

  @override
  State<RiderRegistrationScreen> createState() =>
      _RiderRegistrationScreenState();
}

/// DLVID5: a draft older than this is never silently offered -- picked
/// deliberately generous (a rider who stepped away for a few days should
/// still get their progress back) while still bounding how long a stale,
/// possibly-another-person's draft can sit around looking resumable. A pure
/// constant/function so it's directly unit-testable and tunable without
/// touching any call site.
const registrationDraftMaxAge = Duration(days: 14);

bool isDraftExpired(DateTime savedAt, {DateTime? now}) =>
    (now ?? DateTime.now()).difference(savedAt) > registrationDraftMaxAge;

class _RiderRegistrationScreenState extends State<RiderRegistrationScreen>
    with WidgetsBindingObserver {
  late final RegistrationService _service =
      widget.service ?? RegistrationService();
  late final RegistrationDraftStore _draftStore =
      widget.draftStore ?? SecureRegistrationDraftStore();
  late final Future<PickedPhoto?> Function(DraftPhoto) _resolveDraftPhoto =
      widget.resolveDraftPhoto ?? _defaultResolveDraftPhoto;
  late final Future<void> Function(String) _deleteStagedFile =
      widget.deleteStagedFile ?? _defaultDeleteStagedFile;
  final RiderApplicationForm _form = RiderApplicationForm();
  final Map<RiderDocument, PickedPhoto> _photos = {};
  final Map<RiderDocument, String> _photoPaths = {};
  final Set<RiderDocument> _missingDraftPhotos = {};
  Set<String> _problems = {};
  RegistrationFailure? _failure;
  bool _submitting = false;
  bool _draftChecked = false;
  int _formGeneration = 0;
  late int _step = _needsAccount ? 0 : 1;

  /// Photos already on file at their fixed paths (a resubmission); an older
  /// URL-only record's photos must be added again.
  final Set<RiderDocument> _onFile = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final d = widget.initial;
    if (d != null) {
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
      return;
    }
    // DLVID4: a resubmission (above) resumes from the server's own record,
    // which is authoritative -- a local draft is only offered for a fresh
    // registration, where nothing server-side exists yet.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForDraft());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // DLVID5: backgrounding is the one moment current-step edits (not yet
    // committed by a step-advance, a photo pick, or a submit attempt) would
    // otherwise be lost to a process kill -- save proactively rather than
    // waiting for a save point that may never come.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      unawaited(_saveDraft());
    }
  }

  bool get _needsAccount => _service.backend.currentUid == null;

  String get _draftKey => _service.backend.currentUid ?? '_pending';

  /// DLVID5: ONLY the current identity's own slot -- a signed-in rider's own
  /// uid, or the shared pre-account `_pending` slot when nobody is signed in
  /// yet. Never falls back from one to the other: that used to let a
  /// completely unrelated signed-in rider silently inherit a stranger's
  /// abandoned pre-account draft on a shared device. The one legitimate
  /// reason a fallback existed -- a crash between account creation and the
  /// next incidental save -- is now closed at the source: `_submit()`
  /// re-keys the draft to the new uid the instant the account exists, before
  /// any upload/submit step that could crash.
  Future<RegistrationDraft?> _loadResumableDraft() => _draftStore.load(_draftKey);

  Future<void> _checkForDraft() async {
    if (_draftChecked || !mounted) return;
    _draftChecked = true;
    final draft = await _loadResumableDraft();
    if (draft == null || !mounted) return;
    if (isDraftExpired(draft.savedAt)) {
      await _clearDraft();
      return;
    }
    final l = AppLocalizations.of(context);
    final resume = await showDeliveryConfirmDialog(
      context: context,
      title: l.regDraftFoundTitle,
      body: l.regDraftFoundBody,
      confirmLabel: l.regDraftResume,
      cancelLabel: l.regDraftStartOver,
    );
    if (!mounted) return;
    if (resume) {
      await _applyDraft(draft);
    } else {
      await _clearDraft();
    }
  }

  Future<void> _applyDraft(RegistrationDraft draft) async {
    final photos = <RiderDocument, PickedPhoto>{};
    final paths = <RiderDocument, String>{};
    final missing = <RiderDocument>{};
    for (final entry in draft.photos.entries) {
      final resolved = await _resolveDraftPhoto(entry.value);
      if (resolved != null) {
        photos[entry.key] = resolved;
        paths[entry.key] = entry.value.path;
      } else {
        missing.add(entry.key);
      }
    }
    if (!mounted) return;
    final minStep = _needsAccount ? 0 : 1;
    final step = draft.step < minStep ? minStep : (draft.step > 4 ? 4 : draft.step);
    setState(() {
      _form
        ..email = draft.form.email
        ..name = draft.form.name
        ..phone = draft.form.phone
        ..altPhone = draft.form.altPhone
        ..vehicleType = draft.form.vehicleType
        ..vehicleNumber = draft.form.vehicleNumber
        ..licenseNumber = draft.form.licenseNumber
        ..aadhaarNumber = draft.form.aadhaarNumber
        ..address = draft.form.address
        ..city = draft.form.city
        ..pincode = draft.form.pincode
        ..accountHolderName = draft.form.accountHolderName
        ..bankAccountNumber = draft.form.bankAccountNumber
        ..ifscCode = draft.form.ifscCode
        ..upiId = draft.form.upiId;
      _photos.addAll(photos);
      _photoPaths.addAll(paths);
      _missingDraftPhotos
        ..clear()
        ..addAll(missing);
      _step = step;
      _formGeneration++; // force every TextFormField to remount with the restored value
    });
  }

  Future<void> _clearDraft() async {
    await _draftStore.clear(_draftKey);
    await _draftStore.clear('_pending');
    await _deleteStagedPhotoFiles();
  }

  /// DLVID5: the picked-photo cache files a draft's paths point at are this
  /// app's own private, otherwise-unreferenced copies -- once the draft they
  /// belong to is gone (discarded, or successfully submitted), delete them
  /// too rather than leaving Aadhaar/selfie images sitting in cache
  /// indefinitely.
  Future<void> _deleteStagedPhotoFiles() async {
    for (final path in _photoPaths.values) {
      await _deleteStagedFile(path);
    }
  }

  /// Best-effort: a file already gone, or a path that was never real, is not
  /// an error.
  Future<void> _defaultDeleteStagedFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // best-effort cleanup only
    }
  }

  Future<void> _saveDraft() async {
    final key = _draftKey;
    await _draftStore.save(
      key,
      RegistrationDraft(
        step: _step,
        form: _form,
        photos: {
          for (final e in _photoPaths.entries)
            if (_photos.containsKey(e.key))
              e.key: DraftPhoto(path: e.value, contentType: _photos[e.key]!.contentType),
        },
        savedAt: DateTime.now(),
      ),
    );
    // Promote: once the account exists, the pre-account slot is stale.
    if (key != '_pending') await _draftStore.clear('_pending');
  }

  Future<void> _confirmStartOver() async {
    final l = AppLocalizations.of(context);
    final discard = await showDeliveryConfirmDialog(
      context: context,
      title: l.regDraftDiscardTitle,
      body: l.regDraftDiscardBody,
      confirmLabel: l.regDraftStartOver,
      destructive: true,
    );
    if (!discard || !mounted) return;
    await _clearDraft();
    if (!mounted) return;
    setState(() {
      _form
        ..email = ''
        ..password = ''
        ..name = ''
        ..phone = ''
        ..altPhone = ''
        ..vehicleType = VehicleType.bike
        ..vehicleNumber = ''
        ..licenseNumber = ''
        ..aadhaarNumber = ''
        ..address = ''
        ..city = ''
        ..pincode = ''
        ..accountHolderName = ''
        ..bankAccountNumber = ''
        ..ifscCode = ''
        ..upiId = '';
      _photos.clear();
      _photoPaths.clear();
      _missingDraftPhotos.clear();
      _onFile.clear();
      _problems = {};
      _failure = null;
      _step = _needsAccount ? 0 : 1;
      _formGeneration++;
    });
  }

  bool get _hasDraftableInput =>
      _form.name.isNotEmpty ||
      _form.phone.isNotEmpty ||
      _form.address.isNotEmpty ||
      _photos.isNotEmpty ||
      _step > (_needsAccount ? 0 : 1);

  Future<PickedPhoto?> _defaultResolveDraftPhoto(DraftPhoto stored) async {
    final file = File(stored.path);
    if (!await file.exists()) return null;
    return (
      bytes: await file.readAsBytes(),
      contentType: stored.contentType,
      path: stored.path,
    );
  }

  Future<PickedPhoto?> _defaultPick(RiderDocument doc) async {
    final file = await ImagePicker().pickImage(
      source:
          doc == RiderDocument.selfie ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (file == null) return null;
    return (
      bytes: await file.readAsBytes(),
      contentType: file.mimeType ?? 'image/jpeg',
      path: file.path,
    );
  }

  Future<void> _pick(RiderDocument doc) async {
    final photo = await (widget.pickPhoto ?? _defaultPick)(doc);
    if (photo == null || !mounted) return;
    setState(() {
      _photos[doc] = photo;
      if (photo.path != null) {
        _photoPaths[doc] = photo.path!;
      } else {
        _photoPaths.remove(doc);
      }
      _missingDraftPhotos.remove(doc);
      _service.uploaded.remove(doc); // a new photo must be uploaded again
      _problems.remove('documents.${doc.key}');
    });
    unawaited(_saveDraft());
  }

  List<String> _problemsForStep(int step) {
    final all = [
      ...accountProblems(_form, needsAccount: _needsAccount),
      ...applicationProblems(_form),
      for (final d in RiderDocument.values)
        if (!_photos.containsKey(d) && !_onFile.contains(d))
          'documents.${d.key}',
    ];
    return all.where((k) => stepOfProblem(k) == step).toList();
  }

  void _next() {
    final problems = _problemsForStep(_step);
    setState(() {
      _problems = {
        ..._problems.where((k) => stepOfProblem(k) != _step),
        ...problems,
      };
      _failure = null;
    });
    if (problems.isNotEmpty) return;
    if (_step < 4) {
      setState(() => _step++);
      unawaited(_saveDraft());
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
    // A snapshot taken right before the risky calls, matching every other
    // step-advance save point.
    await _saveDraft();
    try {
      // DLVID5: create (or reuse) the account FIRST, then immediately re-key
      // this device's own draft under the account's own uid -- before any
      // upload or submit step that could crash. A process kill from here on
      // leaves the draft already correctly owned, so `_loadResumableDraft`
      // never needs (and no longer has) a cross-key fallback to find it.
      await _service.ensureAccount(_form);
      await _saveDraft();
      await _service.submitAll(_form, _photos);
      if (!mounted) return;
      await _clearDraft();
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
        if (e.problems.isNotEmpty) {
          _step = e.problems.map(stepOfProblem).reduce((a, b) => a < b ? a : b);
        }
        if (e.failure == RegistrationFailure.documentsMissing) {
          final missingDocs = e.problems
              .where((p) => p.startsWith('documents.'))
              .map((p) => p.substring('documents.'.length))
              .toSet();
          if (missingDocs.isEmpty) {
            // submitAll()'s own client-side check throws with no problem
            // keys when a doc is simply absent from _photos -- we can't tell
            // which one was meant, so fall back to the previous behaviour.
            _service.uploaded.clear();
            _onFile.clear();
          } else {
            // The server named specific documents: only those need
            // re-uploading, so a rider never has to re-pick photos that
            // already succeeded.
            for (final doc in RiderDocument.values) {
              if (missingDocs.contains(doc.key)) {
                _service.uploaded.remove(doc);
                _onFile.remove(doc);
              }
            }
          }
        }
      });
      unawaited(_saveDraft());
    } catch (e) {
      debugPrint('Registration failed: $e');
      if (mounted) setState(() => _failure = RegistrationFailure.unknown);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _field(
    String key,
    String label,
    String initial,
    ValueChanged<String> onChanged, {
    TextInputType? keyboard,
    bool obscure = false,
    int maxLines = 1,
    TextCapitalization caps = TextCapitalization.none,
  }) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: DeliverySpace.md),
      child: TextFormField(
        key: ValueKey('field-$key'),
        initialValue: initial,
        keyboardType: keyboard,
        obscureText: obscure,
        maxLines: maxLines,
        textCapitalization: caps,
        onChanged: (v) {
          // DLVID4: always rebuilds (not just when clearing a problem) so
          // _hasDraftableInput -- and the "Start over" action it gates --
          // stays live as the rider types, not just after a step change.
          setState(() {
            onChanged(v);
            _problems.remove(key);
          });
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
    final c = context.colors;
    final t = context.text;
    final photo = _photos[doc];
    final onFile = _onFile.contains(doc) && photo == null;
    final missing = _problems.contains('documents.${doc.key}');
    // DLVID4: a resumed draft whose stored file no longer exists on disk --
    // distinct from "never picked" (grey) and "done" (green): the rider
    // previously picked this, but it can't be silently reused.
    final needsReselect = photo == null && _missingDraftPhotos.contains(doc);
    return Semantics(
      button: true,
      child: InkWell(
        key: ValueKey('photo-${doc.key}'),
        onTap: _submitting ? null : () => _pick(doc),
        borderRadius: DeliveryRadius.rMd,
        child: Container(
          width: DeliverySize.thumbLg + DeliverySize.thumbMd,
          padding: const EdgeInsets.all(DeliverySpace.sm),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: DeliveryRadius.rMd,
            border: Border.all(
              color: missing
                  ? c.danger.border
                  : (needsReselect ? c.warning.border : c.borderStrong),
              width: missing || needsReselect
                  ? DeliverySize.outline
                  : DeliverySize.hairline,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: DeliverySize.thumbLg,
                width: double.infinity,
                child: photo == null
                    ? Container(
                        decoration: BoxDecoration(
                          color: onFile
                              ? c.success.container
                              : (needsReselect
                                  ? c.warning.container
                                  : c.surfaceVariant),
                          borderRadius: DeliveryRadius.rSm,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          onFile
                              ? DeliveryIcons.checkCircle
                              : (needsReselect
                                  ? DeliveryIcons.warning
                                  : DeliveryIcons.camera),
                          color: onFile
                              ? c.success.icon
                              : (needsReselect ? c.warning.icon : c.textTertiary),
                          size: DeliveryIconSize.xl,
                        ),
                      )
                    : ClipRRect(
                        borderRadius: DeliveryRadius.rSm,
                        child: Image.memory(photo.bytes, fit: BoxFit.cover),
                      ),
              ),
              const SizedBox(height: DeliverySpace.xxs),
              Text(
                label,
                style: t.labelMedium.copyWith(color: c.textPrimary),
              ),
              Text(
                missing
                    ? l.docMissing
                    : (needsReselect
                        ? l.regDraftPhotoMissing
                        : (photo == null && !onFile ? l.docAdd : l.docChange)),
                style: t.bodySmall.copyWith(
                  color: missing
                      ? c.danger.text
                      : (needsReselect ? c.warning.text : c.brand),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  DeliveryVehicleKind _kindOf(VehicleType v) => switch (v) {
        VehicleType.bicycle => DeliveryVehicleKind.bicycle,
        VehicleType.bike => DeliveryVehicleKind.motorcycle,
        VehicleType.scooter => DeliveryVehicleKind.scooter,
        VehicleType.ev => DeliveryVehicleKind.evTwoWheeler,
        VehicleType.threeWheeler => DeliveryVehicleKind.autoThreeWheeler,
        VehicleType.car || VehicleType.van => DeliveryVehicleKind.miniTruck,
      };

  VehicleType _typeOf(DeliveryVehicleKind k) => switch (k) {
        DeliveryVehicleKind.bicycle => VehicleType.bicycle,
        DeliveryVehicleKind.motorcycle => VehicleType.bike,
        DeliveryVehicleKind.scooter => VehicleType.scooter,
        DeliveryVehicleKind.evTwoWheeler => VehicleType.ev,
        DeliveryVehicleKind.autoThreeWheeler => VehicleType.threeWheeler,
        DeliveryVehicleKind.miniTruck => VehicleType.van,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final t = context.text;
    final f = _form;

    final steps = <Step>[
      Step(
        title: Text(l.regStepAccount),
        isActive: _step == 0,
        state: _needsAccount ? StepState.indexed : StepState.complete,
        content: _needsAccount
            ? Column(
                children: [
                  _field(
                    'email',
                    l.fieldEmail,
                    f.email,
                    (v) => f.email = v,
                    keyboard: TextInputType.emailAddress,
                  ),
                  _field(
                    'password',
                    l.fieldPassword,
                    f.password,
                    (v) => f.password = v,
                    obscure: true,
                  ),
                ],
              )
            : const SizedBox.shrink(),
      ),
      Step(
        title: Text(l.regStepAbout),
        isActive: _step == 1,
        content: Column(
          children: [
            _field(
              'name',
              l.fieldName,
              f.name,
              (v) => f.name = v,
              caps: TextCapitalization.words,
            ),
            _field(
              'phone',
              l.fieldPhone,
              f.phone,
              (v) => f.phone = v,
              keyboard: TextInputType.phone,
            ),
            _field(
              'altPhone',
              l.fieldAltPhone,
              f.altPhone,
              (v) => f.altPhone = v,
              keyboard: TextInputType.phone,
            ),
            _field(
              'address',
              l.fieldAddress,
              f.address,
              (v) => f.address = v,
              maxLines: 2,
            ),
            _field(
              'city',
              l.fieldCity,
              f.city,
              (v) => f.city = v,
              caps: TextCapitalization.words,
            ),
            _field(
              'pincode',
              l.fieldPincode,
              f.pincode,
              (v) => f.pincode = v,
              keyboard: TextInputType.number,
            ),
          ],
        ),
      ),
      Step(
        title: Text(l.regStepVehicle),
        isActive: _step == 2,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DeliveryVehicleSelector(
              selected: _kindOf(f.vehicleType),
              onSelected: (k) => setState(() => f.vehicleType = _typeOf(k)),
              options: [
                DeliveryVehicleOption(
                  kind: DeliveryVehicleKind.bicycle,
                  label: l.vehicleBicycle,
                  subtitle: l.vehicleBicycleSub,
                ),
                DeliveryVehicleOption(
                  kind: DeliveryVehicleKind.motorcycle,
                  label: l.vehicleBike,
                  subtitle: l.vehicleMotorcycleSub,
                ),
                DeliveryVehicleOption(
                  kind: DeliveryVehicleKind.scooter,
                  label: l.vehicleScooter,
                  subtitle: l.vehicleScooterSub,
                ),
                DeliveryVehicleOption(
                  kind: DeliveryVehicleKind.evTwoWheeler,
                  label: l.vehicleEv,
                  subtitle: l.vehicleEvSub,
                ),
                DeliveryVehicleOption(
                  kind: DeliveryVehicleKind.autoThreeWheeler,
                  label: l.vehicleThreeWheeler,
                  subtitle: l.vehicleAutoSub,
                ),
                DeliveryVehicleOption(
                  kind: DeliveryVehicleKind.miniTruck,
                  label: l.vehicleVan,
                  subtitle: l.vehicleMiniTruckSub,
                ),
              ],
            ),
            const SizedBox(height: DeliverySpace.md),
            Padding(
              padding: const EdgeInsets.only(bottom: DeliverySpace.md),
              child: DropdownButtonFormField<VehicleType>(
                key: const ValueKey('field-vehicleType'),
                initialValue: f.vehicleType,
                decoration: InputDecoration(labelText: l.fieldVehicleType),
                items: [
                  for (final v in VehicleType.values)
                    DropdownMenuItem(value: v, child: Text(vehicleLabel(l, v))),
                ],
                onChanged: (v) =>
                    setState(() => f.vehicleType = v ?? f.vehicleType),
              ),
            ),
            if (f.needsPlate)
              _field(
                'vehicleNumber',
                l.fieldVehicleNumber,
                f.vehicleNumber,
                (v) => f.vehicleNumber = v,
                caps: TextCapitalization.characters,
              ),
            _field(
              'licenseNumber',
              l.fieldLicenseNumber,
              f.licenseNumber,
              (v) => f.licenseNumber = v,
              caps: TextCapitalization.characters,
            ),
          ],
        ),
      ),
      Step(
        title: Text(l.regStepDocuments),
        isActive: _step == 3,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field(
              'aadhaarNumber',
              l.fieldAadhaarNumber,
              f.aadhaarNumber,
              (v) => f.aadhaarNumber = v,
              keyboard: TextInputType.number,
            ),
            Wrap(
              spacing: DeliverySpace.sm,
              runSpacing: DeliverySpace.sm,
              children: [
                _photoTile(RiderDocument.aadhaarFront, l.docAadhaarFront),
                _photoTile(RiderDocument.aadhaarBack, l.docAadhaarBack),
                _photoTile(RiderDocument.selfie, l.docSelfie),
                _photoTile(RiderDocument.license, l.docLicense),
              ],
            ),
            const SizedBox(height: DeliverySpace.sm),
            Text(
              l.docsPrivacy,
              style: t.bodySmall.copyWith(color: c.textSecondary),
            ),
          ],
        ),
      ),
      Step(
        title: Text(l.regStepPayout),
        isActive: _step == 4,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: DeliverySpace.md),
              child: Text(
                l.payoutHint,
                style: t.bodySmall.copyWith(color: c.textSecondary),
              ),
            ),
            _field(
              'accountHolderName',
              l.fieldAccountHolder,
              f.accountHolderName,
              (v) => f.accountHolderName = v,
              caps: TextCapitalization.words,
            ),
            _field(
              'bankAccountNumber',
              l.fieldAccountNumber,
              f.bankAccountNumber,
              (v) => f.bankAccountNumber = v,
              keyboard: TextInputType.number,
            ),
            _field(
              'ifscCode',
              l.fieldIfsc,
              f.ifscCode,
              (v) => f.ifscCode = v,
              caps: TextCapitalization.characters,
            ),
            _field(
              'upiId',
              l.fieldUpi,
              f.upiId,
              (v) => f.upiId = v,
              keyboard: TextInputType.emailAddress,
            ),
          ],
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: Text(l.regTitle),
        actions: [
          if (widget.initial == null && _hasDraftableInput)
            TextButton(
              onPressed: _submitting ? null : _confirmStartOver,
              child: Text(l.regStartOverAction),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DeliverySpace.page,
              vertical: DeliverySpace.sm,
            ),
            child: DeliveryStepIndicator(
              currentStep: _step,
              labels: [
                l.regStepAccount,
                l.regStepAbout,
                l.regStepVehicle,
                l.regStepDocuments,
                l.regStepPayout,
              ],
            ),
          ),
          if (!_needsAccount)
            Container(
              width: double.infinity,
              color: c.info.container,
              padding: const EdgeInsets.symmetric(
                horizontal: DeliverySpace.page,
                vertical: DeliverySpace.sm,
              ),
              child: Text(
                widget.initial != null ? l.regResubmitNote : l.regResumeNote,
                style: t.bodySmall.copyWith(color: c.info.text),
              ),
            ),
          if (_failure != null)
            Semantics(
              liveRegion: true,
              child: Container(
                key: const ValueKey('registration-failure'),
                width: double.infinity,
                color: c.danger.container,
                padding: const EdgeInsets.symmetric(
                  horizontal: DeliverySpace.page,
                  vertical: DeliverySpace.md,
                ),
                child: Text(
                  registrationFailureText(l, _failure!),
                  style: t.bodyMedium.copyWith(color: c.danger.text),
                ),
              ),
            ),
          Expanded(
            child: Stepper(
              // DLVID4: keying the whole Stepper by generation forces every
              // field beneath it (including each TextFormField, which only
              // reads `initialValue` on its first build) to be discarded and
              // rebuilt fresh when a loaded draft changes _form after this
              // subtree's first build -- without changing any field's own
              // ValueKey, which existing tests locate by exact string.
              key: ValueKey('registration-stepper-$_formGeneration'),
              currentStep: _step,
              onStepTapped: _submitting
                  ? null
                  : (s) => setState(
                        () => _step = (s == 0 && !_needsAccount) ? 1 : s,
                      ),
              onStepContinue: _submitting ? null : _next,
              onStepCancel: _submitting || _step <= (_needsAccount ? 0 : 1)
                  ? null
                  : () => setState(() => _step--),
              controlsBuilder: (context, details) => Padding(
                padding: const EdgeInsets.only(top: DeliverySpace.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DeliveryButton.primary(
                      key: ValueKey(
                        'registration-continue-${details.stepIndex}',
                      ),
                      label: _step == 4
                          ? (_submitting ? l.regSubmitting : l.regSubmit)
                          : l.regNext,
                      isLoading: _submitting && _step == 4,
                      onPressed: details.onStepContinue,
                    ),
                    if (details.onStepCancel != null) ...[
                      const SizedBox(height: DeliverySpace.xs),
                      DeliveryButton.ghost(
                        label: l.regBack,
                        onPressed: details.onStepCancel,
                      ),
                    ],
                  ],
                ),
              ),
              steps: steps,
            ),
          ),
        ],
      ),
    );
  }
}
