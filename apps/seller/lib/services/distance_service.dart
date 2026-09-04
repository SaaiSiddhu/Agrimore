// lib/services/distance_service.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'geocoding_service.dart';

/// Service for calculating distance and delivery earnings
class DistanceService {
  // Rate per kilometer in rupees
  static const double ratePerKm = 4.75;
  
  // Minimum earnings per delivery
  static const double minimumEarnings = 15.0;
  
  // Earth's radius in kilometers
  static const double earthRadiusKm = 6371.0;

  /// Calculate distance between two GPS coordinates using Haversine formula
  /// Returns distance in kilometers
  static double calculateDistance({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    // Convert degrees to radians
    final lat1Rad = _degreesToRadians(startLat);
    final lat2Rad = _degreesToRadians(endLat);
    final deltaLat = _degreesToRadians(endLat - startLat);
    final deltaLng = _degreesToRadians(endLng - startLng);
    
    // Haversine formula
    final a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) *
        sin(deltaLng / 2) * sin(deltaLng / 2);
    
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    final distance = earthRadiusKm * c;
    
    debugPrint('📏 Distance calculated: ${distance.toStringAsFixed(2)} km');
    return distance;
  }
  
  /// Convert degrees to radians
  static double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }
  
  /// Calculate estimated earnings based on distance
  /// Returns earnings in rupees
  static double calculateEarnings(double distanceKm) {
    final earnings = distanceKm * ratePerKm;
    // Ensure minimum earnings
    final finalEarnings = earnings < minimumEarnings ? minimumEarnings : earnings;
    debugPrint('💰 Earnings calculated: ₹${finalEarnings.toStringAsFixed(2)} for ${distanceKm.toStringAsFixed(1)} km');
    return finalEarnings;
  }
  
  /// Get formatted distance string
  static String formatDistance(double distanceKm) {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).toStringAsFixed(0)} m';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }
  
  /// Get formatted earnings string
  static String formatEarnings(double earnings) {
    return '₹${earnings.toStringAsFixed(2)}';
  }
  
  /// Calculate and format both distance and earnings
  static Map<String, dynamic> calculateDeliveryDetails({
    required double partnerLat,
    required double partnerLng,
    required double customerLat,
    required double customerLng,
  }) {
    final distance = calculateDistance(
      startLat: partnerLat,
      startLng: partnerLng,
      endLat: customerLat,
      endLng: customerLng,
    );
    
    final earnings = calculateEarnings(distance);
    
    return {
      'distanceKm': distance,
      'distanceFormatted': formatDistance(distance),
      'earnings': earnings,
      'earningsFormatted': formatEarnings(earnings),
      'ratePerKm': ratePerKm,
    };
  }
  
  /// Estimate delivery time based on distance
  /// Average speed: 25 km/h in city traffic
  static String estimateDeliveryTime(double distanceKm) {
    const avgSpeedKmh = 25.0;
    final timeHours = distanceKm / avgSpeedKmh;
    final timeMinutes = (timeHours * 60).round();
    
    if (timeMinutes < 5) {
      return '~5 min';
    } else if (timeMinutes < 60) {
      return '~$timeMinutes min';
    } else {
      final hours = timeMinutes ~/ 60;
      final mins = timeMinutes % 60;
      return '~${hours}h ${mins}m';
    }
  }

  /// Calculate distance using geocoding when coordinates are missing
  /// This is async because it may need to geocode the customer address
  static Future<Map<String, dynamic>> calculateDeliveryDetailsAsync({
    required double partnerLat,
    required double partnerLng,
    required AddressModel customerAddress,
  }) async {
    // Get customer coordinates
    double? customerLat = customerAddress.latitude;
    double? customerLng = customerAddress.longitude;
    
    // If coordinates missing, geocode the address
    if (customerLat == null || customerLng == null) {
      debugPrint('📍 Customer coords missing, geocoding address...');
      final location = await GeocodingService.getCoordinatesForAddress(customerAddress);
      
      if (location != null) {
        customerLat = location.latitude;
        customerLng = location.longitude;
        debugPrint('✅ Geocoded: $customerLat, $customerLng');
      } else {
        debugPrint('⚠️ Could not geocode address, using fallback');
        // Return with unknown distance
        return {
          'distanceKm': 0.0,
          'distanceFormatted': 'Unknown',
          'earnings': minimumEarnings,
          'earningsFormatted': formatEarnings(minimumEarnings),
          'ratePerKm': ratePerKm,
          'eta': 'Unknown',
          'geocoded': false,
        };
      }
    }
    
    // Calculate distance
    final distance = calculateDistance(
      startLat: partnerLat,
      startLng: partnerLng,
      endLat: customerLat,
      endLng: customerLng,
    );
    
    final earnings = calculateEarnings(distance);
    
    return {
      'distanceKm': distance,
      'distanceFormatted': formatDistance(distance),
      'earnings': earnings,
      'earningsFormatted': formatEarnings(earnings),
      'ratePerKm': ratePerKm,
      'eta': estimateDeliveryTime(distance),
      'geocoded': true,
      'customerLat': customerLat,
      'customerLng': customerLng,
    };
  }

  /// Quick sync calculation when coordinates are available
  static Map<String, dynamic>? calculateIfCoordsAvailable({
    required double partnerLat,
    required double partnerLng,
    required AddressModel customerAddress,
  }) {
    if (customerAddress.latitude == null || customerAddress.longitude == null) {
      return null; // Needs async geocoding
    }
    
    return calculateDeliveryDetails(
      partnerLat: partnerLat,
      partnerLng: partnerLng,
      customerLat: customerAddress.latitude!,
      customerLng: customerAddress.longitude!,
    );
  }
}

