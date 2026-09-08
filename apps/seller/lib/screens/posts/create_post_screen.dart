import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../providers/seller_auth_provider.dart';
import '../../providers/seller_product_provider.dart';
import '../../providers/seller_post_provider.dart';

/// BUSINESS-NETWORK-2 (slice 2 of 2): lets a seller post text, an image,
/// and/or a tag linking one of their own products to their followers.
/// Reached from SellerProductsScreen's own AppBar action -- deliberately
/// NOT a new persistent bottom-nav tab (SellerShell's 5 tabs are fixed).
///
/// SellerPostProvider is a plain (non-Provider-tree) instance, listener-
/// driven setState -- matching BUSINESS-NETWORK-1's own BusinessFollowProvider
/// pattern -- rather than registered in main.dart's app-wide MultiProvider,
/// since its only state (_isPosting) matters solely while this screen is open.
class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  static const _accentColor = Color(0xFF2D7D3C);

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
      if (mounted) SnackbarHelper.showError(context, 'Unable to pick an image.');
    }
  }

  Future<void> _submit() async {
    final sellerId = context.read<SellerAuthProvider>().currentUser?.uid;
    if (sellerId == null) return;

    final hasText = _textController.text.trim().isNotEmpty;
    final hasImage = _selectedImageBytes != null;
    final hasProduct = _taggedProduct != null;
    if (!hasText && !hasImage && !hasProduct) {
      SnackbarHelper.showError(context, 'Add some text, an image, or tag a product first.');
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
      SnackbarHelper.showSuccess(context, 'Posted to your followers!');
      Navigator.pop(context);
    } else {
      SnackbarHelper.showError(context, 'Could not create the post. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPosting = _postProvider.isPosting;
    final products = context.watch<SellerProductProvider>().allProducts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Post'),
        actions: [
          TextButton(
            onPressed: isPosting ? null : _submit,
            child: isPosting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _accentColor),
                  )
                : const Text('Post', style: TextStyle(fontWeight: FontWeight.bold, color: _accentColor)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _textController,
            maxLines: 5,
            maxLength: 500,
            decoration: const InputDecoration(
              hintText: "What's new? Tell your followers about it...",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          if (_selectedImageBytes != null)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _selectedImageBytes!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: Colors.black54),
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => setState(() {
                      _selectedImage = null;
                      _selectedImageBytes = null;
                    }),
                  ),
                ),
              ],
            )
          else
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.image_outlined, color: _accentColor),
              label: const Text('Add a photo', style: TextStyle(color: _accentColor)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                side: const BorderSide(color: _accentColor),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            'Tag a product (optional)',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<ProductModel>(
            initialValue: _taggedProduct,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            hint: const Text('None'),
            items: products
                .map((p) => DropdownMenuItem(value: p, child: Text(p.name, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (p) => setState(() => _taggedProduct = p),
          ),
        ],
      ),
    );
  }
}
