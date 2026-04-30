import 'package:flutter/material.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_services/agrimore_services.dart';

class AddressProvider with ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  final AuthService _authService = AuthService();

  List<AddressModel> _addresses = [];
  AddressModel? _selectedAddress;
  bool _isLoading = false;
  String? _error;

  List<AddressModel> get addresses => _addresses;
  AddressModel? get selectedAddress => _selectedAddress;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  bool get hasAddresses => _addresses.isNotEmpty;
  AddressModel? get defaultAddress {
    if (_addresses.isEmpty) return null;
    try {
      return _addresses.firstWhere((addr) => addr.isDefault);
    } catch (_) {
      return _addresses.first;
    }
  }

  // Load user addresses
  void loadAddresses() {
    final userId = _authService.currentUserId;
    if (userId == null) return;

    _databaseService.getUserAddresses(userId).listen(
      (addresses) {
        _addresses = addresses;
        notifyListeners();
      },
      onError: (error) {
        _error = error.toString();
        notifyListeners();
      },
    );
  }

  // Add address
  Future<String?> addAddress(AddressModel address) async {
    try {
      _isLoading = true;
      notifyListeners();

      AddressModel toSave = address;

      // ── First address ever → always default ──────────────────
      if (_addresses.isEmpty) {
        toSave = address.copyWith(isDefault: true);
        debugPrint('📍 First address → setting as default automatically');
      } else if (address.isDefault) {
        // Remove default flag from all existing addresses
        for (var addr in _addresses) {
          if (addr.isDefault) {
            await _databaseService.updateAddress(addr.id, {'isDefault': false});
          }
        }
      }

      final addressId = await _databaseService.addAddress(toSave);

      _isLoading = false;
      notifyListeners();
      return addressId;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }


  // Update address
  Future<bool> updateAddress(String addressId, Map<String, dynamic> updates) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _databaseService.updateAddress(addressId, updates);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Delete address
  Future<bool> deleteAddress(String addressId) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _databaseService.deleteAddress(addressId);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Set default address
  Future<bool> setDefaultAddress(String addressId) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Remove default from all addresses
      for (var addr in _addresses) {
        if (addr.isDefault && addr.id != addressId) {
          await _databaseService.updateAddress(addr.id, {'isDefault': false});
        }
      }

      // Set new default
      await _databaseService.updateAddress(addressId, {'isDefault': true});

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Select address
  void selectAddress(AddressModel address) {
    _selectedAddress = address;
    notifyListeners();
  }

  // Clear selected address
  void clearSelectedAddress() {
    _selectedAddress = null;
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
