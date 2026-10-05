import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agrimore_services/agrimore_services.dart';

class AddressProvider with ChangeNotifier {
  AddressProvider({
    String? Function()? currentUserId,
    Stream<String?> Function()? authChanges,
    Stream<List<AddressModel>> Function(String)? snapshots,
    Future<List<AddressModel>> Function(String)? read,
    Future<String> Function(AddressModel)? add,
    Future<void> Function(String, Map<String, dynamic>)? update,
    Future<void> Function(String)? delete,
  })  : _currentUserId = currentUserId ?? (() => AuthService().currentUserId),
        _authChanges = authChanges ??
            (() => AuthService().authStateChanges.map((u) => u?.uid)),
        _snapshots = snapshots,
        _read = read,
        _add = add,
        _update = update,
        _delete = delete;
  late final DatabaseService _databaseService = DatabaseService();
  final String? Function() _currentUserId;
  final Stream<String?> Function() _authChanges;
  final Stream<List<AddressModel>> Function(String)? _snapshots;
  final Future<List<AddressModel>> Function(String)? _read;
  final Future<String> Function(AddressModel)? _add;
  final Future<void> Function(String, Map<String, dynamic>)? _update;
  final Future<void> Function(String)? _delete;
  Stream<List<AddressModel>> _stream(String uid) =>
      _snapshots?.call(uid) ?? _databaseService.getUserAddresses(uid);
  Future<String> _save(AddressModel value) =>
      _add?.call(value) ?? _databaseService.addAddress(value);
  Future<void> _edit(String id, Map<String, dynamic> value) =>
      _update?.call(id, value) ?? _databaseService.updateAddress(id, value);
  Future<void> _remove(String id) =>
      _delete?.call(id) ?? _databaseService.deleteAddress(id);
  StreamSubscription<List<AddressModel>>? _addressSubscription;
  StreamSubscription<String?>? _authSubscription;
  List<AddressModel> _addresses = [];
  AddressModel? _selectedAddress;
  String? _ownerId, _error;
  int _sessionGeneration = 0, _listGeneration = 0, _operations = 0;
  bool _disposed = false, _listStarted = false;
  Future<void> _writeQueue = Future<void>.value();
  bool get _hasOwner =>
      !_disposed && _ownerId != null && _ownerId == _currentUserId();
  bool _owns(String uid, int generation) =>
      _hasOwner && _ownerId == uid && generation == _sessionGeneration;
  bool _valid(AddressModel value, String uid) =>
      value.userId == uid && value.id.isNotEmpty;
  List<AddressModel> get addresses =>
      List.unmodifiable(_hasOwner ? _addresses : <AddressModel>[]);
  AddressModel? get selectedAddress => _hasOwner ? _selectedAddress : null;
  bool get isLoading => _hasOwner && _operations > 0;
  String? get error =>
      !_disposed && _ownerId == _currentUserId() ? _error : null;
  bool get hasAddresses => addresses.isNotEmpty;
  AddressModel? get defaultAddress {
    final rows = addresses;
    if (rows.isEmpty) return null;
    return rows.firstWhere((a) => a.isDefault, orElse: () => rows.first);
  }

  bool _syncOwner() {
    final uid = _currentUserId();
    if (_ownerId == uid) return false;
    _ownerId = uid;
    ++_sessionGeneration;
    ++_listGeneration;
    _addressSubscription?.cancel();
    _addressSubscription = null;
    _addresses = [];
    _selectedAddress = null;
    _error = null;
    _operations = 0;
    _writeQueue = Future<void>.value();
    return true;
  }

  bool _bindSession() {
    if (_disposed) return false;
    _authSubscription ??= _authChanges().listen((uid) {
      if (_disposed || uid != _currentUserId() || uid == _ownerId) return;
      _syncOwner();
      notifyListeners();
      if (_listStarted && uid != null) loadAddresses();
    });
    return _syncOwner();
  }

  void loadAddresses() {
    if (_disposed) return;
    _listStarted = true;
    _bindSession();
    _addressSubscription?.cancel();
    _addressSubscription = null;
    final listGeneration = ++_listGeneration;
    final uid = _ownerId;
    _error = null;
    if (uid == null) {
      notifyListeners();
      return;
    }
    final generation = _sessionGeneration;
    bool ownsList() =>
        _owns(uid, generation) && listGeneration == _listGeneration;
    _addressSubscription = _stream(uid).listen((rows) {
      if (!ownsList()) return;
      if (rows.any((a) => !_valid(a, uid))) {
        _addresses = [];
        _selectedAddress = null;
        _error = 'Could not load your addresses.';
      } else {
        _addresses = List.of(rows);
        _error = null;
        if (_selectedAddress != null) {
          final matching = rows.where((a) => a.id == _selectedAddress!.id);
          _selectedAddress = matching.isEmpty ? null : matching.first;
        }
      }
      notifyListeners();
    }, onError: (Object e) {
      if (!ownsList()) return;
      _error = 'Could not load your addresses. Please try again.';
      notifyListeners();
    });
  }

