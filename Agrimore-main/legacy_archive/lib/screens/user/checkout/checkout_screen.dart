import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../app/themes/app_colors.dart';
import '../../../models/address_model.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/coupon_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../helpers/ad_helper.dart';
import 'add_address_screen.dart';
import 'payment_method_screen.dart';
import 'widgets/checkout_steps.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({Key? key}) : super(key: key);

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  AddressModel? _selectedAddress;
  bool _isLoadingAddresses = true;
  List<AddressModel> _addresses = [];

  // Banner Ad Variables (EXACT MATCH FROM PROFILE)
  BannerAd? _bannerAd;
  AnchoredAdaptiveBannerAdSize? _adSize;
  bool _isBannerAdReady = false;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
    // Initialize ads (EXACT MATCH FROM PROFILE)
    MobileAds.instance.initialize().then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadBannerAd();
      });
    });
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  // EXACT COPY FROM PROFILE SCREEN
  Future<void> _loadBannerAd() async {
    final width = MediaQuery.of(context).size.width.truncate();
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);

    if (size == null || !mounted) return;

    setState(() {
      _adSize = size;
    });

    _bannerAd = BannerAd(
      adUnitId: AdHelper.checkoutBannerAdUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('✅ Checkout Ad loaded successfully!');
          if (mounted) {
            setState(() {
              _isBannerAdReady = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('❌ Checkout Ad failed to load: $error');
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

  Future<void> _loadAddresses() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('addresses')
          .where('userId', isEqualTo: userId)
          .get();

      if (mounted) {
        setState(() {
          _addresses = snapshot.docs
              .map((doc) => AddressModel.fromMap(doc.data()))
              .toList();

          _addresses.sort((a, b) {
            if (a.isDefault && !b.isDefault) return -1;
            if (!a.isDefault && b.isDefault) return 1;
            return 0;
          });

          if (_addresses.isNotEmpty) {
            _selectedAddress = _addresses.firstWhere(
              (addr) => addr.isDefault,
              orElse: () => _addresses.first,
            );
          }

          _isLoadingAddresses = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading addresses: $e');
      if (mounted) setState(() => _isLoadingAddresses = false);
    }
  }

  Future<void> _openInMaps(AddressModel addr) async {
    if (addr.latitude != null && addr.longitude != null) {
      final String googleMapsUrl =
          'https://www.google.com/maps/search/?api=1&query=${addr.latitude},${addr.longitude}';

      final Uri uri = Uri.parse(googleMapsUrl);

      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          _showSnackBar('Could not open maps', isError: true);
        }
      } catch (e) {
        debugPrint('Error opening maps: $e');
        _showSnackBar('Error opening maps', isError: true);
      }
    } else {
      _showSnackBar('Location coordinates not available', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 4,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final backgroundColor = isDark ? const Color(0xFF121212) : Colors.grey[50];

    final cartProvider = context.watch<CartProvider>();
    final couponProvider = context.watch<CouponProvider>();
    final subtotal = cartProvider.subtotal;
    final discount = couponProvider.calculateDiscount();
    final total = subtotal - discount;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: _buildAppBar(isDark, cardColor),
      body: Column(
        children: [
          const CheckoutSteps(currentStep: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildAddressSection(isDark, cardColor, accentColor),
                  const SizedBox(height: 16),
                  
                  // ✅ EXACT MATCH AD BANNER FROM PROFILE
                  _buildAdBanner(_bannerAd, _isBannerAdReady, isDark),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          _buildBottomBar(total, isDark, accentColor, cardColor),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark, Color cardColor) {
    return AppBar(
      backgroundColor: cardColor,
      elevation: 0,
      title: Text(
        'Select Address',
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w800,
          fontSize: 18,
          letterSpacing: -0.3,
        ),
      ),
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : Colors.black87,
            size: 16,
          ),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      centerTitle: true,
    );
  }

  Widget _buildAddressSection(bool isDark, Color cardColor, Color accentColor) {
    return _buildCardSection(
      isDark: isDark,
      cardColor: cardColor,
      title: 'Delivery Address',
      icon: Icons.location_on_rounded,
      accentColor: accentColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isLoadingAddresses)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: CircularProgressIndicator(
                  color: accentColor,
                  strokeWidth: 2.5,
                ),
              ),
            )
          else if (_addresses.isEmpty)
            Column(
              children: [
                Icon(
                  Icons.location_off_rounded,
                  size: 48,
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
                const SizedBox(height: 12),
                Text(
                  'No addresses found',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Please add a delivery address to continue',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],
            )
          else
            Column(
              children: _addresses.map((addr) {
                final isSelected = _selectedAddress?.id == addr.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildDetailedAddressCard(
                    address: addr,
                    isSelected: isSelected,
                    isDark: isDark,
                    accentColor: accentColor,
                    onTap: () {
                      setState(() => _selectedAddress = addr);
                      HapticFeedback.selectionClick();
                    },
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddAddressScreen(),
                ),
              );
              _loadAddresses();
            },
            icon: Icon(
              Icons.add_location_alt_outlined,
              size: 18,
              color: accentColor,
            ),
            label: Text(
              'Add New Address',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: accentColor,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: accentColor, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ EXACT COPY FROM PROFILE SCREEN - SPONSORED BANNER AD
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

  // EXACT SAME ADDRESS CARD FROM PAYMENT SCREEN
  Widget _buildDetailedAddressCard({
    required AddressModel address,
    required bool isSelected,
    required bool isDark,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withOpacity(0.1)
              : (isDark ? Colors.grey[850] : Colors.grey[50]),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? accentColor
                : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
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
                              address.name,
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
                            address.phone,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.grey[300] : Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Map button + Radio button
                Row(
                  children: [
                    if (address.latitude != null && address.longitude != null)
                      IconButton(
                        onPressed: () => _openInMaps(address),
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.map_outlined,
                            color: accentColor,
                            size: 16,
                          ),
                        ),
                        tooltip: 'Open in Maps',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    const SizedBox(width: 8),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? accentColor
                              : (isDark ? Colors.grey[600]! : Colors.grey[400]!),
                          width: 2,
                        ),
                        color: isSelected ? accentColor : Colors.transparent,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 16)
                          : null,
                    ),
                  ],
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
              value: address.addressLine1,
              isDark: isDark,
            ),

            // Address Line 2 (if exists)
            if (address.addressLine2.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildAddressRow(
                icon: Icons.location_city_outlined,
                value: address.addressLine2,
                isDark: isDark,
                isSecondary: true,
              ),
            ],

            // Landmark (if exists)
            if (address.landmark != null && address.landmark!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildAddressRow(
                icon: Icons.place_outlined,
                value: 'Near ${address.landmark}',
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
                  label: address.city,
                  isDark: isDark,
                ),
                _buildLocationChip(
                  icon: Icons.map_outlined,
                  label: address.state,
                  isDark: isDark,
                ),
                _buildLocationChip(
                  icon: Icons.pin_drop_outlined,
                  label: address.zipcode,
                  isDark: isDark,
                ),
              ],
            ),

            // Country (if not India)
            if (address.country.isNotEmpty && address.country != 'India') ...[
              const SizedBox(height: 8),
              _buildLocationChip(
                icon: Icons.flag_outlined,
                label: address.country,
                isDark: isDark,
              ),
            ],

            // Address Type Badge (if exists)
            if (address.addressType != null && address.addressType!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _getAddressTypeColor(address.addressType!).withValues(alpha: 0.15),
                  border: Border.all(
                    color: _getAddressTypeColor(address.addressType!).withValues(alpha: 0.3),
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getAddressTypeIcon(address.addressType!),
                      size: 14,
                      color: _getAddressTypeColor(address.addressType!),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      address.addressType!.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _getAddressTypeColor(address.addressType!),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
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

  Widget _buildCardSection({
    required Widget child,
    required bool isDark,
    required Color cardColor,
    required Color accentColor,
    String? title,
    IconData? icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(icon, color: accentColor, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    title,
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(double total, bool isDark, Color accentColor, Color cardColor) {
    final hasAddress = _selectedAddress != null;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
        border: Border(
          top: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
        ),
      ),
      child: ElevatedButton(
        onPressed: hasAddress
            ? () {
                HapticFeedback.mediumImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PaymentMethodScreen(
                      selectedAddress: _selectedAddress!,
                      total: total,
                    ),
                  ),
                );
              }
            : null,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 54),
          backgroundColor: accentColor,
          foregroundColor: isDark ? Colors.black : Colors.white,
          disabledBackgroundColor: accentColor.withOpacity(0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasAddress ? Icons.arrow_forward_rounded : Icons.location_off_rounded,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              hasAddress ? 'Continue to Payment' : 'Select Address',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
