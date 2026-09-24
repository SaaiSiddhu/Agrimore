import 'dart:typed_data';

import 'package:agrimore_core/agrimore_core.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/seller_auth_provider.dart';
import '../../providers/seller_post_provider.dart';
import '../../providers/seller_product_provider.dart';

/// M-05 Post composer (ADR §10.6, SELLER-UI-1d): text, photo, optional
/// product tag, published to followers.
class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key, this.provider});

  /// Injected in tests; otherwise a Firebase-backed [SellerPostProvider].
  final SellerPostProvider? provider;

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  static const int _maxText = 500;
  static const int _imageQuality = 82;
  static const double _imageMaxWidth = 1600;

  final _textController = TextEditingController();
  final _imagePicker = ImagePicker();
  late final SellerPostProvider _postProvider = widget.provider ?? SellerPostProvider();

  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  ProductModel? _taggedProduct;
  bool _showRequirement = false;

  @override
  void initState() {
    super.initState();
    _postProvider.addListener(_onPostingChanged);
  }

  void _onPostingChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _postProvider.removeListener(_onPostingChanged);
    if (widget.provider == null) _postProvider.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final l10n = AppLocalizations.of(context);
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: _imageQuality, maxWidth: _imageMaxWidth);
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _selectedImage = image;
        _selectedImageBytes = bytes;
      });
    } catch (e) {
      debugPrint('Post image pick failed: $e');
      if (mounted) SellerToast.show(context, l10n.editorPhotoFailed, tone: SellerToastTone.danger);
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final sellerId = context.read<SellerAuthProvider>().currentUser?.uid;
    if (sellerId == null) return;
    if (_textController.text.trim().isEmpty && _selectedImageBytes == null && _taggedProduct == null) {
      setState(() => _showRequirement = true);
      SellerToast.show(context, l10n.postEmpty, tone: SellerToastTone.danger);
      return;
    }
    final ok = await _postProvider.createPost(
      sellerId: sellerId,
      text: _textController.text,
      imageBytes: _selectedImageBytes,
      imageFileName: _selectedImage?.name,
      productId: _taggedProduct?.id,
    );
    if (!mounted) return;
    if (ok) {
      SellerToast.show(context, l10n.postPublished, tone: SellerToastTone.success);
      Navigator.of(context).pop();
    } else {
      SellerToast.show(context, l10n.postFailed, tone: SellerToastTone.danger);
    }
  }

  /// Composer (board 22-09): × and [Post] in the app bar, text with a
  /// counter, photo preview with Remove photo, optional product tag, and
  /// the posting rule.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isPosting = _postProvider.isPosting;
    final products = context.watch<SellerProductProvider>().allProducts;
    final bytes = _selectedImageBytes;
    final hasContent = _textController.text.trim().isNotEmpty || bytes != null || _taggedProduct != null;

    return SellerDiscardGuard(
      hasChanges: hasContent && !isPosting,
      child: Scaffold(
        appBar: SellerAppBar.detail(context, title: l10n.productNewPost, close: true, actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: SellerSpace.s8),
            child: SellerButton(label: l10n.postPublish, compact: true, expand: false, loading: isPosting, loadingLabel: l10n.postPosting, onPressed: _submit),
          ),
        ]),
        body: SellerPage(
          gap: SellerSpace.s16,
          children: [
            SellerTextField(
              label: l10n.productNewPost,
              hint: l10n.postHint,
              controller: _textController,
              maxLines: 6,
              minLines: 4,
              maxLength: _maxText,
              showCounter: true,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
            ),
            if (bytes != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(SellerRadius.card),
                child: AspectRatio(aspectRatio: 16 / 9, child: Image.memory(bytes, fit: BoxFit.cover)),
              ),
              SellerButton.dangerOutline(
                label: l10n.postRemovePhoto,
                icon: SellerIcons.delete,
                onPressed: () => setState(() {
                  _selectedImage = null;
                  _selectedImageBytes = null;
                }),
              ),
            ] else
              SellerPhotoTile(label: l10n.postAddPhoto, state: SellerUploadState.empty, onTap: _pickImage, size: SellerSize.thumbXl + SellerSpace.s32),
            SellerSelectField<ProductModel?>(
              label: l10n.postTagProduct,
              optional: true,
              prefixIcon: SellerIcons.tag,
              value: _taggedProduct,
              options: [
                SellerOption<ProductModel?>(null, l10n.postNoTag),
                for (final p in products) SellerOption<ProductModel?>(p, p.name),
              ],
              onChanged: (p) => setState(() => _taggedProduct = p),
            ),
            SellerBanner(tone: _showRequirement && !hasContent ? SellerTone.danger : SellerTone.info, message: l10n.postRequirement),
          ],
        ),
      ),
    );
  }
}
