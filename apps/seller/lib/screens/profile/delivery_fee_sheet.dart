import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

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
/// Opens the Flat/Slab delivery fee editor as a bottom sheet, writing
/// directly to sellers/{uid}.deliveryFeeSchedule (no callable — mirrors
/// seller_profile_screen.dart's own edit-dialog convention of a direct
/// Firestore write for a seller's own profile fields). Calls [onSaved]
/// after a successful write so the caller can refresh its own cached copy
/// of the seller doc.
void showDeliveryFeeSheet(
  BuildContext context, {
  required String uid,
  required Map<String, dynamic>? initialSchedule,
  required VoidCallback onSaved,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _DeliveryFeeSheet(
      uid: uid,
      initialSchedule: initialSchedule,
      onSaved: onSaved,
    ),
  );
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

class _DeliveryFeeSheet extends StatefulWidget {
  final String uid;
  final Map<String, dynamic>? initialSchedule;
  final VoidCallback onSaved;

  const _DeliveryFeeSheet({
    required this.uid,
    required this.initialSchedule,
    required this.onSaved,
  });

  @override
  State<_DeliveryFeeSheet> createState() => _DeliveryFeeSheetState();
}

class _DeliveryFeeSheetState extends State<_DeliveryFeeSheet> {
  late bool _isSlab;
  late TextEditingController _flatAmount;
  final List<_SlabRow> _slabs = [];
  bool _saving = false;

  /// Shown inline (validation or save failure).
  String? _error;

  @override
  void initState() {
    super.initState();
    final raw = widget.initialSchedule;
    final scheduleType = raw?['type'];
    _isSlab = scheduleType == 'slab';
    Object? flatAmount;
    if (scheduleType == 'flat') {
      flatAmount = raw?['amount'];
    }
    _flatAmount = TextEditingController(text: flatAmount?.toString() ?? '');
    if (_isSlab) {
      final rawSlabs = raw?['slabs'];
      if (rawSlabs is List) {
        for (final s in rawSlabs) {
          if (s is Map) {
            _slabs.add(_SlabRow(
              minOrderValue: s['minOrderValue']?.toString() ?? '',
              fee: s['fee']?.toString() ?? '',
            ));
          }
        }
      }
    }
    if (_slabs.isEmpty) {
      // A fresh slab schedule always starts with the required zero-value
      // slab pre-filled, rather than an empty list a seller has to know to
      // seed correctly themselves.
      _slabs.add(_SlabRow(minOrderValue: '0', fee: ''));
    }
  }

  @override
  void dispose() {
    _flatAmount.dispose();
    for (final s in _slabs) {
      s.dispose();
    }
    super.dispose();
  }

  /// Returns a user-safe error message, or null if valid. Delegates to
  /// delivery_fee_validation.dart's pure functions (unit-tested in
  /// apps/seller/test/delivery_fee_validation_test.dart) so this widget
  /// only handles reading the current form state, never the bounds
  /// themselves. Never throws; the caller shows the returned string via
  /// SnackbarHelper.showError directly, so it must already be a complete,
  /// honest sentence (feedback.md §2).
  String? _validate() {
    if (!_isSlab) {
      return validateFlatFee(double.tryParse(_flatAmount.text.trim()));
    }
    return validateSlabSchedule([
      for (final slab in _slabs)
        (
          minOrderValue: double.tryParse(slab.minOrderValue.text.trim()),
          fee: double.tryParse(slab.fee.text.trim()),
        ),
    ]);
  }

  Future<void> _save() async {
    final error = _validate();
    setState(() => _error = error);
    if (error != null) return;

    setState(() => _saving = true);
    try {
      final Map<String, dynamic> schedule = _isSlab
          ? {
              'type': 'slab',
              'slabs': _slabs
                  .map((s) => {
                        'minOrderValue': double.parse(s.minOrderValue.text.trim()),
                        'fee': double.parse(s.fee.text.trim()),
                      })
                  .toList(),
            }
          : {
              'type': 'flat',
              'amount': double.parse(_flatAmount.text.trim()),
            };

      await FirebaseFirestore.instance.collection('sellers').doc(widget.uid).set({
        'deliveryFeeSchedule': schedule,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.pop(context);
      widget.onSaved();
      if (messenger != null) WsToast.show(messenger.context, l10n.feeSaved, tone: WsToastTone.success);
    } catch (e) {
      // Never render e.toString() (feedback.md §2) — the detail is logged,
      // never shown.
      debugPrint('❌ Error saving delivery fee schedule: $e');
      if (mounted) setState(() => _error = AppLocalizations.of(context).feeSaveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addSlab() {
    if (_slabs.length >= kMaxSlabs) return;
    setState(() => _slabs.add(_SlabRow()));
  }

  void _removeSlab(int index) {
    if (_slabs.length <= 1) return;
    setState(() {
      _slabs[index].dispose();
      _slabs.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    final text = context.wsText;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(WsSpace.page, 0, WsSpace.page, WsSpace.s24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(l10n.accountDeliveryFee, style: text.titleMedium),
            const SizedBox(height: WsSpace.s4),
            Text(l10n.feeIntro, style: text.bodySmall!.copyWith(color: t.textSecondary)),
            const SizedBox(height: WsSpace.s16),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: false, label: Text(l10n.feeFlat)),
                ButtonSegment(value: true, label: Text(l10n.feeSlab)),
              ],
              selected: {_isSlab},
              onSelectionChanged: (s) => setState(() => _isSlab = s.first),
            ),
            const SizedBox(height: WsSpace.s16),
            if (!_isSlab)
              TextField(
                key: const ValueKey('feeFlat'),
                controller: _flatAmount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: l10n.feeAmount, helperText: l10n.feeFlatHelp),
              )
            else ...[
              Text(l10n.feeSlabRule, style: text.bodySmall!.copyWith(color: t.textSecondary)),
              const SizedBox(height: WsSpace.s12),
              for (var i = 0; i < _slabs.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: WsSpace.s12),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _slabs[i].minOrderValue,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: l10n.feeMinOrder, isDense: true),
                      ),
                    ),
                    const SizedBox(width: WsSpace.s8),
                    Expanded(
                      child: TextField(
                        controller: _slabs[i].fee,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: l10n.feeSlabFee, isDense: true),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.feeRemoveSlab,
                      onPressed: _slabs.length > 1 ? () => _removeSlab(i) : null,
                      icon: Icon(AgIcons.delete, color: _slabs.length > 1 ? t.errorFg : t.disabledContent),
                    ),
                  ]),
                ),
              if (_slabs.length < kMaxSlabs)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(onPressed: _addSlab, icon: const Icon(AgIcons.add), label: Text(l10n.feeAddSlab)),
                ),
            ],
            if (_error != null) ...[
              const SizedBox(height: WsSpace.s8),
              SaInfoBanner(variant: SaBannerVariant.error, message: _error!),
            ],
            const SizedBox(height: WsSpace.s24),
            SaLoadingButton(text: l10n.accountSave, isLoading: _saving, onPressed: _saving ? null : _save),
          ]),
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
    return amount == null ? l10n.feeDefault : l10n.feeSummaryFlat(AgFormat.rupeesWhole(amount));
  }
  if (raw['type'] == 'slab') {
    final slabs = raw['slabs'];
    final count = slabs is List ? slabs.length : 0;
    return count > 0 ? l10n.feeSummarySlab(count) : l10n.feeDefault;
  }
  return l10n.feeDefault;
}
