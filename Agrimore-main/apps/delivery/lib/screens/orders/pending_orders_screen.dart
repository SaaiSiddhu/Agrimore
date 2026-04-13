// lib/screens/orders/pending_orders_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_core/agrimore_core.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/location_provider.dart';
import '../../widgets/order_preview_card.dart';
import '../../widgets/order_detail_popup.dart';
import '../../services/distance_service.dart';

class PendingOrdersScreen extends StatefulWidget {
  const PendingOrdersScreen({super.key});

  @override
  State<PendingOrdersScreen> createState() => _PendingOrdersScreenState();
}

class _PendingOrdersScreenState extends State<PendingOrdersScreen> {
  bool _isAccepting = false;
  
  // Cache for distance calculations
  final Map<String, Map<String, dynamic>> _distanceCache = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Orders'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              _distanceCache.clear(); // Clear cache on refresh
              context.read<DeliveryOrderProvider>().loadAvailableOrders();
            },
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Consumer2<DeliveryOrderProvider, LocationProvider>(
        builder: (context, orderProvider, locationProvider, _) {
          if (orderProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (orderProvider.availableOrders.isEmpty) {
            return _buildEmptyState(colorScheme);
          }
          
          return RefreshIndicator(
            onRefresh: () async {
              _distanceCache.clear();
              orderProvider.loadAvailableOrders();
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orderProvider.availableOrders.length,
              itemBuilder: (context, index) {
                final order = orderProvider.availableOrders[index];
                return _buildOrderCard(order, locationProvider);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order, LocationProvider locationProvider) {
    // Check cache first
    if (_distanceCache.containsKey(order.id)) {
      final cached = _distanceCache[order.id]!;
      return OrderPreviewCard(
        order: order,
        distanceKm: cached['distanceKm'] as double?,
        onTap: () => _showOrderDetailPopup(order, cached),
      );
    }
    
    // Log partner location status
    debugPrint('📍 Partner location: lat=${locationProvider.latitude}, lng=${locationProvider.longitude}');
    debugPrint('📍 Order ${order.orderNumber} address: lat=${order.deliveryAddress.latitude}, lng=${order.deliveryAddress.longitude}');
    
    // Try sync calculation if coords available
    if (locationProvider.currentPosition != null) {
      final syncResult = DistanceService.calculateIfCoordsAvailable(
        partnerLat: locationProvider.latitude!,
        partnerLng: locationProvider.longitude!,
        customerAddress: order.deliveryAddress,
      );
      
      if (syncResult != null) {
        debugPrint('✅ Sync calculation succeeded for order ${order.orderNumber}');
        _distanceCache[order.id] = syncResult;
        return OrderPreviewCard(
          order: order,
          distanceKm: syncResult['distanceKm'] as double,
          onTap: () => _showOrderDetailPopup(order, syncResult),
        );
      } else {
        debugPrint('⚠️ Sync failed, coordinates missing - falling back to async geocoding');
      }
    } else {
      debugPrint('⚠️ Partner position is null - cannot calculate distance');
    }
    
    // Need async geocoding - return card with loading, calculate in background
    _calculateDistanceAsync(order, locationProvider);
    
    return OrderPreviewCard(
      order: order,
      distanceKm: null, // Shows loading
      onTap: () => _showOrderDetailPopup(order, null),
    );
  }

  Future<void> _calculateDistanceAsync(OrderModel order, LocationProvider locationProvider) async {
    if (locationProvider.currentPosition == null) {
      debugPrint('⚠️ Cannot geocode - partner position null');
      return;
    }
    if (_distanceCache.containsKey(order.id)) return; // Already cached
    
    debugPrint('🔄 Starting async geocoding for order ${order.orderNumber}');
    
    final result = await DistanceService.calculateDeliveryDetailsAsync(
      partnerLat: locationProvider.latitude!,
      partnerLng: locationProvider.longitude!,
      customerAddress: order.deliveryAddress,
    );
    
    debugPrint('📊 Async result for ${order.orderNumber}: distance=${result['distanceKm']}km, earnings=₹${result['earnings']}');
    
    if (mounted) {
      setState(() {
        _distanceCache[order.id] = result;
      });
    }
  }


  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inbox_rounded,
              size: 56,
              color: colorScheme.outline,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No orders available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pull down to refresh',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => context.read<DeliveryOrderProvider>().loadAvailableOrders(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  void _showOrderDetailPopup(OrderModel order, Map<String, dynamic>? deliveryDetails) {
    final locationProvider = context.read<LocationProvider>();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => _OrderDetailPopupWithLoading(
          order: order,
          initialDetails: deliveryDetails,
          locationProvider: locationProvider,
          isAccepting: _isAccepting,
          onAccept: () => _acceptOrder(order),
          onDeny: () => _denyOrder(order),
        ),
      ),
    );
  }

  Future<void> _acceptOrder(OrderModel order) async {
    if (_isAccepting) return;
    
    setState(() => _isAccepting = true);
    HapticFeedback.heavyImpact();
    
    final auth = context.read<DeliveryAuthProvider>();
    final orderProvider = context.read<DeliveryOrderProvider>();
    
    if (auth.user == null) {
      setState(() => _isAccepting = false);
      return;
    }
    
    final success = await orderProvider.acceptOrder(order.id, auth.user!.uid);
    
    setState(() => _isAccepting = false);
    
    if (success && mounted) {
      Navigator.pop(context); // Close popup
      Navigator.pop(context); // Go back to dashboard
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 12),
              const Text('Order accepted! Navigate to pickup.'),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _denyOrder(OrderModel order) {
    HapticFeedback.mediumImpact();
    
    // Hide from list using provider
    context.read<DeliveryOrderProvider>().denyOrder(order.id);
    
    Navigator.pop(context); // Close the popup
    debugPrint('📦 Order denied: ${order.orderNumber}');
    
    // Show snackbar feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.visibility_off_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            const Text('Order hidden from list'),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

/// Wrapper that handles async distance loading in popup
class _OrderDetailPopupWithLoading extends StatefulWidget {
  final OrderModel order;
  final Map<String, dynamic>? initialDetails;
  final LocationProvider locationProvider;
  final bool isAccepting;
  final VoidCallback onAccept;
  final VoidCallback onDeny;

  const _OrderDetailPopupWithLoading({
    required this.order,
    this.initialDetails,
    required this.locationProvider,
    required this.isAccepting,
    required this.onAccept,
    required this.onDeny,
  });

  @override
  State<_OrderDetailPopupWithLoading> createState() => _OrderDetailPopupWithLoadingState();
}

class _OrderDetailPopupWithLoadingState extends State<_OrderDetailPopupWithLoading> {
  Map<String, dynamic>? _details;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _details = widget.initialDetails;
    
    // If no details, fetch async
    if (_details == null && widget.locationProvider.currentPosition != null) {
      _loadDistance();
    }
  }

  Future<void> _loadDistance() async {
    setState(() => _isLoading = true);
    
    final result = await DistanceService.calculateDeliveryDetailsAsync(
      partnerLat: widget.locationProvider.latitude!,
      partnerLng: widget.locationProvider.longitude!,
      customerAddress: widget.order.deliveryAddress,
    );
    
    if (mounted) {
      setState(() {
        _details = result;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return OrderDetailPopup(
      order: widget.order,
      distanceKm: _details?['distanceKm'] as double?,
      earnings: _details?['earnings'] as double?,
      isCalculating: _isLoading,
      isAccepting: widget.isAccepting,
      onAccept: widget.onAccept,
      onDeny: widget.onDeny,
    );
  }
}
