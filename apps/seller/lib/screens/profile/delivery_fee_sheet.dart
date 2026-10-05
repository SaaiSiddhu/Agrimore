import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import 'delivery_fee_validation.dart';

// Phase FIX-8B — seller-side config for functions/src/customer/
// deliveryFeeSchedule.ts (Phase FIX-8, WS1a, already merged and E2E_DEVELOP).
// Server-side schedule validation remains authoritative. The seller UI
// mirrors its safe money bounds and requires a configured shop location for
// distance pricing; customer route and final fee are calculated on server.
/// Opens the delivery fee screen (board 22-06): flat, order-value, or road-distance pricing,
/// written to sellers/{uid}.deliveryFeeSchedule. Calls [onSaved]
/// after a successful write.
void showDeliveryFeeSheet(
  BuildContext context, {
  required String uid,
  required Map<String, dynamic>? initialSchedule,
  required bool hasShopLocation,
  required int deliveryRadiusKm,
  required VoidCallback onSaved,
}) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => DeliveryFeeScreen(uid: uid, initialSchedule: initialSchedule, hasShopLocation: hasShopLocation, deliveryRadiusKm: deliveryRadiusKm, onSaved: onSaved),
  ));
}

class _SlabRow {
  final TextEditingController minOrderValue;
  final TextEditingController fee;
  _SlabRow({String minOrderValue = '', String fee = ''})
      : minOrderValue = TextEditingController(text: minOrderValue),
        fee = TextEditingController(text: fee);

  void dispose() {
    minOrderValue.dispose();
    fee.dispose();
  }
}

class DeliveryFeeScreen extends StatefulWidget {
  const DeliveryFeeScreen({super.key, required this.uid, required this.initialSchedule, required this.hasShopLocation, required this.deliveryRadiusKm, required this.onSaved, this.save});

  final String uid;
  final Map<String, dynamic>? initialSchedule;
  final bool hasShopLocation;
  final int deliveryRadiusKm;
  final VoidCallback onSaved;

  /// Replaces the Firestore write in tests.
  final Future<void> Function(Map<String, dynamic> schedule)? save;

  @override
  State<DeliveryFeeScreen> createState() => _DeliveryFeeScreenState();
}

class _DeliveryFeeScreenState extends State<DeliveryFeeScreen> {
  late String _feeType;
  late TextEditingController _flatAmount;
  late TextEditingController _distanceBase;
  late TextEditingController _distanceRate;
  final List<_SlabRow> _slabs = [];
  late bool _hasShopLocation;
  bool _saving = false;
  bool _settingLocation = false;
  bool _dirty = false;

  /// Shown inline (validation or save failure).
  String? _error;

  String _num(Object? v) {
    if (v is num) return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
    return v?.toString() ?? '';
  }

  @override
  void initState() {
    super.initState();
    final raw = widget.initialSchedule;
    final scheduleType = raw?['type'];
    _feeType = scheduleType == 'slab' || scheduleType == 'distance' ? scheduleType as String : 'flat';
    _hasShopLocation = widget.hasShopLocation;
    _flatAmount = TextEditingController(text: scheduleType == 'flat' ? _num(raw?['amount']) : '');
    _distanceBase = TextEditingController(text: scheduleType == 'distance' && raw?['baseFeePaise'] is num ? ((raw!['baseFeePaise'] as num) / 100).toStringAsFixed(2) : '');
    _distanceRate = TextEditingController(text: scheduleType == 'distance' && raw?['ratePerKmPaise'] is num ? ((raw!['ratePerKmPaise'] as num) / 100).toStringAsFixed(2) : '');
    if (_feeType == 'slab') {
      final rawSlabs = raw?['slabs'];
      if (rawSlabs is List) {
        for (final s in rawSlabs) {
          if (s is Map) _slabs.add(_SlabRow(minOrderValue: _num(s['minOrderValue']), fee: _num(s['fee'])));
        }
      }
    }
    // A fresh tier schedule starts with the required ₹0 tier pre-filled.
    if (_slabs.isEmpty) _slabs.add(_SlabRow(minOrderValue: '0'));
    _flatAmount.addListener(_touch);
    _distanceBase.addListener(_touch);
    _distanceRate.addListener(_touch);
    for (final s in _slabs) {
      s.minOrderValue.addListener(_touch);
      s.fee.addListener(_touch);
    }
  }

