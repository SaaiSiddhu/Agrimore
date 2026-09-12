import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

class LocationSettingsScreen extends StatefulWidget {
  const LocationSettingsScreen({Key? key}) : super(key: key);

  @override
  State<LocationSettingsScreen> createState() => _LocationSettingsScreenState();
}

class _LocationSettingsScreenState extends State<LocationSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;

  bool _isHyperlocalEnabled = true;
  double _maxRadiusKm = 50.0;
  List<String> _activeLocations = [];
  final _newLocationController = TextEditingController();

  // HOME-2: the Home app bar's delivery-promise text, admin-editable
  // instead of a hardcoded Dart string. cityEtaOverrides keys are
  // lowercased on save so apps/marketplace's case-insensitive lookup
  // always matches what's saved here.
  final _defaultEtaTextController = TextEditingController(text: '10-15 mins');
  final _unserviceableTextController =
      TextEditingController(text: 'Not currently serviceable');
  Map<String, String> _cityEtaOverrides = {};
  final _overrideCityController = TextEditingController();
  final _overrideEtaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _newLocationController.dispose();
    _defaultEtaTextController.dispose();
    _unserviceableTextController.dispose();
    _overrideCityController.dispose();
    _overrideEtaController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('location_settings')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _isHyperlocalEnabled = data['isHyperlocalEnabled'] ?? true;
          _maxRadiusKm = (data['maxRadiusKm'] ?? 50.0).toDouble();
          _activeLocations = List<String>.from(data['activeLocations'] ?? []);
          final rawEta = data['defaultEtaText'];
          if (rawEta is String && rawEta.trim().isNotEmpty) {
            _defaultEtaTextController.text = rawEta;
          }
          final rawUnserviceable = data['unserviceableText'];
          if (rawUnserviceable is String && rawUnserviceable.trim().isNotEmpty) {
            _unserviceableTextController.text = rawUnserviceable;
          }
          final rawOverrides = data['cityEtaOverrides'];
          if (rawOverrides is Map) {
            _cityEtaOverrides = rawOverrides
                .map((key, value) => MapEntry(key.toString(), value.toString()));
          }
        });
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to load location settings: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('settings')
          .doc('location_settings')
          .set({
        'isHyperlocalEnabled': _isHyperlocalEnabled,
        'maxRadiusKm': _maxRadiusKm,
        'activeLocations': _activeLocations,
        'defaultEtaText': _defaultEtaTextController.text.trim(),
        'unserviceableText': _unserviceableTextController.text.trim(),
        'cityEtaOverrides': _cityEtaOverrides,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Location settings saved successfully');
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to save settings: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _addLocation() {
    final text = _newLocationController.text.trim();
    if (text.isNotEmpty && !_activeLocations.contains(text)) {
      setState(() {
        _activeLocations.add(text);
        _newLocationController.clear();
      });
    }
  }

  void _removeLocation(String location) {
    setState(() {
      _activeLocations.remove(location);
    });
  }

  void _addCityEtaOverride() {
    final city = _overrideCityController.text.trim().toLowerCase();
    final eta = _overrideEtaController.text.trim();
    if (city.isEmpty || eta.isEmpty) return;
    setState(() {
      _cityEtaOverrides = {..._cityEtaOverrides, city: eta};
      _overrideCityController.clear();
      _overrideEtaController.clear();
    });
  }

  void _removeCityEtaOverride(String city) {
    setState(() {
      _cityEtaOverrides = {..._cityEtaOverrides}..remove(city);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Location Settings'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hyperlocal GPS Settings',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Configure where products are available and how far users can see products from their GPS location.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),

                  // Hyperlocal Toggle
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: SwitchListTile(
                      title: const Text('Enable Hyperlocal Mode (GPS based)'),
                      subtitle: const Text('If enabled, users only see products within the set radius.'),
                      value: _isHyperlocalEnabled,
                      onChanged: (val) => setState(() => _isHyperlocalEnabled = val),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Radius Limit
                  if (_isHyperlocalEnabled)
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Service Surrounding Radius: ${_maxRadiusKm.toStringAsFixed(0)} km',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Slider(
                              value: _maxRadiusKm,
                              min: 1,
                              max: 500,
                              divisions: 100,
                              label: '${_maxRadiusKm.round()} km',
                              onChanged: (val) => setState(() => _maxRadiusKm = val),
                            ),
                            const Text(
                              'Users cannot view products if they are beyond this radius from the seller or active area.',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 24),

                  // Active Locations
                  const Text(
                    'Active Service Locations',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add cities/districts where sellers are allowed to add products (e.g., Theni, Madurai).',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newLocationController,
                          decoration: const InputDecoration(
                            hintText: 'Add new location',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onSubmitted: (_) => _addLocation(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addLocation,
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _activeLocations.map((loc) {
                      return Chip(
                        label: Text(loc),
                        onDeleted: () => _removeLocation(loc),
                        deleteIcon: const Icon(Icons.close, size: 18),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 32),

                  // Delivery Promise (ETA) — HOME-2
                  const Text(
                    'Delivery Promise (Home screen)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'The delivery-time text shown in the Home app bar. Set a default, and '
                    'optionally a different promise for specific active locations above.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _defaultEtaTextController,
                    decoration: const InputDecoration(
                      labelText: 'Default delivery promise',
                      hintText: 'e.g. 10-15 mins',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _unserviceableTextController,
                    decoration: const InputDecoration(
                      labelText: 'Message when not serviceable',
                      hintText: 'e.g. Not currently serviceable',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Per-location overrides',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _overrideCityController,
                          decoration: const InputDecoration(
                            hintText: 'Location (e.g. Chennai)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _overrideEtaController,
                          decoration: const InputDecoration(
                            hintText: 'ETA (e.g. 15-20 mins)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onSubmitted: (_) => _addCityEtaOverride(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addCityEtaOverride,
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_cityEtaOverrides.isEmpty)
                    const Text(
                      'No per-location overrides — the default promise above applies everywhere serviceable.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    )
                  else
                    Column(
                      children: _cityEtaOverrides.entries.map((entry) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            dense: true,
                            title: Text(entry.key),
                            subtitle: Text(entry.value),
                            trailing: IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () => _removeCityEtaOverride(entry.key),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Save Location Settings'),
                    ),
                  )
                ],
              ),
            ),
    );
  }
}
