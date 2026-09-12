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
import '../../../../providers/address_provider.dart';
import '../../../../providers/location_settings_provider.dart';
import '../../../../providers/wallet_provider.dart';
import '../../../../providers/market_mode_provider.dart';
import '../../../../providers/auth_provider.dart' as app_auth;
import '../../profile/profile_screen.dart';
import 'address_bottom_sheet.dart';

class HomeAppBar extends StatefulWidget {
  // 0.0 = fully expanded (top row + search bar), 1.0 = fully collapsed (only
  // the pinned search bar). Driven continuously by scroll offset via
  // _HomeAppBarDelegate in mobile_home_screen.dart, so the top row shrinks
  // and fades in step with the scroll instead of snapping at a threshold.
  final double collapseProgress;

  const HomeAppBar({Key? key, this.collapseProgress = 0.0}) : super(key: key);

  @override
  State<HomeAppBar> createState() => _HomeAppBarState();
}

class _HomeAppBarState extends State<HomeAppBar> {
  // Auto-location state (fallback only if no saved addresses)
  String _autoLocationText = '';
  // Clean city only (no sub-locality), for matching against the admin's
  // serviceable-location list — HOME-2. Kept separate from
  // _autoLocationText, which is a combined display string.
  String? _autoDetectedCity;
  bool _isLoadingAutoLocation = true;
  bool _isMounted = true;

