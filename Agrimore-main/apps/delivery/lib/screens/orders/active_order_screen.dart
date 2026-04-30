// lib/screens/orders/active_order_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:agrimore_core/agrimore_core.dart';
import '../../providers/order_provider.dart';

/// Delivery workflow states — each maps to a Firestore orderStatus
enum DeliveryStep {
  accepted,        // "picked_up" (order accepted by partner)
  reachedPickup,   // "reached_pickup"
  parcelPicked,    // "parcel_picked"
  outForDelivery,  // "out_for_delivery"
  delivered,       // "delivered" (requires verification code)
}

class ActiveOrderScreen extends StatefulWidget {
  final OrderModel order;
  
  const ActiveOrderScreen({super.key, required this.order});

  @override
  State<ActiveOrderScreen> createState() => _ActiveOrderScreenState();
}

class _ActiveOrderScreenState extends State<ActiveOrderScreen> {
  late DeliveryStep _currentStep;
  bool _isUpdating = false;
  File? _proofPhoto;
  final ImagePicker _picker = ImagePicker();
  
  @override
  void initState() {
    super.initState();
    _currentStep = _mapStatusToStep(widget.order.orderStatus);
  }

  DeliveryStep _mapStatusToStep(String status) {
    switch (status) {
      case 'picked_up':
        return DeliveryStep.accepted;
      case 'reached_pickup':
        return DeliveryStep.reachedPickup;
      case 'parcel_picked':
        return DeliveryStep.parcelPicked;
      case 'out_for_delivery':
      case 'outfordelivery':
        return DeliveryStep.outForDelivery;
      case 'delivered':
        return DeliveryStep.delivered;
      default:
        return DeliveryStep.accepted;
    }
  }

