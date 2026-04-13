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

import '../../../app/themes/app_colors.dart';
import '../../../models/address_model.dart';
import '../../../models/india_locations.dart';
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
  Timer? _debounceTimer;
  String? _darkMapStyle;
  String? _lightMapStyle;

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
      if (mounted) _showSnackBar('Request timed out', isError: true);
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) _showSnackBar('Unable to fetch address', isError: true);
    } finally {
      if (mounted) setState(() => _isFetchingAddress = false);
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

      // District and City matching
      if (_selectedState != null) {
        // Try to match district from subAdministrativeArea or locality
        String districtCandidate = subAdministrativeArea.isNotEmpty 
            ? subAdministrativeArea 
            : locality;

        if (districtCandidate.isNotEmpty) {
          bool districtMatched = false;

          // Exact match
          for (String district in _filteredDistricts) {
            if (district.toLowerCase() == districtCandidate.toLowerCase()) {
              _selectedDistrict = district;
              _filteredCities = IndiaLocations.getCities(_selectedState!, district);
              _isManualDistrictEntry = false;
              districtMatched = true;
              debugPrint('✅ District matched (exact): $district');
              break;
            }
          }

          // Partial match
          if (!districtMatched) {
            for (String district in _filteredDistricts) {
              if (district.toLowerCase().contains(districtCandidate.toLowerCase()) ||
                  districtCandidate.toLowerCase().contains(district.toLowerCase())) {
                _selectedDistrict = district;
                _filteredCities = IndiaLocations.getCities(_selectedState!, district);
                _isManualDistrictEntry = false;
                districtMatched = true;
                debugPrint('✅ District matched (partial): $district');
                break;
              }
            }
          }

          if (!districtMatched) {
            _isManualDistrictEntry = true;
            _manualDistrictController.text = districtCandidate;
            debugPrint('❌ District not matched, using manual: $districtCandidate');
          }
        }

        // Try to match city
        if (_selectedDistrict != null && locality.isNotEmpty) {
          bool cityMatched = false;

          // Exact match
          for (String city in _filteredCities) {
            if (city.toLowerCase() == locality.toLowerCase()) {
              _selectedCity = city;
              _isManualCityEntry = false;
              cityMatched = true;
              debugPrint('✅ City matched (exact): $city');
              break;
            }
          }

          // Partial match
          if (!cityMatched) {
            for (String city in _filteredCities) {
              if (city.toLowerCase().contains(locality.toLowerCase()) ||
                  locality.toLowerCase().contains(city.toLowerCase())) {
                _selectedCity = city;
                _isManualCityEntry = false;
                cityMatched = true;
                debugPrint('✅ City matched (partial): $city');
                break;
              }
            }
          }

          if (!cityMatched) {
            _isManualCityEntry = true;
            _manualCityController.text = locality;
            debugPrint('❌ City not matched, using manual: $locality');
          }
        } else if (locality.isNotEmpty) {
          _isManualCityEntry = true;
          _manualCityController.text = locality;
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        content: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accentColor, accentColor.withOpacity(0.7)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 32),
                ),
                const SizedBox(height: 20),
                Text(
                  'Confirm Location',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Is this correct?',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[850] : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: accentColor.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (street.isNotEmpty && !street.toLowerCase().contains('unnamed')) ...[
                        _buildDialogAddressRow(Icons.home_rounded, street, isDark),
                        const SizedBox(height: 8),
                      ],
                      if (subLocality.isNotEmpty && subLocality != street) ...[
                        _buildDialogAddressRow(Icons.location_city_rounded, subLocality, isDark),
                        const SizedBox(height: 8),
                      ],
                      if (locality.isNotEmpty) ...[
                        _buildDialogAddressRow(Icons.location_on_rounded, locality, isDark),
                        const SizedBox(height: 8),
                      ],
                      if (subAdministrativeArea.isNotEmpty) ...[
                        _buildDialogAddressRow(Icons.map_rounded, subAdministrativeArea, isDark),
                        const SizedBox(height: 8),
                      ],
                      if (state.isNotEmpty || pincode.isNotEmpty)
                        _buildDialogAddressRow(
                          Icons.place_rounded,
                          '${state.isNotEmpty ? state : 'Unknown'}${pincode.isNotEmpty ? ' - $pincode' : ''}',
                          isDark,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: isDark ? Colors.black : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Use Address',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
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

  Future<void> _confirmLocationManually() async {
    HapticFeedback.mediumImpact();
    await _getAddressFromLatLng(_currentPosition, showConfirmation: true);
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.heavyImpact();
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
              },
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

          // Center Pin
          if (!_isLoadingLocation)
            IgnorePointer(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: _isFetchingAddress
                          ? SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                color: isDark ? Colors.black : Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : Icon(
                              Icons.location_on_rounded,
                              color: isDark ? Colors.black : Colors.white,
                              size: 32,
                            ),
                    ),
                    const SizedBox(height: 60),
                  ],
                ),
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

          // Top Bar
          SafeArea(
            child: Container(
              margin: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _buildIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.pop(context),
                    isDark: isDark,
                    cardColor: cardColor,
                  ),
                  const Spacer(),
                  _buildConfirmButton(isDark, accentColor),
                  const SizedBox(width: 8),
                  _buildIconButton(
                    icon: Icons.my_location_rounded,
                    onTap: _getCurrentLocation,
                    isDark: isDark,
                    cardColor: cardColor,
                  ),
                ],
              ),
            ),
          ),

          // Bottom Sheet
          if (!_isLoadingLocation)
            NotificationListener<DraggableScrollableNotification>(
              onNotification: (notification) {
                setState(() {
                  _isBottomSheetInteracting = notification.extent < 0.9;
                });
                return true;
              },
              child: DraggableScrollableSheet(
                initialChildSize: 0.45,
                minChildSize: 0.45,
                maxChildSize: 0.95,
                snap: true,
                snapSizes: const [0.45, 0.7, 0.95],
                builder: (context, scrollController) {
                  return NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is ScrollStartNotification) {
                        setState(() => _isBottomSheetInteracting = true);
                      } else if (notification is ScrollEndNotification) {
                        Future.delayed(const Duration(milliseconds: 300), () {
                          if (mounted) setState(() => _isBottomSheetInteracting = false);
                        });
                      }
                      return true;
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
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
                          Expanded(
                            child: SingleChildScrollView(
                              controller: scrollController,
                              physics: const ClampingScrollPhysics(),
                              padding: const EdgeInsets.all(20),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Enter Complete Address',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? Colors.white : Colors.black87,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Click "Confirm" to detect from map',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 24),

                                    // Address Types
                                    Row(
                                      children: [
                                        Expanded(child: _buildAddressTypeChip('Home', isDark, accentColor)),
                                        const SizedBox(width: 8),
                                        Expanded(child: _buildAddressTypeChip('Office', isDark, accentColor)),
                                        const SizedBox(width: 8),
                                        Expanded(child: _buildAddressTypeChip('Other', isDark, accentColor)),
                                      ],
                                    ),
                                    const SizedBox(height: 20),

                                    // Name & Phone
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildTextField(
                                            controller: _nameController,
                                            label: 'Full Name',
                                            icon: Icons.person_outline_rounded,
                                            isDark: isDark,
                                            accentColor: accentColor,
                                            validator: (value) =>
                                                value?.isEmpty ?? true ? 'Required' : null,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _buildTextField(
                                            controller: _phoneController,
                                            label: 'Phone',
                                            icon: Icons.phone_outlined,
                                            keyboardType: TextInputType.phone,
                                            isDark: isDark,
                                            accentColor: accentColor,
                                            inputFormatters: [
                                              FilteringTextInputFormatter.digitsOnly,
                                              LengthLimitingTextInputFormatter(10),
                                            ],
                                            validator: (value) {
                                              if (value?.isEmpty ?? true) return 'Required';
                                              if (value!.length != 10) return 'Invalid';
                                              return null;
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),

                                    _buildTextField(
                                      controller: _addressLine1Controller,
                                      label: 'House No, Building',
                                      icon: Icons.home_outlined,
                                      isDark: isDark,
                                      accentColor: accentColor,
                                      validator: (value) =>
                                          value?.isEmpty ?? true ? 'Required' : null,
                                    ),
                                    const SizedBox(height: 16),

                                    _buildTextField(
                                      controller: _addressLine2Controller,
                                      label: 'Road, Area, Colony',
                                      icon: Icons.location_city_outlined,
                                      isDark: isDark,
                                      accentColor: accentColor,
                                      validator: (value) =>
                                          value?.isEmpty ?? true ? 'Required' : null,
                                    ),
                                    const SizedBox(height: 16),

                                    _buildTextField(
                                      controller: _landmarkController,
                                      label: 'Landmark (Optional)',
                                      icon: Icons.place_outlined,
                                      isDark: isDark,
                                      accentColor: accentColor,
                                    ),
                                    const SizedBox(height: 20),

                                    // Location Header
                                    Row(
                                      children: [
                                        Icon(Icons.location_city_rounded, color: accentColor, size: 18),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Select Location',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // State
                                    _isManualStateEntry
                                        ? _buildTextField(
                                            controller: _manualStateController,
                                            label: 'State',
                                            icon: Icons.map_outlined,
                                            isDark: isDark,
                                            accentColor: accentColor,
                                            suffix: IconButton(
                                              icon: const Icon(Icons.close_rounded, size: 20),
                                              onPressed: () {
                                                setState(() {
                                                  _isManualStateEntry = false;
                                                  _manualStateController.clear();
                                                });
                                              },
                                            ),
                                          )
                                        : _buildLocationSelector(
                                            label: 'State',
                                            value: _selectedState,
                                            icon: Icons.map_outlined,
                                            onTap: _showStateSelector,
                                            isDark: isDark,
                                            accentColor: accentColor,
                                          ),
                                    const SizedBox(height: 12),

                                    // District
                                    _isManualDistrictEntry
                                        ? _buildTextField(
                                            controller: _manualDistrictController,
                                            label: 'District',
                                            icon: Icons.location_city_outlined,
                                            isDark: isDark,
                                            accentColor: accentColor,
                                            suffix: IconButton(
                                              icon: const Icon(Icons.close_rounded, size: 20),
                                              onPressed: () {
                                                setState(() {
                                                  _isManualDistrictEntry = false;
                                                  _manualDistrictController.clear();
                                                });
                                              },
                                            ),
                                          )
                                        : _buildLocationSelector(
                                            label: 'District',
                                            value: _selectedDistrict,
                                            icon: Icons.location_city_outlined,
                                            onTap: _showDistrictSelector,
                                            isDark: isDark,
                                            accentColor: accentColor,
                                          ),
                                    const SizedBox(height: 12),

                                    // City
                                    _isManualCityEntry
                                        ? _buildTextField(
                                            controller: _manualCityController,
                                            label: 'City',
                                            icon: Icons.location_on_outlined,
                                            isDark: isDark,
                                            accentColor: accentColor,
                                            suffix: IconButton(
                                              icon: const Icon(Icons.close_rounded, size: 20),
                                              onPressed: () {
                                                setState(() {
                                                  _isManualCityEntry = false;
                                                  _manualCityController.clear();
                                                });
                                              },
                                            ),
                                          )
                                        : _buildLocationSelector(
                                            label: 'City',
                                            value: _selectedCity,
                                            icon: Icons.location_on_outlined,
                                            onTap: _showCitySelector,
                                            isDark: isDark,
                                            accentColor: accentColor,
                                          ),
                                    const SizedBox(height: 16),

                                    // Pincode
                                    _buildTextField(
                                      controller: _pincodeController,
                                      label: 'Pincode',
                                      icon: Icons.pin_drop_outlined,
                                      keyboardType: TextInputType.number,
                                      isDark: isDark,
                                      accentColor: accentColor,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(6),
                                      ],
                                      validator: (value) {
                                        if (value?.isEmpty ?? true) return 'Required';
                                        if (value!.length != 6) return 'Must be 6 digits';
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 20),

                                    // Default checkbox
                                    InkWell(
                                      onTap: () {
                                        setState(() => _isDefault = !_isDefault);
                                        HapticFeedback.lightImpact();
                                      },
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: _isDefault
                                              ? accentColor.withOpacity(0.1)
                                              : (isDark ? Colors.grey[850] : Colors.grey[50]),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: _isDefault
                                                ? accentColor
                                                : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                                            width: _isDefault ? 2 : 1,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 24,
                                              height: 24,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: _isDefault
                                                      ? accentColor
                                                      : (isDark ? Colors.grey[600]! : Colors.grey[400]!),
                                                  width: 2,
                                                ),
                                                color: _isDefault
                                                    ? accentColor
                                                    : Colors.transparent,
                                              ),
                                              child: _isDefault
                                                  ? Icon(
                                                      Icons.check,
                                                      color: isDark ? Colors.black : Colors.white,
                                                      size: 16,
                                                    )
                                                  : null,
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              'Set as default address',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: isDark ? Colors.white : Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),

                                    // Save Button
                                    SizedBox(
                                      width: double.infinity,
                                      height: 54,
                                      child: ElevatedButton(
                                        onPressed: _isSaving ? null : _saveAddress,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: accentColor,
                                          foregroundColor: isDark ? Colors.black : Colors.white,
                                          disabledBackgroundColor: accentColor.withOpacity(0.5),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: _isSaving
                                            ? SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(
                                                  color: isDark ? Colors.black : Colors.white,
                                                  strokeWidth: 2.5,
                                                ),
                                              )
                                            : Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.check_circle_rounded,
                                                    size: 20,
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Text(
                                                    'Save Address',
                                                    style: TextStyle(
                                                      fontSize: 17,
                                                      fontWeight: FontWeight.w800,
                                                      letterSpacing: -0.3,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),
                                    const SizedBox(height: 40),
                                  ],
                                ),
                              ),
                            ),
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

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
    required Color cardColor,
  }) {
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(10),
      elevation: 4,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 48,
          height: 48,
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            color: isDark ? Colors.white : Colors.black87,
            size: 20,
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
