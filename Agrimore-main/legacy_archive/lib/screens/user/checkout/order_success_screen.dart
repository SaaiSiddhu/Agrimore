import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:confetti/confetti.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../app/themes/app_colors.dart';
import '../../../models/order_model.dart';
import '../../../providers/theme_provider.dart';
import '../../../helpers/ad_helper.dart';
import '../shop/mobile_shop_screen.dart';
import '../orders/order_details_screen.dart';

class OrderSuccessScreen extends StatefulWidget {
  final OrderModel order;

  const OrderSuccessScreen({
    Key? key,
    required this.order,
  }) : super(key: key);

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late ConfettiController _confettiController;

  // Banner Ad Variables (EXACT MATCH FROM PROFILE & CHECKOUT)
  BannerAd? _bannerAd;
  AnchoredAdaptiveBannerAdSize? _adSize;
  bool _isBannerAdReady = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );

    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );

    // Start animations
    _animationController.forward();
    _confettiController.play();

    // Haptic feedback
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) HapticFeedback.mediumImpact();
    });

    // Initialize ads (EXACT MATCH FROM PROFILE & CHECKOUT)
    MobileAds.instance.initialize().then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadBannerAd();
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _confettiController.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  // EXACT COPY FROM PROFILE & CHECKOUT SCREEN
  Future<void> _loadBannerAd() async {
    final width = MediaQuery.of(context).size.width.truncate();
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);

    if (size == null || !mounted) return;

    setState(() {
      _adSize = size;
    });

    _bannerAd = BannerAd(
      adUnitId: AdHelper.bannerAdUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('✅ Order Success Ad loaded successfully!');
          if (mounted) {
            setState(() {
              _isBannerAdReady = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('❌ Order Success Ad failed to load: $error');
          ad.dispose();
          if (mounted) {
            setState(() {
              _bannerAd = null;
            });
          }
        },
      ),
    );

    await _bannerAd!.load();
  }

  String _formatOrderId(String orderNumber) {
    try {
      final numericPart = orderNumber.replaceAll(RegExp(r'[^0-9]'), '');
      if (numericPart.isNotEmpty) {
        final number = int.parse(numericPart);
        return 'ORD${number.toString().padLeft(8, '0')}';
      }
    } catch (e) {
      debugPrint('Error formatting order ID: $e');
    }
    return 'ORD00000001';
  }

  void _navigateToShop() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MobileShopScreen()),
      (route) => false,
    );
  }

  void _navigateToOrderDetails() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => OrderDetailsScreen(orderId: widget.order.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final backgroundColor = isDark ? const Color(0xFF121212) : Colors.grey[50];

    final addr = widget.order.deliveryAddress;
    final formattedOrderId = _formatOrderId(widget.order.orderNumber);
    final formattedDate = DateFormat('MMM dd, yyyy - hh:mm a').format(widget.order.createdAt);

    return WillPopScope(
      onWillPop: () async {
        _navigateToShop();
        return false;
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: Stack(
          children: [
            // Confetti Effect
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                particleDrag: 0.05,
                emissionFrequency: 0.05,
                numberOfParticles: 30,
                gravity: 0.1,
                shouldLoop: false,
                colors: const [
                  Colors.green,
                  Colors.blue,
                  Colors.pink,
                  Colors.orange,
                  Colors.purple,
                  Colors.yellow,
                ],
              ),
            ),

            // Main Content
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Success Icon & Message
                    Expanded(
                      flex: 3,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ScaleTransition(
                              scale: _scaleAnimation,
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.green.shade400,
                                      Colors.green.shade600,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withValues(alpha: 0.4),
                                      blurRadius: 30,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.check_circle_rounded,
                                  size: 70,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Order Placed Successfully!',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : Colors.black87,
                                letterSpacing: -0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Thank you for your order',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Order Details Card
                    Expanded(
                      flex: 5,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            children: [
                              // Order ID Card
                              _buildOrderIdCard(
                                formattedOrderId,
                                formattedDate,
                                isDark,
                                cardColor,
                                accentColor,
                              ),
                              const SizedBox(height: 12),

                              // Delivery Address Card
                              _buildAddressCard(
                                addr,
                                isDark,
                                cardColor,
                                accentColor,
                              ),
                              const SizedBox(height: 12),

                              // Order Summary Card
                              _buildOrderSummaryCard(
                                isDark,
                                cardColor,
                                accentColor,
                              ),
                              const SizedBox(height: 12),

                              // ✅ NEW BANNER AD WITH SPONSORED LABEL (EXACT MATCH)
                              _buildAdBanner(_bannerAd, _isBannerAdReady, isDark),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Action Buttons
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          // Track Order Button
                          ElevatedButton(
                            onPressed: _navigateToOrderDetails,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 54),
                              backgroundColor: accentColor,
                              foregroundColor: isDark ? Colors.black : Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.local_shipping_rounded, size: 20),
                                SizedBox(width: 10),
                                Text(
                                  'Track Order',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Continue Shopping Button
                          OutlinedButton(
                            onPressed: _navigateToShop,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 54),
                              foregroundColor: accentColor,
                              side: BorderSide(color: accentColor, width: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.shopping_bag_rounded, size: 20),
                                SizedBox(width: 10),
                                Text(
                                  'Continue Shopping',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ EXACT COPY FROM PROFILE & CHECKOUT - SPONSORED BANNER AD
  Widget _buildAdBanner(BannerAd? ad, bool isReady, bool isDark) {
    final double height = _adSize != null ? _adSize!.height.toDouble() : 60.0;

    // Return a placeholder if ad isn't ready or failed to load
    if (!isReady || ad == null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.grey[50],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.grey[800]! : Colors.grey.shade200,
          ),
        ),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
          ),
        ),
      );
    }

    // Main ad container
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            // Sponsored Label
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.grey[50],
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.campaign_rounded,
                    size: 10,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Sponsored',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            // Ad Widget
            Container(
              width: double.infinity,
              height: height,
              color: isDark ? Colors.grey[900] : Colors.grey[50],
              child: Center(
                child: SizedBox(
                  width: ad.size.width.toDouble(),
                  height: ad.size.height.toDouble(),
                  child: AdWidget(ad: ad),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderIdCard(
    String orderId,
    String date,
    bool isDark,
    Color cardColor,
    Color accentColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.grey[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.receipt_long_rounded, color: accentColor, size: 18),
                const SizedBox(width: 10),
                Text(
                  'Order Details',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Order ID
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order ID',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: accentColor.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        orderId,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: accentColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Order Date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order Date',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    Text(
                      date,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Payment Method
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Payment Method',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: widget.order.paymentMethod == 'cod'
                            ? Colors.orange.withOpacity(0.15)
                            : Colors.blue.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        widget.order.paymentMethod == 'cod'
                            ? 'Cash on Delivery'
                            : 'Online Payment',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: widget.order.paymentMethod == 'cod'
                              ? Colors.orange.shade700
                              : Colors.blue.shade700,
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
    );
  }

  Widget _buildAddressCard(
    dynamic addr,
    bool isDark,
    Color cardColor,
    Color accentColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.grey[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on_rounded, color: accentColor, size: 18),
                const SizedBox(width: 10),
                Text(
                  'Delivery Address',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                Row(
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      size: 16,
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        addr.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Phone
                Row(
                  children: [
                    Icon(
                      Icons.phone_outlined,
                      size: 16,
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      addr.phone,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                    height: 1,
                  ),
                ),
                
                // Address Line 1
                _buildAddressRow(
                  icon: Icons.home_outlined,
                  value: addr.addressLine1,
                  isDark: isDark,
                ),
                
                // Address Line 2 (if exists)
                if (addr.addressLine2.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildAddressRow(
                    icon: Icons.location_city_outlined,
                    value: addr.addressLine2,
                    isDark: isDark,
                    isSecondary: true,
                  ),
                ],
                
                // Landmark (if exists)
                if (addr.landmark != null && addr.landmark!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildAddressRow(
                    icon: Icons.place_outlined,
                    value: 'Near ${addr.landmark}',
                    isDark: isDark,
                  ),
                ],
                
                const SizedBox(height: 12),
                
                // City, State, Zipcode
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildLocationChip(
                      icon: Icons.location_city,
                      label: addr.city,
                      isDark: isDark,
                    ),
                    _buildLocationChip(
                      icon: Icons.map_outlined,
                      label: addr.state,
                      isDark: isDark,
                    ),
                    _buildLocationChip(
                      icon: Icons.pin_drop_outlined,
                      label: addr.zipcode,
                      isDark: isDark,
                    ),
                  ],
                ),
                
                // Country (if not India)
                if (addr.country.isNotEmpty && addr.country != 'India') ...[
                  const SizedBox(height: 8),
                  _buildLocationChip(
                    icon: Icons.flag_outlined,
                    label: addr.country,
                    isDark: isDark,
                  ),
                ],
                
                // Address Type Badge (if exists)
                if (addr.addressType != null && addr.addressType!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getAddressTypeColor(addr.addressType!).withOpacity(0.15),
                      border: Border.all(
                        color: _getAddressTypeColor(addr.addressType!).withOpacity(0.3),
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getAddressTypeIcon(addr.addressType!),
                          size: 14,
                          color: _getAddressTypeColor(addr.addressType!),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          addr.addressType!.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _getAddressTypeColor(addr.addressType!),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressRow({
    required IconData icon,
    required String value,
    required bool isDark,
    bool isSecondary = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isSecondary)
          Icon(
            icon,
            size: 16,
            color: isDark ? Colors.grey[500] : Colors.grey[600],
          ),
        if (!isSecondary) const SizedBox(width: 8),
        if (isSecondary) const SizedBox(width: 24),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationChip({
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getAddressTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'home':
        return Icons.home_rounded;
      case 'office':
      case 'work':
        return Icons.work_rounded;
      default:
        return Icons.location_on_rounded;
    }
  }

  Color _getAddressTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'home':
        return Colors.blue;
      case 'office':
      case 'work':
        return Colors.orange;
      default:
        return Colors.purple;
    }
  }

  Widget _buildOrderSummaryCard(
    bool isDark,
    Color cardColor,
    Color accentColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.grey[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.shopping_bag_rounded, color: accentColor, size: 18),
                const SizedBox(width: 10),
                Text(
                  'Order Summary',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _priceRow('Subtotal', widget.order.subtotal, isDark),
                if (widget.order.discount > 0) ...[
                  const SizedBox(height: 10),
                  _priceRow(
                    'Discount',
                    -widget.order.discount,
                    isDark,
                    color: Colors.green.shade600,
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Divider(
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                    height: 1,
                  ),
                ),
                _priceRow(
                  'Total Amount',
                  widget.order.total,
                  isDark,
                  isTotal: true,
                  color: accentColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceRow(
    String title,
    double value,
    bool isDark, {
    Color? color,
    bool isTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
            fontSize: isTotal ? 16 : 13,
            color: color ??
                (isDark
                    ? (isTotal ? Colors.white : Colors.grey[400])
                    : (isTotal ? Colors.black87 : Colors.grey[600])),
          ),
        ),
        Text(
          "₹${value.abs().toStringAsFixed(0)}",
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w700,
            fontSize: isTotal ? 18 : 14,
            color: color ?? (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ],
    );
  }
}