  String _stepToStatus(DeliveryStep step) {
    switch (step) {
      case DeliveryStep.accepted:
        return 'picked_up';
      case DeliveryStep.reachedPickup:
        return 'reached_pickup';
      case DeliveryStep.parcelPicked:
        return 'parcel_picked';
      case DeliveryStep.outForDelivery:
        return 'out_for_delivery';
      case DeliveryStep.delivered:
        return 'delivered';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${widget.order.orderNumber}'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Delivery Progress Stepper ──
            _buildDeliveryStepper(colorScheme),
            const SizedBox(height: 24),
            
            // ── Customer Info ──
            _buildSection(
              'Customer',
              Icons.person_outline_rounded,
              colorScheme,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.order.deliveryAddress.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  if (widget.order.deliveryAddress.phone != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _callCustomer(),
                          icon: const Icon(Icons.call, size: 16),
                          label: const Text('Call'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _navigateToAddress(),
                          icon: const Icon(Icons.navigation, size: 16),
                          label: const Text('Navigate'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // ── Delivery Address ──
            _buildSection(
              'Delivery Address',
              Icons.location_on_outlined,
              colorScheme,
              child: Text(
                widget.order.deliveryAddress.fullAddress,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurface,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // ── Order Items ──
            _buildSection(
              'Items (${widget.order.items.length})',
              Icons.shopping_bag_outlined,
              colorScheme,
              child: Column(
                children: widget.order.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.productName,
                          style: const TextStyle(fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        'x${item.quantity}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ),
            ),
            const SizedBox(height: 16),
            
            // ── Payment Info ──
            _buildSection(
              'Payment',
              Icons.payment_outlined,
              colorScheme,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.order.paymentMethod.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '₹${widget.order.total.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Proof of Delivery Photo ──
            if (_currentStep == DeliveryStep.outForDelivery)
              _buildProofOfDeliverySection(colorScheme),

            const SizedBox(height: 24),
            
            // ── Action Button ──
            _buildNextStepButton(context, colorScheme),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════
  // DELIVERY PROGRESS STEPPER
  // ════════════════════════════════════════════
  Widget _buildDeliveryStepper(ColorScheme colorScheme) {
    final steps = [
      _StepInfo('Accepted', Icons.check_circle_rounded),
      _StepInfo('Reached\nPickup', Icons.store_rounded),
      _StepInfo('Parcel\nPicked', Icons.inventory_2_rounded),
      _StepInfo('Out for\nDelivery', Icons.delivery_dining_rounded),
      _StepInfo('Delivered', Icons.done_all_rounded),
    ];
    
    final currentIndex = _currentStep.index;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Delivery Progress',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(steps.length * 2 - 1, (index) {
              if (index.isOdd) {
                // Connector line
                final stepIndex = index ~/ 2;
                final isCompleted = stepIndex < currentIndex;
                return Expanded(
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? Colors.green
                          : colorScheme.outline.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }
              
              // Step circle
              final stepIndex = index ~/ 2;
              final step = steps[stepIndex];
              final isCompleted = stepIndex < currentIndex;
              final isCurrent = stepIndex == currentIndex;
              
              return Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCompleted
                          ? Colors.green
                          : isCurrent
                              ? colorScheme.primary
                              : colorScheme.surfaceContainerHighest,
                      border: isCurrent
                          ? Border.all(color: colorScheme.primary, width: 3)
                          : null,
                      boxShadow: isCurrent
                          ? [BoxShadow(
                              color: colorScheme.primary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              spreadRadius: 2,
                            )]
                          : null,
                    ),
                    child: Icon(
                      isCompleted ? Icons.check : step.icon,
                      size: 18,
                      color: isCompleted || isCurrent
                          ? Colors.white
                          : colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    step.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
                      color: isCurrent
                          ? colorScheme.primary
                          : isCompleted
                              ? Colors.green
                              : colorScheme.outline,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════
  // PROOF OF DELIVERY SECTION
  // ════════════════════════════════════════════
  Widget _buildProofOfDeliverySection(ColorScheme colorScheme) {
    return _buildSection(
      'Proof of Delivery (Optional)',
      Icons.camera_alt_outlined,
      colorScheme,
      child: Column(
        children: [
          if (_proofPhoto != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                _proofPhoto!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _takePhoto(),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Retake'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _proofPhoto = null),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Remove'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ),
              ],
            ),
          ] else ...[
            GestureDetector(
              onTap: () => _takePhoto(),
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.3),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_rounded, size: 36, color: colorScheme.outline),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to take delivery photo',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ════════════════════════════════════════════
  // NEXT STEP ACTION BUTTON
  // ════════════════════════════════════════════
  Widget _buildNextStepButton(BuildContext context, ColorScheme colorScheme) {
    if (_currentStep == DeliveryStep.delivered) {
      return const SizedBox.shrink();
    }

    final nextStep = DeliveryStep.values[_currentStep.index + 1];
    final buttonLabel = _getButtonLabel(nextStep);
    final buttonColor = nextStep == DeliveryStep.delivered
        ? Colors.green
        : colorScheme.primary;

    return FilledButton(
      onPressed: _isUpdating ? null : () => _handleNextStep(context, nextStep),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: buttonColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: _isUpdating
          ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_getButtonIcon(nextStep), size: 20),
                const SizedBox(width: 8),
                Text(
                  buttonLabel,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
    );
  }

  String _getButtonLabel(DeliveryStep step) {
    switch (step) {
      case DeliveryStep.accepted:
        return 'Accept Order';
      case DeliveryStep.reachedPickup:
        return 'Reached Pickup Location';
      case DeliveryStep.parcelPicked:
        return 'Parcel Picked Up';
      case DeliveryStep.outForDelivery:
        return 'Start Delivery';
      case DeliveryStep.delivered:
        return 'Complete Delivery';
    }
  }

  IconData _getButtonIcon(DeliveryStep step) {
    switch (step) {
      case DeliveryStep.accepted:
        return Icons.check_circle;
      case DeliveryStep.reachedPickup:
        return Icons.store;
      case DeliveryStep.parcelPicked:
        return Icons.inventory_2;
      case DeliveryStep.outForDelivery:
        return Icons.delivery_dining;
      case DeliveryStep.delivered:
        return Icons.verified;
    }
  }

  // ════════════════════════════════════════════
  // HANDLE NEXT STEP
  // ════════════════════════════════════════════
  Future<void> _handleNextStep(BuildContext context, DeliveryStep nextStep) async {
    if (nextStep == DeliveryStep.delivered) {
      // Final step — show verification code dialog
      _showVerificationDialog(context);
    } else {
      // All other steps — simple status update
      await _updateToStep(context, nextStep);
    }
  }

  Future<void> _updateToStep(BuildContext context, DeliveryStep step) async {
    setState(() => _isUpdating = true);
    HapticFeedback.mediumImpact();

    final orderProvider = context.read<DeliveryOrderProvider>();
    final status = _stepToStatus(step);
    final description = _getStepDescription(step);

    final success = await orderProvider.updateOrderStatus(
      widget.order.id,
      status,
      description,
    );

    if (mounted) {
      setState(() {
        _isUpdating = false;
        if (success) _currentStep = step;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${_getButtonLabel(step)}'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  String _getStepDescription(DeliveryStep step) {
    switch (step) {
      case DeliveryStep.accepted:
        return 'Delivery partner accepted the order';
      case DeliveryStep.reachedPickup:
        return 'Delivery partner reached the pickup location';
      case DeliveryStep.parcelPicked:
        return 'Parcel has been picked up from seller';
      case DeliveryStep.outForDelivery:
        return 'Order is now out for delivery';
      case DeliveryStep.delivered:
        return 'Order delivered and verified by customer';
    }
  }

  // ════════════════════════════════════════════
  // 🔐 VERIFICATION CODE DIALOG
  // The delivery boy does NOT see the code.
  // They must ask the customer for it.
  // We validate it against Firestore.
  // ════════════════════════════════════════════
  void _showVerificationDialog(BuildContext context) {
    final codeController = TextEditingController();
    String? errorText;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.verified_user, color: Colors.green.shade700, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Verify Delivery',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ask the customer for their 6-digit delivery verification code.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 8,
                  ),
                  decoration: InputDecoration(
                    hintText: '• • • • • •',
                    hintStyle: TextStyle(
                      fontSize: 24,
                      letterSpacing: 8,
                      color: Colors.grey.shade400,
                    ),
                    errorText: errorText,
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.green.shade600, width: 2),
                    ),
                  ),
                  onChanged: (val) {
                    if (errorText != null) {
                      setDialogState(() => errorText = null);
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  final inputCode = codeController.text.trim();

                  if (inputCode.isEmpty || inputCode.length < 6) {
                    setDialogState(() => errorText = 'Enter the full 6-digit code');
                    return;
                  }

                  // 🔐 Fetch the real code from Firestore (never stored locally)
                  try {
                    final orderDoc = await FirebaseFirestore.instance
                        .collection('orders')
                        .doc(widget.order.id)
                        .get();

                    final realCode = orderDoc.data()?['deliveryVerificationCode'] as String?;

                    if (realCode == null) {
                      setDialogState(() => errorText = 'Verification not available for this order');
                      return;
                    }

                    if (inputCode == realCode) {
                      // ✅ Code matches — complete delivery
                      Navigator.pop(ctx);
                      await _completeDelivery(context);
                    } else {
                      HapticFeedback.heavyImpact();
                      setDialogState(() => errorText = 'Incorrect code. Please try again.');
                    }
                  } catch (e) {
                    debugPrint('❌ Verification error: $e');
                    setDialogState(() => errorText = 'Verification failed. Try again.');
                  }
                },
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Verify & Complete'),
                style: FilledButton.styleFrom(backgroundColor: Colors.green),
              ),
            ],
          );
        },
      ),
    );
  }

  // ════════════════════════════════════════════
  // COMPLETE THE DELIVERY
  // ════════════════════════════════════════════
  Future<void> _completeDelivery(BuildContext context) async {
    setState(() => _isUpdating = true);
    HapticFeedback.heavyImpact();

    String? proofPhotoUrl;

    // Upload proof photo if available
    if (_proofPhoto != null) {
      try {
        final ref = FirebaseStorage.instance
            .ref()
            .child('delivery_proofs')
            .child('${widget.order.id}_${DateTime.now().millisecondsSinceEpoch}.jpg');

        await ref.putFile(_proofPhoto!);
        proofPhotoUrl = await ref.getDownloadURL();
        debugPrint('📸 Proof photo uploaded: $proofPhotoUrl');
      } catch (e) {
        debugPrint('⚠️ Failed to upload proof photo: $e');
      }
    }

    // Update order status to delivered
    final orderProvider = context.read<DeliveryOrderProvider>();
    final success = await orderProvider.updateOrderStatus(
      widget.order.id,
      'delivered',
      'Order delivered and verified by customer',
    );

    // Save proof photo URL if available
    if (proofPhotoUrl != null) {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.order.id)
          .update({'deliveryProofPhoto': proofPhotoUrl});
    }

    if (mounted) {
      setState(() {
        _isUpdating = false;
        if (success) _currentStep = DeliveryStep.delivered;
      });

      if (success) {
        // Show success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.done_all_rounded, size: 48, color: Colors.green.shade600),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Delivery Complete! 🎉',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  'Order #${widget.order.orderNumber} has been successfully delivered.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx); // Close dialog
                  Navigator.pop(context); // Go back to dashboard
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: Colors.green,
                ),
                child: const Text('Back to Dashboard'),
              ),
            ],
          ),
        );
      }
    }
  }

  // ════════════════════════════════════════════
  // TAKE PROOF PHOTO
  // ════════════════════════════════════════════
  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1200,
      );
      if (photo != null && mounted) {
        setState(() => _proofPhoto = File(photo.path));
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      debugPrint('📸 Camera error: $e');
    }
  }

  // ════════════════════════════════════════════
  // UI HELPERS
  // ════════════════════════════════════════════
  Widget _buildSection(String title, IconData icon, ColorScheme colorScheme, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
  
  void _callCustomer() async {
    final phone = widget.order.deliveryAddress.phone;
    if (phone != null) {
      final url = Uri.parse('tel:$phone');
      if (await canLaunchUrl(url)) launchUrl(url);
    }
  }
  
  void _navigateToAddress() async {
    final address = widget.order.deliveryAddress;
    if (address.latitude != null && address.longitude != null) {
      final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${address.latitude},${address.longitude}');
      if (await canLaunchUrl(url)) launchUrl(url);
    }
  }
}

class _StepInfo {
  final String label;
  final IconData icon;
  const _StepInfo(this.label, this.icon);
}
