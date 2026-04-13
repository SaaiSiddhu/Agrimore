import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:ui' as ui;

import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../../providers/address_provider.dart';
import '../../../../providers/theme_provider.dart';
import '../../../user/profile/saved_addresses_screen.dart';
import 'sort_bottom_sheet.dart';

const double kAppBarHeight = 138; // Compact height for professional look

class ShopAppBar extends StatefulWidget implements PreferredSizeWidget {
  final bool showViewToggle;
  final VoidCallback? onViewToggle;
  final bool isGridView;
  final String title;
  final String sortBy;
  final Function(String) onSortChanged;
  final int activeFiltersCount;
  final VoidCallback onFilterTap;
  final Function(String)? onSearchChanged;
  final TextEditingController? searchController;

  const ShopAppBar({
    Key? key,
    this.showViewToggle = true, // Default to showing toggle
    this.onViewToggle,
    this.isGridView = true,
    this.title = 'Shop',
    this.sortBy = 'newest',
    required this.onSortChanged,
    this.activeFiltersCount = 0,
    required this.onFilterTap,
    this.onSearchChanged,
    this.searchController,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kAppBarHeight);

  @override
  State<ShopAppBar> createState() => _ShopAppBarState();
}

class _ShopAppBarState extends State<ShopAppBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String _currentLocationText = 'Fetching location...';
  bool _isLoadingLocation = false;

