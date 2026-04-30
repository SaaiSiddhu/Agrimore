import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_core/agrimore_core.dart';
import '../../../providers/theme_provider.dart';

class AddAddressScreen extends StatefulWidget {
  final AddressModel? existingAddress;

  const AddAddressScreen({Key? key, this.existingAddress}) : super(key: key);

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  GoogleMapController? _mapController;
  LatLng _currentPosition = const LatLng(28.6139, 77.2090);
  bool _isLoadingLocation = true;
  bool _isSaving = false;
  bool _isFetchingAddress = false;
  bool _isBottomSheetInteracting = false;
  bool _showConfirmButton = false;  // New: for delayed confirm button
  Timer? _debounceTimer;
  Timer? _confirmButtonTimer;  // New: timer for 2-second delay
  String? _darkMapStyle;
  String? _lightMapStyle;
  MapType _currentMapType = MapType.normal;  // Satellite toggle support

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressLine1Controller = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _landmarkController = TextEditingController();
  final _pincodeController = TextEditingController();

  String? _selectedState;
  String? _selectedDistrict;
  String? _selectedCity;

  List<String> _filteredStates = [];
  List<String> _filteredDistricts = [];
  List<String> _filteredCities = [];

  bool _isManualStateEntry = false;
  bool _isManualDistrictEntry = false;
  bool _isManualCityEntry = false;

  final _manualStateController = TextEditingController();
  final _manualDistrictController = TextEditingController();
  final _manualCityController = TextEditingController();

  String _selectedAddressType = 'Home';
  bool _isDefault = false;

  @override
  void initState() {
    super.initState();
    _filteredStates = IndiaLocations.allStates;
    _loadMapStyles();

    if (widget.existingAddress != null) {
      _loadExistingAddress();
    } else {
      _getCurrentLocation();
    }
  }

  Future<void> _loadMapStyles() async {
    _darkMapStyle = await rootBundle.loadString('assets/map_styles/dark_map.json');
    _lightMapStyle = await rootBundle.loadString('assets/map_styles/light_map.json');
  }

  void _applyMapTheme() {
    if (_mapController == null) return;
    final isDark = context.read<ThemeProvider>().isDarkMode;
    _mapController!.setMapStyle(isDark ? _darkMapStyle : _lightMapStyle);
  }

