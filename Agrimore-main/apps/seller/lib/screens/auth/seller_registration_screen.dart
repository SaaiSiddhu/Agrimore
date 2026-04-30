import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

class SellerRegistrationScreen extends StatefulWidget {
  const SellerRegistrationScreen({Key? key}) : super(key: key);

  @override
  State<SellerRegistrationScreen> createState() => _SellerRegistrationScreenState();
}

class _SellerRegistrationScreenState extends State<SellerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _shopNameController = TextEditingController();
  final _shopAddressController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _ifscController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _mobileController.dispose();
    _shopNameController.dispose();
    _shopAddressController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _ifscController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final uid = userCredential.user!.uid;

      final batch = FirebaseFirestore.instance.batch();

      // Create user doc
      batch.set(FirebaseFirestore.instance.collection('users').doc(uid), {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'mobile': _mobileController.text.trim(),
        'role': 'user', // Initial role, upgraded to seller after approval
        'sellerStatus': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Create seller request doc
      batch.set(FirebaseFirestore.instance.collection('sellerRequests').doc(uid), {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'mobile': _mobileController.text.trim(),
        'shopName': _shopNameController.text.trim(),
        'shopAddress': _shopAddressController.text.trim(),
        'bankName': _bankNameController.text.trim(),
        'accountNumber': _accountNumberController.text.trim(),
        'ifsc': _ifscController.text.trim(),
        'status': 'pending',
        'appliedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Registration submitted for approval');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Registration failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register as Seller'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Join Agrimore',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Fill in the details below to become a seller. Your account will be reviewed by admin.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),

              const Text('Personal Info', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              _buildField(_nameController, 'Full Name', Icons.person),
              const SizedBox(height: 16),
              _buildField(_emailController, 'Email', Icons.email, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 16),
              _buildField(_passwordController, 'Password', Icons.lock, obscureText: true),
              const SizedBox(height: 16),
              _buildField(_mobileController, 'Mobile Number', Icons.phone, keyboardType: TextInputType.phone),

              const SizedBox(height: 32),
              const Text('Business Info', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              _buildField(_shopNameController, 'Shop / Business Name', Icons.store),
              const SizedBox(height: 16),
              _buildField(_shopAddressController, 'Shop Address', Icons.location_on, maxLines: 3),

              const SizedBox(height: 32),
              const Text('Bank Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              _buildField(_bankNameController, 'Bank Name', Icons.account_balance),
              const SizedBox(height: 16),
              _buildField(_accountNumberController, 'Account Number', Icons.numbers, keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              _buildField(_ifscController, 'IFSC Code', Icons.code),

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _isLoading ? null : _submit,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Submit Application', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon,
      {bool obscureText = false, TextInputType? keyboardType, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
    );
  }
}
