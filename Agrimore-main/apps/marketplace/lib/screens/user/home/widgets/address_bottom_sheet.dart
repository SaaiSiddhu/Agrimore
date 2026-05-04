import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_services/agrimore_services.dart';
import '../../../../providers/address_provider.dart';
import '../../../../providers/theme_provider.dart';
import '../../../../app/routes.dart';

/// Enhanced compact address selection bottom sheet
class AddressBottomSheet extends StatefulWidget {
  const AddressBottomSheet({Key? key}) : super(key: key);

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddressBottomSheet(),
    );
  }

  @override
  State<AddressBottomSheet> createState() => _AddressBottomSheetState();
}

class _AddressBottomSheetState extends State<AddressBottomSheet> {
  bool _isLoadingCurrentLocation = false;
  String? _currentLocationError;
  String? _currentLocationText;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<AddressProvider>(context, listen: false).loadAddresses();
      }
    });
  }

  Future<void> _useCurrentLocation() async {
    HapticFeedback.lightImpact();
    setState(() {
      _isLoadingCurrentLocation = true;
      _currentLocationError = null;
      _currentLocationText = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _currentLocationError = 'Enable location services';
          _isLoadingCurrentLocation = false;
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        setState(() {
          _currentLocationError = 'Location permission denied';
          _isLoadingCurrentLocation = false;
        });
        return;
      }

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

      List<Placemark> placemarks = [];
      try {
        placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      } catch (_) {
        // Geocoding might fail on web or without internet
      }
      
      String locationText = 'Current Location';
      String city = '';
      String state = '';
      String pincode = '';
      String addressLine1 = '';

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        locationText = [
          place.subLocality,
          place.locality,
          place.administrativeArea,
        ].where((e) => e != null && e.isNotEmpty).join(', ');
        
        addressLine1 = [
          place.street,
          place.subLocality,
        ].where((e) => e != null && e.isNotEmpty).join(', ');
        city = place.locality ?? '';
        state = place.administrativeArea ?? '';
        pincode = place.postalCode ?? '';
      } else {
        // Fallback to HTTP Geocoding
        try {
          const apiKey = 'AIzaSyCKL5RYJ39x93yz1Km59KwpYybRod3IOeg';
          final url = 'https://maps.googleapis.com/maps/api/geocode/json?latlng=${pos.latitude},${pos.longitude}&key=$apiKey&language=en';
          final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
          
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['status'] == 'OK' && data['results'] != null && (data['results'] as List).isNotEmpty) {
              final components = data['results'][0]['address_components'] as List;
              
              for (final c in components) {
                final types = (c['types'] as List).cast<String>();
                if (types.contains('locality')) city = c['long_name'];
                else if (types.contains('administrative_area_level_1')) state = c['long_name'];
                else if (types.contains('postal_code')) pincode = c['long_name'];
                else if (types.contains('sublocality_level_1')) addressLine1 = c['long_name'];
              }
              
              final formattedAddress = data['results'][0]['formatted_address'] as String;
              if (formattedAddress.isNotEmpty) {
                final parts = formattedAddress.split(',');
                locationText = parts.take(2).join(',').trim();
                if (addressLine1.isEmpty) addressLine1 = locationText;
              }
            }
          }
        } catch (_) {}
      }
      
      if (mounted) {
        // ✅ Stay on the same page — show detected location
        setState(() {
          _currentLocationText = locationText;
          _isLoadingCurrentLocation = false;
        });

        // Check if a saved address is near this location
        final addressProvider = Provider.of<AddressProvider>(context, listen: false);
        final savedAddresses = addressProvider.addresses;
        
        AddressModel? nearbyAddress;
        for (final addr in savedAddresses) {
          if (addr.latitude != null && addr.longitude != null) {
            final distance = Geolocator.distanceBetween(
              pos.latitude, pos.longitude,
              addr.latitude!, addr.longitude!,
            );
            if (distance < 500) { // Within 500 meters
              nearbyAddress = addr;
              break;
            }
          }
        }

        if (nearbyAddress != null) {
          // ✅ Found a nearby saved address — set it as default
          debugPrint('📍 Found nearby saved address: ${nearbyAddress.addressLine1}');
          addressProvider.setDefaultAddress(nearbyAddress.id);
          if (mounted) Navigator.pop(context);
        } else {
          // ✅ No saved address nearby — auto-add this as a new address
          debugPrint('📍 No nearby address found, creating new one from GPS');
          final userId = AuthService().currentUserId;
          if (userId != null) {
            final newAddress = AddressModel(
              id: '',
              userId: userId,
              name: 'Current Location',
              phone: '',
              addressLine1: addressLine1.isNotEmpty ? addressLine1 : locationText,
              addressLine2: '',
              city: city,
              state: state,
              zipcode: pincode,
              country: 'India',
              latitude: pos.latitude,
              longitude: pos.longitude,
              isDefault: true,
              addressType: 'other',
            );
            await addressProvider.addAddress(newAddress);
          }
          if (mounted) Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentLocationError = 'Failed to get GPS location';
          _isLoadingCurrentLocation = false;
        });
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[700] : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Compact Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
            child: Row(
              children: [
                Text(
                  'Delivery Location',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close, size: 18, color: isDark ? Colors.grey[400] : Colors.black54),
                  ),
                ),
              ],
            ),
          ),
          

          
          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current Location Button
                  _buildCompactTile(
                    icon: Icons.my_location_rounded,
                    iconColor: Colors.blueAccent,
                    title: 'Use current location',
                    subtitle: _currentLocationError ?? _currentLocationText,
                    subtitleColor: _currentLocationError != null ? Colors.red : accentColor,
                    isLoading: _isLoadingCurrentLocation,
                    onTap: _useCurrentLocation,
                    isDark: isDark,
                  ),
                  
                  const SizedBox(height: 6),
                  
                  // Add New Address → Profile → Saved Addresses page
                  _buildCompactTile(
                    icon: Icons.add_location_alt_rounded,
                    iconColor: accentColor,
                    title: 'Add new address',
                    subtitle: 'Go to Profile → Delivery Address',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, AppRoutes.savedAddresses);
                    },
                    isDark: isDark,
                  ),
                  

                  
                  // Saved Addresses
                  Consumer<AddressProvider>(
                    builder: (context, addressProvider, _) {
                      final addresses = addressProvider.addresses;
                      if (addresses.isEmpty) return const SizedBox.shrink();
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          _buildSectionHeader('Saved Addresses', isDark),
                          ...addresses.map((addr) => _buildAddressItem(
                            address: addr,
                            isDark: isDark,
                            accentColor: accentColor,
                            onTap: () {
                              Navigator.pop(context);
                              if (!addr.isDefault) {
                                addressProvider.setDefaultAddress(addr.id);
                              }
                            },
                          )),
                        ],
                      );
                    },
                  ),
                  

                  
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.grey[500] : Colors.grey[600],
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildCompactTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Color? subtitleColor,
    bool isLoading = false,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF303030) : Colors.grey[50],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: isLoading
                    ? Padding(
                        padding: const EdgeInsets.all(6),
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(iconColor)),
                      )
                    : Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                    if (subtitle != null)
                      Text(subtitle, style: TextStyle(fontSize: 11, color: subtitleColor ?? (isDark ? Colors.grey[400] : Colors.grey[600]))),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: isDark ? Colors.grey[600] : Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddressItem({
    required AddressModel address,
    required bool isDark,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    IconData typeIcon;
    Color typeColor;
    
    switch (address.addressType?.toLowerCase()) {
      case 'home': typeIcon = Icons.home_rounded; typeColor = Colors.blue; break;
      case 'work': typeIcon = Icons.work_rounded; typeColor = Colors.orange; break;
      default: typeIcon = Icons.location_on_rounded; typeColor = Colors.grey;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: address.isDefault ? accentColor.withOpacity(0.08) : (isDark ? const Color(0xFF303030) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: address.isDefault ? accentColor.withOpacity(0.3) : (isDark ? Colors.grey[800]! : Colors.grey[200]!),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: typeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              child: Icon(typeIcon, color: typeColor, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        address.addressType ?? 'Other',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                      ),
                      if (address.isDefault) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(color: accentColor.withOpacity(0.15), borderRadius: BorderRadius.circular(3)),
                          child: Text('DEFAULT', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: accentColor)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${address.addressLine1}, ${address.city}, ${address.state} ${address.zipcode}',
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (address.isDefault) Icon(Icons.check_circle, color: accentColor, size: 18),
          ],
        ),
      ),
    );
  }
}