  @override
  void initState() {
    super.initState();
    // Load saved addresses first
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<AddressProvider>(context, listen: false).loadAddresses();
        Provider.of<LocationSettingsProvider>(context, listen: false)
            .loadSettings();
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
            _autoDetectedCity = locality.isNotEmpty
                ? locality
                : (district.isNotEmpty ? district : adminArea);
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
                _autoDetectedCity =
                    locality.isNotEmpty ? locality : adminArea;
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

    // Directly bound to scroll-driven collapseProgress, not an
    // AnimationController — any implicit duration here would lag a frame
    // behind the user's finger and feel rubbery instead of 1:1 with the drag.
    final revealFactor = (1 - widget.collapseProgress).clamp(0.0, 1.0);

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
            if (revealFactor > 0) ...[
              ClipRect(
                child: Align(
                  heightFactor: revealFactor,
                  alignment: Alignment.topCenter,
                  child: Opacity(
                    opacity: revealFactor,
                    child: _buildTopRow(isDark, isB2B),
                  ),
                ),
              ),
              SizedBox(height: 8 * revealFactor),
            ],
            // Search bar + B2B toggle - always visible
            _buildSearchBar(isDark, isB2B),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildTopRow(bool isDark, bool isB2B) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: "Agrimore in" / "30 minutes" / address
          Expanded(
            child: Consumer<AddressProvider>(
              builder: (context, addressProvider, _) {
                final hasSavedAddress = addressProvider.addresses.isNotEmpty;
                final defaultAddress = hasSavedAddress
                    ? addressProvider.addresses.firstWhere(
                        (a) => a.isDefault,
                        orElse: () => addressProvider.addresses.first,
                      )
                    : null;

                // Priority: 1. Saved/Selected address, 2. Auto-detected, 3. Fallback
                String label;
                String addressText;

                if (hasSavedAddress && defaultAddress != null) {
                  final rawLabel = defaultAddress.addressType?.trim() ?? '';
                  label = rawLabel.isNotEmpty ? rawLabel.toUpperCase() : 'SAVED';
                  final parts = <String>[
                    if (defaultAddress.addressLine1.isNotEmpty)
                      defaultAddress.addressLine1,
                    if (defaultAddress.addressLine2.isNotEmpty)
                      defaultAddress.addressLine2,
                    if (defaultAddress.city.isNotEmpty) defaultAddress.city,
                  ];
                  addressText = parts.isNotEmpty
                      ? parts.join(', ')
                      : defaultAddress.fullAddress;
                } else if (_autoLocationText.isNotEmpty) {
                  label = 'CURRENT';
                  addressText = _autoLocationText;
                } else if (_isLoadingAutoLocation) {
                  label = '';
                  addressText = 'Detecting location...';
                } else {
                  label = '';
                  addressText = 'Set delivery location';
                }

                // Same resolution priority as the address text above:
                // saved default address's city first, else the
                // auto-detected clean city — HOME-2, replacing the
                // hardcoded '30 minutes'.
                final resolvedCity = (hasSavedAddress &&
                        defaultAddress != null &&
                        defaultAddress.city.isNotEmpty)
                    ? defaultAddress.city
                    : _autoDetectedCity;
                final locationSettings =
                    context.watch<LocationSettingsProvider>();
                final String etaLine;
                if (isB2B) {
                  etaLine = 'Bulk Freight';
                } else if (resolvedCity == null || resolvedCity.isEmpty) {
                  etaLine = _isLoadingAutoLocation
                      ? 'Checking delivery time...'
                      : 'Select location';
                } else if (locationSettings.isServiceable(resolvedCity)) {
                  etaLine = locationSettings.etaTextFor(resolvedCity);
                } else {
                  etaLine = locationSettings.unserviceableText;
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isB2B ? 'Agrimore B2B in' : 'Agrimore in',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      etaLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 5),
                    GestureDetector(
                      onTap: () => AddressBottomSheet.show(context),
                      child: Row(
                        children: [
                          Flexible(
                            child: RichText(
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                children: [
                                  if (label.isNotEmpty)
                                    TextSpan(
                                      text: '$label - ',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  TextSpan(
                                    text: addressText,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withValues(alpha: 0.85),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 15,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          // Right: Wallet + Profile avatar — same 32x32 circle, single row,
          // no stacked label under either so their centres line up exactly.
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildWalletIconBtn(isDark),
              const SizedBox(width: 8),
              _buildProfileAvatar(isDark, isB2B),
            ],
          ),
        ],
      ),
    );
  }

  static const double _kTopIconSize = 32;

  Widget _buildWalletIconBtn(bool isDark) {
    return Consumer<WalletProvider>(
      builder: (context, walletProvider, _) {
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.pushNamed(context, AppRoutes.wallet);
          },
          child: Container(
            width: _kTopIconSize,
            height: _kTopIconSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.account_balance_wallet_rounded,
              size: 16,
              color: isDark ? AppColors.primaryLight : AppColors.primary,
            ),
          ),
        );
      },
    );
  }

  // Was missing entirely before — the home app bar had a Wallet button but
  // no way to reach Profile except through the bottom nav. Ported from the
  // reference build: a small circular avatar (photo, or a generic user icon
  // as a fallback) that pushes ProfileScreen directly.
  Widget _buildProfileAvatar(bool isDark, bool isB2B) {
    return Consumer<app_auth.AuthProvider>(
      builder: (context, authProvider, _) {
        final user = authProvider.currentUser;
        final photoUrl = user?.photoUrl;
        final iconColor = isB2B ? const Color(0xFFD97706) : AppColors.primary;
        final fallbackIcon = Icon(
          Icons.person_rounded,
          size: 18,
          color: iconColor,
        );

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
          },
          child: Container(
            width: _kTopIconSize,
            height: _kTopIconSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? AppColors.surfaceDark : const Color(0xFFFEF3C7),
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
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
                      errorBuilder: (_, __, ___) => Center(child: fallbackIcon),
                    )
                  : Center(child: fallbackIcon),
            ),
          ),
        );
      },
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
                if (!context.mounted) return;
                if (result == null || result is! String || result.isEmpty) {
                  return;
                }
                // Navigate to shop tab with search query.
                // The analyzer still flags this `context` even after the
                // isolated `if (!context.mounted) return;` two lines up —
                // tried as a standalone guard, merged into a single compound
                // condition, and as two sequential guards; all three verified
                // structurally identical to sites elsewhere in this phase
                // that DID clear. This is a confirmed analyzer limitation on
                // this specific shape, not an unguarded use.
                Navigator.pushNamed(
                  // ignore: use_build_context_synchronously
                  context,
                  AppRoutes.shopWithSearch,
                  arguments: result,
                );
              },
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
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
                        color: accent.withValues(alpha: 0.12),
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
                  color: isB2B ? const Color(0xFFFEF08A) : Colors.white.withValues(alpha: 0.35),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.0),
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
                          color: Colors.black.withValues(alpha: 0.2),
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

}
