import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrimore_ui/agrimore_ui.dart' show SnackbarHelper;
import 'package:agrimore_core/agrimore_core.dart';

// Phase FIX-8B — seller-side config for functions/src/customer/
// deliveryFeeSchedule.ts (Phase FIX-8, WS1a, already merged and E2E_DEVELOP).
// firestore.rules places no constraint on sellers/{uid}.deliveryFeeSchedule
// beyond the existing blanket privileged-field denylist (status stays
// admin-only) — parseDeliveryFeeSchedule() on the server is the ONLY other
// validation this value ever gets, so every bound below is copied from that
// file's own source, not reinvented: a malformed schedule is treated by the
// server as fully ABSENT (silent fallback to legacy pricing), not partially
// applied and not an error the seller would ever see — so getting these
// bounds wrong here would look like "my setting did nothing" with no
// explanation, which is worse than rejecting it up front with a clear
// reason.
const int _kMaxFeeRupees = 1000;
const int _kMaxSlabs = 10;
const _kAccentColor = Color(0xFF2D7D3C);

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
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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

  /// Returns a user-safe error message, or null if valid — mirrors
  /// parseDeliveryFeeSchedule()'s exact bounds. Never throws; the caller
  /// shows the returned string via SnackbarHelper.showError directly, so it
  /// must already be a complete, honest sentence (feedback.md §2).
  String? _validate() {
    if (!_isSlab) {
      final amount = double.tryParse(_flatAmount.text.trim());
      if (amount == null || amount < 0) {
        return 'Enter a valid delivery fee (0 or more)';
      }
      if (amount > _kMaxFeeRupees) {
        return 'Delivery fee cannot exceed ₹$_kMaxFeeRupees';
      }
      return null;
    }

    if (_slabs.isEmpty) {
      return 'Add at least one slab';
    }
    if (_slabs.length > _kMaxSlabs) {
      return 'A maximum of $_kMaxSlabs slabs is allowed';
    }
    bool hasZeroSlab = false;
    for (final slab in _slabs) {
      final minOrderValue = double.tryParse(slab.minOrderValue.text.trim());
      final fee = double.tryParse(slab.fee.text.trim());
      if (minOrderValue == null || minOrderValue < 0) {
        return 'Every slab needs a valid minimum order value (0 or more)';
      }
      if (fee == null || fee < 0) {
        return 'Every slab needs a valid delivery fee (0 or more)';
      }
      if (fee > _kMaxFeeRupees) {
        return 'A slab fee cannot exceed ₹$_kMaxFeeRupees';
      }
      if (minOrderValue == 0) hasZeroSlab = true;
    }
    if (!hasZeroSlab) {
      return 'One slab must start at a minimum order value of 0, so every order matches a slab';
    }
    return null;
  }

  Future<void> _save() async {
    final error = _validate();
    if (error != null) {
      SnackbarHelper.showError(context, error);
      return;
    }

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
      Navigator.pop(context);
      widget.onSaved();
      SnackbarHelper.showSuccess(context, 'Delivery fee updated');
    } catch (e) {
      // Never render e.toString() (feedback.md §2) — the detail is logged,
      // never shown.
      debugPrint('❌ Error saving delivery fee schedule: $e');
      if (mounted) {
        SnackbarHelper.showError(
            context, 'Could not save your delivery fee right now. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addSlab() {
    if (_slabs.length >= _kMaxSlabs) return;
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
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Delivery Fee',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              'Choose how you charge customers for delivery.',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            const SizedBox(height: 16),
            _buildTypeToggle(),
            const SizedBox(height: 16),
            if (!_isSlab) _buildFlatForm() else _buildSlabForm(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: _kAccentColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save Changes',
                        style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeToggle() {
    return Row(
      children: [
        Expanded(
          child: _buildTypeButton('Flat', !_isSlab, () {
            setState(() => _isSlab = false);
          }),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildTypeButton('Slab', _isSlab, () {
            setState(() => _isSlab = true);
          }),
        ),
      ],
    );
  }

  Widget _buildTypeButton(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _kAccentColor.withOpacity(0.1) : Colors.transparent,
          border: Border.all(
              color: selected ? _kAccentColor : Colors.grey[300]!, width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: selected ? _kAccentColor : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildFlatForm() {
    return TextField(
      controller: _flatAmount,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        labelText: 'Delivery Fee (₹)',
        border: OutlineInputBorder(),
        helperText: 'Charged on every order, regardless of order value',
      ),
    );
  }

  Widget _buildSlabForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'One slab must start at a minimum order value of ₹0.',
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
        const SizedBox(height: 10),
        for (int i = 0; i < _slabs.length; i++) _buildSlabRow(i),
        const SizedBox(height: 4),
        if (_slabs.length < _kMaxSlabs)
          TextButton.icon(
            onPressed: _addSlab,
            icon: const Icon(Icons.add, color: _kAccentColor),
            label: const Text('Add Slab', style: TextStyle(color: _kAccentColor)),
          ),
      ],
    );
  }

  Widget _buildSlabRow(int index) {
    final slab = _slabs[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: slab.minOrderValue,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Min order (₹)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: slab.fee,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Fee (₹)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          IconButton(
            onPressed: _slabs.length > 1 ? () => _removeSlab(index) : null,
            icon: Icon(Icons.remove_circle_outline,
                color: _slabs.length > 1 ? Colors.red : Colors.grey[300]),
          ),
        ],
      ),
    );
  }
}

/// Summary text for the menu item's subtitle — reuses PriceFormatter
/// (feedback.md §2: rupee amounts never string-concatenated with a
/// hardcoded symbol in a new file) rather than a bespoke '₹$amount'.
String describeDeliveryFeeSchedule(Map<String, dynamic>? raw) {
  if (raw == null) return 'Using default pricing';
  if (raw['type'] == 'flat') {
    final amount = (raw['amount'] as num?)?.toDouble();
    if (amount == null) return 'Using default pricing';
    return 'Flat ${PriceFormatter.formatPriceInt(amount)}';
  }
  if (raw['type'] == 'slab') {
    final slabs = raw['slabs'];
    final count = slabs is List ? slabs.length : 0;
    return count > 0 ? 'Slab pricing · $count tier${count == 1 ? '' : 's'}' : 'Using default pricing';
  }
  return 'Using default pricing';
}
