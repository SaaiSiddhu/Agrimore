import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import 'delivery_fee_validation.dart';

// Phase FIX-8B — seller-side config for functions/src/customer/
// deliveryFeeSchedule.ts (Phase FIX-8, WS1a, already merged and E2E_DEVELOP).
// firestore.rules places no constraint on sellers/{uid}.deliveryFeeSchedule
// beyond the existing blanket privileged-field denylist (status stays
// admin-only) — parseDeliveryFeeSchedule() on the server is the ONLY other
// validation this value ever gets, so a malformed schedule is treated by
// the server as fully ABSENT (silent fallback to legacy pricing), not
// partially applied and not an error the seller would ever see — so
// getting the bounds wrong here would look like "my setting did nothing"
// with no explanation, which is worse than rejecting it up front with a
// clear reason. The bounds themselves live in delivery_fee_validation.dart,
// unit-tested against deliveryFeeSchedule.ts's own source there.
/// Opens the delivery fee screen (board 22-06): flat fee or tiers by order
/// value, written to sellers/{uid}.deliveryFeeSchedule (the server's
/// parseDeliveryFeeSchedule is the only other check). Calls [onSaved]
/// after a successful write.
void showDeliveryFeeSheet(
  BuildContext context, {
  required String uid,
  required Map<String, dynamic>? initialSchedule,
  required VoidCallback onSaved,
}) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => DeliveryFeeScreen(uid: uid, initialSchedule: initialSchedule, onSaved: onSaved),
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
  const DeliveryFeeScreen({super.key, required this.uid, required this.initialSchedule, required this.onSaved, this.save});

  final String uid;
  final Map<String, dynamic>? initialSchedule;
  final VoidCallback onSaved;

  /// Replaces the Firestore write in tests.
  final Future<void> Function(Map<String, dynamic> schedule)? save;

  @override
  State<DeliveryFeeScreen> createState() => _DeliveryFeeScreenState();
}

class _DeliveryFeeScreenState extends State<DeliveryFeeScreen> {
  late bool _isSlab;
  late TextEditingController _flatAmount;
  final List<_SlabRow> _slabs = [];
  bool _saving = false;
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
    _isSlab = scheduleType == 'slab';
    _flatAmount = TextEditingController(text: scheduleType == 'flat' ? _num(raw?['amount']) : '');
    if (_isSlab) {
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
    for (final s in _slabs) {
      s.dispose();
    }
    super.dispose();
  }

  FeeError? _validate() {
    if (!_isSlab) return validateFlatFee(double.tryParse(_flatAmount.text.trim()));
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
      final Map<String, dynamic> schedule = _isSlab
          ? {
              'type': 'slab',
              'slabs': [
                for (final s in _slabs)
                  {'minOrderValue': double.parse(s.minOrderValue.text.trim()), 'fee': double.parse(s.fee.text.trim())},
              ],
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
            SellerSegmented<bool>(
              semanticLabel: l10n.accountDeliveryFee,
              segments: [SellerSegment(false, l10n.feeFlat), SellerSegment(true, l10n.feeSlab)],
              selected: _isSlab,
              onChanged: (v) => setState(() {
                _isSlab = v;
                _dirty = true;
                _error = null;
              }),
            ),
            if (!_isSlab)
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
            else
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
  return l10n.feeDefault;
}
