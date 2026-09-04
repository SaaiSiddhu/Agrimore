import 'package:flutter/foundation.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_services/agrimore_services.dart';
import 'dart:async';

class VendorProvider with ChangeNotifier {
  final VendorService _service = VendorService();
  
  List<VendorModel> _vendors = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription? _vendorSub;

  List<VendorModel> get vendors => _vendors;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get totalVendors => _vendors.length;
  int get activeVendors => _vendors.where((v) => v.status == VendorStatus.active).length;

  VendorProvider() {
    _init();
  }

  void _init() {
    _isLoading = true;
    notifyListeners();
    
    _vendorSub = _service.getVendors().listen(
      (data) {
        _vendors = data;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _isLoading = false;
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  Future<void> addVendor(VendorModel vendor) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      await _service.addVendor(vendor);
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateVendor(VendorModel vendor) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      await _service.updateVendor(vendor);
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteVendor(String id) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      await _service.deleteVendor(id);
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    _vendorSub?.cancel();
    super.dispose();
  }
}