  void _loadExistingAddress() {
    final address = widget.existingAddress!;
    _nameController.text = address.name;
    _phoneController.text = address.phone;
    _addressLine1Controller.text = address.addressLine1;
    _addressLine2Controller.text = address.addressLine2;
    _landmarkController.text = address.landmark ?? '';
    _pincodeController.text = address.zipcode;
    _selectedAddressType = address.addressType ?? 'Home';
    _isDefault = address.isDefault;

    if (IndiaLocations.allStates.contains(address.state)) {
      _selectedState = address.state;
      _filteredDistricts = IndiaLocations.getDistricts(_selectedState!);
    } else {
      _isManualStateEntry = true;
      _manualStateController.text = address.state;
    }

    if (address.latitude != null && address.longitude != null) {
      _currentPosition = LatLng(address.latitude!, address.longitude!);
    }
    setState(() => _isLoadingLocation = false);
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationServiceDialog();
        setState(() => _isLoadingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showPermissionDeniedDialog();
          setState(() => _isLoadingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showPermissionDeniedDialog();
        setState(() => _isLoadingLocation = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
          _isLoadingLocation = false;
        });

        if (_mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(_currentPosition, 16),
          );
          _applyMapTheme();
        }
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  Future<void> _getAddressFromLatLng(LatLng position, {bool showConfirmation = false}) async {
    if (!showConfirmation) return;

    _debounceTimer?.cancel();
    if (!mounted) return;

    setState(() => _isFetchingAddress = true);

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Geocoding timed out'),
      );

      if (!mounted) return;

      if (placemarks.isEmpty) {
        _showSnackBar('No address found', isError: true);
        return;
      }

      Placemark place = placemarks[0];
      debugPrint('📍 Placemark: $place');

      // Extract with null safety
      String street = (place.street ?? place.name ?? '').trim();
      String subLocality = (place.subLocality ?? '').trim();
      String thoroughfare = (place.thoroughfare ?? '').trim();
      String locality = (place.locality ?? '').trim();
      String subAdministrativeArea = (place.subAdministrativeArea ?? '').trim();
      String administrativeArea = (place.administrativeArea ?? '').trim();
      String postalCode = (place.postalCode ?? '').trim();

      debugPrint('🔍 Street: $street');
      debugPrint('🔍 SubLocality: $subLocality');
      debugPrint('🔍 Thoroughfare: $thoroughfare');
      debugPrint('🔍 Locality: $locality');
      debugPrint('🔍 SubAdministrativeArea: $subAdministrativeArea');
      debugPrint('🔍 AdministrativeArea: $administrativeArea');
      debugPrint('🔍 PostalCode: $postalCode');

      if (street.isEmpty && subLocality.isEmpty && locality.isEmpty) {
        _showSnackBar('Insufficient address data', isError: true);
        return;
      }

      if (mounted) {
        bool? confirmed = await _showAddressConfirmationDialog(
          street: street,
          subLocality: subLocality,
          thoroughfare: thoroughfare,
          locality: locality,
          subAdministrativeArea: subAdministrativeArea,
          state: administrativeArea,
          pincode: postalCode,
        );

        if (confirmed == true && mounted) {
          _fillAddressFields(
            street: street,
            subLocality: subLocality,
            thoroughfare: thoroughfare,
            locality: locality,
            subAdministrativeArea: subAdministrativeArea,
            administrativeArea: administrativeArea,
            postalCode: postalCode,
          );
        }
      }
    } on TimeoutException catch (e) {
      debugPrint('Timeout: $e');
      // Fallback to HTTP Geocoding API
      if (mounted) {
        debugPrint('🔄 Trying HTTP Geocoding API fallback...');
        await _getAddressFromLatLngHttp(position);
      }
    } catch (e) {
      debugPrint('Error: $e');
      // Fallback to HTTP Geocoding API
      if (mounted) {
        debugPrint('🔄 Trying HTTP Geocoding API fallback...');
        await _getAddressFromLatLngHttp(position);
      }
    } finally {
      if (mounted) setState(() => _isFetchingAddress = false);
    }
  }

  /// HTTP-based geocoding fallback using Google Maps Geocoding API
  Future<void> _getAddressFromLatLngHttp(LatLng position) async {
    try {
      const apiKey = 'AIzaSyCKL5RYJ39x93yz1Km59KwpYybRod3IOeg';
      final url = 'https://maps.googleapis.com/maps/api/geocode/json'
          '?latlng=${position.latitude},${position.longitude}'
          '&key=$apiKey&language=en';

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('HTTP Geocoding timed out'),
      );

      if (response.statusCode != 200) {
        _showSnackBar('Unable to fetch address. Please enter manually.', isError: true);
        return;
      }

      final data = jsonDecode(response.body);
      if (data['status'] != 'OK' || data['results'] == null || (data['results'] as List).isEmpty) {
        _showSnackBar('No address found for this location', isError: true);
        return;
      }

      final result = data['results'][0];
      final components = result['address_components'] as List;

      String street = '';
      String subLocality = '';
      String locality = '';
      String subAdminArea = '';
      String adminArea = '';
      String postalCode = '';

      for (final component in components) {
        final types = (component['types'] as List).cast<String>();
        final longName = component['long_name'] ?? '';

        if (types.contains('route') || types.contains('premise')) {
          street = longName;
        } else if (types.contains('sublocality_level_1') || types.contains('sublocality')) {
          subLocality = longName;
        } else if (types.contains('locality')) {
          locality = longName;
        } else if (types.contains('administrative_area_level_2')) {
          subAdminArea = longName;
        } else if (types.contains('administrative_area_level_1')) {
          adminArea = longName;
        } else if (types.contains('postal_code')) {
          postalCode = longName;
        }
      }

      debugPrint('📍 HTTP Geocode: street=$street, sub=$subLocality, loc=$locality, dist=$subAdminArea, state=$adminArea, pin=$postalCode');

      if (!mounted) return;

      bool? confirmed = await _showAddressConfirmationDialog(
        street: street,
        subLocality: subLocality,
        thoroughfare: '',
        locality: locality,
        subAdministrativeArea: subAdminArea,
        state: adminArea,
        pincode: postalCode,
      );

      if (confirmed == true && mounted) {
        _fillAddressFields(
          street: street,
          subLocality: subLocality,
          thoroughfare: '',
          locality: locality,
          subAdministrativeArea: subAdminArea,
          administrativeArea: adminArea,
          postalCode: postalCode,
        );
      }
    } catch (e) {
      debugPrint('❌ HTTP Geocoding also failed: $e');
      if (mounted) {
        _showSnackBar('Could not detect address. Please enter manually.', isError: true);
      }
    }
  }

  void _fillAddressFields({
    required String street,
    required String subLocality,
    required String thoroughfare,
    required String locality,
    required String subAdministrativeArea,
    required String administrativeArea,
    required String postalCode,
  }) {
    setState(() {
      // Address Line 1: Street/Name
      if (street.isNotEmpty && !street.toLowerCase().contains('unnamed')) {
        _addressLine1Controller.text = street;
      } else if (thoroughfare.isNotEmpty) {
        _addressLine1Controller.text = thoroughfare;
      }

      // Address Line 2: SubLocality or Area
      if (subLocality.isNotEmpty && subLocality != street) {
        _addressLine2Controller.text = subLocality;
      } else if (thoroughfare.isNotEmpty && thoroughfare != street) {
        _addressLine2Controller.text = thoroughfare;
      }

      // Pincode
      if (postalCode.length == 6 && RegExp(r'^[0-9]{6}$').hasMatch(postalCode)) {
        _pincodeController.text = postalCode;
      }

      // State matching
      if (administrativeArea.isNotEmpty) {
        bool stateMatched = false;
        
        // Try exact match first
        for (String state in IndiaLocations.allStates) {
          if (state.toLowerCase() == administrativeArea.toLowerCase()) {
            _selectedState = state;
            _filteredDistricts = IndiaLocations.getDistricts(state);
            _isManualStateEntry = false;
            stateMatched = true;
            debugPrint('✅ State matched (exact): $state');
            break;
          }
        }

        // Try partial match
        if (!stateMatched) {
          for (String state in IndiaLocations.allStates) {
            if (state.toLowerCase().contains(administrativeArea.toLowerCase()) ||
                administrativeArea.toLowerCase().contains(state.toLowerCase())) {
              _selectedState = state;
              _filteredDistricts = IndiaLocations.getDistricts(state);
              _isManualStateEntry = false;
              stateMatched = true;
              debugPrint('✅ State matched (partial): $state');
              break;
            }
          }
        }

        if (!stateMatched) {
          _isManualStateEntry = true;
          _manualStateController.text = administrativeArea;
          debugPrint('❌ State not matched, using manual: $administrativeArea');
        }
      }

      // District and City matching - IMPROVED LOGIC
      if (_selectedState != null) {
        // Ensure districts are loaded for the state
        if (_filteredDistricts.isEmpty) {
          _filteredDistricts = IndiaLocations.getDistricts(_selectedState!);
          debugPrint('📦 Loaded ${_filteredDistricts.length} districts for $_selectedState');
        }

        bool districtSet = false;
        bool citySet = false;

        debugPrint('🔍 Trying to match district. subAdmin="$subAdministrativeArea", locality="$locality"');
        debugPrint('📦 Available districts: ${_filteredDistricts.take(5)}...');

        // STEP 1: Try to match district from subAdministrativeArea
        if (subAdministrativeArea.isNotEmpty) {
          for (String district in _filteredDistricts) {
            if (district.toLowerCase() == subAdministrativeArea.toLowerCase() ||
                district.toLowerCase().contains(subAdministrativeArea.toLowerCase()) ||
                subAdministrativeArea.toLowerCase().contains(district.toLowerCase())) {
              _selectedDistrict = district;
              _filteredCities = IndiaLocations.getCities(_selectedState!, district);
              _isManualDistrictEntry = false;
              districtSet = true;
              debugPrint('✅ District from subAdmin: $district');
              break;
            }
          }
          if (!districtSet) {
            _isManualDistrictEntry = true;
            _manualDistrictController.text = subAdministrativeArea;
            debugPrint('❌ District manual: $subAdministrativeArea');
          }
        }

        // STEP 2: If no district yet, try to match locality as district
        if (!districtSet && locality.isNotEmpty) {
          for (String district in _filteredDistricts) {
            if (district.toLowerCase() == locality.toLowerCase() ||
                district.toLowerCase().contains(locality.toLowerCase()) ||
                locality.toLowerCase().contains(district.toLowerCase())) {
              _selectedDistrict = district;
              _filteredCities = IndiaLocations.getCities(_selectedState!, district);
              _isManualDistrictEntry = false;
              districtSet = true;
              // Since locality matched district, DON'T use it for city
              debugPrint('✅ District from locality: $district (city left empty)');
              break;
            }
          }
        }

        // STEP 2.5: REVERSE LOOKUP - if locality is a city, find its parent district
        // IMPORTANT: Do EXACT match first to avoid "Ambattur" matching "Attur"
        if (!districtSet && locality.isNotEmpty && _selectedState != null) {
          debugPrint('🔄 Trying reverse lookup for locality: $locality');
          
          // First pass: EXACT match only
          bool exactFound = false;
          for (String district in _filteredDistricts) {
            List<String> citiesInDistrict = IndiaLocations.getCities(_selectedState!, district);
            for (String city in citiesInDistrict) {
              if (city.toLowerCase() == locality.toLowerCase()) {
                // EXACT MATCH found!
                _selectedDistrict = district;
                _filteredCities = citiesInDistrict;
                _isManualDistrictEntry = false;
                districtSet = true;
                _selectedCity = city;
                _isManualCityEntry = false;
                exactFound = true;
                debugPrint('✅ REVERSE LOOKUP (EXACT): District=$district, City=$city');
                break;
              }
            }
            if (exactFound) break;
          }
          
          // Second pass: Partial match only if no exact match found
          if (!exactFound) {
            debugPrint('🔍 No exact match, trying partial match...');
            for (String district in _filteredDistricts) {
              List<String> citiesInDistrict = IndiaLocations.getCities(_selectedState!, district);
              for (String city in citiesInDistrict) {
                // Only match if locality starts with city or city starts with locality
                // This prevents "Ambattur" from matching "Attur"
                if (city.toLowerCase().startsWith(locality.toLowerCase()) ||
                    locality.toLowerCase().startsWith(city.toLowerCase())) {
                  _selectedDistrict = district;
                  _filteredCities = citiesInDistrict;
                  _isManualDistrictEntry = false;
                  districtSet = true;
                  _selectedCity = city;
                  _isManualCityEntry = false;
                  debugPrint('✅ REVERSE LOOKUP (partial): District=$district, City=$city');
                  break;
                }
              }
              if (districtSet) break;
            }
          }
        }

        // STEP 3: Try to match city from locality (only if locality wasn't used for district)
        if (districtSet && locality.isNotEmpty && _selectedDistrict != null) {
          // Only try city if locality is DIFFERENT from district and city not already set
          if (_selectedCity == null && _selectedDistrict!.toLowerCase() != locality.toLowerCase()) {
            for (String city in _filteredCities) {
              if (city.toLowerCase() == locality.toLowerCase() ||
                  city.toLowerCase().contains(locality.toLowerCase()) ||
                  locality.toLowerCase().contains(city.toLowerCase())) {
                _selectedCity = city;
                _isManualCityEntry = false;
                citySet = true;
                debugPrint('✅ City matched: $city');
                break;
              }
            }
            if (!citySet) {
              _isManualCityEntry = true;
              _manualCityController.text = locality;
              debugPrint('❌ City manual: $locality');
            }
          } else {
            debugPrint('ℹ️ Locality same as district, city left for user to select');
          }
        }

        // STEP 4: If no district was set and locality wasn't matched, set locality as city
        if (!districtSet && locality.isNotEmpty) {
          _isManualCityEntry = true;
          _manualCityController.text = locality;
          debugPrint('ℹ️ No district found, locality set as city: $locality');
        }
      }
    });

    HapticFeedback.mediumImpact();
    _showSnackBar('Address detected! Please review.');
  }

  Future<bool?> _showAddressConfirmationDialog({
    required String street,
    required String subLocality,
    required String thoroughfare,
    required String locality,
    required String subAdministrativeArea,
    required String state,
    required String pincode,
  }) async {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: EdgeInsets.zero,
        content: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.92,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Enhanced Gradient Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [accentColor, accentColor.withOpacity(0.8)],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.location_on_rounded, color: Colors.white, size: 26),
                    ),
                    const SizedBox(height: 10),
                    Text('Confirm Location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text('Is this address correct?', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              
              // Address Card
              Padding(
                padding: const EdgeInsets.all(14),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[850] : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (street.isNotEmpty && !street.toLowerCase().contains('unnamed'))
                        _buildEnhancedAddressItem('Street', street, Icons.home_rounded, isDark, accentColor),
                      if (subLocality.isNotEmpty && subLocality != street)
                        _buildEnhancedAddressItem('Area', subLocality, Icons.location_city_rounded, isDark, accentColor),
                      if (locality.isNotEmpty)
                        _buildEnhancedAddressItem('City', locality, Icons.apartment_rounded, isDark, accentColor),
                      // Always show District with fallback
                      _buildEnhancedAddressItem('District', subAdministrativeArea.isNotEmpty ? subAdministrativeArea : (locality.isNotEmpty ? locality : 'Not detected'), Icons.map_rounded, isDark, accentColor),
                      // State & Pincode in row
                      if (state.isNotEmpty || pincode.isNotEmpty)
                        Row(
                          children: [
                            if (state.isNotEmpty)
                              Expanded(child: _buildEnhancedAddressItem('State', state, Icons.flag_rounded, isDark, accentColor, compact: true)),
                            if (state.isNotEmpty && pincode.isNotEmpty) const SizedBox(width: 8),
                            if (pincode.isNotEmpty)
                              _buildEnhancedAddressItem('Pincode', pincode, Icons.pin_drop_rounded, isDark, accentColor, compact: true),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              
              // Action Buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                          ),
                        ),
                        child: Text('Adjust', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: isDark ? Colors.black : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_rounded, size: 16),
                            const SizedBox(width: 6),
                            Text('Use This Address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogAddressRow(IconData icon, String text, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: isDark ? Colors.grey[500] : Colors.grey[600],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
              height: 1.5,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // Enhanced Address Item with label
  Widget _buildEnhancedAddressItem(String label, String value, IconData icon, bool isDark, Color accentColor, {bool compact = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 0 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 13, color: accentColor),
          ),
          const SizedBox(width: 8),
          compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontSize: 9, color: isDark ? Colors.grey[500] : Colors.grey[500], fontWeight: FontWeight.w600)),
                    Text(value, style: TextStyle(fontSize: 11, color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w700)),
                  ],
                )
              : Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: TextStyle(fontSize: 9, color: isDark ? Colors.grey[500] : Colors.grey[500], fontWeight: FontWeight.w600)),
                      Text(value, style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  Future<void> _confirmLocationManually() async {
    HapticFeedback.mediumImpact();
    await _getAddressFromLatLng(_currentPosition, showConfirmation: true);
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      return;
    }

    // Validate basic fields
    if (_nameController.text.trim().isEmpty) {
      _showSnackBar('Please enter name', isError: true);
      return;
    }
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length != 10) {
      _showSnackBar('Phone must be exactly 10 digits', isError: true);
      return;
    }
    if (_addressLine1Controller.text.trim().isEmpty) {
      _showSnackBar('Please enter house/building', isError: true);
      return;
    }
    if (_addressLine2Controller.text.trim().isEmpty) {
      _showSnackBar('Please enter road/area', isError: true);
      return;
    }

    String finalState, finalDistrict, finalCity;

    if (_isManualStateEntry) {
      if (_manualStateController.text.trim().isEmpty) {
        _showSnackBar('Please enter state', isError: true);
        return;
      }
      finalState = _manualStateController.text.trim();
    } else {
      if (_selectedState == null) {
        _showSnackBar('Please select state', isError: true);
        return;
      }
      finalState = _selectedState!;
    }

    if (_isManualDistrictEntry) {
      if (_manualDistrictController.text.trim().isEmpty) {
        _showSnackBar('Please enter district', isError: true);
        return;
      }
      finalDistrict = _manualDistrictController.text.trim();
    } else {
      if (_selectedDistrict == null) {
        _showSnackBar('Please select district', isError: true);
        return;
      }
      finalDistrict = _selectedDistrict!;
    }

    if (_isManualCityEntry) {
      if (_manualCityController.text.trim().isEmpty) {
        _showSnackBar('Please enter city', isError: true);
        return;
      }
      finalCity = _manualCityController.text.trim();
    } else {
      if (_selectedCity == null) {
        _showSnackBar('Please select city', isError: true);
        return;
      }
      finalCity = _selectedCity!;
    }

    // Validate landmark (required)
    if (_landmarkController.text.trim().isEmpty) {
      _showSnackBar('Please enter landmark', isError: true);
      return;
    }

    // Validate pincode (exactly 6 digits)
    final pincode = _pincodeController.text.trim();
    if (pincode.isEmpty || pincode.length != 6) {
      _showSnackBar('Pincode must be exactly 6 digits', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('User not logged in');

      final addressId = widget.existingAddress?.id ??
          FirebaseFirestore.instance.collection('addresses').doc().id;

      final address = AddressModel(
        id: addressId,
        userId: userId,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        addressLine1: _addressLine1Controller.text.trim(),
        addressLine2: _addressLine2Controller.text.trim(),
        city: finalCity,
        state: finalState,
        zipcode: _pincodeController.text.trim(),
        country: 'India',
        latitude: _currentPosition.latitude,
        longitude: _currentPosition.longitude,
        isDefault: _isDefault,
        addressType: _selectedAddressType,
        landmark: _landmarkController.text.trim(),
      );

      if (_isDefault) {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('addresses')
            .where('userId', isEqualTo: userId)
            .where('isDefault', isEqualTo: true)
            .get();

        for (var doc in querySnapshot.docs) {
          await doc.reference.update({'isDefault': false});
        }
      }

      await FirebaseFirestore.instance
          .collection('addresses')
          .doc(addressId)
          .set(address.toMap());

      if (mounted) {
        HapticFeedback.heavyImpact();
        _showSnackBar('Address saved!');
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          Navigator.pop(context, address);
        }
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) _showSnackBar('Error: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
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

  void _showLocationServiceDialog() {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Location Services Disabled',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          'Please enable location services.',
          style: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey[700],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPermissionDeniedDialog() {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Location Permission Required',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          'Please grant location permission.',
          style: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey[700],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: isDark ? Colors.black : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Settings'),
          ),
        ],
      ),
    );
  }

  void _showStateSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LocationSelector(
        title: 'Select State',
        items: _filteredStates,
        selectedItem: _selectedState,
        onSelected: (state) {
          setState(() {
            _selectedState = state;
            _selectedDistrict = null;
            _selectedCity = null;
            _filteredDistricts = IndiaLocations.getDistricts(state);
            _filteredCities = [];
            _isManualStateEntry = false;
          });
          Navigator.pop(context);
        },
        onManualEntry: () {
          setState(() => _isManualStateEntry = true);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showDistrictSelector() {
    if (_selectedState == null) {
      _showSnackBar('Please select state first', isError: true);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LocationSelector(
        title: 'Select District',
        items: _filteredDistricts,
        selectedItem: _selectedDistrict,
        onSelected: (district) {
          setState(() {
            _selectedDistrict = district;
            _selectedCity = null;
            _filteredCities = IndiaLocations.getCities(_selectedState!, district);
            _isManualDistrictEntry = false;
          });
          Navigator.pop(context);
        },
        onManualEntry: () {
          setState(() => _isManualDistrictEntry = true);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showCitySelector() {
    if (_selectedDistrict == null) {
      _showSnackBar('Please select district first', isError: true);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LocationSelector(
        title: 'Select City',
        items: _filteredCities,
        selectedItem: _selectedCity,
        onSelected: (city) {
          setState(() {
            _selectedCity = city;
            _isManualCityEntry = false;
          });
          Navigator.pop(context);
        },
        onManualEntry: () {
          setState(() => _isManualCityEntry = true);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final backgroundColor = isDark ? const Color(0xFF121212) : Colors.grey[50];

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // Map View
          if (!_isLoadingLocation)
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentPosition,
                zoom: 16,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
                _applyMapTheme();
              },
              onCameraMove: (position) {
                _currentPosition = position.target;
                // Hide confirm button when moving
                _confirmButtonTimer?.cancel();
                if (_showConfirmButton) {
                  setState(() => _showConfirmButton = false);
                }
              },
              onCameraIdle: () {
                // Show confirm button after 2 second delay when idle
                _confirmButtonTimer?.cancel();
                _confirmButtonTimer = Timer(const Duration(milliseconds: 300), () {
                  if (mounted && !_isFetchingAddress) {
                    setState(() => _showConfirmButton = true);
                  }
                });
              },
              mapType: _currentMapType,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
            ),

          // Blocking overlay when bottom sheet interacts
          if (_isBottomSheetInteracting && !_isLoadingLocation)
            Positioned.fill(
              child: Container(
                color: Colors.transparent,
              ),
            ),

          // Center Pin + Confirm Button
          if (!_isLoadingLocation)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Enhanced Compact Pin
                  IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [accentColor, accentColor.withOpacity(0.8)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withOpacity(0.5),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: _isFetchingAddress
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: isDark ? Colors.black : Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Icon(
                              Icons.location_on_rounded,
                              color: isDark ? Colors.black : Colors.white,
                              size: 24,
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Confirm Tap Button - appears below pin after 2s delay
                  if (_showConfirmButton && !_isFetchingAddress && !_isBottomSheetInteracting)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _confirmLocationManually,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(isDark ? 0.3 : 0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                            border: Border.all(color: accentColor, width: 1.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded, color: accentColor, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                'Confirm',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: accentColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 50),
                ],
              ),
            ),

          // Loading
          if (_isLoadingLocation)
            Container(
              color: backgroundColor,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: accentColor),
                    const SizedBox(height: 16),
                    Text(
                      'Getting your location...',
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Top Bar - Back Button Only
          SafeArea(
            child: Container(
              margin: const EdgeInsets.all(12),
              child: _buildIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.pop(context),
                isDark: isDark,
                cardColor: cardColor,
              ),
            ),
          ),
          
          // Map Type Toggle Button - Top Right
          if (!_isLoadingLocation)
            Positioned(
              right: 12,
              top: MediaQuery.of(context).padding.top + 12,
              child: _buildIconButton(
                icon: _currentMapType == MapType.normal
                    ? Icons.satellite_alt_rounded
                    : Icons.map_rounded,
                onTap: () {
                  setState(() {
                    _currentMapType = _currentMapType == MapType.normal
                        ? MapType.hybrid
                        : MapType.normal;
                  });
                  HapticFeedback.selectionClick();
                },
                isDark: isDark,
                cardColor: cardColor,
              ),
            ),

          // Current Location Button - Bottom Right (above bottom sheet)
          if (!_isLoadingLocation)
            Positioned(
              right: 12,
              bottom: 390, // Above the bottom sheet
              child: _buildIconButton(
                icon: Icons.my_location_rounded,
                onTap: _getCurrentLocation,
                isDark: isDark,
                cardColor: cardColor,
              ),
            ),

          // Fixed Bottom Sheet - Non-scrollable
          if (!_isLoadingLocation)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Handle bar
                          Center(
                            child: Container(
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.grey[700] : Colors.grey[300],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Header Row (Title + Address Type inline)
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Complete Address',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                              _buildMiniTypeChip('Home', Icons.home_rounded, isDark, accentColor),
                              const SizedBox(width: 4),
                              _buildMiniTypeChip('Office', Icons.work_rounded, isDark, accentColor),
                              const SizedBox(width: 4),
                              _buildMiniTypeChip('Other', Icons.location_on_rounded, isDark, accentColor),
                            ],
                          ),
                          const SizedBox(height: 8),


                          // Row 1: Name + Phone
                          Row(
                            children: [
                              Expanded(child: _buildMiniField(controller: _nameController, label: 'Name *', icon: Icons.person_outline_rounded, isDark: isDark, accentColor: accentColor)),
                              const SizedBox(width: 6),
                              Expanded(child: _buildMiniField(controller: _phoneController, label: 'Phone *', icon: Icons.phone_outlined, isDark: isDark, accentColor: accentColor, keyboardType: TextInputType.phone)),
                            ],
                          ),
                          const SizedBox(height: 6),


                          // Row 2: House + Road
                          Row(
                            children: [
                              Expanded(child: _buildMiniField(controller: _addressLine1Controller, label: 'House *', icon: Icons.home_outlined, isDark: isDark, accentColor: accentColor)),
                              const SizedBox(width: 6),
                              Expanded(child: _buildMiniField(controller: _addressLine2Controller, label: 'Road *', icon: Icons.signpost_outlined, isDark: isDark, accentColor: accentColor)),
                            ],
                          ),
                          const SizedBox(height: 6),

                          // Row 3: Landmark + Pincode
                          Row(
                            children: [
                              Expanded(child: _buildMiniField(controller: _landmarkController, label: 'Landmark *', icon: Icons.explore_outlined, isDark: isDark, accentColor: accentColor)),
                              const SizedBox(width: 6),
                              Expanded(child: _buildMiniField(controller: _pincodeController, label: 'Pincode *', icon: Icons.pin_drop_outlined, isDark: isDark, accentColor: accentColor, keyboardType: TextInputType.number, maxLength: 6, inputFormatters: [FilteringTextInputFormatter.digitsOnly])),
                            ],
                          ),
                          const SizedBox(height: 6),


                          // Row 4: State + District  
                          Row(
                            children: [
                              Expanded(child: _buildMiniSelector(label: 'State', value: _isManualStateEntry ? _manualStateController.text : _selectedState, icon: Icons.map_outlined, onTap: _showStateSelector, isDark: isDark, accentColor: accentColor)),
                              const SizedBox(width: 6),
                              Expanded(child: _buildMiniSelector(label: 'District', value: _isManualDistrictEntry ? _manualDistrictController.text : _selectedDistrict, icon: Icons.business_outlined, onTap: _showDistrictSelector, isDark: isDark, accentColor: accentColor)),
                            ],
                          ),
                          const SizedBox(height: 6),


                          // Row 5: City + Default toggle
                          Row(
                            children: [
                              Expanded(child: _buildMiniSelector(label: 'City/Town', value: _isManualCityEntry ? _manualCityController.text : _selectedCity, icon: Icons.location_city_outlined, onTap: _showCitySelector, isDark: isDark, accentColor: accentColor)),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () {
                                  setState(() => _isDefault = !_isDefault);
                                  HapticFeedback.lightImpact();
                                },
                                child: Container(
                                  height: 42,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: _isDefault ? accentColor.withOpacity(0.15) : (isDark ? const Color(0xFF252525) : Colors.grey[100]),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: _isDefault ? accentColor : (isDark ? Colors.grey[700]! : Colors.grey[300]!), width: _isDefault ? 1.5 : 1),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(_isDefault ? Icons.check_circle_rounded : Icons.circle_outlined, size: 14, color: _isDefault ? accentColor : (isDark ? Colors.grey[500] : Colors.grey[600])),
                                      const SizedBox(width: 4),
                                      Text('Default', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _isDefault ? accentColor : (isDark ? Colors.grey[400] : Colors.grey[700]))),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Save Button - compact
                          SizedBox(
                            width: double.infinity,
                            height: 42,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _saveAddress,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentColor,
                                foregroundColor: isDark ? Colors.black : Colors.white,
                                disabledBackgroundColor: accentColor.withOpacity(0.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                              ),
                              child: _isSaving
                                  ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: isDark ? Colors.black : Colors.white, strokeWidth: 2))
                                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                      Icon(Icons.check_circle_rounded, size: 16),
                                      const SizedBox(width: 6),
                                      Text('Save Address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                    ]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton(bool isDark, Color accentColor) {
    return Material(
      color: accentColor,
      borderRadius: BorderRadius.circular(10),
      elevation: 4,
      child: InkWell(
        onTap: _isFetchingAddress ? null : _confirmLocationManually,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isFetchingAddress ? Icons.hourglass_empty_rounded : Icons.check_circle_rounded,
                color: isDark ? Colors.black : Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                _isFetchingAddress ? 'Wait...' : 'Confirm',
                style: TextStyle(
                  color: isDark ? Colors.black : Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationSelector({
    required String label,
    required String? value,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
    required Color accentColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: value != null
                ? accentColor
                : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
            width: value != null ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: value != null
                  ? accentColor
                  : (isDark ? Colors.grey[500] : Colors.grey[400]),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value ?? 'Tap to select',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: value != null
                          ? (isDark ? Colors.white : Colors.black87)
                          : (isDark ? Colors.grey[600] : Colors.grey[500]),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  // Compact Location Selector for 2x2 grid
  Widget _buildCompactLocationSelector({
    required String label,
    required String? value,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
    required Color accentColor,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: value != null
                ? accentColor.withOpacity(0.5)
                : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
            width: value != null ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: value != null
                  ? accentColor
                  : (isDark ? Colors.grey[500] : Colors.grey[400]),
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value ?? 'Select',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: value != null
                          ? (isDark ? Colors.white : Colors.black87)
                          : (isDark ? Colors.grey[600] : Colors.grey[500]),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  // Compact TextField for 2x2 grid
  Widget _buildCompactTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    required Color accentColor,
    VoidCallback? onClear,
  }) {
    return Container(
      height: 52,
      child: TextFormField(
        controller: controller,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[500] : Colors.grey[600],
          ),
          prefixIcon: Icon(icon, color: accentColor, size: 16),
          suffixIcon: onClear != null
              ? InkWell(
                  onTap: onClear,
                  child: Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                )
              : null,
          filled: true,
          fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: accentColor, width: 1.5),
          ),
        ),
      ),
    );
  }

  // Compact Pincode Field for 2x2 grid
  Widget _buildCompactPincodeField({
    required TextEditingController controller,
    required bool isDark,
    required Color accentColor,
  }) {
    return Container(
      height: 52,
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
        validator: (value) {
          if (value?.isEmpty ?? true) return 'Required';
          if (value!.length != 6) return '6 digits';
          return null;
        },
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          labelText: 'Pincode',
          labelStyle: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[500] : Colors.grey[600],
          ),
          prefixIcon: Icon(Icons.pin_drop_outlined, color: accentColor, size: 16),
          filled: true,
          fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: accentColor, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.red, width: 1),
          ),
        ),
      ),
    );
  }

  // Section Header Widget
  Widget _buildSectionHeader(String title, Color accentColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accentColor.withOpacity(0.15), accentColor.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accentColor.withOpacity(0.3), width: 1),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: accentColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // Enhanced Selector for 2x2 grid - BETTER styling
  Widget _buildEnhancedSelector({
    required String label,
    required String? value,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
    required Color accentColor,
  }) {
    final bool hasValue = value != null && value.isNotEmpty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF252525) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasValue
                  ? accentColor.withOpacity(0.6)
                  : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
              width: hasValue ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: hasValue
                      ? accentColor.withOpacity(0.15)
                      : (isDark ? Colors.grey[800] : Colors.grey[100]),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  icon,
                  color: hasValue ? accentColor : (isDark ? Colors.grey[500] : Colors.grey[400]),
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasValue ? value : 'Select',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: hasValue
                            ? (isDark ? Colors.white : Colors.black87)
                            : (isDark ? Colors.grey[600] : Colors.grey[400]),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: hasValue ? accentColor : (isDark ? Colors.grey[600] : Colors.grey[400]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Enhanced TextField for 2x2 grid
  Widget _buildEnhancedTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    required Color accentColor,
    VoidCallback? onClear,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[500] : Colors.grey[600],
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.only(left: 8, right: 4),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: accentColor, size: 16),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 40),
          suffixIcon: onClear != null
              ? InkWell(
                  onTap: onClear,
                  borderRadius: BorderRadius.circular(12),
                  child: Icon(Icons.close_rounded, size: 18, color: Colors.grey[500]),
                )
              : null,
          filled: false,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }

  // Enhanced Pincode Field
  Widget _buildEnhancedPincode({
    required TextEditingController controller,
    required bool isDark,
    required Color accentColor,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
        validator: (value) {
          if (value?.isEmpty ?? true) return 'Required';
          if (value!.length != 6) return '6 digits';
          return null;
        },
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: isDark ? Colors.white : Colors.black87,
          letterSpacing: 2,
        ),
        decoration: InputDecoration(
          labelText: 'Pincode',
          labelStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[500] : Colors.grey[600],
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.only(left: 8, right: 4),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.pin_drop_outlined, color: accentColor, size: 16),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 40),
          filled: false,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }

  // Enhanced Input Field for address details
  Widget _buildEnhancedInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    required Color accentColor,
    String? Function(String?)? validator,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        validator: validator,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
          ),
          labelStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[500] : Colors.grey[600],
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.only(left: 8, right: 4),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: accentColor, size: 16),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 40),
          filled: false,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }

  // Mini Field for ultra-compact form
  Widget _buildMiniField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    required Color accentColor,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
  }) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!, width: 1),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLength: maxLength,
        style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 16, color: isDark ? Colors.grey[500] : Colors.grey[600]),
          hintText: label,
          hintStyle: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey[500]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
          isDense: true,
          counterText: '', // Hide character counter
        ),
      ),
    );
  }

  // Mini Selector for ultra-compact dropdown-like fields
  Widget _buildMiniSelector({
    required String label,
    required String? value,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
    required Color accentColor,
  }) {
    final hasValue = value != null && value.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF252525) : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!, width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: isDark ? Colors.grey[500] : Colors.grey[600]),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                hasValue ? value! : label,
                style: TextStyle(
                  fontSize: 11,
                  color: hasValue ? (isDark ? Colors.white : Colors.black87) : (isDark ? Colors.grey[500] : Colors.grey[500]),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: isDark ? Colors.grey[500] : Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  // Mini Type Chip for address type in header
  Widget _buildMiniTypeChip(String type, IconData icon, bool isDark, Color accentColor) {
    final isSelected = _selectedAddressType == type;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedAddressType = type);
        HapticFeedback.lightImpact();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? accentColor : (isDark ? const Color(0xFF252525) : Colors.grey[100]),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? accentColor : (isDark ? Colors.grey[700]! : Colors.grey[300]!), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: isSelected ? (isDark ? Colors.black : Colors.white) : (isDark ? Colors.grey[400] : Colors.grey[600])),
            const SizedBox(width: 4),
            Text(type, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isSelected ? (isDark ? Colors.black : Colors.white) : (isDark ? Colors.grey[400] : Colors.grey[600]))),
          ],
        ),
      ),
    );
  }

  // Compact Type Chip for address type selection
  Widget _buildCompactTypeChip(String type, IconData icon, bool isDark, Color accentColor) {
    final isSelected = _selectedAddressType == type;
    return InkWell(
      onTap: () {
        setState(() => _selectedAddressType = type);
        HapticFeedback.lightImpact();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? accentColor : (isDark ? const Color(0xFF252525) : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? accentColor : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
            width: isSelected ? 0 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: accentColor.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
            const SizedBox(width: 4),
            Text(
              type,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
    required Color cardColor,
  }) {
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(8),
      elevation: 3,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 36,
          height: 36,
          padding: const EdgeInsets.all(4),
          child: Icon(
            icon,
            color: isDark ? Colors.white : Colors.black87,
            size: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildAddressTypeChip(String type, bool isDark, Color accentColor) {
    final isSelected = _selectedAddressType == type;
    IconData chipIcon;

    switch (type.toLowerCase()) {
      case 'home':
        chipIcon = Icons.home_rounded;
        break;
      case 'office':
        chipIcon = Icons.work_rounded;
        break;
      default:
        chipIcon = Icons.location_on_rounded;
    }

    return InkWell(
      onTap: () {
        setState(() => _selectedAddressType = type);
        HapticFeedback.lightImpact();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor
              : (isDark ? Colors.grey[850] : Colors.grey[100]),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? accentColor
                : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              chipIcon,
              size: 16,
              color: isSelected
                  ? (isDark ? Colors.black : Colors.white)
                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
            const SizedBox(width: 6),
            Text(
              type,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? (isDark ? Colors.black : Colors.white)
                    : (isDark ? Colors.grey[400] : Colors.grey[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    required Color accentColor,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    Widget? suffix,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      inputFormatters: inputFormatters,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.grey[500] : Colors.grey[600],
        ),
        prefixIcon: Icon(
          icon,
          color: accentColor,
          size: 20,
        ),
        suffixIcon: suffix,
        filled: true,
        fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: accentColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        errorStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _confirmButtonTimer?.cancel();
    _nameController.dispose();
    _phoneController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _landmarkController.dispose();
    _pincodeController.dispose();
    _manualStateController.dispose();
    _manualDistrictController.dispose();
    _manualCityController.dispose();
    _mapController?.dispose();
    super.dispose();
  }
}

// Location Selector Bottom Sheet
class _LocationSelector extends StatefulWidget {
  final String title;
  final List<String> items;
  final String? selectedItem;
  final Function(String) onSelected;
  final VoidCallback onManualEntry;

  const _LocationSelector({
    required this.title,
    required this.items,
    required this.selectedItem,
    required this.onSelected,
    required this.onManualEntry,
  });

  @override
  State<_LocationSelector> createState() => _LocationSelectorState();
}

class _LocationSelectorState extends State<_LocationSelector> {
  late List<String> _filteredItems;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
  }

  void _filterItems(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredItems = widget.items;
      } else {
        _filteredItems = widget.items
            .where((item) => item.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.12),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[700] : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  onChanged: _filterItems,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.grey[600] : Colors.grey[400],
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: isDark ? Colors.grey[500] : Colors.grey[400],
                    ),
                    filled: true,
                    fillColor: isDark ? Colors.grey[850] : Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: widget.onManualEntry,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: accentColor,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.edit_rounded,
                          color: accentColor,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Enter manually',
                          style: TextStyle(
                            color: accentColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _filteredItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 64,
                          color: isDark ? Colors.grey[700] : Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No results found',
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredItems.length,
                    padding: const EdgeInsets.only(bottom: 20),
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      final item = _filteredItems[index];
                      final isSelected = item == widget.selectedItem;
                      return InkWell(
                        onTap: () => widget.onSelected(item),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? accentColor.withOpacity(0.1)
                                : null,
                            border: Border(
                              bottom: BorderSide(
                                color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: isSelected
                                        ? accentColor
                                        : (isDark ? Colors.white : Colors.black87),
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: accentColor,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
