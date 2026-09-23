import 'dart:typed_data';

import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/seller_auth_provider.dart';
import '../../providers/seller_post_provider.dart';
import '../../providers/seller_product_provider.dart';

/// M-05 Post composer (ADR §10.6, SELLER-UI-1d): text, photo, optional
/// product tag, published to followers.
class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  static const int _maxText = 500;
  static const int _imageQuality = 82;
  static const double _imageMaxWidth = 1600;

  final _textController = TextEditingController();
  final _imagePicker = ImagePicker();
  final _postProvider = SellerPostProvider();

  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  ProductModel? _taggedProduct;

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
    _postProvider.dispose();
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
      if (mounted) WsToast.show(context, l10n.editorPhotoFailed, tone: WsToastTone.error);
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final sellerId = context.read<SellerAuthProvider>().currentUser?.uid;
    if (sellerId == null) return;
    if (_textController.text.trim().isEmpty && _selectedImageBytes == null && _taggedProduct == null) {
      WsToast.show(context, l10n.postEmpty, tone: WsToastTone.error);
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
      WsToast.show(context, l10n.postPublished, tone: WsToastTone.success);
      Navigator.of(context).pop();
    } else {
      WsToast.show(context, l10n.postFailed, tone: WsToastTone.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    final text = context.wsText;
    final isPosting = _postProvider.isPosting;
    final products = context.watch<SellerProductProvider>().allProducts;
    final bytes = _selectedImageBytes;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(tooltip: l10n.back, icon: const Icon(AgIcons.close), onPressed: () => Navigator.of(context).maybePop()),
        title: Text(l10n.productNewPost),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: WsSpace.s8),
            child: FilledButton(onPressed: isPosting ? null : _submit, child: Text(isPosting ? l10n.postPosting : l10n.postPublish)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(WsSpace.page),
        children: [
          TextField(
            controller: _textController,
            maxLines: 5,
            maxLength: _maxText,
            decoration: InputDecoration(hintText: l10n.postHint),
          ),
          const SizedBox(height: WsSpace.s16),
          if (bytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(WsRadius.card),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(fit: StackFit.expand, children: [
                  Image.memory(bytes, fit: BoxFit.cover),
                  Positioned(
                    top: WsSpace.s8,
                    right: WsSpace.s8,
                    child: IconButton.filledTonal(
                      tooltip: l10n.postRemovePhoto,
                      icon: const Icon(AgIcons.close),
                      onPressed: () => setState(() {
                        _selectedImage = null;
                        _selectedImageBytes = null;
                      }),
                    ),
                  ),
                ]),
              ),
            )
          else
            OutlinedButton.icon(onPressed: _pickImage, icon: const Icon(AgIcons.image), label: Text(l10n.postAddPhoto)),
          const SizedBox(height: WsSpace.s24),
          Text(l10n.postTagProduct, style: text.titleSmall),
          const SizedBox(height: WsSpace.s8),
          DropdownButtonFormField<ProductModel>(
            initialValue: _taggedProduct,
            hint: Text(l10n.postNoTag, style: text.bodyMedium!.copyWith(color: t.textTertiary)),
            items: [
              for (final p in products) DropdownMenuItem(value: p, child: Text(p.name, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (p) => setState(() => _taggedProduct = p),
          ),
        ],
      ),
    );
  }
}
