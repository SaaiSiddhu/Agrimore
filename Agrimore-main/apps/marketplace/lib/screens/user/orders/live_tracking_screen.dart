// lib/screens/user/orders/live_tracking_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../providers/order_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/delivery_tracking_service.dart';

class LiveTrackingScreen extends StatefulWidget {
  final String orderId;
  final OrderModel? initialOrder;

  const LiveTrackingScreen({
    Key? key,
    required this.orderId,
    this.initialOrder,
  }) : super(key: key);

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen>
    with TickerProviderStateMixin {
  final DeliveryTrackingService _trackingService = DeliveryTrackingService();
  GoogleMapController? _mapController;
  
  OrderModel? _order;
  DeliveryPartnerModel? _partner;
  int? _etaMinutes;
  
  StreamSubscription? _orderSubscription;
  Timer? _etaTimer;
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Map markers and polyline
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  // Default location (India center)
  static const LatLng _defaultLocation = LatLng(20.5937, 78.9629);

  @override
  void initState() {
    super.initState();
    _order = widget.initialOrder;
    _setupAnimations();
    _loadOrderData();
    _startLocationStream();
    _startETATimer();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _loadOrderData() {
    final orderProvider = context.read<OrderProvider>();
    orderProvider.loadOrderById(widget.orderId);
  }

  void _startLocationStream() {
    _orderSubscription = _trackingService
        .streamOrderStatus(widget.orderId)
        .listen((order) {
      if (order != null && mounted) {
        setState(() {
          _order = order;
          _partner = order.deliveryPartner;
          _updateMapMarkers();
          _calculateETA();
        });
      }
    });
  }

  void _startETATimer() {
    _etaTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _calculateETA();
    });
  }

  void _calculateETA() {
    if (_order == null) return;

    final deliveryAddress = _order!.deliveryAddress;
    
    // Try to get ETA from estimated delivery time
    if (_order!.estimatedDeliveryTime != null) {
      final diff = _order!.estimatedDeliveryTime!.difference(DateTime.now());
      setState(() {
        _etaMinutes = diff.inMinutes.clamp(1, 120);
      });
      return;
    }

    // Calculate based on partner location
    if (_partner?.hasLocation == true) {
      // For now, use a simulated ETA based on order status
      setState(() {
        _etaMinutes = _getSimulatedETA(_order!.orderStatus);
      });
    }
  }