  void _touch() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    _flatAmount.dispose();
    _distanceBase.dispose();
    _distanceRate.dispose();
    for (final s in _slabs) {
      s.dispose();
    }
    super.dispose();
  }

  FeeError? _validate() {
    if (_feeType == 'flat') return validateFlatFee(double.tryParse(_flatAmount.text.trim()));
    if (_feeType == 'distance') {
      if (!_hasShopLocation || widget.deliveryRadiusKm < 1 || widget.deliveryRadiusKm > 100) return FeeError.noLocation;
      return validateDistanceFee(baseRupees: double.tryParse(_distanceBase.text.trim()), rateRupeesPerKm: double.tryParse(_distanceRate.text.trim()));
    }
    return validateSlabSchedule([
      for (final slab in _slabs)
        (minOrderValue: double.tryParse(slab.minOrderValue.text.trim()), fee: double.tryParse(slab.fee.text.trim())),
    ]);
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final error = _validate();
    setState(() => _error = error == null ? null : feeErrorText(l10n, error, SellerFormat.moneyWhole(kMaxFeeRupees)));
    if (error != null) return;
    setState(() => _saving = true);
    try {
      final Map<String, dynamic> schedule = _feeType == 'slab'
          ? {
              'type': 'slab',
              'slabs': [
                for (final s in _slabs)
                  {'minOrderValue': double.parse(s.minOrderValue.text.trim()), 'fee': double.parse(s.fee.text.trim())},
              ],
            }
          : _feeType == 'distance'
              ? {
                  'type': 'distance',
                  'baseFeePaise': (double.parse(_distanceBase.text.trim()) * 100).round(),
                  'ratePerKmPaise': (double.parse(_distanceRate.text.trim()) * 100).round(),
                }
              : {'type': 'flat', 'amount': double.parse(_flatAmount.text.trim())};
      if (widget.save != null) {
        await widget.save!(schedule);
      } else {
        await FirebaseFirestore.instance.collection('sellers').doc(widget.uid).set({
          'deliveryFeeSchedule': schedule,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      if (!mounted) return;
      _dirty = false;
      SellerToast.show(context, l10n.feeSaved, tone: SellerToastTone.success);
      widget.onSaved();
      Navigator.of(context).pop();
    } catch (e) {
      // Never render e.toString() — the detail is logged, never shown.
      debugPrint('Error saving delivery fee schedule: $e');
      if (mounted) setState(() => _error = l10n.feeSaveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setShopLocation() async {
    setState(() => _settingLocation = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) throw StateError('location permission denied');
      final position = await Geolocator.getCurrentPosition();
      await FirebaseFirestore.instance.collection('sellers').doc(widget.uid).set({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      setState(() { _hasShopLocation = true; _dirty = true; });
      SellerToast.show(context, AppLocalizations.of(context).feeLocationSaved, tone: SellerToastTone.success);
      widget.onSaved();
    } catch (_) {
      if (mounted) setState(() => _error = AppLocalizations.of(context).feeLocationFailed);
    } finally {
      if (mounted) setState(() => _settingLocation = false);
    }
  }

  void _addSlab() {
    if (_slabs.length >= kMaxSlabs) return;
    final row = _SlabRow()
      ..minOrderValue.addListener(_touch)
      ..fee.addListener(_touch);
    setState(() {
      _slabs.add(row);
      _dirty = true;
    });
  }

  void _removeSlab(int index) {
    if (_slabs.length <= 1) return;
    setState(() {
      _slabs[index].dispose();
      _slabs.removeAt(index);
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final text = context.text;
    return SellerDiscardGuard(
      hasChanges: _dirty && !_saving,
      child: Scaffold(
        appBar: SellerAppBar.detail(context, title: l10n.accountDeliveryFee),
        body: SellerPage(
          gap: SellerSpace.s16,
          footer: SellerButton(label: l10n.accountSave, expand: true, loading: _saving, loadingLabel: l10n.saving, onPressed: _save),
          children: [
            Text(l10n.feeIntro, style: text.bodyLarge),
            SellerSegmented<String>(
              semanticLabel: l10n.accountDeliveryFee,
              segments: [SellerSegment('flat', l10n.feeFlat), SellerSegment('slab', l10n.feeSlab), SellerSegment('distance', l10n.feeDistance)],
              selected: _feeType,
              onChanged: (v) => setState(() {
                _feeType = v;
                _dirty = true;
                _error = null;
              }),
            ),
            if (_feeType == 'flat')
              SellerCard(
                child: SellerTextField(
                  fieldKey: const ValueKey('feeFlat'),
                  label: l10n.feeAmount,
                  controller: _flatAmount,
                  prefixText: SellerFormat.rupeeSymbol,
                  tabular: true,
                  helper: l10n.feeFlatHelp,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              )
            else if (_feeType == 'slab')
              SellerCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(child: Text(l10n.feeMinOrder, style: text.labelLarge)),
                    const SizedBox(width: SellerSpace.s12),
                    Expanded(child: Text(l10n.feeSlabFee, style: text.labelLarge)),
                    const SizedBox(width: SellerSize.touchTarget),
                  ]),
                  const SizedBox(height: SellerSpace.s8),
                  for (var i = 0; i < _slabs.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: SellerSpace.s8),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(
                          child: Semantics(
                            label: l10n.feeMinOrder,
                            child: TextField(
                              controller: _slabs[i].minOrderValue,
                              style: text.bodyLarge!.tabular,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(prefixText: SellerFormat.rupeeSymbol, hintText: l10n.feeMinOrder),
                            ),
                          ),
                        ),
                        const SizedBox(width: SellerSpace.s12),
                        Expanded(
                          child: Semantics(
                            label: l10n.feeSlabFee,
                            child: TextField(
                              controller: _slabs[i].fee,
                              style: text.bodyLarge!.tabular,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(prefixText: SellerFormat.rupeeSymbol, hintText: l10n.feeSlabFee),
                            ),
                          ),
                        ),
                        SellerIconButton(
                          icon: SellerIcons.delete,
                          label: l10n.feeRemoveSlab,
                          color: c.danger,
                          onPressed: _slabs.length > 1 ? () => _removeSlab(i) : null,
                        ),
                      ]),
                    ),
                  if (_slabs.length < kMaxSlabs)
                    SellerButton.secondary(label: l10n.feeAddSlab, icon: SellerIcons.add, expand: true, onPressed: _addSlab),
                  const SizedBox(height: SellerSpace.s8),
                  Text(l10n.feeSlabRule, style: text.bodySmall),
                ]),
              ),
            if (_feeType == 'distance') ...[
              SellerCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextField(controller: _distanceBase, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: l10n.feeDistanceBase, prefixText: SellerFormat.rupeeSymbol)),
                const SizedBox(height: SellerSpace.s12),
                TextField(controller: _distanceRate, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: l10n.feeDistanceRate, prefixText: SellerFormat.rupeeSymbol, suffixText: '/km')),
                const SizedBox(height: SellerSpace.s8),
                Text(l10n.feeDistanceHelp, style: text.bodySmall),
              ])),
              SellerBanner(tone: _hasShopLocation ? SellerTone.success : SellerTone.warning,
                message: _hasShopLocation ? l10n.feeDistanceLocationReady('${widget.deliveryRadiusKm}') : l10n.feeDistanceLocationMissing),
              SellerButton.secondary(label: l10n.feeSetLocation, loading: _settingLocation, onPressed: _settingLocation ? null : _setShopLocation),
            ],
            SellerBanner(tone: SellerTone.info, title: l10n.feeFreeTitle, message: l10n.feeFreeBody),
            if (_error != null) SellerBanner(tone: SellerTone.danger, message: _error!, announce: true),
          ],
        ),
      ),
    );
  }
}

/// One-line summary for the Account row.
String describeDeliveryFeeSchedule(Map<String, dynamic>? raw, AppLocalizations l10n) {
  if (raw == null) return l10n.feeDefault;
  if (raw['type'] == 'flat') {
    final amount = (raw['amount'] as num?)?.toDouble();
    return amount == null ? l10n.feeDefault : l10n.feeSummaryFlat(SellerFormat.moneyWhole(amount));
  }
  if (raw['type'] == 'slab') {
    final slabs = raw['slabs'];
    final count = slabs is List ? slabs.length : 0;
    return count > 0 ? l10n.feeSummarySlab(count) : l10n.feeDefault;
  }
  if (raw['type'] == 'distance') {
    final base = raw['baseFeePaise'];
    final rate = raw['ratePerKmPaise'];
    if (base is num && rate is num) {
      return l10n.feeSummaryDistance(SellerFormat.money(base / 100), SellerFormat.money(rate / 100));
    }
  }
  return l10n.feeDefault;
}
