import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

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
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _shopNameController =
        TextEditingController(text: widget.initialData['shopName']?.toString() ?? '');
    _shopAddressController =
        TextEditingController(text: widget.initialData['shopAddress']?.toString() ?? '');
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _shopAddressController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('sellers').doc(widget.sellerId).update({
        'shopName': _shopNameController.text.trim(),
        'shopAddress': _shopAddressController.text.trim(),
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
}
