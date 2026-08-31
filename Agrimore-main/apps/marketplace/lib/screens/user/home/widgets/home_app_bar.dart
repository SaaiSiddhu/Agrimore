import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../../app/routes.dart';
import '../../../../providers/theme_provider.dart';
import '../../../../providers/category_provider.dart';
import '../../../../providers/shop_entry_provider.dart';
import '../../../../providers/address_provider.dart';
import '../../../../providers/cart_provider.dart';
import '../../../../providers/wallet_provider.dart';
import '../../../../providers/market_mode_provider.dart';
import '../../../../providers/auth_provider.dart' as app_auth;
import '../../profile/profile_screen.dart';
import 'address_bottom_sheet.dart';

class HomeAppBar extends StatefulWidget {
  final bool isCollapsed;

  const HomeAppBar({Key? key, this.isCollapsed = false}) : super(key: key);

  @override
  State<HomeAppBar> createState() => _HomeAppBarState();
}

class _HomeAppBarState extends State<HomeAppBar> {
  int _selectedCategoryIndex = 0;

  // Auto-location state (fallback only if no saved addresses)
  String _autoLocationText = '';
  bool _isLoadingAutoLocation = true;
  bool _isMounted = true;

  @override
  void initState() {
    super.initState();
    // Load saved addresses first
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<AddressProvider>(context, listen: false).loadAddresses();
      }
    });
    // Also get auto-location as fallback
    _getCurrentLocationAddress();
  }

  @override
  void dispose() {
    _isMounted = false;
    super.dispose();
  }

  void _safeSyncState(VoidCallback callback) {
    if (_isMounted && mounted) {
      try {
        setState(callback);
      } catch (e) {
        debugPrint('⚠️ Error in setState: $e');
      }
    }
  }

  Future<void> _getCurrentLocationAddress() async {
    if (!_isMounted) return;

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _safeSyncState(() => _isLoadingAutoLocation = false);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        _safeSyncState(() => _isLoadingAutoLocation = false);
        return;
      }

      if (!_isMounted) return;

      Position? pos;
      try {
        pos = await Geolocator.getLastKnownPosition();
      } catch (_) {}

      if (pos == null) {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 10),
        );
      }

      if (!_isMounted) return;

      try {
        final placemarks =
            await placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (placemarks.isNotEmpty && _isMounted) {
          final locality = placemarks.first.locality ?? '';
          final subLocality = placemarks.first.subLocality ?? '';
          final adminArea = placemarks.first.administrativeArea ?? '';
          final district = placemarks.first.subAdministrativeArea ?? locality;

          String locationText;
          if (subLocality.isNotEmpty && locality.isNotEmpty) {
            locationText = '$subLocality, $locality';
          } else if (subLocality.isNotEmpty) {
            locationText = subLocality;
          } else if (locality.isNotEmpty) {
            locationText = locality;
          } else if (adminArea.isNotEmpty) {
            locationText = adminArea;
          } else {
            locationText = 'Current Location';
          }

          _safeSyncState(() {
            _autoLocationText = locationText;
            _isLoadingAutoLocation = false;
          });
          await _saveLocationTargeting(
            lat: pos.latitude,
            lng: pos.longitude,
            state: adminArea,
            district: district,
            displayLocation: locationText,
          );
          return;
        }
      } catch (e) {
        debugPrint('⚠️ Native Geocoding error: $e');
      }

      // Fallback to HTTP Geocoding (especially for Web)
      if (_isMounted) {
        try {
          const apiKey = MapsConfig.apiKey;
          final url =
              'https://maps.googleapis.com/maps/api/geocode/json?latlng=${pos.latitude},${pos.longitude}&key=$apiKey&language=en';
          final response = await http
              .get(Uri.parse(url))
              .timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['status'] == 'OK' &&
                data['results'] != null &&
                (data['results'] as List).isNotEmpty) {
              final components =
                  data['results'][0]['address_components'] as List;
              String locality = '';
              String subLocality = '';
              String adminArea = '';

              for (final c in components) {
                final types = (c['types'] as List).cast<String>();
                if (types.contains('locality'))
                  locality = c['long_name'];
                else if (types.contains('sublocality'))
                  subLocality = c['long_name'];
                else if (types.contains('administrative_area_level_1'))
                  adminArea = c['long_name'];
              }

              String locationText;
              if (subLocality.isNotEmpty && locality.isNotEmpty) {
                locationText = '$subLocality, $locality';
              } else if (subLocality.isNotEmpty) {
                locationText = subLocality;
              } else if (locality.isNotEmpty) {
                locationText = locality;
              } else if (adminArea.isNotEmpty) {
                locationText = adminArea;
              } else {
                locationText = 'Current Location';
              }

              _safeSyncState(() {
                _autoLocationText = locationText;
                _isLoadingAutoLocation = false;
              });
              await _saveLocationTargeting(
                lat: pos.latitude,
                lng: pos.longitude,
                state: adminArea,
                district: locality,
                displayLocation: locationText,
              );
              return;
            }
          }
        } catch (e) {
          debugPrint('⚠️ HTTP Geocoding error: $e');
        }

        _safeSyncState(() {
          _autoLocationText = 'Current Location';
          _isLoadingAutoLocation = false;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Location error: $e');
      if (_isMounted) {
        _safeSyncState(() => _isLoadingAutoLocation = false);
      }
    }
  }

  Future<void> _saveLocationTargeting({
    required double lat,
    required double lng,
    required String state,
    required String district,
    required String displayLocation,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('selected_latitude', lat);
    await prefs.setDouble('selected_longitude', lng);
    if (state.trim().isNotEmpty) {
      await prefs.setString('selected_state', state.trim());
    }
    if (district.trim().isNotEmpty) {
      await prefs.setString('selected_district', district.trim());
    }
    await prefs.setString('selected_location', displayLocation);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final marketMode = Provider.of<MarketModeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final isB2B = marketMode.isB2B;

    // Amber/gold in B2B mode, the usual emerald-jade otherwise — a
    // full-bar colour shift so B2B is unmistakable at a glance, not just a
    // small badge someone could miss.
    final gradientColors = isB2B
        ? (isDark
            ? const [Color(0xFF451A03), Color(0xFF291102)]
            : const [Color(0xFFD97706), Color(0xFFB45309), Color(0xFF9A3412)])
        : (isDark
            ? const [Color(0xFF0D3D2B), Color(0xFF0A2F22)]
            : const [Color(0xFF0D9B5C), Color(0xFF06804A)]);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top section - Only show when not collapsed
            if (!widget.isCollapsed) ...[
              _buildTopRow(isDark, isB2B),
              const SizedBox(height: 6),
            ],
            // Search bar + B2B toggle - always visible
            _buildSearchBar(isDark, isB2B),
            const SizedBox(height: 6),
            // Categories - always visible
            _buildCategoryChips(isDark),
            const SizedBox(height: 6), // Space below categories
          ],
        ),
      ),
    );
  }

  Widget _buildTopRow(bool isDark, bool isB2B) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          // Left: Brand + Location
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Brand name with lightning
                Row(
                  children: [
                    Text(
                      isB2B ? 'Agrimore B2B' : 'Agrimore',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isB2B
                            ? Colors.white.withOpacity(0.25)
                            : Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isB2B
                              ? Colors.white.withOpacity(0.4)
                              : Colors.amber.withOpacity(0.3),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isB2B ? Icons.local_shipping_rounded : Icons.bolt,
                            size: 14,
                            color: isB2B ? Colors.white : Colors.amber[300],
                          ),
                          const SizedBox(width: 3),
                          Text(
                            isB2B ? 'Bulk Freight' : '30 min',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isB2B ? Colors.white : Colors.amber[100],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                // Location - Prioritizes saved address, falls back to auto-detected
                Consumer<AddressProvider>(
                  builder: (context, addressProvider, _) {
                    // Determine what to display
                    final hasSavedAddress =
                        addressProvider.addresses.isNotEmpty;
                    final defaultAddress = hasSavedAddress
                        ? addressProvider.addresses.firstWhere(
                            (a) => a.isDefault,
                            orElse: () => addressProvider.addresses.first,
                          )
                        : null;

                    // Priority: 1. Saved/Selected address, 2. Auto-detected, 3. Fallback
                    String displayLocation;
                    IconData locationIcon;
                    Color iconColor;
                    String? addressLabel;

                    if (hasSavedAddress && defaultAddress != null) {
                      // Show saved address - House, Road, City, State, Pincode
                      final parts = <String>[];
                      if (defaultAddress.addressLine1.isNotEmpty)
                        parts.add(defaultAddress.addressLine1);
                      if (defaultAddress.addressLine2.isNotEmpty)
                        parts.add(defaultAddress.addressLine2);
                      if (defaultAddress.city.isNotEmpty)
                        parts.add(defaultAddress.city);
                      if (defaultAddress.state.isNotEmpty)
                        parts.add(defaultAddress.state);
                      if (defaultAddress.zipcode.isNotEmpty)
                        parts.add(defaultAddress.zipcode);
                      displayLocation = parts.isNotEmpty
                          ? parts.join(', ')
                          : defaultAddress.fullAddress;
                      locationIcon = Icons.home_rounded;
                      iconColor = Colors.greenAccent;
                      addressLabel = defaultAddress.addressType?.toUpperCase();
                    } else if (_autoLocationText.isNotEmpty) {
                      // Show auto-detected location
                      displayLocation = _autoLocationText;
                      locationIcon = Icons.my_location;
                      iconColor = Colors.cyanAccent;
                      addressLabel = null;
                    } else if (_isLoadingAutoLocation) {
                      // Still loading
                      displayLocation = 'Detecting location...';
                      locationIcon = Icons.location_searching;
                      iconColor = Colors.white70;
                      addressLabel = null;
                    } else {
                      // Fallback
                      displayLocation = 'Set delivery location';
                      locationIcon = Icons.add_location_alt;
                      iconColor = Colors.white70;
                      addressLabel = null;
                    }
                    // Clickable address row (plain text style)
                    return GestureDetector(
                      onTap: () => AddressBottomSheet.show(context),
                      child: Row(
                        children: [
                          // Address Type Badge or Icon
                          if (hasSavedAddress && addressLabel != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(locationIcon,
                                      size: 12, color: iconColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    addressLabel,
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                          ] else ...[
                            if (_isLoadingAutoLocation && !hasSavedAddress)
                              SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  valueColor:
                                      AlwaysStoppedAnimation(Colors.white70),
                                ),
                              )
                            else
                              Icon(locationIcon, size: 12, color: iconColor),
                            const SizedBox(width: 4),
                          ],
                          // Address Text
                          Flexible(
                            child: Text(
                              displayLocation,
                              style: TextStyle(
                                fontSize: 11,
                                color: hasSavedAddress
                                    ? Colors.white
                                    : Colors.white70,
                                fontWeight: hasSavedAddress
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(Icons.keyboard_arrow_down,
                              size: 14, color: Colors.white70),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          // Right: Wallet + Profile avatar
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Consumer<WalletProvider>(
                builder: (context, walletProvider, _) {
                  final balance = walletProvider.balance;
                  final displayBalance = balance >= 1000
                      ? '₹${(balance / 1000).toStringAsFixed(1)}k'
                      : '₹${balance.toStringAsFixed(0)}';
                  return _buildIconBtn(
                    Icons.account_balance_wallet_outlined,
                    displayBalance,
                    isDark,
                    onTap: () => Navigator.pushNamed(context, AppRoutes.wallet),
                  );
                },
              ),
              const SizedBox(width: 10),
              _buildProfileAvatar(isDark, isB2B),
            ],
          ),
        ],
      ),
    );
  }

  // Was missing entirely before — the home app bar had a Wallet button but
  // no way to reach Profile except through the bottom nav. Ported from the
  // reference build: a small circular avatar (photo, or the user's first
  // initial as a fallback) that pushes ProfileScreen directly.
  Widget _buildProfileAvatar(bool isDark, bool isB2B) {
    return Consumer<app_auth.AuthProvider>(
      builder: (context, authProvider, _) {
        final user = authProvider.currentUser;
        final photoUrl = user?.photoUrl;
        final userName = user?.name ?? 'U';
        final initial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
          },
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? AppColors.surfaceDark : const Color(0xFFFEF3C7),
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: (photoUrl != null && photoUrl.isNotEmpty)
                  ? Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(
                          initial,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: isB2B ? const Color(0xFFD97706) : AppColors.primary,
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        initial,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: isB2B ? const Color(0xFFD97706) : AppColors.primary,
                        ),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIconBtn(IconData icon, String? badge, bool isDark,
      {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            if (badge != null) ...[
              const SizedBox(width: 4),
              Text(badge,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark, bool isB2B) {
    final accent = isB2B
        ? const Color(0xFFD97706)
        : (isDark ? AppColors.primaryLight : AppColors.primary);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () async {
                HapticFeedback.lightImpact();
                final result = await Navigator.pushNamed(context, AppRoutes.search);
                if (result != null && result is String && result.isNotEmpty) {
                  // Navigate to shop tab with search query
                  if (context.mounted) {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.shopWithSearch,
                      arguments: result,
                    );
                  }
                }
              },
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    Icon(Icons.search, size: 22, color: isB2B ? accent : (isDark ? Colors.grey[400] : const Color(0xFF2E7D32))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isB2B ? 'Search wholesale & bulk items...' : 'Search groceries, dairy, snacks...',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.mic, size: 18, color: accent),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _buildB2BSwitch(isB2B),
        ],
      ),
    );
  }

  // Was missing entirely before — MarketModeProvider/isB2B already existed
  // and drove pricing on other screens (see profile_screen.dart's B2B
  // SwitchListTile), but nothing on the home screen itself let a user
  // reach that toggle without going to Profile first. Ported from the
  // reference build's Zomato-style pill switch.
  Widget _buildB2BSwitch(bool isB2B) {
    return Consumer<MarketModeProvider>(
      builder: (context, marketMode, _) {
        return GestureDetector(
          onTap: () {
            HapticFeedback.heavyImpact();
            marketMode.setB2B(!isB2B);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'B2B\nMODE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.8,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 3),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                width: 38,
                height: 20,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: isB2B ? const Color(0xFFFEF08A) : Colors.white.withOpacity(0.35),
                  border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.0),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  alignment: isB2B ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isB2B ? const Color(0xFFD97706) : Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryChips(bool isDark) {
    return Consumer<CategoryProvider>(
      builder: (context, categoryProvider, _) {
        final categories = categoryProvider.categories
            .where((c) =>
                c.isActive &&
                (c.parentId == null || c.parentId!.trim().isEmpty))
            .toList()
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

        final allItems = [
          {'name': 'All', 'icon': Icons.apps},
          ...categories.map((c) => {'name': c.name, 'icon': _getIcon(c.name)}),
        ];

        return SizedBox(
          height: 34,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: allItems.length,
            itemBuilder: (context, index) {
              final item = allItems[index];
              final isSelected = _selectedCategoryIndex == index;

              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _selectedCategoryIndex = index);
                  final shopEntry =
                      Provider.of<ShopEntryProvider>(context, listen: false);
                  if (index == 0) {
                    shopEntry.clearCategoryFilter();
                    shopEntry.openShopWithCategory();
                  } else {
                    final cat = categories[index - 1];
                    shopEntry.openShopWithCategory(
                      categoryId: cat.id,
                      categoryName: cat.name,
                    );
                  }
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item['icon'] as IconData,
                        size: 14,
                        color: isSelected
                            ? (isDark
                                ? AppColors.primaryLight
                                : AppColors.primary)
                            : Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item['name'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected
                              ? (isDark
                                  ? AppColors.primaryLight
                                  : AppColors.primary)
                              : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  IconData _getIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('bath') || n.contains('wash')) return Icons.soap;
    if (n.contains('biscuit') || n.contains('cookie')) return Icons.cookie;
    if (n.contains('chip') || n.contains('namkeen')) return Icons.fastfood;
    if (n.contains('chocolate') || n.contains('candy')) return Icons.cake;
    if (n.contains('detergent') || n.contains('clean'))
      return Icons.cleaning_services;
    if (n.contains('oil')) return Icons.water_drop;
    if (n.contains('hair')) return Icons.face;
    if (n.contains('sweet')) return Icons.icecream;
    if (n.contains('masala') || n.contains('spice'))
      return Icons.local_fire_department;
    if (n.contains('milk') || n.contains('dairy')) return Icons.egg;
    if (n.contains('noodle') || n.contains('pasta')) return Icons.ramen_dining;
    if (n.contains('oral') || n.contains('tooth')) return Icons.auto_fix_high;
    if (n.contains('salt') || n.contains('sugar')) return Icons.grain;
    if (n.contains('tea') || n.contains('coffee')) return Icons.coffee;
    return Icons.category;
  }
}
