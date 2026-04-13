// lib/screens/admin/delivery/order_assignment_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrimore_core/agrimore_core.dart';
import '../../../app/themes/admin_colors.dart';

class OrderAssignmentScreen extends StatefulWidget {
  final OrderModel order;
  
  const OrderAssignmentScreen({super.key, required this.order});

  @override
  State<OrderAssignmentScreen> createState() => _OrderAssignmentScreenState();
}

class _OrderAssignmentScreenState extends State<OrderAssignmentScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<DeliveryPartnerModel> _partners = [];
  bool _isLoading = true;
  String? _selectedPartnerId;
  bool _isAssigning = false;

  @override
  void initState() {
    super.initState();
    _loadOnlinePartners();
  }

  Future<void> _loadOnlinePartners() async {
    try {
      debugPrint('🚚 Loading online partners...');
      final snapshot = await _firestore
          .collection('delivery_partners')
          .get(); // Get all first for debugging
      
      debugPrint('🚚 Found ${snapshot.docs.length} total partners');
      
      setState(() {
        _partners = snapshot.docs
            .map((doc) {
              final partner = DeliveryPartnerModel.fromMap(doc.data(), doc.id);
              debugPrint('  Partner: ${partner.name}, isOnline: ${partner.isOnline}');
              return partner;
            })
            .where((p) => p.isOnline) // Filter in code
            .toList();
        _isLoading = false;
        debugPrint('🚚 ${_partners.length} online partners');
      });
    } catch (e) {
      debugPrint('❌ Error loading partners: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Delivery Partner'),
        backgroundColor: AdminColors.cardBackground,
      ),
      body: Column(
        children: [
          // Order Info
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AdminColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AdminColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AdminColors.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#${widget.order.orderNumber}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '₹${widget.order.total.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AdminColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.order.deliveryAddress.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.order.deliveryAddress.fullAddress,
                  style: TextStyle(fontSize: 12, color: AdminColors.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          
          // Partner Selection
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Select Online Partner',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AdminColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_partners.length} available',
                  style: TextStyle(color: AdminColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          
          // Partner List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _partners.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_off_rounded, size: 48, color: AdminColors.textSecondary),
                            const SizedBox(height: 12),
                            const Text('No online partners available'),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _partners.length,
                        itemBuilder: (context, index) {
                          final partner = _partners[index];
                          final isSelected = _selectedPartnerId == partner.id;
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: AdminColors.cardBackground,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? AdminColors.primary : AdminColors.border,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: RadioListTile<String>(
                              value: partner.id,
                              groupValue: _selectedPartnerId,
                              onChanged: (v) => setState(() => _selectedPartnerId = v),
                              title: Text(partner.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Row(
                                children: [
                                  Icon(
                                    partner.vehicleType == 'ev' ? Icons.electric_moped : Icons.two_wheeler,
                                    size: 14,
                                    color: AdminColors.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(partner.vehicleNumber),
                                  const SizedBox(width: 12),
                                  Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                                  const SizedBox(width: 2),
                                  Text(partner.formattedRating),
                                ],
                              ),
                              secondary: CircleAvatar(
                                backgroundColor: AdminColors.primary.withValues(alpha: 0.1),
                                child: Text(
                                  partner.name[0].toUpperCase(),
                                  style: TextStyle(color: AdminColors.primary, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          
          // Assign Button
          Container(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _selectedPartnerId == null || _isAssigning ? null : _assignPartner,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AdminColors.primary,
                ),
                child: _isAssigning
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Assign Partner',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _assignPartner() async {
    if (_selectedPartnerId == null) return;
    
    setState(() => _isAssigning = true);
    
    try {
      // Get the selected partner details
      final selectedPartner = _partners.firstWhere(
        (p) => p.id == _selectedPartnerId,
      );
      
      // Update order with partner assignment and delivery details
      await _firestore.collection('orders').doc(widget.order.id).update({
        'deliveryPartnerId': _selectedPartnerId,
        'orderStatus': 'ready_for_pickup',
        'updatedAt': FieldValue.serverTimestamp(),
        // Add partner details for display
        'deliveryPartner': {
          'id': selectedPartner.id,
          'name': selectedPartner.name,
          'phone': selectedPartner.phone,
          'vehicleType': selectedPartner.vehicleType,
          'vehicleNumber': selectedPartner.vehicleNumber,
          'currentLat': selectedPartner.currentLat,
          'currentLng': selectedPartner.currentLng,
        },
        // Ensure delivery address has coordinates for distance calculation
        'deliveryAddress.latitude': widget.order.deliveryAddress.latitude,
        'deliveryAddress.longitude': widget.order.deliveryAddress.longitude,
      });
      
      // Add timeline event
      await _firestore.collection('orders').doc(widget.order.id).collection('timeline').add({
        'status': 'ready_for_pickup',
        'title': 'Ready for Pickup',
        'description': 'Delivery partner ${selectedPartner.name} assigned',
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      // Update partner's current order and status
      await _firestore.collection('delivery_partners').doc(_selectedPartnerId).update({
        'currentOrderId': widget.order.id,
        'isAvailable': false,
      });
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${selectedPartner.name} assigned to order #${widget.order.orderNumber}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Assignment error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isAssigning = false);
    }
  }
}
