import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_services/agrimore_services.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

/// Configure checkout delivery windows (`settings/delivery` → `timeSlots`).
class DeliveryTimeSlotsManagementScreen extends StatefulWidget {
  const DeliveryTimeSlotsManagementScreen({Key? key}) : super(key: key);

  @override
  State<DeliveryTimeSlotsManagementScreen> createState() =>
      _DeliveryTimeSlotsManagementScreenState();
}

class _DeliveryTimeSlotsManagementScreenState
    extends State<DeliveryTimeSlotsManagementScreen> {
  final DeliverySlotService _service = DeliverySlotService();
  List<DeliveryTimeSlotModel> _slots = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _service.fetchSlots();
    if (!mounted) return;
    setState(() {
      _slots = List.from(list);
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _service.saveSlots(_slots);
      if (mounted) SnackbarHelper.showSuccess(context, 'Time slots saved');
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, 'Save failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editSlot(int index) async {
    final s = _slots[index];
    final labelCtrl = TextEditingController(text: s.label);
    final startCtrl = TextEditingController(text: s.start);
    final endCtrl = TextEditingController(text: s.end);
    final iconCtrl = TextEditingController(text: s.icon);
    var active = s.active;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Edit time slot'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(labelText: 'Label'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: startCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Start (24h HH:mm)',
                    hintText: '06:00',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: endCtrl,
                  decoration: const InputDecoration(
                    labelText: 'End (24h HH:mm)',
                    hintText: '09:00',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: iconCtrl,
                  decoration: const InputDecoration(labelText: 'Icon (emoji)'),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  value: active,
                  onChanged: (v) => setD(() => active = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );

    if (ok == true && mounted) {
      setState(() {
        _slots[index] = DeliveryTimeSlotModel(
          id: s.id,
          label: labelCtrl.text.trim().isEmpty ? s.label : labelCtrl.text.trim(),
          start: startCtrl.text.trim().isEmpty ? s.start : startCtrl.text.trim(),
          end: endCtrl.text.trim().isEmpty ? s.end : endCtrl.text.trim(),
          active: active,
          icon: iconCtrl.text.trim().isEmpty ? s.icon : iconCtrl.text.trim(),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Delivery time slots'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Save',
            onPressed: _loading || _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.lightImpact();
          setState(() {
            _slots.add(DeliveryTimeSlotModel(
              id: 'slot_${DateTime.now().millisecondsSinceEpoch}',
              label: 'New window',
              start: '09:00',
              end: '12:00',
              active: true,
              icon: '🕒',
            ));
          });
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('Add slot'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: _slots.length,
              itemBuilder: (context, i) {
                final s = _slots[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: Text(s.icon, style: const TextStyle(fontSize: 28)),
                    title: Text(s.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      '${s.start} – ${s.end}${s.active ? '' : ' (inactive)'}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() => _slots.removeAt(i));
                      },
                    ),
                    onTap: () => _editSlot(i),
                  ),
                );
              },
            ),
    );
  }
}