  int _getSimulatedETA(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return 25;
      case 'processing':
        return 18;
      case 'shipped':
      case 'out_for_delivery':
        return 8;
      default:
        return 15;
    }
  }

  void _updateMapMarkers() {
    if (_order == null) return;

    final deliveryAddress = _order!.deliveryAddress;
    final markers = <Marker>{};
    final polylines = <Polyline>{};

    // Destination marker
    if (deliveryAddress.latitude != null && deliveryAddress.longitude != null) {
      final destinationLatLng = LatLng(
        deliveryAddress.latitude!,
        deliveryAddress.longitude!,
      );

      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: destinationLatLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: 'Delivery Location'),
        ),
      );

      // Delivery partner marker
      if (_partner?.hasLocation == true) {
        final partnerLatLng = LatLng(
          _partner!.currentLat!,
          _partner!.currentLng!,
        );

        markers.add(
          Marker(
            markerId: const MarkerId('partner'),
            position: partnerLatLng,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
            infoWindow: InfoWindow(title: _partner!.name),
          ),
        );

        // Route polyline
        polylines.add(
          Polyline(
            polylineId: const PolylineId('route'),
            points: [partnerLatLng, destinationLatLng],
            color: const Color(0xFF2D7D3C),
            width: 4,
            patterns: [PatternItem.dash(20), PatternItem.gap(10)],
          ),
        );
      }
    }

    setState(() {
      _markers = markers;
      _polylines = polylines;
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _orderSubscription?.cancel();
    _etaTimer?.cancel();
    _mapController?.dispose();
    _trackingService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : Colors.grey[50],
      body: Stack(
        children: [
          // Map View
          _buildMapView(isDark),
          
          // Top overlay - ETA and status
          _buildETAOverlay(isDark),
          
          // Back button
          _buildBackButton(isDark),
          
          // Bottom sheet - Partner info and order details
          _buildBottomSheet(isDark),
        ],
      ),
    );
  }

  Widget _buildMapView(bool isDark) {
    final deliveryAddress = _order?.deliveryAddress;
    LatLng initialPosition = _defaultLocation;

    if (deliveryAddress?.latitude != null && deliveryAddress?.longitude != null) {
      initialPosition = LatLng(
        deliveryAddress!.latitude!,
        deliveryAddress.longitude!,
      );
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: initialPosition,
        zoom: 14,
      ),
      markers: _markers,
      polylines: _polylines,
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      onMapCreated: (controller) {
        _mapController = controller;
        if (isDark) {
          controller.setMapStyle(_darkMapStyle);
        }
      },
    );
  }

  Widget _buildETAOverlay(bool isDark) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 60,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Pulsing indicator
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D7D3C),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2D7D3C).withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 16),
            
            // ETA info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_etaMinutes != null) ...[
                    Text(
                      _trackingService.formatETAWithPrefix(_etaMinutes!),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    _trackingService.getStatusMessage(_order?.orderStatus ?? 'pending'),
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            
            // Delivery icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF2D7D3C).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.delivery_dining_rounded,
                color: Color(0xFF2D7D3C),
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackButton(bool isDark) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
              ),
            ],
          ),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSheet(bool isDark) {
    return DraggableScrollableSheet(
      initialChildSize: 0.35,
      minChildSize: 0.2,
      maxChildSize: 0.6,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              
              // Delivery partner card
              if (_partner != null) _buildPartnerCard(isDark),
              
              // Placeholder when no partner
              if (_partner == null) _buildNoPartnerCard(isDark),
              
              const SizedBox(height: 16),
              
              // Order summary
              _buildOrderSummary(isDark),
              
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPartnerCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Partner photo
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF2D7D3C),
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: _partner!.photoUrl != null
                      ? CachedNetworkImage(
                          imageUrl: _partner!.photoUrl!,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: const Color(0xFF2D7D3C).withOpacity(0.1),
                          child: Icon(
                            Icons.person_rounded,
                            size: 28,
                            color: const Color(0xFF2D7D3C),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              
              // Partner info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _partner!.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _partner!.formattedRating,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.two_wheeler_rounded,
                          size: 14,
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _partner!.vehicleNumber,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.phone_rounded,
                  label: 'Call',
                  onTap: () => _callPartner(),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.chat_bubble_rounded,
                  label: 'Chat',
                  onTap: () => _chatWithPartner(),
                  isDark: isDark,
                  isPrimary: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoPartnerCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.delivery_dining_rounded,
            size: 48,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
          ),
          const SizedBox(height: 12),
          Text(
            'Finding delivery partner...',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Please wait while we assign someone',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isPrimary
              ? const Color(0xFF2D7D3C)
              : (isDark ? const Color(0xFF333333) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: !isPrimary
              ? Border.all(
                  color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                )
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isPrimary
                  ? Colors.white
                  : (isDark ? Colors.grey[300] : Colors.grey[700]),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isPrimary
                    ? Colors.white
                    : (isDark ? Colors.grey[300] : Colors.grey[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary(bool isDark) {
    if (_order == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order #${_order!.orderNumber}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                '₹${_order!.total.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF2D7D3C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_order!.items.length} item${_order!.items.length > 1 ? 's' : ''}',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  void _callPartner() async {
    if (_partner?.phone != null) {
      final url = Uri.parse('tel:${_partner!.phone}');
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
    }
  }

  void _chatWithPartner() {
    // TODO: Implement in-app chat or SMS
    if (_partner?.phone != null) {
      final url = Uri.parse('sms:${_partner!.phone}');
      launchUrl(url);
    }
  }

  // Dark mode map style
  static const String _darkMapStyle = '''
  [
    {"elementType": "geometry", "stylers": [{"color": "#212121"}]},
    {"elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
    {"elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
    {"elementType": "labels.text.stroke", "stylers": [{"color": "#212121"}]},
    {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#2c2c2c"}]},
    {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#000000"}]}
  ]
  ''';
}
