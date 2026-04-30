import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:agrimore_core/agrimore_core.dart';

/// Firestore-backed delivery time windows for checkout.
///
/// Document: `settings/delivery` field `timeSlots`: list of maps
/// `{ id, label, start, end, active, icon }` with `start`/`end` as `HH:mm`.
class DeliverySlotService {
  DeliverySlotService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const _docPath = 'settings/delivery';

  Future<List<DeliveryTimeSlotModel>> fetchSlots() async {
    try {
      final doc = await _db.doc(_docPath).get();
      if (!doc.exists) return DeliveryTimeSlotModel.defaultSlots();
      final data = doc.data();
      if (data == null) return DeliveryTimeSlotModel.defaultSlots();
      final raw = data['timeSlots'];
      if (raw is! List || raw.isEmpty) {
        return DeliveryTimeSlotModel.defaultSlots();
      }
      final slots = raw
          .whereType<Map<String, dynamic>>()
          .map(DeliveryTimeSlotModel.fromMap)
          .where((s) => s.id.isNotEmpty)
          .toList();
      return slots.isEmpty ? DeliveryTimeSlotModel.defaultSlots() : slots;
    } catch (e) {
      debugPrint('DeliverySlotService.fetchSlots: $e');
      return DeliveryTimeSlotModel.defaultSlots();
    }
  }

  Future<void> saveSlots(List<DeliveryTimeSlotModel> slots) async {
    await _db.doc(_docPath).set(
      {
        'timeSlots': slots.map((e) => e.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
