import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_services/agrimore_services.dart' hide DefaultFirebaseOptions;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/seller_auth_provider.dart';
import '../../providers/seller_product_provider.dart';
import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import '../products/seller_products_screen.dart' show productStockBadge;
import '../products/widgets/product_tax_section.dart';
import '../products/product_stats.dart';
import '../../providers/seller_order_provider.dart';
import '../products/widgets/product_variants_section.dart';

/// The real category, if any, whose name exactly matches [typed]
/// (case-insensitive, trimmed) -- CAT-15's own resolution rule, kept as a
/// standalone function so it is unit-testable without a widget tree or
/// Firebase. Returns null for free text that doesn't match a real category,
/// which callers should then fall back to storing as-is: a seller is never
/// blocked from creating a product because the category they need doesn't
/// exist yet in the admin-managed tree.
CategoryModel? matchCategoryByName(String typed, List<CategoryModel> categories) {
  final needle = typed.trim().toLowerCase();
  if (needle.isEmpty) return null;
  for (final c in categories) {
    if (c.name.trim().toLowerCase() == needle) return c;
  }
  return null;
}

/// Up to 6 real categories whose name contains [typed] (case-insensitive) --
/// the seller's own suggestion list as they type. A standalone function for
/// the same testability reason as [matchCategoryByName].
List<CategoryModel> categorySuggestionsFor(String typed, List<CategoryModel> categories) {
  final needle = typed.trim().toLowerCase();
  if (needle.isEmpty) return const [];
  return categories.where((c) => c.name.toLowerCase().contains(needle)).take(6).toList();
}

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
  final _b2bPriceController = TextEditingController();
  final _b2bMoqController = TextEditingController();
  // SELLER-CATALOGUE-1: tax data for GST invoices.
  final _hsnController = TextEditingController();
  double? _gstRate;
  List<ProductVariant> _variants = [];

  final ImagePicker _imagePicker = ImagePicker();
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  List<String> _masterImages = [];
  List<Map<String, dynamic>> _masterSuggestions = [];
  List<Map<String, dynamic>> _centers = [];
  Map<String, dynamic>? _selectedMasterProduct;
  Map<String, dynamic>? _selectedCenter;
  List<CategoryModel> _allCategories = [];
  List<CategoryModel> _categorySuggestions = [];
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
  bool _isB2BEnabled = false;

  // Redesign (board 18-04, decision D6): one form + sub-screens.
  final _scopeKey = GlobalKey<SellerFormScopeState>();
  final ValueNotifier<int> _rev = ValueNotifier(0);
  bool _dirty = false;
  bool _saveFailed = false;

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
      _isB2BEnabled = p.isB2BEnabled;
      _b2bPriceController.text = p.b2bPrice?.toStringAsFixed(0) ?? '';
      _b2bMoqController.text = p.b2bMoq?.toString() ?? '';
      _hsnController.text = p.hsnCode ?? '';
      _gstRate = p.gstRate;
      _variants = List.of(p.variants);
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
    for (final c in [
      _nameController, _descriptionController, _priceController, _originalPriceController, _stockController,
      _categoryController, _lowStockThresholdController, _districtController, _latController, _lngController,
      _b2bPriceController, _b2bMoqController, _hsnController,
    ]) {
      c.addListener(_markDirty);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCenters());
    _loadCategories();
  }

  /// Loads the real category list once for the suggestion panel, and -- when
  /// editing an existing product -- resolves its stored `categoryId` to a
  /// human-readable name if it happens to be a real category's own id (an
  /// admin-linked product), so the field never shows a raw internal id
  /// string. A seller-typed name that doesn't match anything keeps showing
  /// exactly as stored, unchanged. Best-effort: if this fails, the field
  /// still works exactly as a plain free-text field, same as before CAT-15.
  Future<void> _loadCategories() async {
    try {
      final categories = await DatabaseService().getAllCategories();
      if (!mounted) return;
      setState(() {
        _allCategories = categories;
        if (isEditing) {
          final rawId = widget.existingProduct!.categoryId;
          for (final c in categories) {
            if (c.id == rawId) {
              _categoryController.text = c.name;
              break;
            }
          }
        }
      });
    } catch (_) {
      // Suggestions are a UI aid only.
    }
  }

  void _markDirty() {
    if (!_dirty && mounted) setState(() => _dirty = true);
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _rev.value++;
  }

  @override
  void dispose() {
    _rev.dispose();
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
    _b2bPriceController.dispose();
    _b2bMoqController.dispose();
    _hsnController.dispose();
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
    } catch (e) {
      debugPrint('Centres unavailable: $e');
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
    final rawCategory =
        (product['categoryId'] ?? product['category'] ?? 'general').toString();
    // The master product's own categoryId may be a real category id (show
    // its name, same reasoning as _loadCategories' own edit-time
    // resolution) or a plain name/legacy value (show it as-is, unchanged).
    var resolvedCategoryName = rawCategory;
    for (final c in _allCategories) {
      if (c.id == rawCategory) {
        resolvedCategoryName = c.name;
        break;
      }
    }
    setState(() {
      _selectedMasterProduct = product;
      _masterSuggestions = [];
      _nameController.text = (product['name'] ?? '').toString();
      _descriptionController.text = (product['description'] ?? '').toString();
      _categoryController.text = resolvedCategoryName;
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

  void _onCategoryTextChanged(String value) {
    setState(() => _categorySuggestions = categorySuggestionsFor(value, _allCategories));
  }

  void _selectCategorySuggestion(CategoryModel category) {
    setState(() {
      _categoryController.text = category.name;
      _categorySuggestions = [];
    });
  }

  /// What to save as `categoryId`: a real category's own id when the typed
  /// text exactly matches one, otherwise the raw typed text (today's
  /// existing behaviour, unchanged) so a seller is never blocked from saving
  /// by the category system's own incompleteness.
  String _resolveCategoryId() {
    final typed = _categoryController.text.trim();
    if (typed.isEmpty) return 'general';
    return matchCategoryByName(typed, _allCategories)?.id ?? typed;
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
      _toastError(AppLocalizations.of(context).editorNeedDistrict);
      return false;
    }
    if (_locationType == 'radius') {
      final lat = double.tryParse(_latController.text.trim());
      final lng = double.tryParse(_lngController.text.trim());
      if (lat == null || lng == null) {
        _toastError(AppLocalizations.of(context).editorNeedCoordinates);
        return false;
      }
    }
    return true;
  }

  bool _validateB2B() {
    if (!_isB2BEnabled) return true;

    final b2bPrice = double.tryParse(_b2bPriceController.text.trim());
    if (b2bPrice == null || b2bPrice <= 0) {
      _toastError(AppLocalizations.of(context).editorNeedB2bPrice);
      return false;
    }

    final salePrice = double.tryParse(_priceController.text.trim());
    if (salePrice != null && b2bPrice >= salePrice) {
      _toastError(AppLocalizations.of(context).editorB2bTooHigh(SellerFormat.moneyWhole(b2bPrice), SellerFormat.moneyWhole(salePrice)));
      return false;
    }

    final b2bMoq = int.tryParse(_b2bMoqController.text.trim());
    if (b2bMoq == null || b2bMoq <= 0) {
      _toastError(AppLocalizations.of(context).editorNeedMoq);
      return false;
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
          _toastError(AppLocalizations.of(context).editorLocationOff);
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
          _toastError(AppLocalizations.of(context).editorLocationDenied);
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
        _toastError(AppLocalizations.of(context).editorLocationFailed);
      }
    } finally {
      if (mounted) setState(() => _isDetectingCoverageLocation = false);
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
        _toastError(AppLocalizations.of(context).editorPhotoFailed);
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

  /// [asDraft]: save without publishing (isActive false, isDraft true). A
  /// draft only needs a name; publishing runs every validation.
  Future<void> _saveProduct({bool asDraft = false}) async {
    if (asDraft) {
      if (_nameController.text.trim().isEmpty) {
        _toastError(AppLocalizations.of(context).draftNeedsName);
        return;
      }
    } else {
      if (!_formKey.currentState!.validate()) {
        setState(() {});
        WidgetsBinding.instance.addPostFrameCallback((_) => _scopeKey.currentState?.focusFirstInvalid());
        return;
      }
      if (!_validateCoverage()) return;
      if (!_validateB2B()) return;
    }
    final hsn = _hsnController.text.trim();

    final auth = context.read<SellerAuthProvider>();
    if (auth.currentUser == null) return;
    final sellerId = auth.currentUser!.uid;
    final productProvider = context.read<SellerProductProvider>();

    setState(() {
      _isSaving = true;
      _saveFailed = false;
    });

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
        _toastError(AppLocalizations.of(context).editorUploadFailed);
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
        categoryId: _resolveCategoryId(),
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
        isB2BEnabled: _isB2BEnabled,
        b2bPrice: _isB2BEnabled
            ? double.tryParse(_b2bPriceController.text.trim())
            : null,
        b2bMoq: _isB2BEnabled
            ? int.tryParse(_b2bMoqController.text.trim())
            : null,
        hsnCode: hsn,
        gstRate: _gstRate,
        variants: _variants,
        isDraft: asDraft,
        isActive: asDraft ? false : null,
        updatedAt: DateTime.now(),
      );

      final success = await productProvider.updateProduct(updated);

      if (!mounted) return;
      setState(() => _isSaving = false);

      if (success) {
        _dirty = false;
        SellerToast.show(context, asDraft ? AppLocalizations.of(context).draftSaved : AppLocalizations.of(context).editorUpdated,
            tone: SellerToastTone.success);
        Navigator.pop(context);
      } else {
        // SELLER-UI-1c: a failed save used to end silently.
        setState(() => _saveFailed = true);
        _toastError(AppLocalizations.of(context).editorSaveFailed);
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
        categoryId: _resolveCategoryId(),
        sellerId: sellerId,
        location: _coverageLabel(),
        locationType: _locationType,
        state: _selectedState,
        district: coverageDistrict,
        lat: coverageLat,
        lng: coverageLng,
        radiusKm: coverageRadius,
        isVerified: false,
        isActive: !asDraft,
        isDraft: asDraft,
        hsnCode: hsn.isEmpty ? null : hsn,
        gstRate: _gstRate,
        variants: _variants,
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
        isB2BEnabled: _isB2BEnabled,
        b2bPrice: _isB2BEnabled
            ? double.tryParse(_b2bPriceController.text.trim())
            : null,
        b2bMoq: _isB2BEnabled
            ? int.tryParse(_b2bMoqController.text.trim())
            : null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final success = await productProvider.addProduct(product);

      if (!mounted) return;
      setState(() => _isSaving = false);

      if (success) {
        _dirty = false;
        SellerToast.show(context, asDraft ? AppLocalizations.of(context).draftSaved : AppLocalizations.of(context).editorAdded,
            tone: SellerToastTone.success);
        Navigator.pop(context);
      } else {
        setState(() => _saveFailed = true);
        _toastError(AppLocalizations.of(context).editorSaveFailed);
      }
    }
  }

  void _toastError(String message) => SellerToast.show(context, message, tone: SellerToastTone.danger);

  /// A user edit outside the text fields.
  void _edit(VoidCallback fn) => setState(() {
        fn();
        _dirty = true;
      });

  // ─────────────────────── sub-screens (decision D6) ───────────────────────

  Map<String, Object?> _snapshot() => {
        'price': _priceController.text,
        'mrp': _originalPriceController.text,
        'district': _districtController.text,
        'lat': _latController.text,
        'lng': _lngController.text,
        'b2bPrice': _b2bPriceController.text,
        'b2bMoq': _b2bMoqController.text,
        'hsn': _hsnController.text,
        'gst': _gstRate,
        'variants': List.of(_variants),
        'locationType': _locationType,
        'state': _selectedState,
        'radius': _radiusKm,
        'b2b': _isB2BEnabled,
        'center': _selectedCenter,
        'source': _priceSource,
        'manual': _manualPriceEdited,
        'area': _areaPrice,
        'dirty': _dirty,
      };

  void _restore(Map<String, Object?> s) {
    _isApplyingProgrammaticPrice = true;
    _priceController.text = s['price']! as String;
    _isApplyingProgrammaticPrice = false;
    _originalPriceController.text = s['mrp']! as String;
    _districtController.text = s['district']! as String;
    _latController.text = s['lat']! as String;
    _lngController.text = s['lng']! as String;
    _b2bPriceController.text = s['b2bPrice']! as String;
    _b2bMoqController.text = s['b2bMoq']! as String;
    _hsnController.text = s['hsn']! as String;
    setState(() {
      _gstRate = s['gst'] as double?;
      _variants = s['variants']! as List<ProductVariant>;
      _locationType = s['locationType']! as String;
      _selectedState = s['state']! as String;
      _radiusKm = s['radius']! as double;
      _isB2BEnabled = s['b2b']! as bool;
      _selectedCenter = s['center'] as Map<String, dynamic>?;
      _priceSource = s['source']! as String;
      _manualPriceEdited = s['manual']! as bool;
      _areaPrice = s['area'] as double?;
      _dirty = s['dirty']! as bool;
    });
  }

  /// Opens a sub-screen that edits this form's state live. "Apply changes"
  /// keeps the edits (after [validate]); leaving any other way restores
  /// what was there before.
  Future<void> _openSubscreen(String title, WidgetBuilder body, {bool Function()? validate}) async {
    final before = _snapshot();
    final applied = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (routeContext) => _EditorSubscreen(
        title: title,
        summary: _summaryHeader(),
        rev: _rev,
        body: body,
        onApply: () {
          if (validate != null && !validate()) return;
          Navigator.of(routeContext).pop(true);
        },
      ),
    ));
    if (applied != true && mounted) _restore(before);
  }

  Widget _summaryHeader() => Builder(builder: (context) {
        final l10n = AppLocalizations.of(context);
        final text = context.text;
        final existing = isEditing ? widget.existingProduct!.primaryImage : (_masterImages.isEmpty ? '' : _masterImages.first);
        final name = _nameController.text.trim();
        return SellerCard(
          child: Row(children: [
            SellerImage(url: existing, bytes: _selectedImageBytes, size: SellerSize.thumbMd),
            const SizedBox(width: SellerSpace.s12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name.isEmpty ? l10n.editorNewTitle : name, style: text.titleSmall),
                if (_priceController.text.trim().isNotEmpty)
                  Text(SellerFormat.money(double.tryParse(_priceController.text.trim()) ?? 0), style: text.bodyMedium!.tabular),
                if (_categoryController.text.trim().isNotEmpty) Text(_categoryController.text.trim(), style: text.bodyMedium),
              ]),
            ),
          ]),
        );
      });

  // ─────────────────────── form parts ───────────────────────

  /// Last-30-day sales for the product being edited (gap 18).
  Widget _buildStatsCard() {
    final l10n = AppLocalizations.of(context);
    final text = context.text;
    final stats = ProductSalesStats.of(context.watch<SellerOrderProvider>().allOrders, widget.existingProduct!.id, DateTime.now());
    Widget cell(String value, String label) => Expanded(
          child: MergeSemantics(
            child: Column(children: [
              Text(value, style: text.titleMedium!.tabular),
              Text(label, style: text.bodySmall, textAlign: TextAlign.center),
            ]),
          ),
        );
    return SellerCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l10n.productStatsTitle, style: text.titleSmall),
        const SizedBox(height: SellerSpace.s12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          cell(SellerFormat.count(stats.units), l10n.productStatsUnits),
          cell(SellerFormat.moneyWhole(stats.revenue), l10n.kpiSales),
          cell(SellerFormat.count(stats.orders), l10n.kpiOrders),
        ]),
        const SizedBox(height: SellerSpace.s8),
        Text(
          stats.lastSold == null ? l10n.productStatsNeverSold : l10n.productStatsLastSold(SellerFormat.date(stats.lastSold!)),
          style: text.bodySmall,
        ),
      ]),
    );
  }

  /// Photo row (board 18-04): the product photo with a camera badge, then
  /// "Add photo" — or, once there is one, [Replace photo] + stock details.
  Widget _buildImagePicker() {
    final l10n = AppLocalizations.of(context);
    final text = context.text;
    final existingImage = isEditing ? widget.existingProduct!.primaryImage : (_masterImages.isEmpty ? '' : _masterImages.first);
    final hasImage = _selectedImageBytes != null || existingImage.isNotEmpty;
    final photo = SellerPhotoTile(
      label: hasImage ? l10n.editorChangePhoto : l10n.editorAddPhoto,
      state: hasImage ? SellerUploadState.uploaded : SellerUploadState.empty,
      imageUrl: existingImage,
      bytes: _selectedImageBytes,
      size: SellerSize.thumbXl + SellerSpace.s32,
      onTap: _isSaving ? null : _pick,
    );
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      photo,
      const SizedBox(width: SellerSpace.s16),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (hasImage)
            SellerButton.secondary(label: l10n.editorReplacePhoto, icon: SellerIcons.camera, compact: true, onPressed: _isSaving ? null : _pick)
          else
            Text(l10n.editorAddPhoto, style: text.titleSmall),
          if (isEditing) ...[
            const SizedBox(height: SellerSpace.s8),
            productStockBadge(l10n, widget.existingProduct!),
            const SizedBox(height: SellerSpace.s4),
            Text(l10n.editorLowStockAlert(_lowStockThresholdController.text.trim()), style: text.bodyMedium),
          ],
        ]),
      ),
    ]);
  }

  Future<void> _pick() async {
    final before = _selectedImageBytes;
    await _pickProductImage();
    if (_selectedImageBytes != before) _edit(() {});
  }

  Widget _suggestions(List<Widget> rows) => Padding(
        padding: const EdgeInsets.only(top: SellerSpace.s8),
        child: SellerMenuGroup(children: rows),
      );

  Widget _buildMasterSuggestions() {
    if (_isSearchingMasterProducts) {
      return Padding(padding: const EdgeInsets.only(top: SellerSpace.s8), child: SellerProgressLabel(label: AppLocalizations.of(context).dsLoading, center: false));
    }
    if (_masterSuggestions.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return _suggestions([
      for (final product in _masterSuggestions)
        SellerListRow(
          icon: SellerIcons.product,
          title: (product['name'] ?? '').toString(),
          subtitle: [
            if (product['category'] != null) product['category'].toString(),
            if (product['unit'] != null) product['unit'].toString(),
            if ((product['basePrice'] ?? product['salePrice'] ?? product['price']) is num)
              SellerFormat.money((product['basePrice'] ?? product['salePrice'] ?? product['price']) as num),
          ].join(l10n.editorSeparator),
          showChevron: false,
          onTap: () {
            _selectMasterProduct(product);
            _dirty = true;
          },
        ),
    ]);
  }

  Widget _buildCategorySuggestions() {
    if (_categorySuggestions.isEmpty) return const SizedBox.shrink();
    return _suggestions([
      for (final category in _categorySuggestions)
        SellerListRow(icon: SellerIcons.tag, title: category.name, showChevron: false, onTap: () => _selectCategorySuggestion(category)),
    ]);
  }

  // Pricing & tax (board 18-06). Centre pricing shows only real data: the
  // centre list and mapped prices come from the server.
  Widget _pricingBody(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final text = context.text;
    final selectedCenterId = _selectedCenter?['id']?.toString();
    final priceLabel = switch (_priceSource) {
      'manual' => l10n.editorPriceManual,
      'area' => l10n.editorPriceArea,
      _ => l10n.editorPriceDefault,
    };
    String money(double? v) => v == null ? l10n.editorNoValue : SellerFormat.moneyWhole(v);
    Widget tile(String label, String value, bool current) => Expanded(
          child: SellerCard(
            tone: current ? SellerCardTone.mint : SellerCardTone.surface,
            padding: const EdgeInsets.all(SellerSpace.s12),
            child: MergeSemantics(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: text.bodyMedium!.copyWith(color: current ? c.textPrimary : null)),
                Text(value, style: text.titleMedium!.tabular),
              ]),
            ),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _priceFields(context),
      const SizedBox(height: SellerSpace.section),
      SellerSectionHeader(title: l10n.editorCenterPricing),
      SellerSelectField<String>(
        label: _isLoadingCenters ? l10n.editorLoadingCenters : l10n.editorCenter,
        prefixIcon: SellerIcons.location,
        value: _centers.any((c) => c['id'].toString() == selectedCenterId) ? selectedCenterId : null,
        options: [for (final center in _centers) SellerOption(center['id'].toString(), center['name'].toString())],
        onChanged: (id) {
          final center = _centers.cast<Map<String, dynamic>?>().firstWhere((item) => item?['id']?.toString() == id, orElse: () => null);
          _dirty = true;
          _selectCenter(center);
        },
      ),
      const SizedBox(height: SellerSpace.s12),
      Row(children: [
        tile(l10n.editorPriceDefault, money(_basePrice), _priceSource == 'default'),
        const SizedBox(width: SellerSpace.s8),
        tile(l10n.editorPriceArea, money(_areaPrice), _priceSource == 'area'),
        const SizedBox(width: SellerSpace.s8),
        tile(l10n.editorPriceCurrent, money(double.tryParse(_priceController.text.trim())), _priceSource == 'manual'),
      ]),
      const SizedBox(height: SellerSpace.s12),
      Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: SellerSpace.s8, runSpacing: SellerSpace.s8, children: [
        Text(l10n.editorPriceSourceLabel, style: text.bodyMedium),
        SellerStatusBadge(label: priceLabel, tone: SellerTone.brand),
        SellerButton.tertiary(
          label: l10n.editorResetPrice,
          icon: SellerIcons.replace,
          onPressed: (_basePrice == null && _areaPrice == null) ? null : () => _edit(_resetToMappedPrice),
        ),
      ]),
      const SizedBox(height: SellerSpace.section),
      ProductTaxSection(hsnController: _hsnController, gstRate: _gstRate, onGstRateChanged: (v) => _edit(() => _gstRate = v)),
    ]);
  }

  Widget _priceFields(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String? required(String v) => v.trim().isEmpty ? l10n.editorRequired : null;
    final price = SellerTextField(
      label: l10n.editorSalePrice,
      required: true,
      controller: _priceController,
      prefixText: SellerFormat.rupeeSymbol,
      tabular: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: required,
    );
    final mrp = SellerTextField(
      label: l10n.editorMrp,
      controller: _originalPriceController,
      prefixText: SellerFormat.rupeeSymbol,
      tabular: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    );
    return _pair(price, mrp);
  }

  Widget _pair(Widget a, Widget b) => context.largeText
      ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [a, const SizedBox(height: SellerSpace.s16), b])
      : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: a),
          const SizedBox(width: SellerSpace.s12),
          Expanded(child: b),
        ]);

  // Coverage (board 18-07).
  Widget _coverageBody(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = context.text;
    final districtValue = _tamilNaduDistricts.contains(_districtController.text.trim()) ? _districtController.text.trim() : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(l10n.editorCoverageLead, style: text.bodyLarge),
      const SizedBox(height: SellerSpace.s16),
      SellerSegmented<String>(
        semanticLabel: l10n.editorCoverage,
        segments: [
          SellerSegment('state', l10n.editorCoverageState),
          SellerSegment('district', l10n.editorCoverageDistrict),
          SellerSegment('radius', l10n.editorCoverageRadius),
        ],
        selected: _locationType,
        onChanged: (v) => _edit(() => _locationType = v),
      ),
      const SizedBox(height: SellerSpace.s16),
      SellerSelectField<String>(
        label: l10n.accountState,
        prefixIcon: SellerIcons.location,
        value: _selectedState,
        options: [for (final s in _states) SellerOption(s, s)],
        onChanged: (v) {
          if (v != null) _edit(() => _selectedState = v);
        },
      ),
      if (_locationType == 'district') ...[
        const SizedBox(height: SellerSpace.s16),
        SellerSelectField<String>(
          label: l10n.editorCoverageDistrict,
          required: true,
          prefixIcon: SellerIcons.location,
          value: districtValue,
          options: [for (final d in _tamilNaduDistricts) SellerOption(d, d)],
          onChanged: (v) {
            if (v != null) _edit(() => _districtController.text = v);
          },
        ),
      ],
      if (_locationType == 'radius') ...[
        const SizedBox(height: SellerSpace.s16),
        _pair(
          SellerTextField(
            label: l10n.editorLatitude,
            controller: _latController,
            tabular: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          ),
          SellerTextField(
            label: l10n.editorLongitude,
            controller: _lngController,
            tabular: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          ),
        ),
        const SizedBox(height: SellerSpace.s12),
        SellerButton.secondary(
          label: l10n.editorUseLocation,
          icon: SellerIcons.locate,
          loading: _isDetectingCoverageLocation,
          loadingLabel: l10n.editorDetecting,
          expand: true,
          onPressed: _useCurrentCoverageLocation,
        ),
        const SizedBox(height: SellerSpace.s12),
        SellerSliderField(
          label: l10n.editorCoverageRadius,
          value: _radiusKm.clamp(1, 50),
          min: 1,
          max: 50,
          divisions: 49,
          valueLabel: l10n.editorRadiusValue(_radiusKm.round()),
          onChanged: (v) => _edit(() => _radiusKm = v),
        ),
      ],
      const SizedBox(height: SellerSpace.s16),
      SellerCard(
        tone: SellerCardTone.mint,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SellerIconTile(icon: SellerIcons.location),
          const SizedBox(width: SellerSpace.s12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l10n.editorCoverageSummary, style: text.bodyMedium!.copyWith(color: context.colors.textPrimary)),
              Text(_coverageLabel(), style: text.titleSmall),
            ]),
          ),
        ]),
      ),
    ]);
  }

  // Wholesale (board 18-08).
  Widget _wholesaleBody(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = context.text;
    final price = double.tryParse(_b2bPriceController.text.trim());
    final moq = int.tryParse(_b2bMoqController.text.trim());
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SellerSwitchRow(
        title: l10n.editorB2b,
        subtitle: l10n.editorB2bHint,
        icon: SellerIcons.wholesale,
        bordered: true,
        value: _isB2BEnabled,
        onChanged: (v) => _edit(() => _isB2BEnabled = v),
      ),
      const SizedBox(height: SellerSpace.s16),
      if (!_isB2BEnabled)
        SellerEmptyState(icon: SellerIcons.store, title: l10n.editorWholesaleOffTitle, message: l10n.editorWholesaleOffBody, compact: true)
      else ...[
        SellerTextField(
          label: l10n.editorB2bPrice,
          required: true,
          controller: _b2bPriceController,
          prefixText: SellerFormat.rupeeSymbol,
          tabular: true,
          helper: l10n.editorB2bRuleShort,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: SellerSpace.s16),
        SellerTextField(
          label: l10n.editorB2bMoq,
          required: true,
          controller: _b2bMoqController,
          tabular: true,
          helper: l10n.editorMoqHelper,
          keyboardType: TextInputType.number,
        ),
        if (price != null && price > 0 && moq != null && moq > 0) ...[
          const SizedBox(height: SellerSpace.s16),
          SellerCard(
            tone: SellerCardTone.mint,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                const Icon(SellerIcons.tag, size: SellerIconSize.md),
                const SizedBox(width: SellerSpace.s8),
                Text(l10n.editorWholesaleSummary, style: text.titleSmall),
              ]),
              SellerKeyValueRow(label: l10n.editorB2bPrice, value: SellerFormat.money(price), tabular: true),
              SellerKeyValueRow(label: l10n.editorB2bMoq, value: l10n.editorWholesaleMinUnits(moq), tabular: true),
            ]),
          ),
        ],
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String? required(String v) => v.trim().isEmpty ? l10n.editorRequired : null;
    const gap = SizedBox(height: SellerSpace.s16);
    final invalid = _scopeKey.currentState?.invalidLabels ?? const <String>[];
    final b2bPrice = double.tryParse(_b2bPriceController.text.trim());
    final b2bMoq = int.tryParse(_b2bMoqController.text.trim());

    final stock = SellerTextField(
      label: l10n.editorStock,
      required: true,
      controller: _stockController,
      tabular: true,
      keyboardType: TextInputType.number,
      validator: required,
    );
    final lowStock = SellerTextField(
      label: l10n.editorLowStock,
      controller: _lowStockThresholdController,
      tabular: true,
      helper: l10n.editorLowStockHelp,
      keyboardType: TextInputType.number,
    );

    return SellerDiscardGuard(
      hasChanges: _dirty && !_isSaving,
      child: Scaffold(
        appBar: SellerAppBar.detail(context, title: isEditing ? l10n.editorEditTitle : l10n.editorNewTitle),
        body: SellerFormScope(
          key: _scopeKey,
          child: Form(
            key: _formKey,
            child: SellerPage(
              footer: SellerButtonBar(children: [
                SellerButton.secondary(
                  label: l10n.saveDraftCta,
                  icon: SellerIcons.document,
                  onPressed: _isSaving ? null : () => _saveProduct(asDraft: true),
                ),
                SellerButton(
                  label: isEditing ? l10n.editorUpdate : l10n.editorSave,
                  icon: SellerIcons.check,
                  loading: _isSaving,
                  loadingLabel: l10n.editorSaving,
                  onPressed: () => _saveProduct(),
                ),
              ]),
              children: [
                if (invalid.isNotEmpty) ...[
                  SellerFormErrorSummary(labels: invalid, onSelect: (label) => _scopeKey.currentState?.focusLabel(label)),
                  gap,
                ],
                if (_saveFailed) ...[
                  SellerBanner(tone: SellerTone.danger, title: l10n.editorSaveFailed, message: l10n.editorSaveFailedBody),
                  gap,
                ],
                if (isEditing) ...[_buildStatsCard(), gap],
                _buildImagePicker(),
                const SizedBox(height: SellerSpace.s24),
                SellerTextField(
                  label: l10n.editorName,
                  required: true,
                  controller: _nameController,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: _searchMasterProducts,
                  validator: required,
                ),
                _buildMasterSuggestions(),
                gap,
                SellerTextField(
                  label: l10n.editorDescription,
                  hint: l10n.editorDescriptionHint,
                  required: true,
                  controller: _descriptionController,
                  maxLines: 5,
                  minLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  validator: required,
                ),
                gap,
                SellerTextField(
                  label: l10n.editorCategory,
                  hint: l10n.editorCategoryHint,
                  controller: _categoryController,
                  prefixIcon: SellerIcons.sprout,
                  onChanged: _onCategoryTextChanged,
                ),
                _buildCategorySuggestions(),
                gap,
                _priceFields(context),
                gap,
                _pair(stock, lowStock),
                const SizedBox(height: SellerSpace.s24),
                SellerMenuGroup(children: [
                  SellerListRow(
                    icon: SellerIcons.packing,
                    plainIcon: true,
                    title: l10n.editorPackOptions,
                    subtitle: _variants.isEmpty ? l10n.editorPackOptionsHint : l10n.editorOptionsCount(_variants.length),
                    onTap: () => _openSubscreen(
                      l10n.editorPackOptions,
                      (_) => ProductVariantsSection(variants: _variants, onChanged: (v) => _edit(() => _variants = v)),
                    ),
                  ),
                  SellerListRow(
                    icon: SellerIcons.tag,
                    plainIcon: true,
                    title: l10n.editorPricingTax,
                    subtitle: l10n.editorPricingTaxHint,
                    onTap: () => _openSubscreen(l10n.editorPricingTax, _pricingBody),
                  ),
                  SellerListRow(
                    icon: SellerIcons.coverage,
                    plainIcon: true,
                    title: l10n.editorCoverage,
                    subtitle: _coverageLabel(),
                    onTap: () => _openSubscreen(l10n.editorCoverage, _coverageBody, validate: _validateCoverage),
                  ),
                  SellerListRow(
                    icon: SellerIcons.wholesale,
                    plainIcon: true,
                    title: l10n.editorWholesale,
                    subtitle: _isB2BEnabled && b2bPrice != null && b2bMoq != null
                        ? l10n.editorWholesaleLine(SellerFormat.money(b2bPrice), b2bMoq)
                        : l10n.editorWholesaleRowHint,
                    onTap: () => _openSubscreen(l10n.editorWholesale, _wholesaleBody, validate: _validateB2B),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sub-screen chrome (boards 18-05…18-08): back arrow + title, the product
/// summary, the section, and a sticky [Apply changes]. Rebuilds whenever
/// the editor's state changes ([rev]).
class _EditorSubscreen extends StatelessWidget {
  const _EditorSubscreen({required this.title, required this.summary, required this.rev, required this.body, required this.onApply});

  final String title;
  final Widget summary;
  final ValueNotifier<int> rev;
  final WidgetBuilder body;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: SellerAppBar.detail(context, title: title),
      body: ValueListenableBuilder<int>(
        valueListenable: rev,
        builder: (context, _, __) => SellerPage(
          gap: SellerSpace.s16,
          footer: SellerButton(label: l10n.editorApply, icon: SellerIcons.check, expand: true, onPressed: onApply),
          children: [summary, body(context)],
        ),
      ),
    );
  }
}
