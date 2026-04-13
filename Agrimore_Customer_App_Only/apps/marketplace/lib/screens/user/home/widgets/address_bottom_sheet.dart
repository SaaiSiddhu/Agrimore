import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
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

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      
      if (mounted && placemarks.isNotEmpty) {
        final place = placemarks.first;
        final locationText = [
          place.subLocality,
          place.locality,
          place.administrativeArea,
        ].where((e) => e != null && e.isNotEmpty).join(', ');
        
        setState(() {
          _currentLocationText = locationText;
          _isLoadingCurrentLocation = false;
        });

        // Update app bar location by navigating to add address
        if (mounted) {
          Navigator.pop(context);
          Navigator.pushNamed(
            context, 
            AppRoutes.addAddress,
            arguments: {
              'latitude': pos.latitude,
              'longitude': pos.longitude,
              'address': locationText,
              'city': place.locality ?? '',
              'state': place.administrativeArea ?? '',
              'pincode': place.postalCode ?? '',
            },
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentLocationError = 'Failed to get location';
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
                  
                  // Add New Address
                  _buildCompactTile(
                    icon: Icons.add_location_alt_rounded,
                    iconColor: accentColor,
                    title: 'Add new address',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, AppRoutes.addAddress);
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
            color: isDark ? Colors.grey[850] : Colors.grey[50],
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
          color: address.isDefault ? accentColor.withOpacity(0.08) : (isDark ? Colors.grey[850] : Colors.white),
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
