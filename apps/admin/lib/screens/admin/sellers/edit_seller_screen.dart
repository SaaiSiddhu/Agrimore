import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../products/widgets/image_uploader.dart';

/// Edit an already-approved seller's profile (ADMIN-SELLER-CMS-1).
/// Writes only to `sellers/{sellerId}` via `.update()` — the doc is known to
/// exist (opened from ManageSellersScreen's own live query). Never reads or
/// writes `seller_payout_details/{uid}` (bankName/accountNumber/ifsc) — that
/// collection is structurally separate, per FIX-2/N-2.
class EditSellerScreen extends StatefulWidget {
  final String sellerId;
  final Map<String, dynamic> initialData;

  const EditSellerScreen({
    Key? key,
    required this.sellerId,
    required this.initialData,
  }) : super(key: key);

  @override
  State<EditSellerScreen> createState() => _EditSellerScreenState();
}

class _EditSellerScreenState extends State<EditSellerScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _shopNameController;
  late final TextEditingController _shopAddressController;
  late final TextEditingController _descriptionController;
  String? _logoUrl;
  String? _coverImageUrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _shopNameController =
        TextEditingController(text: widget.initialData['shopName']?.toString() ?? '');
    _shopAddressController =
        TextEditingController(text: widget.initialData['shopAddress']?.toString() ?? '');
    _descriptionController =
        TextEditingController(text: widget.initialData['description']?.toString() ?? '');
    final logo = widget.initialData['logoUrl']?.toString();
    _logoUrl = (logo != null && logo.isNotEmpty) ? logo : null;
    final cover = widget.initialData['coverImageUrl']?.toString();
    _coverImageUrl = (cover != null && cover.isNotEmpty) ? cover : null;
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _shopAddressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('sellers').doc(widget.sellerId).update({
        'shopName': _shopNameController.text.trim(),
        'shopAddress': _shopAddressController.text.trim(),
        'description': _descriptionController.text.trim(),
        'logoUrl': _logoUrl ?? '',
        'coverImageUrl': _coverImageUrl ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Seller profile updated');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        SnackbarHelper.showError(context, 'Failed to update: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.initialData['name']?.toString() ?? '';
    final email = widget.initialData['email']?.toString() ?? '';
    final mobile = widget.initialData['mobile']?.toString() ?? '';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Edit seller'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? '(no name on file)' : name,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$email · $mobile',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _shopNameController,
                decoration: const InputDecoration(
                  labelText: 'Shop name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.storefront_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _shopAddressController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Shop address',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Shop description (optional)',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 20),
              _buildSingleImageSection(
                title: 'Shop logo (optional)',
                currentUrl: _logoUrl,
                onChanged: (url) => setState(() => _logoUrl = url),
              ),
              const SizedBox(height: 16),
              _buildSingleImageSection(
                title: 'Cover image (optional)',
                currentUrl: _coverImageUrl,
                onChanged: (url) => setState(() => _coverImageUrl = url),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _isSaving ? null : _save,
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Wraps the shared `ImageUploader` (a multi-image picker) in single-image
  /// mode: only ever passes it a 0-or-1-item list, and on every change keeps
  /// just the LAST image the widget reports (covers both "picked a new one
  /// while one already existed" and "removed it"). Uploads go to
  /// `sellers/{sellerId}/{fileName}` via the widget's `storageFolder` param
  /// (ADMIN-SELLER-CMS-1's own generalization of the previously-hardcoded
  /// `products/{fileName}` path), matching this phase's storage.rules block.
  Widget _buildSingleImageSection({
    required String title,
    required String? currentUrl,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          SizedBox(
            height: 300,
            child: ImageUploader(
              imageUrls: currentUrl != null ? [currentUrl] : const [],
              storageFolder: 'sellers/${widget.sellerId}',
              onImagesChanged: (list) => onChanged(list.isEmpty ? null : list.last),
            ),
          ),
        ],
      ),
    );
  }
}
