import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_services/agrimore_services.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/seller_auth_provider.dart';
import '../../providers/seller_product_provider.dart';
import '../../l10n/app_localizations.dart';
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
      _toastError(AppLocalizations.of(context).editorB2bTooHigh(AgFormat.rupeesWhole(b2bPrice), AgFormat.rupeesWhole(salePrice)));
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
      if (!_formKey.currentState!.validate()) return;
      if (!_validateCoverage()) return;
      if (!_validateB2B()) return;
    }
    final hsn = _hsnController.text.trim();

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
        WsToast.show(context, asDraft ? AppLocalizations.of(context).draftSaved : AppLocalizations.of(context).editorUpdated,
            tone: WsToastTone.success);
        Navigator.pop(context);
      } else {
        // SELLER-UI-1c: a failed save used to end silently.
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
        WsToast.show(context, asDraft ? AppLocalizations.of(context).draftSaved : AppLocalizations.of(context).editorAdded,
            tone: WsToastTone.success);
        Navigator.pop(context);
      } else {
        _toastError(AppLocalizations.of(context).editorSaveFailed);
      }
    }
  }

  void _toastError(String message) => WsToast.show(context, message, tone: WsToastTone.error);

  /// A titled, bordered section (ADR §7 card) with an icon and a hint.
  Widget _section({required IconData icon, required String title, String? hint, Widget? trailing, required List<Widget> children}) {
    final t = context.ws;
    final text = context.wsText;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(WsSpace.s16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(WsSpace.s8),
              decoration: BoxDecoration(color: t.primarySubtle, borderRadius: BorderRadius.circular(WsRadius.small)),
              child: Icon(icon, color: t.primary, size: WsIconSize.control),
            ),
            const SizedBox(width: WsSpace.s12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: text.titleSmall),
                if (hint != null) Text(hint, style: text.bodySmall!.copyWith(color: t.textSecondary)),
              ]),
            ),
            if (trailing != null) trailing,
          ]),
          if (children.isNotEmpty) const SizedBox(height: WsSpace.s16),
          ...children,
        ]),
      ),
    );
  }

  /// Last-30-day sales for the product being edited (gap 18).
  Widget _buildStatsCard() {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    final text = context.wsText;
    final stats = ProductSalesStats.of(context.watch<SellerOrderProvider>().allOrders, widget.existingProduct!.id, DateTime.now());
    Widget cell(String value, String label) => Expanded(
          child: Column(children: [
            Text(value, style: text.titleMedium!.copyWith(fontFeatures: WsType.tabularFigures)),
            Text(label, style: text.bodySmall!.copyWith(color: t.textSecondary)),
          ]),
        );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(WsSpace.s16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.productStatsTitle, style: text.titleSmall),
          const SizedBox(height: WsSpace.s12),
          Row(children: [
            cell(AgFormat.count(stats.units), l10n.productStatsUnits),
            cell(AgFormat.rupeesWhole(stats.revenue), l10n.kpiSales),
            cell(AgFormat.count(stats.orders), l10n.kpiOrders),
          ]),
          const SizedBox(height: WsSpace.s8),
          Text(
            stats.lastSold == null ? l10n.productStatsNeverSold : l10n.productStatsLastSold(AgFormat.date(stats.lastSold!)),
            style: text.bodySmall!.copyWith(color: t.textSecondary),
          ),
        ]),
      ),
    );
  }

  Widget _buildImagePicker() {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    final text = context.wsText;
    final existingImage = isEditing ? widget.existingProduct!.primaryImage : '';
    final hasSelectedImage = _selectedImageBytes != null;
    final hasExistingImage = existingImage.isNotEmpty;
    return Semantics(
      button: true,
      label: hasSelectedImage || hasExistingImage ? l10n.editorChangePhoto : l10n.editorAddPhoto,
      child: InkWell(
        onTap: _isSaving ? null : _pickProductImage,
        borderRadius: BorderRadius.circular(WsRadius.card),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(WsRadius.card),
            child: Stack(fit: StackFit.expand, children: [
              if (hasSelectedImage)
                Image.memory(_selectedImageBytes!, fit: BoxFit.cover)
              else if (hasExistingImage)
                Image.network(existingImage, fit: BoxFit.cover, errorBuilder: (_, __, ___) => ColoredBox(color: t.surfaceSunken))
              else
                ColoredBox(
                  color: t.surfaceSunken,
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(AgIcons.camera, size: WsIconSize.feature, color: t.textTertiary),
                    const SizedBox(height: WsSpace.s8),
                    Text(l10n.editorAddPhoto, style: text.bodyMedium!.copyWith(color: t.textSecondary)),
                  ]),
                ),
              if (hasSelectedImage || hasExistingImage)
                Positioned(
                  right: WsSpace.s12,
                  bottom: WsSpace.s12,
                  child: ExcludeSemantics(
                    child: Chip(
                      avatar: Icon(AgIcons.image, size: WsIconSize.supporting, color: t.primary),
                      label: Text(l10n.editorChangePhoto),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _suggestionList(List<Widget> tiles) => Card(
        margin: const EdgeInsets.only(top: WsSpace.s8),
        clipBehavior: Clip.antiAlias,
        child: Column(children: tiles),
      );

  Widget _buildMasterSuggestions() {
    if (_isSearchingMasterProducts) {
      return const Padding(padding: EdgeInsets.only(top: WsSpace.s8), child: LinearProgressIndicator());
    }
    if (_masterSuggestions.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return _suggestionList([
      for (final product in _masterSuggestions)
        ListTile(
          leading: const Icon(AgIcons.product),
          title: Text((product['name'] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            [
              if (product['category'] != null) product['category'].toString(),
              if (product['unit'] != null) product['unit'].toString(),
              if ((product['basePrice'] ?? product['salePrice'] ?? product['price']) is num)
                AgFormat.rupees((product['basePrice'] ?? product['salePrice'] ?? product['price']) as num),
            ].join(l10n.editorSeparator),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => _selectMasterProduct(product),
        ),
    ]);
  }

  Widget _buildCategorySuggestions() {
    if (_categorySuggestions.isEmpty) return const SizedBox.shrink();
    return _suggestionList([
      for (final category in _categorySuggestions)
        ListTile(
          leading: const Icon(AgIcons.tag),
          title: Text(category.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => _selectCategorySuggestion(category),
        ),
    ]);
  }

  Widget _buildSelectorPricingSection(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    final selectedCenterId = _selectedCenter?['id']?.toString();
    final priceLabel = switch (_priceSource) {
      'manual' => l10n.editorPriceManual,
      'area' => l10n.editorPriceArea,
      _ => l10n.editorPriceDefault,
    };
    String money(double? v) => v == null ? l10n.editorNoValue : AgFormat.rupeesWhole(v);
    return _section(
      icon: AgIcons.store,
      title: l10n.editorCenterPricing,
      trailing: Chip(label: Text(priceLabel), visualDensity: VisualDensity.compact),
      children: [
        DropdownButtonFormField<String>(
          initialValue: selectedCenterId,
          decoration: InputDecoration(
            labelText: _isLoadingCenters ? l10n.editorLoadingCenters : l10n.editorCenter,
            prefixIcon: const Icon(AgIcons.location),
          ),
          items: [
            for (final center in _centers)
              DropdownMenuItem<String>(value: center['id'].toString(), child: Text(center['name'].toString())),
          ],
          onChanged: (id) {
            final center = _centers.cast<Map<String, dynamic>?>().firstWhere(
                  (item) => item?['id']?.toString() == id,
                  orElse: () => null,
                );
            _selectCenter(center);
          },
        ),
        const SizedBox(height: WsSpace.s12),
        Wrap(spacing: WsSpace.s8, runSpacing: WsSpace.s8, children: [
          Chip(label: Text(l10n.editorPriceChip(l10n.editorPriceDefault, money(_basePrice)))),
          Chip(label: Text(l10n.editorPriceChip(l10n.editorPriceArea, money(_areaPrice)))),
          Chip(label: Text(l10n.editorPriceChip(l10n.editorPriceCurrent, money(double.tryParse(_priceController.text.trim()))))),
        ]),
        const SizedBox(height: WsSpace.s8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: (_basePrice == null && _areaPrice == null) ? null : _resetToMappedPrice,
            icon: const Icon(AgIcons.undo),
            label: Text(l10n.editorResetPrice),
          ),
        ),
      ],
    );
  }

  Widget _buildCoverageSection(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    final text = context.wsText;
    final districtValue =
        _tamilNaduDistricts.contains(_districtController.text.trim()) ? _districtController.text.trim() : null;
    return _section(
      icon: AgIcons.location,
      title: l10n.editorCoverage,
      hint: l10n.editorCoverageHint,
      children: [
        Wrap(spacing: WsSpace.s8, runSpacing: WsSpace.s8, children: [
          for (final (value, label) in [
            ('state', l10n.editorCoverageState),
            ('district', l10n.editorCoverageDistrict),
            ('radius', l10n.editorCoverageRadius),
          ])
            ChoiceChip(label: Text(label), selected: _locationType == value, onSelected: (_) => setState(() => _locationType = value)),
        ]),
        const SizedBox(height: WsSpace.s16),
        DropdownButtonFormField<String>(
          initialValue: _selectedState,
          decoration: InputDecoration(labelText: l10n.accountState, prefixIcon: const Icon(AgIcons.location)),
          items: [for (final s in _states) DropdownMenuItem(value: s, child: Text(s))],
          onChanged: (value) {
            if (value == null) return;
            setState(() => _selectedState = value);
          },
        ),
        if (_locationType == 'district') ...[
          const SizedBox(height: WsSpace.s16),
          DropdownButtonFormField<String>(
            initialValue: districtValue,
            decoration: InputDecoration(labelText: l10n.editorCoverageDistrict, prefixIcon: const Icon(AgIcons.location)),
            items: [for (final d in _tamilNaduDistricts) DropdownMenuItem(value: d, child: Text(d))],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _districtController.text = value);
            },
            validator: (_) =>
                _locationType == 'district' && _districtController.text.trim().isEmpty ? l10n.editorRequired : null,
          ),
        ],
        if (_locationType == 'radius') ...[
          const SizedBox(height: WsSpace.s16),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _latController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: InputDecoration(labelText: l10n.editorLatitude),
              ),
            ),
            const SizedBox(width: WsSpace.s12),
            Expanded(
              child: TextFormField(
                controller: _lngController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: InputDecoration(labelText: l10n.editorLongitude),
              ),
            ),
          ]),
          const SizedBox(height: WsSpace.s12),
          SaLoadingButton(
            text: l10n.editorUseLocation,
            loadingText: l10n.editorDetecting,
            isLoading: _isDetectingCoverageLocation,
            variant: SaButtonVariant.outlined,
            icon: AgIcons.location,
            onPressed: _isDetectingCoverageLocation ? null : _useCurrentCoverageLocation,
          ),
          const SizedBox(height: WsSpace.s12),
          Text(l10n.editorRadiusValue(_radiusKm.round()), style: text.labelLarge),
          Slider(
            min: 1,
            max: 50,
            divisions: 49,
            value: _radiusKm.clamp(1, 50),
            label: l10n.editorRadiusValue(_radiusKm.round()),
            onChanged: (value) => setState(() => _radiusKm = value),
          ),
        ],
      ],
    );
  }

  Widget _buildB2BSection(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    final text = context.wsText;
    return _section(
      icon: AgIcons.store,
      title: l10n.editorB2b,
      hint: l10n.editorB2bHint,
      trailing: Switch(value: _isB2BEnabled, onChanged: (value) => setState(() => _isB2BEnabled = value)),
      children: [
        if (_isB2BEnabled) ...[
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _b2bPriceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: l10n.editorB2bPrice, prefixIcon: const Icon(AgIcons.rupee)),
              ),
            ),
            const SizedBox(width: WsSpace.s12),
            Expanded(
              child: TextFormField(
                controller: _b2bMoqController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.editorB2bMoq),
              ),
            ),
          ]),
          const SizedBox(height: WsSpace.s8),
          Text(l10n.editorB2bRule, style: text.bodySmall!.copyWith(color: t.textSecondary)),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    String? required(String? v) => (v ?? '').trim().isEmpty ? l10n.editorRequired : null;
    const gap = SizedBox(height: WsSpace.s16);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(tooltip: l10n.back, icon: const Icon(AgIcons.arrowLeft), onPressed: () => Navigator.of(context).maybePop()),
        title: Text(isEditing ? l10n.editorEditTitle : l10n.editorNewTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(WsSpace.page),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: WsSize.formMaxWidth),
            child: Form(
              key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (isEditing) ...[
                  _buildStatsCard(),
                  const SizedBox(height: WsSpace.s16),
                ],
                _buildImagePicker(),
                const SizedBox(height: WsSpace.s24),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: l10n.editorName, prefixIcon: const Icon(AgIcons.product)),
                  onChanged: _searchMasterProducts,
                  validator: required,
                ),
                _buildMasterSuggestions(),
                gap,
                _buildSelectorPricingSection(theme),
                gap,
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: InputDecoration(labelText: l10n.editorDescription, hintText: l10n.editorDescriptionHint, alignLabelWithHint: true),
                  validator: required,
                ),
                gap,
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: l10n.editorSalePrice, prefixIcon: const Icon(AgIcons.rupee)),
                      validator: required,
                    ),
                  ),
                  const SizedBox(width: WsSpace.s16),
                  Expanded(
                    child: TextFormField(
                      controller: _originalPriceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: l10n.editorMrp, prefixIcon: const Icon(AgIcons.tag)),
                    ),
                  ),
                ]),
                gap,
                _buildB2BSection(theme),
                gap,
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: TextFormField(
                      controller: _stockController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: l10n.editorStock, prefixIcon: const Icon(AgIcons.inventory)),
                      validator: required,
                    ),
                  ),
                  const SizedBox(width: WsSpace.s16),
                  Expanded(
                    child: TextFormField(
                      controller: _lowStockThresholdController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.editorLowStock,
                        prefixIcon: const Icon(AgIcons.bell),
                        helperText: l10n.editorLowStockHelp,
                        helperMaxLines: 2,
                      ),
                    ),
                  ),
                ]),
                gap,
                TextFormField(
                  controller: _categoryController,
                  decoration: InputDecoration(labelText: l10n.editorCategory, hintText: l10n.editorCategoryHint, prefixIcon: const Icon(AgIcons.tag)),
                  onChanged: _onCategoryTextChanged,
                ),
                _buildCategorySuggestions(),
                gap,
                ProductTaxSection(
                  hsnController: _hsnController,
                  gstRate: _gstRate,
                  onGstRateChanged: (v) => setState(() => _gstRate = v),
                ),
                gap,
                ProductVariantsSection(variants: _variants, onChanged: (v) => setState(() => _variants = v)),
                gap,
                _buildCoverageSection(theme),
                const SizedBox(height: WsSpace.s32),
                SaLoadingButton(
                  text: isEditing ? l10n.editorUpdate : l10n.editorSave,
                  loadingText: l10n.editorSaving,
                  isLoading: _isSaving,
                  icon: AgIcons.success,
                  onPressed: _isSaving ? null : () => _saveProduct(),
                ),
                const SizedBox(height: WsSpace.s12),
                SaLoadingButton(
                  text: l10n.saveDraftCta,
                  variant: SaButtonVariant.outlined,
                  icon: AgIcons.document,
                  onPressed: _isSaving ? null : () => _saveProduct(asDraft: true),
                ),
                const SizedBox(height: WsSpace.s24),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
