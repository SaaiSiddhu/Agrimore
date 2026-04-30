import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../../../app/routes.dart';
import '../../../../providers/theme_provider.dart';
import '../../../../providers/category_provider.dart';
import '../../../../providers/shop_entry_provider.dart';
import '../../../../providers/address_provider.dart';
import '../../../../providers/cart_provider.dart';
import '../../../../providers/wallet_provider.dart';
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
      
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );

      if (!_isMounted) return;

      final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty && _isMounted) {
        final locality = placemarks.first.locality ?? '';
        final subLocality = placemarks.first.subLocality ?? '';
        final adminArea = placemarks.first.administrativeArea ?? '';
        
        String locationText;
        if (subLocality.isNotEmpty) {
          locationText = '$subLocality, $locality';
        } else if (locality.isNotEmpty) {
          locationText = locality;
        } else {
          locationText = adminArea;
        }
        
        _safeSyncState(() {
          _autoLocationText = locationText;
          _isLoadingAutoLocation = false;
        });
      } else {
        _safeSyncState(() => _isLoadingAutoLocation = false);
      }
    } catch (e) {
      debugPrint('⚠️ Location error: $e');
      if (_isMounted) {
        _safeSyncState(() => _isLoadingAutoLocation = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0D3D2B), const Color(0xFF0A2F22)]
              : [const Color(0xFF0D9B5C), const Color(0xFF06804A)], // Unique emerald-jade green
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
              _buildTopRow(isDark),
              const SizedBox(height: 6),
            ],
            // Search bar - always visible
            _buildSearchBar(isDark),
            const SizedBox(height: 6),
            // Categories - always visible
            _buildCategoryChips(isDark),
            const SizedBox(height: 6), // Space below categories
          ],
        ),
      ),
    );
  }

  Widget _buildTopRow(bool isDark) {
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
                      'Agrimore',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.amber.withOpacity(0.3), width: 0.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt, size: 14, color: Colors.amber[300]),
                          const SizedBox(width: 3),
                          Text(
                            '30 min',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.amber[100],
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
                    final hasSavedAddress = addressProvider.addresses.isNotEmpty;
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
                      if (defaultAddress.addressLine1.isNotEmpty) parts.add(defaultAddress.addressLine1);
                      if (defaultAddress.addressLine2.isNotEmpty) parts.add(defaultAddress.addressLine2);
                      if (defaultAddress.city.isNotEmpty) parts.add(defaultAddress.city);
                      if (defaultAddress.state.isNotEmpty) parts.add(defaultAddress.state);
                      if (defaultAddress.zipcode.isNotEmpty) parts.add(defaultAddress.zipcode);
                      displayLocation = parts.isNotEmpty ? parts.join(', ') : defaultAddress.fullAddress;
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
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(locationIcon, size: 12, color: iconColor),
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
                                  valueColor: AlwaysStoppedAnimation(Colors.white70),
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
                                color: hasSavedAddress ? Colors.white : Colors.white70,
                                fontWeight: hasSavedAddress ? FontWeight.w500 : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(Icons.keyboard_arrow_down, size: 14, color: Colors.white70),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          // Right: Wallet
          Consumer<WalletProvider>(
            builder: (context, walletProvider, _) {
              final balance = walletProvider.balance;
              final displayBalance = balance >= 1000 
                  ? '₹${(balance/1000).toStringAsFixed(1)}k' 
                  : '₹${balance.toStringAsFixed(0)}';
              return _buildIconBtn(
                Icons.account_balance_wallet_outlined, 
                displayBalance, 
                isDark,
                onTap: () => Navigator.pushNamed(context, AppRoutes.wallet),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildIconBtn(IconData icon, String? badge, bool isDark, {VoidCallback? onTap}) {
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
              Text(badge, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
              Icon(Icons.search, size: 22, color: isDark ? Colors.grey[400] : const Color(0xFF2E7D32)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Search groceries, dairy, snacks...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.primaryLight : AppColors.primary).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.mic,
                  size: 18,
                  color: isDark ? AppColors.primaryLight : AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
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
                  final shopEntry = Provider.of<ShopEntryProvider>(context, listen: false);
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                            ? (isDark ? AppColors.primaryLight : AppColors.primary)
                            : Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item['name'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected 
                              ? (isDark ? AppColors.primaryLight : AppColors.primary)
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
    if (n.contains('detergent') || n.contains('clean')) return Icons.cleaning_services;
    if (n.contains('oil')) return Icons.water_drop;
    if (n.contains('hair')) return Icons.face;
    if (n.contains('sweet')) return Icons.icecream;
    if (n.contains('masala') || n.contains('spice')) return Icons.local_fire_department;
    if (n.contains('milk') || n.contains('dairy')) return Icons.egg;
    if (n.contains('noodle') || n.contains('pasta')) return Icons.ramen_dining;
    if (n.contains('oral') || n.contains('tooth')) return Icons.auto_fix_high;
    if (n.contains('salt') || n.contains('sugar')) return Icons.grain;
    if (n.contains('tea') || n.contains('coffee')) return Icons.coffee;
    return Icons.category;
  }
}