  bool _isMounted = true;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _getCurrentLocationAddress();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
            begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
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
      _safeSyncState(() => _isLoadingLocation = true);
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _safeSyncState(() {
          _currentLocationText = 'Location disabled';
          _isLoadingLocation = false;
        });
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        _safeSyncState(() {
          _currentLocationText = 'Location denied';
          _isLoadingLocation = false;
        });
        return;
      }
      if (!_isMounted) return;
      
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 4),
      );

      if (!_isMounted) return;

      final placemarks =
          await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty && _isMounted) {
        final city = placemarks.first.locality ??
            placemarks.first.administrativeArea ??
            '';
        final pin = placemarks.first.postalCode ?? '';
        _safeSyncState(() {
          _currentLocationText = pin.isEmpty ? city : '$city, $pin';
          _isLoadingLocation = false;
        });
      }
    } catch (_) {
      if (_isMounted) {
        _safeSyncState(() {
          _currentLocationText = 'Set delivery location';
          _isLoadingLocation = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _isMounted = false;
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      const Color(0xFF1E1E1E),
                      const Color(0xFF2D3A2D),
                      const Color(0xFF3A4D3A),
                    ]
                  : [
                      const Color(0xFF2D7D3C),
                      const Color(0xFF3DA34E),
                      const Color(0xFF4DB85F),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: const [0.0, 0.5, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: (isDark ? Colors.black : const Color(0xFF2D7D3C))
                    .withOpacity(isDark ? 0.5 : 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Opacity(
                    opacity: isDark ? 0.05 : 0.08,
                    child: CustomPaint(painter: PremiumPatternPainter()),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                      child: Column(
                        children: [
                          // Row 1: Title, Icons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  widget.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18, // Compact professional size
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Only show view toggle if enabled
                                  if (widget.showViewToggle && widget.onViewToggle != null)
                                    _buildIconButton(
                                      context,
                                      icon: widget.isGridView
                                          ? Icons.grid_view_rounded
                                          : Icons.view_list_rounded,
                                      badge: 0,
                                      isDark: isDark,
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        widget.onViewToggle!();
                                      },
                                    ),
                                  if (widget.showViewToggle && widget.onViewToggle != null)
                                    const SizedBox(width: 6),
                                  _buildIconButton(
                                    context,
                                    icon: Icons.tune_rounded,
                                    badge: widget.activeFiltersCount,
                                    isDark: isDark,
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      widget.onFilterTap();
                                    },
                                  ),
                                  const SizedBox(width: 6),
                                  _buildIconButton(
                                    context,
                                    icon: Icons.sort_rounded,
                                    badge: 0,
                                    isDark: isDark,
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      showModalBottomSheet(
                                        context: context,
                                        backgroundColor: Colors.transparent,
                                        isScrollControlled: true,
                                        builder: (context) => SortBottomSheet(
                                          currentSort: widget.sortBy,
                                          onSort: widget.onSortChanged,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildSearchBar(isDark),
                          const SizedBox(height: 6),
                          _buildLocationLine(context, isDark),
                          const SizedBox(height: 6), // Compact bottom padding
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Icon(
              Icons.search_rounded,
              color: isDark ? AppColors.primaryLight : const Color(0xFF2D7D3C),
              size: 18,
            ),
          ),
          Expanded(
            child: TextField(
              controller: widget.searchController,
              onChanged: widget.onSearchChanged,
              textInputAction: TextInputAction.search,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Search products, brands...',
                hintStyle: TextStyle(
                  color: isDark ? Colors.grey[500] : Colors.grey[400],
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              ),
            ),
          ),
          if (widget.searchController?.text.isNotEmpty ?? false)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    widget.searchController?.clear();
                    widget.onSearchChanged?.call("");
                    HapticFeedback.selectionClick();
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close_rounded,
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                      size: 16,
                    ),
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: 10),
        ],
      ),
    );
  }

  Widget _buildLocationLine(BuildContext context, bool isDark) {
    return Consumer<AddressProvider>(
      builder: (context, addressProvider, _) {
        final address = addressProvider.addresses.isNotEmpty
            ? addressProvider.addresses.firstWhere(
                (a) => a.isDefault,
                orElse: () => addressProvider.addresses.first,
              )
            : null;
        final displayLoc = address != null
            ? '${address.city}, ${address.state}'
            : _currentLocationText;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withOpacity(isDark ? 0.15 : 0.25),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 12,
                color: Colors.yellow[isDark ? 400 : 300],
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _isLoadingLocation
                      ? 'Fetching location...'
                      : 'Deliver to: ${displayLoc.isEmpty ? 'Set Location' : displayLoc}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(isDark ? 0.9 : 0.85),
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SavedAddressesScreen()),
                    ).then((result) {
                      if (result == true) {
                        addressProvider.loadAddresses();
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (isDark
                              ? AppColors.primaryLight
                              : const Color(0xFF2D7D3C))
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Change',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.primaryLight
                            : const Color(0xFF2D7D3C),
                      ),
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

  Widget _buildIconButton(
    BuildContext context, {
    required IconData icon,
    required int badge,
    required bool isDark,
    required VoidCallback onTap,
    Color badgeColor = Colors.red,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(isDark ? 0.15 : 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withOpacity(isDark ? 0.2 : 0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              if (badge > 0)
                Positioned(
                  right: -8,
                  top: -8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [badgeColor.withOpacity(0.9), badgeColor],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: badgeColor.withOpacity(0.7),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    constraints:
                        const BoxConstraints(minWidth: 20, minHeight: 20),
                    child: Text(
                      badge > 99 ? '99+' : badge.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class PremiumPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1;

    for (int i = 0; i < size.width; i += 40) {
      canvas.drawLine(
        Offset(i.toDouble(), 0),
        Offset(i.toDouble(), size.height),
        paint,
      );
    }

    for (int i = 0; i < size.height; i += 40) {
      canvas.drawLine(
        Offset(0, i.toDouble()),
        Offset(size.width, i.toDouble()),
        paint,
      );
    }

    final circlePaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(
        Offset(size.width * (0.25 + i * 0.3), size.height * 0.5),
        60 + i * 15,
        circlePaint,
      );
    }

    final accentPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;

    for (int i = 0; i < (size.width + size.height); i += 80) {
      canvas.drawLine(
        Offset(i.toDouble(), 0),
        Offset(i.toDouble() - size.height, size.height),
        accentPaint,
      );
    }
  }

  @override
  bool shouldRepaint(PremiumPatternPainter oldDelegate) => false;
}