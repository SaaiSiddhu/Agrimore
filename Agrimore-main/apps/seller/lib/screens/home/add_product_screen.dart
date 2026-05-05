import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/seller_auth_provider.dart';
import '../../providers/seller_product_provider.dart';

class AddProductScreen extends StatefulWidget {
  final ProductModel? existingProduct;

  const AddProductScreen({super.key, this.existingProduct});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _originalPriceController = TextEditingController();
  final _stockController = TextEditingController();
  final _categoryController = TextEditingController();
  final _lowStockThresholdController = TextEditingController(text: '10');
  final _districtController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  List<String> _masterImages = [];
  List<Map<String, dynamic>> _masterSuggestions = [];
  List<Map<String, dynamic>> _centers = [];
  Map<String, dynamic>? _selectedMasterProduct;
  Map<String, dynamic>? _selectedCenter;
  bool _isGeneratingAI = false;
  bool _isSaving = false;
  bool _isSearchingMasterProducts = false;
  bool _isLoadingCenters = false;
  bool _isDetectingCoverageLocation = false;
  bool _isApplyingProgrammaticPrice = false;
  bool _manualPriceEdited = false;
  String _locationType = 'state';
  String _selectedState = 'Tamil Nadu';
  String _priceSource = 'default';
  double _radiusKm = 10;
  double? _basePrice;
  double? _areaPrice;

  static const List<String> _states = ['Tamil Nadu'];
  static const List<String> _tamilNaduDistricts = [
    'Ariyalur',
    'Chengalpattu',
    'Chennai',
    'Coimbatore',
    'Cuddalore',
    'Dharmapuri',
    'Dindigul',
    'Erode',
    'Kallakurichi',
    'Kanchipuram',
    'Kanniyakumari',
    'Karur',
    'Krishnagiri',
    'Madurai',
    'Mayiladuthurai',
    'Nagapattinam',
    'Namakkal',
    'Nilgiris',
    'Perambalur',
    'Pudukkottai',
    'Ramanathapuram',
    'Ranipet',
    'Salem',
    'Sivaganga',
    'Tenkasi',
    'Thanjavur',
    'Theni',
    'Thoothukudi',
    'Tiruchirappalli',
    'Tirunelveli',
    'Tirupathur',
    'Tiruppur',
    'Tiruvallur',
    'Tiruvannamalai',
    'Tiruvarur',
    'Vellore',
    'Viluppuram',
    'Virudhunagar',
  ];

