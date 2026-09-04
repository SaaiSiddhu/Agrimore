// lib/services/geocoding_service.dart
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:agrimore_core/agrimore_core.dart';

/// Service for geocoding addresses to GPS coordinates
class GeocodingService {
  // Cache for geocoded addresses to avoid repeated API calls
  static final Map<String, Location?> _cache = {};

  /// Get coordinates from an AddressModel
  /// Uses cached coords if available, otherwise geocodes the address string
  static Future<Location?> getCoordinatesForAddress(AddressModel address) async {
    // If address already has coordinates, use them
    if (address.latitude != null && address.longitude != null) {
      debugPrint('📍 Using existing coordinates: ${address.latitude}, ${address.longitude}');
      return Location(
        latitude: address.latitude!,
        longitude: address.longitude!,
        timestamp: DateTime.now(),
      );
    }

    debugPrint('📍 Address has no coordinates, attempting geocoding...');
    debugPrint('   addressLine1: "${address.addressLine1}"');
    debugPrint('   addressLine2: "${address.addressLine2}"');
    debugPrint('   city: "${address.city}"');
    debugPrint('   state: "${address.state}"');
    debugPrint('   zipcode: "${address.zipcode}"');

    // Try multiple address string formats
    final addressFormats = _buildAddressStrings(address);
    
    for (final addressString in addressFormats) {
      // Check cache first
      if (_cache.containsKey(addressString)) {
        final cached = _cache[addressString];
        if (cached != null) {
          debugPrint('📍 Using cached geocoding for: $addressString');
          return cached;
        }
        continue; // Try next format
      }

      try {
        debugPrint('🔍 Trying geocode: "$addressString"');
        final locations = await locationFromAddress(addressString);
        
        if (locations.isNotEmpty) {
          final location = locations.first;
          debugPrint('✅ Geocoded successfully: ${location.latitude}, ${location.longitude}');
          _cache[addressString] = location;
          return location;
        }
        
        debugPrint('⚠️ No results for: "$addressString"');
        _cache[addressString] = null;
      } catch (e) {
        debugPrint('❌ Geocoding error for "$addressString": $e');
        _cache[addressString] = null;
      }
    }
    
    debugPrint('❌ All geocoding attempts failed for this address');
    return null;
  }

  /// Build multiple geocodable address string formats to try
  static List<String> _buildAddressStrings(AddressModel address) {
    final formats = <String>[];
    
    // Format 1: Full address
    final fullParts = <String>[];
    if (address.addressLine1.isNotEmpty) fullParts.add(address.addressLine1);
    if (address.addressLine2.isNotEmpty) fullParts.add(address.addressLine2);
    if (address.city.isNotEmpty) fullParts.add(address.city);
    if (address.state.isNotEmpty) fullParts.add(address.state);
    if (address.zipcode.isNotEmpty) fullParts.add(address.zipcode);
    if (address.country.isNotEmpty) fullParts.add(address.country);
    if (fullParts.isNotEmpty) formats.add(fullParts.join(', '));
    
    // Format 2: City, State, Pincode, Country (most reliable)
    final cityStateParts = <String>[];
    if (address.city.isNotEmpty) cityStateParts.add(address.city);
    if (address.state.isNotEmpty) cityStateParts.add(address.state);
    if (address.zipcode.isNotEmpty) cityStateParts.add(address.zipcode);
    cityStateParts.add('India');
    if (cityStateParts.length > 2) formats.add(cityStateParts.join(', '));
    
    // Format 3: Just pincode + Country (fallback)
    if (address.zipcode.isNotEmpty && address.zipcode.length == 6) {
      formats.add('${address.zipcode}, India');
    }
    
    // Format 4: City, State, India
    if (address.city.isNotEmpty && address.state.isNotEmpty) {
      formats.add('${address.city}, ${address.state}, India');
    }
    
    return formats;
  }

  /// Get coordinates from a raw address string
  static Future<Location?> geocodeAddress(String address) async {
    if (address.isEmpty) return null;
    
    // Check cache
    if (_cache.containsKey(address)) {
      return _cache[address];
    }
    
    try {
      debugPrint('🔍 Geocoding: $address');
      final locations = await locationFromAddress(address);
      
      if (locations.isNotEmpty) {
        final location = locations.first;
        debugPrint('✅ Geocoded to: ${location.latitude}, ${location.longitude}');
        _cache[address] = location;
        return location;
      }
      
      _cache[address] = null;
      return null;
    } catch (e) {
      debugPrint('❌ Geocoding error: $e');
      _cache[address] = null;
      return null;
    }
  }

  /// Clear the geocoding cache
  static void clearCache() {
    _cache.clear();
    debugPrint('🗑️ Geocoding cache cleared');
  }

  /// Get reverse geocoding (coords → address)
  static Future<String?> getAddressFromCoordinates(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      
      if (placemarks.isNotEmpty) {
        final pm = placemarks.first;
        return '${pm.street}, ${pm.locality}, ${pm.administrativeArea} ${pm.postalCode}';
      }
      return null;
    } catch (e) {
      debugPrint('❌ Reverse geocoding error: $e');
      return null;
    }
  }
}