  Future<T?> _mutate<T>(
      Future<T> Function(String, int, List<AddressModel>) action) async {
    if (_disposed) return null;
    final changed = _bindSession();
    if (changed && _listStarted && _ownerId != null) loadAddresses();
    final uid = _ownerId;
    if (uid == null) return null;
    final generation = _sessionGeneration;
    ++_operations;
    _error = null;
    notifyListeners();
    final result = _writeQueue.then<T?>((_) async {
      try {
        if (!_owns(uid, generation)) return null;
        final rows = await (_read?.call(uid) ?? _stream(uid).first);
        if (!_owns(uid, generation)) return null;
        if (rows.any((a) => !_valid(a, uid))) {
          throw StateError('Address owner mismatch.');
        }
        final value = await action(uid, generation, List.of(rows));
        if (!_owns(uid, generation)) return null;
        return value;
      } catch (_) {
        if (_owns(uid, generation)) {
          _error = 'Could not save your address. Please try again.';
        }
        return null;
      } finally {
        if (_owns(uid, generation)) {
          --_operations;
          notifyListeners();
        }
      }
    });
    _writeQueue = result.then((_) {});
    return result;
  }

  void _requireSession(String uid, int generation) {
    if (!_owns(uid, generation)) throw StateError('Address session changed.');
  }

  Future<String?> addAddress(AddressModel address) =>
      _mutate<String>((uid, generation, rows) async {
        if (address.userId != uid) throw StateError('Address owner mismatch.');
        final toSave =
            rows.isEmpty ? address.copyWith(isDefault: true) : address;
        if (toSave.isDefault) {
          for (final row
              in rows.where((a) => a.isDefault && a.id != toSave.id)) {
            _requireSession(uid, generation);
            await _edit(row.id, {'isDefault': false});
            _requireSession(uid, generation);
          }
        }
        _requireSession(uid, generation);
        return _save(toSave);
      });
  Future<bool> updateAddress(
      String addressId, Map<String, dynamic> updates) async {
    final value = Map<String, dynamic>.of(updates);
    return await _mutate<bool>((uid, generation, rows) async {
          if (!rows.any((a) => a.id == addressId) ||
              (value.containsKey('userId') && value['userId'] != uid) ||
              (value.containsKey('id') && value['id'] != addressId)) {
            throw StateError('Address owner mismatch.');
          }
          _requireSession(uid, generation);
          await _edit(addressId, value);
          return true;
        }) ??
        false;
  }

  Future<bool> deleteAddress(String addressId) async =>
      await _mutate<bool>((uid, generation, rows) async {
        if (!rows.any((a) => a.id == addressId)) {
          throw StateError('Address owner mismatch.');
        }
        _requireSession(uid, generation);
        await _remove(addressId);
        return true;
      }) ??
      false;
  Future<bool> setDefaultAddress(String addressId) async =>
      await _mutate<bool>((uid, generation, rows) async {
        if (!rows.any((a) => a.id == addressId)) {
          throw StateError('Address owner mismatch.');
        }
        for (final row in rows.where((a) => a.isDefault && a.id != addressId)) {
          _requireSession(uid, generation);
          await _edit(row.id, {'isDefault': false});
          _requireSession(uid, generation);
        }
        _requireSession(uid, generation);
        await _edit(addressId, {'isDefault': true});
        return true;
      }) ??
      false;
  void selectAddress(AddressModel address) {
    if (_disposed) return;
    final changed = _bindSession();
    if (changed && _listStarted && _ownerId != null) loadAddresses();
    if (!_hasOwner || !_valid(address, _ownerId!)) return;
    _selectedAddress = address;
    notifyListeners();
  }

  void clearSelectedAddress() {
    if (_disposed) return;
    _selectedAddress = null;
    notifyListeners();
  }

  void clearError() {
    if (_disposed) return;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_sessionGeneration;
    ++_listGeneration;
    _authSubscription?.cancel();
    _addressSubscription?.cancel();
    _addresses = [];
    _selectedAddress = null;
    _error = null;
    _operations = 0;
    super.dispose();
  }
}