  bool get isEditing => widget.existingProduct != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final p = widget.existingProduct!;
      _nameController.text = p.name;
      _descriptionController.text = p.description;
      _priceController.text = p.salePrice.toStringAsFixed(0);
      _originalPriceController.text =
          (p.originalPrice ?? p.salePrice).toStringAsFixed(0);
      _stockController.text = p.stock.toString();
      _categoryController.text = p.categoryId;
      _lowStockThresholdController.text =
          (p.lowStockThreshold ?? 10).toString();
      _locationType = p.locationType.isEmpty ? 'state' : p.locationType;
      _selectedState = p.state ?? 'Tamil Nadu';
      _districtController.text = p.district ?? '';
      _latController.text = p.lat?.toString() ?? '';
      _lngController.text = p.lng?.toString() ?? '';
      _radiusKm = p.radiusKm ?? 10;
      _basePrice = p.basePrice ?? p.salePrice;
      _areaPrice = p.areaPrice;
      _manualPriceEdited = p.manualPriceOverride;
      _priceSource = p.priceSource;
      if (p.masterProductRef != null && p.masterProductRef!.isNotEmpty) {
        _selectedMasterProduct = {'id': p.masterProductRef, 'name': p.name};
      }
      if (p.centerId != null && p.centerId!.isNotEmpty) {
        _selectedCenter = {
          'id': p.centerId,
          'name': p.centerName ?? p.centerId
        };
      }
    }
    _priceController.addListener(_handleManualPriceEdit);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCenters());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _originalPriceController.dispose();
    _stockController.dispose();
    _categoryController.dispose();
    _lowStockThresholdController.dispose();
    _districtController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  void _handleManualPriceEdit() {
    if (_isApplyingProgrammaticPrice || _priceController.text.trim().isEmpty) {
      return;
    }
    _manualPriceEdited = true;
    _priceSource = 'manual';
  }

  Future<void> _loadCenters() async {
    if (!mounted) return;
    setState(() => _isLoadingCenters = true);
    try {
      final centers = await context.read<SellerProductProvider>().loadCenters();
      if (!mounted) return;
      setState(() {
        _centers = centers;
        if (_selectedCenter != null) {
          _selectedCenter = centers.cast<Map<String, dynamic>?>().firstWhere(
                (center) => center?['id'] == _selectedCenter?['id'],
                orElse: () => _selectedCenter,
              );
        }
      });
    } finally {
      if (mounted) setState(() => _isLoadingCenters = false);
    }
  }

  Future<void> _searchMasterProducts(String value) async {
    if (value.trim().length < 2) {
      setState(() => _masterSuggestions = []);
      return;
    }
    setState(() => _isSearchingMasterProducts = true);
    final results =
        await context.read<SellerProductProvider>().searchMasterProducts(value);
    if (!mounted) return;
    setState(() {
      _masterSuggestions = results;
      _isSearchingMasterProducts = false;
    });
  }

  Future<void> _selectMasterProduct(Map<String, dynamic> product) async {
    final basePrice = ((product['basePrice'] ??
            product['salePrice'] ??
            product['price'] ??
            product['mrp']) as num?)
        ?.toDouble();
    setState(() {
      _selectedMasterProduct = product;
      _masterSuggestions = [];
      _nameController.text = (product['name'] ?? '').toString();
      _descriptionController.text = (product['description'] ?? '').toString();
      _categoryController.text =
          (product['categoryId'] ?? product['category'] ?? 'general')
              .toString();
      _originalPriceController.text =
          ((product['mrp'] ?? product['originalPrice'] ?? basePrice) ?? '')
              .toString();
      _masterImages = List<String>.from(
        product['images'] ?? product['imageUrls'] ?? const [],
      );
      _basePrice = basePrice;
      _areaPrice = null;
      _manualPriceEdited = false;
      _priceSource = 'default';
    });
    if (basePrice != null) _setEffectivePrice(basePrice, 'default');
    await _applyCenterPrice();
  }

  Future<void> _selectCenter(Map<String, dynamic>? center) async {
    setState(() => _selectedCenter = center);
    await _applyCenterPrice();
  }

  Future<void> _applyCenterPrice() async {
    final masterId = _selectedMasterProduct?['id']?.toString();
    final centerId = _selectedCenter?['id']?.toString();
    if (masterId == null || centerId == null) return;

    final sellerId = context.read<SellerAuthProvider>().currentUser?.uid;
    final centerPrice =
        await context.read<SellerProductProvider>().getCenterPrice(
              masterProductId: masterId,
              centerId: centerId,
              sellerId: sellerId,
            );
    if (!mounted) return;
    setState(() => _areaPrice = centerPrice);

    if (_manualPriceEdited) return;
    if (centerPrice != null) {
      _setEffectivePrice(centerPrice, 'area');
    } else if (_basePrice != null) {
      _setEffectivePrice(_basePrice!, 'default');
    }
  }

  void _setEffectivePrice(double price, String source) {
    _isApplyingProgrammaticPrice = true;
    _priceController.text = price.toStringAsFixed(0);
    _isApplyingProgrammaticPrice = false;
    setState(() {
      _priceSource = source;
      _manualPriceEdited = source == 'manual';
    });
  }

  void _resetToMappedPrice() {
    final price = _areaPrice ?? _basePrice;
    if (price == null) return;
    _setEffectivePrice(price, _areaPrice == null ? 'default' : 'area');
  }

  bool _validateCoverage() {
    if (_locationType == 'district' &&
        _districtController.text.trim().isEmpty) {
      SnackbarHelper.showError(context, 'Please select a delivery district.');
      return false;
    }
    if (_locationType == 'radius') {
      final lat = double.tryParse(_latController.text.trim());
      final lng = double.tryParse(_lngController.text.trim());
      if (lat == null || lng == null) {
        SnackbarHelper.showError(
            context, 'Please set latitude and longitude for radius delivery.');
        return false;
      }
    }
    return true;
  }

  String _coverageLabel() {
    if (_locationType == 'district') {
      return '${_districtController.text.trim()}, $_selectedState';
    }
    if (_locationType == 'radius') {
      return '${_radiusKm.round()} km radius, $_selectedState';
    }
    return _selectedState;
  }

  Future<void> _useCurrentCoverageLocation() async {
    setState(() => _isDetectingCoverageLocation = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          SnackbarHelper.showError(context, 'Please enable location service.');
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          SnackbarHelper.showError(context, 'Location permission denied.');
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      setState(() {
        _locationType = 'radius';
        _latController.text = position.latitude.toStringAsFixed(6);
        _lngController.text = position.longitude.toStringAsFixed(6);
      });
    } catch (_) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Unable to detect current location.');
      }
    } finally {
      if (mounted) setState(() => _isDetectingCoverageLocation = false);
    }
  }

  Future<void> _generateAIDescription() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      SnackbarHelper.showError(context, 'Please enter a product name first.');
      return;
    }

    setState(() => _isGeneratingAI = true);

    // Simulate AI Generation Delay
    await Future.delayed(const Duration(seconds: 2));

    final aiDescription =
        'Premium quality $name sourced directly from trusted farms. '
        'Rich in flavor and naturally grown to ensure the best health benefits for you and your family. '
        'Perfect for everyday use.\n\n'
        '✨ 100% Organic\n'
        '✨ Farm Fresh\n'
        '✨ No Artificial Preservatives';

    setState(() {
      _descriptionController.text = aiDescription;
      _isGeneratingAI = false;
    });

    if (mounted) {
      SnackbarHelper.showSuccess(
          context, 'AI Description Generated Successfully!');
    }
  }

  Future<void> _pickProductImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1600,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _selectedImage = image;
        _selectedImageBytes = bytes;
      });
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Unable to pick product image.');
      }
    }
  }

  Future<String?> _uploadSelectedImage(String sellerId) async {
    if (_selectedImage == null) return null;

    final bytes = _selectedImageBytes ?? await _selectedImage!.readAsBytes();
    final ext = _selectedImage!.name.split('.').last.toLowerCase();
    final normalizedExt =
        ['jpg', 'jpeg', 'png', 'webp'].contains(ext) ? ext : 'jpg';
    final contentType = normalizedExt == 'jpg'
        ? 'image/jpeg'
        : normalizedExt == 'webp'
            ? 'image/webp'
            : 'image/$normalizedExt';

    final ref = FirebaseStorage.instance.ref().child(
          'product_images/${sellerId}_${DateTime.now().millisecondsSinceEpoch}.$normalizedExt',
        );
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_validateCoverage()) return;

    final auth = context.read<SellerAuthProvider>();
    if (auth.currentUser == null) return;
    final sellerId = auth.currentUser!.uid;
    final productProvider = context.read<SellerProductProvider>();

    setState(() => _isSaving = true);

    final salePrice = double.tryParse(_priceController.text) ?? 0.0;
    final originalPrice = double.tryParse(_originalPriceController.text);
    final stock = int.tryParse(_stockController.text) ?? 0;
    final lowThreshold = int.tryParse(_lowStockThresholdController.text) ?? 10;
    final coverageDistrict =
        _locationType == 'district' ? _districtController.text.trim() : null;
    final coverageLat = _locationType == 'radius'
        ? double.tryParse(_latController.text.trim())
        : null;
    final coverageLng = _locationType == 'radius'
        ? double.tryParse(_lngController.text.trim())
        : null;
    final coverageRadius = _locationType == 'radius' ? _radiusKm : null;
    String? uploadedImageUrl;

    try {
      uploadedImageUrl = await _uploadSelectedImage(sellerId);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        SnackbarHelper.showError(
            context, 'Image upload failed. Please try again.');
      }
      return;
    }

    if (isEditing) {
      final existingImages = widget.existingProduct!.images.isNotEmpty
          ? widget.existingProduct!.images
          : _masterImages;
      final updatedImages = uploadedImageUrl == null
          ? existingImages
          : [
              uploadedImageUrl,
              ...existingImages.where((url) => url != uploadedImageUrl),
            ];

      // Update existing product
      final updated = widget.existingProduct!.copyWith(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        salePrice: salePrice,
        originalPrice: originalPrice,
        stock: stock,
        categoryId: _categoryController.text.trim().isEmpty
            ? 'general'
            : _categoryController.text.trim(),
        images: updatedImages,
        lowStockThreshold: lowThreshold,
        masterProductRef: _selectedMasterProduct?['id']?.toString(),
        centerId: _selectedCenter?['id']?.toString(),
        centerName: _selectedCenter?['name']?.toString(),
        basePrice: _basePrice ?? salePrice,
        areaPrice: _areaPrice,
        manualPriceOverride: _manualPriceEdited,
        priceSource: _priceSource,
        location: _coverageLabel(),
        locationType: _locationType,
        state: _selectedState,
        district: coverageDistrict,
        lat: coverageLat,
        lng: coverageLng,
        radiusKm: coverageRadius,
        clearDistrict: _locationType != 'district',
        clearCoordinates: _locationType != 'radius',
        clearRadius: _locationType != 'radius',
        updatedAt: DateTime.now(),
      );

      final success = await productProvider.updateProduct(updated);

      if (!mounted) return;
      setState(() => _isSaving = false);

      if (success) {
        SnackbarHelper.showSuccess(context, 'Product updated successfully!');
        Navigator.pop(context);
      }
    } else {
      // Create new product
      final product = ProductModel(
        id: '',
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        salePrice: salePrice,
        originalPrice: originalPrice,
        stock: stock,
        categoryId: _categoryController.text.trim().isEmpty
            ? 'general'
            : _categoryController.text.trim(),
        sellerId: sellerId,
        location: _coverageLabel(),
        locationType: _locationType,
        state: _selectedState,
        district: coverageDistrict,
        lat: coverageLat,
        lng: coverageLng,
        radiusKm: coverageRadius,
        isVerified: false,
        isActive: true,
        images: uploadedImageUrl == null
            ? _masterImages
            : [
                uploadedImageUrl,
                ..._masterImages.where((url) => url != uploadedImageUrl),
              ],
        lowStockThreshold: lowThreshold,
        masterProductRef: _selectedMasterProduct?['id']?.toString(),
        centerId: _selectedCenter?['id']?.toString(),
        centerName: _selectedCenter?['name']?.toString(),
        basePrice: _basePrice ?? salePrice,
        areaPrice: _areaPrice,
        manualPriceOverride: _manualPriceEdited,
        priceSource: _priceSource,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final success = await productProvider.addProduct(product);

      if (!mounted) return;
      setState(() => _isSaving = false);

      if (success) {
        SnackbarHelper.showSuccess(
            context, 'Product added successfully! Waiting for admin approval.');
        Navigator.pop(context);
      }
    }
  }

  Widget _buildImagePicker() {
    final existingImage = isEditing ? widget.existingProduct!.primaryImage : '';
    final hasSelectedImage = _selectedImageBytes != null;
    final hasExistingImage = existingImage.isNotEmpty;

    return InkWell(
      onTap: _isSaving ? null : _pickProductImage,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        height: 170,
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasSelectedImage)
              Image.memory(_selectedImageBytes!, fit: BoxFit.cover)
            else if (hasExistingImage)
              Image.network(existingImage, fit: BoxFit.cover)
            else
              const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                  SizedBox(height: 8),
                  Text(
                    'Upload Product Image',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            Positioned(
              right: 12,
              bottom: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.photo_library_outlined,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      hasSelectedImage || hasExistingImage
                          ? 'Change'
                          : 'Choose',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMasterSuggestions() {
    if (_isSearchingMasterProducts) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }
    if (_masterSuggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: _masterSuggestions.map((product) {
          final price =
              product['basePrice'] ?? product['salePrice'] ?? product['price'];
          return ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: Text(
              (product['name'] ?? '').toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              [
                if (product['category'] != null) product['category'],
                if (product['unit'] != null) product['unit'],
                if (price != null) 'Rs.$price',
              ].join(' • '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _selectMasterProduct(product),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSelectorPricingSection(ThemeData theme) {
    final selectedCenterId = _selectedCenter?['id']?.toString();
    final priceLabel = switch (_priceSource) {
      'manual' => 'Manual price',
      'area' => 'Area / hub price',
      _ => 'Default price',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hub_outlined, color: Color(0xFF2D7D3C)),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Center / Area Pricing',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              Chip(
                label: Text(priceLabel),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: selectedCenterId,
            decoration: InputDecoration(
              labelText: _isLoadingCenters ? 'Loading centers...' : 'Selector',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.store_mall_directory_outlined),
            ),
            items: _centers
                .map((center) => DropdownMenuItem<String>(
                      value: center['id'].toString(),
                      child: Text(center['name'].toString()),
                    ))
                .toList(),
            onChanged: (id) {
              final center = _centers.cast<Map<String, dynamic>?>().firstWhere(
                    (item) => item?['id']?.toString() == id,
                    orElse: () => null,
                  );
              _selectCenter(center);
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPriceInfoChip('Default', _basePrice),
              _buildPriceInfoChip('Area', _areaPrice),
              _buildPriceInfoChip(
                'Current',
                double.tryParse(_priceController.text.trim()),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: (_basePrice == null && _areaPrice == null)
                  ? null
                  : _resetToMappedPrice,
              icon: const Icon(Icons.restart_alt_outlined),
              label: const Text('Reset mapped price'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceInfoChip(String label, double? price) {
    return Chip(
      label: Text(
          '$label: ${price == null ? '-' : 'Rs.${price.toStringAsFixed(0)}'}'),
      backgroundColor: const Color(0xFF2D7D3C).withValues(alpha: 0.08),
      side: BorderSide.none,
    );
  }

  Widget _buildCoverageSection(ThemeData theme) {
    final districtValue =
        _tamilNaduDistricts.contains(_districtController.text.trim())
            ? _districtController.text.trim()
            : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D7D3C).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  color: Color(0xFF2D7D3C),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delivery Coverage Area',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Default is full Tamil Nadu. Use radius for targeted delivery.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Full State'),
                selected: _locationType == 'state',
                onSelected: (_) => setState(() => _locationType = 'state'),
              ),
              ChoiceChip(
                label: const Text('District'),
                selected: _locationType == 'district',
                onSelected: (_) => setState(() => _locationType = 'district'),
              ),
              ChoiceChip(
                label: const Text('Radius'),
                selected: _locationType == 'radius',
                onSelected: (_) => setState(() => _locationType = 'radius'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedState,
            decoration: const InputDecoration(
              labelText: 'State',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.map_outlined),
            ),
            items: _states
                .map((state) => DropdownMenuItem(
                      value: state,
                      child: Text(state),
                    ))
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selectedState = value);
            },
          ),
          if (_locationType == 'district') ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: districtValue,
              decoration: const InputDecoration(
                labelText: 'District',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_city_outlined),
              ),
              items: _tamilNaduDistricts
                  .map((district) => DropdownMenuItem(
                        value: district,
                        child: Text(district),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _districtController.text = value);
              },
              validator: (_) => _locationType == 'district' &&
                      _districtController.text.trim().isEmpty
                  ? 'Required'
                  : null,
            ),
          ],
          if (_locationType == 'radius') ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _latController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Latitude',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.my_location_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _lngController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Longitude',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.explore_outlined),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isDetectingCoverageLocation
                  ? null
                  : _useCurrentCoverageLocation,
              icon: _isDetectingCoverageLocation
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.gps_fixed_outlined),
              label: Text(
                _isDetectingCoverageLocation
                    ? 'Detecting...'
                    : 'Use Current Location',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Radius: ${_radiusKm.round()} km',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Slider(
              min: 1,
              max: 50,
              divisions: 49,
              value: _radiusKm.clamp(1, 50),
              label: '${_radiusKm.round()} km',
              activeColor: const Color(0xFF2D7D3C),
              onChanged: (value) => setState(() => _radiusKm = value),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Product' : 'Add New Product'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImagePicker(),
              const SizedBox(height: 24),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Product Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.shopping_bag_outlined),
                ),
                onChanged: _searchMasterProducts,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              _buildMasterSuggestions(),
              const SizedBox(height: 16),

              _buildSelectorPricingSection(theme),
              const SizedBox(height: 16),

              // AI Description Field
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.purple.withValues(alpha: 0.3), width: 2),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.auto_awesome,
                                  color: Colors.purple, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'AI Description',
                                style: TextStyle(
                                    color: Colors.purple,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            onPressed:
                                _isGeneratingAI ? null : _generateAIDescription,
                            icon: _isGeneratingAI
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.flash_on, size: 16),
                            label: Text(
                                _isGeneratingAI ? 'Generating...' : 'Generate'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.purple,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText:
                            'Enter product description or use AI to generate an SEO-friendly description.',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Sale Price (₹)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.currency_rupee),
                      ),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _originalPriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'MRP (₹)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.price_change_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Stock + Low Stock Threshold
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _stockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Stock Qty',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.inventory_2_outlined),
                      ),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _lowStockThresholdController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Low Stock Alert',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.notifications_active_outlined),
                        helperText: 'Alert when below this',
                        helperMaxLines: 1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category (e.g., Vegetables)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category_outlined),
                ),
              ),

              const SizedBox(height: 16),
              _buildCoverageSection(theme),

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _saveProduct,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Icon(isEditing ? Icons.save : Icons.check),
                  label: Text(
                    _isSaving
                        ? 'Saving...'
                        : (isEditing ? 'Update Product' : 'Save Product'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2D7D3C),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
