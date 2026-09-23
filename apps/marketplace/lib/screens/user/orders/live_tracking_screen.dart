// lib/screens/user/orders/live_tracking_screen.dart
import 'dart:async';
import 'dart:math';
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
import 'widgets/tracking_marker_icons.dart';

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

  // Phase DLV-3B: the rider leg and the rider's live position replace the
  // one-time order.deliveryPartner copy (which never moved) and the ETA
  // invented from the order status.
  DeliveryTaskModel? _task;
  RiderLivePoint? _live;
  DeliveryEta? _eta;
  LatLng? _riderShown;
  LatLng? _moveFrom;
  LatLng? _moveTo;
  late AnimationController _moveController;
  StreamSubscription? _taskSubscription;
  StreamSubscription? _liveSubscription;
  EtaStage? _fittedForStage;
  TrackingMarkerIcons? _icons;
  bool _fittedOnce = false;
  
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
    _loadMarkerIcons();
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

    // The rider marker glides to each new position instead of jumping.
    _moveController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..addListener(() {
        final from = _moveFrom, to = _moveTo;
        if (from == null || to == null || !mounted) return;
        final t = Curves.easeInOut.transform(_moveController.value);
        setState(() {
          _riderShown = LatLng(
            from.latitude + (to.latitude - from.latitude) * t,
            from.longitude + (to.longitude - from.longitude) * t,
          );
          _updateMapMarkers();
        });
      });
  }

  Future<void> _loadMarkerIcons() async {
    try {
      final icons = await TrackingMarkerIcons.build();
      if (!mounted) return;
      setState(() {
        _icons = icons;
        _updateMapMarkers();
      });
    } catch (e) {
      // Default pins remain.
      debugPrint('Marker icons: $e');
    }
  }

  void _loadOrderData() {
    // After the first frame: loadOrderById notifies listeners, which threw
    // 'setState() or markNeedsBuild() called during build' from initState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<OrderProvider>().loadOrderById(widget.orderId);
    });
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
    _taskSubscription =
        _trackingService.streamTask(widget.orderId).listen((task) {
      if (!mounted) return;
      setState(() {
        _task = task;
        _updateMapMarkers();
        _calculateETA();
      });
    }, onError: (Object e) => debugPrint('Delivery task stream: $e'));
    _liveSubscription =
        _trackingService.streamLivePoint(widget.orderId).listen((live) {
      if (!mounted) return;
      _live = live;
      if (live != null) {
        final next = LatLng(live.lat, live.lng);
        if (_riderShown == null) {
          _riderShown = next;
        } else {
          _moveFrom = _riderShown;
          _moveTo = next;
          _moveController.forward(from: 0);
        }
      }
      setState(() {
        _updateMapMarkers();
        _calculateETA();
      });
    }, onError: (Object e) => debugPrint('Rider live point stream: $e'));
  }

  /// The drop point: the task's (set by the server) or the order address.
  LatLng? get _dropLatLng {
    final d = _task?.drop;
    if (d != null) return LatLng(d.lat, d.lng);
    final a = _order?.deliveryAddress;
    if (a?.latitude != null && a?.longitude != null) {
      return LatLng(a!.latitude!, a.longitude!);
    }
    return null;
  }

  bool get _riderLegActive => const {
        DeliveryTaskStatus.assigned,
        DeliveryTaskStatus.atPickup,
        DeliveryTaskStatus.pickedUp,
        DeliveryTaskStatus.enRoute,
        DeliveryTaskStatus.atDrop,
      }.contains(_task?.status);

  bool get _beforePickup =>
      _task?.status == DeliveryTaskStatus.assigned ||
      _task?.status == DeliveryTaskStatus.atPickup;

  void _startETATimer() {
    // Re-evaluates the ETA and the 'location updated' note as time passes.
    _etaTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(_calculateETA);
    });
  }

  void _calculateETA() {
    final drop = _dropLatLng;
    final eta = DeliveryEtaCalculator.estimate(
      status: _task?.status,
      rider: _live,
      pickup: _task?.pickup,
      drop: drop == null ? null : DeliveryPoint(lat: drop.latitude, lng: drop.longitude),
      now: DateTime.now(),
    );
    _eta = eta;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fitCameraIfNeeded();
    });
  }

  /// Frames rider and next stop once, and again when the rider picks up.
  Future<void> _fitCameraIfNeeded() async {
    final controller = _mapController;
    final rider = _riderShown;
    final target = _beforePickup && _task?.pickup != null
        ? LatLng(_task!.pickup!.lat, _task!.pickup!.lng)
        : _dropLatLng;
    if (controller == null || rider == null || target == null) return;
    final stage = _eta?.stage;
    if (_fittedOnce && stage == _fittedForStage) return;
    _fittedOnce = true;
    _fittedForStage = stage;
    final bounds = LatLngBounds(
      southwest: LatLng(min(rider.latitude, target.latitude), min(rider.longitude, target.longitude)),
      northeast: LatLng(max(rider.latitude, target.latitude), max(rider.longitude, target.longitude)),
    );
    try {
      const pad = 60.0;
      await controller.moveCamera(CameraUpdate.newLatLngBounds(bounds, pad));
      // The ETA card covers the top of the map and the sheet the bottom 35%:
      // zoom out until the framed span fits the visible band between them,
      // then centre it there (seen on the browser run: the store sat under
      // the sheet).
      if (!mounted) return;
      final media = MediaQuery.of(context);
      final h = media.size.height;
      final bandTop = media.padding.top + 170;
      final bandBottom = h * 0.65;
      final band = bandBottom - bandTop;
      final span = h - 2 * pad;
      if (band > 0 && span > band) {
        await controller.moveCamera(CameraUpdate.zoomBy(-(log(span / band) / ln2)));
      }
      await controller.animateCamera(
          CameraUpdate.scrollBy(0, h / 2 - (bandTop + bandBottom) / 2));
    } catch (e) {
      // Map not laid out yet (web): try again shortly.
      debugPrint('Tracking camera fit failed: $e');
      _fittedOnce = false;
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _fitCameraIfNeeded();
      });
    }
  }

  void _updateMapMarkers() {
    if (_order == null) return;
    final markers = <Marker>{};
    final polylines = <Polyline>{};
    final drop = _dropLatLng;
    final pickup = _task?.pickup;

    if (drop != null) {
      markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: drop,
        icon: _icons?.home ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        anchor: _icons == null ? const Offset(0.5, 1) : const Offset(0.5, 0.5),
        infoWindow: const InfoWindow(title: 'Delivery location'),
      ));
    }
    // The store, until the rider has picked the order up.
    if (pickup != null && (_beforePickup || _task?.status == DeliveryTaskStatus.searching)) {
      markers.add(Marker(
        markerId: const MarkerId('store'),
        position: LatLng(pickup.lat, pickup.lng),
        icon: _icons?.store ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        anchor: _icons == null ? const Offset(0.5, 1) : const Offset(0.5, 0.5),
        infoWindow: const InfoWindow(title: 'Store'),
      ));
    }
    // The rider shows while they hold the order (not while searching or
    // after delivery) — independent of whether an ETA could be computed.
    final rider = _riderShown;
    if (rider != null && _riderLegActive) {
      markers.add(Marker(
        markerId: const MarkerId('partner'),
        position: rider,
        zIndexInt: 2,
        anchor: const Offset(0.5, 0.5),
        icon: _icons?.rider ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: _partner?.name ?? 'Delivery partner'),
      ));
      // A straight guide to where the rider goes next (not a road route).
      final next = _beforePickup && pickup != null ? LatLng(pickup.lat, pickup.lng) : drop;
      if (next != null) {
        polylines.add(Polyline(
          polylineId: const PolylineId('route'),
          points: [rider, next],
          color: const Color(0xFF2D7D3C),
          width: 4,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ));
      }
    }

    _markers = markers;
    _polylines = polylines;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _orderSubscription?.cancel();
    _taskSubscription?.cancel();
    _liveSubscription?.cancel();
    _moveController.dispose();
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
        _fitCameraIfNeeded();
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
              color: Colors.black.withValues(alpha: 0.15),
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
                          color: const Color(0xFF2D7D3C).withValues(alpha: 0.4),
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
                  if (_eta != null) ...[
                    Text(
                      DeliveryEtaCalculator.label(_eta!),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    DeliveryTrackingService.stageMessage(
                        _task?.status, _order?.orderStatus ?? 'pending'),
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  if (_eta?.fromStaleLocation == true) ...[
                    const SizedBox(height: 4),
                    Text(
                      locationAgeMessage(_live?.age(DateTime.now())),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.orange[300] : Colors.orange[800],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Delivery icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF2D7D3C).withValues(alpha: 0.1),
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
                color: Colors.black.withValues(alpha: 0.1),
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
                color: Colors.black.withValues(alpha: 0.15),
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
                          color: const Color(0xFF2D7D3C).withValues(alpha: 0.1),
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
                        // DLV-3B: overflowed by 22 px at phone width once the
                        // rider card showed for every accepted order.
                        Flexible(
                          child: Text(
                            _partner!.vehicleNumber,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
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
            DeliveryTrackingService.stageMessage(
                _task?.status, _order?.orderStatus ?? 'pending'),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your delivery partner will show here once assigned',
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

  void _chatWithPartner() async {
    if (_partner?.phone != null) {
      final orderNum = _order?.orderNumber ?? '';
      final body = Uri.encodeComponent('Hi, regarding my Agrimore order #$orderNum');
      final url = Uri.parse('sms:${_partner!.phone}?body=$body');
      try {
        await launchUrl(url);
      } catch (e) {
        // Fallback to plain SMS if body param not supported
        final fallbackUrl = Uri.parse('sms:${_partner!.phone}');
        await launchUrl(fallbackUrl);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery partner contact not available yet')),
        );
      }
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
