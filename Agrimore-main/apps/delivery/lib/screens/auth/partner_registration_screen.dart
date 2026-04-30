import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:flutter/services.dart';

class PartnerRegistrationScreen extends StatefulWidget {
  const PartnerRegistrationScreen({super.key});

  @override
  State<PartnerRegistrationScreen> createState() => _PartnerRegistrationScreenState();
}

class _PartnerRegistrationScreenState extends State<PartnerRegistrationScreen> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _altPhoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  final _aadhaarController = TextEditingController();
  final _vehicleNumberController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _pincodeController = TextEditingController();
  
  final _accountNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _ifscController = TextEditingController();
  final _upiController = TextEditingController();

  String _vehicleType = 'Bike';
  
  XFile? _aadhaarFront;
  XFile? _aadhaarBack;
  XFile? _selfie;
  XFile? _licenseImage;
  
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _altPhoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _aadhaarController.dispose();
    _vehicleNumberController.dispose();
    _licenseNumberController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    _accountNameController.dispose();
    _accountNumberController.dispose();
    _ifscController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(String source) async {
    final picker = ImagePicker();
    XFile? picked;
    if (source == 'selfie') {
      picked = await picker.pickImage(source: ImageSource.camera);
      setState(() => _selfie = picked);
    } else if (source == 'aadhaarFront') {
      picked = await picker.pickImage(source: ImageSource.gallery);
      setState(() => _aadhaarFront = picked);
    } else if (source == 'aadhaarBack') {
      picked = await picker.pickImage(source: ImageSource.gallery);
      setState(() => _aadhaarBack = picked);
    } else if (source == 'license') {
      picked = await picker.pickImage(source: ImageSource.gallery);
      setState(() => _licenseImage = picked);
    }
  }

  Future<String?> _uploadImage(XFile file, String folder) async {
    try {
      final ref = FirebaseStorage.instance.ref().child('delivery_partners/$folder/${DateTime.now().millisecondsSinceEpoch}_${file.name}');
      await ref.putFile(File(file.path));
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Upload error: $e');
      return null;
    }
  }
  
  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Check required images
    if (_aadhaarFront == null || _aadhaarBack == null || _selfie == null || _licenseImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please upload all required images')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Upload all images
      final aadhaarFrontUrl = await _uploadImage(_aadhaarFront!, 'aadhaar_front');
      final aadhaarBackUrl = await _uploadImage(_aadhaarBack!, 'aadhaar_back');
      final selfieUrl = await _uploadImage(_selfie!, 'selfies');
      final licenseUrl = await _uploadImage(_licenseImage!, 'license');

      // 2. Create Firebase Auth User
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      
      final uid = credential.user!.uid;

      // 3. Create UserModel entry
      final userModel = UserModel(
        uid: uid,
        name: '${_nameController.text.trim()} Partner',
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        role: 'delivery_partner', 
        createdAt: DateTime.now(),
      );
      await FirebaseFirestore.instance.collection('users').doc(uid).set(userModel.toMap());

      // 4. Create DeliveryPartnerModel
      final partner = DeliveryPartnerModel(
        id: uid,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        photoUrl: selfieUrl,
        vehicleNumber: _vehicleNumberController.text.trim(),
        vehicleType: _vehicleType.toLowerCase(),
        aadhaarNumber: _aadhaarController.text.replaceAll('-', ''),
        aadhaarFrontImage: aadhaarFrontUrl,
        aadhaarBackImage: aadhaarBackUrl,
        selfieImage: selfieUrl,
        licenseNumber: _licenseNumberController.text.trim(),
        licenseImage: licenseUrl,
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        pincode: _pincodeController.text.trim(),
        accountHolderName: _accountNameController.text.trim(),
        bankAccountNumber: _accountNumberController.text.trim(),
        ifscCode: _ifscController.text.trim(),
        upiId: _upiController.text.trim(),
        status: 'pending', // VERY IMPORTANT
        createdAt: DateTime.now(),
        isOnline: false,
      );

      // 5. Save to Firestore
      await FirebaseFirestore.instance.collection('delivery_partners').doc(uid).set(partner.toMap());

      // 6. Sign out the newly registered user (so they must wait for approval to login)
      await FirebaseAuth.instance.signOut();

      // 7. Show Success
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
          title: const Text('Registration Submitted'),
          content: const Text('Your registration is pending approval by the admin. You will be notified once approved.'),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close screen
              },
              child: const Text('Okay'),
            ),
          ],
        ),
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register as Delivery Partner'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: Form(
        key: _formKey,
        child: Stepper(
          currentStep: _currentStep,
          onStepContinue: () {
            if (_currentStep < 3) {
              setState(() => _currentStep += 1);
            } else {
              _submitRegistration();
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) {
              setState(() => _currentStep -= 1);
            }
          },
          steps: [
            Step(
              title: const Text('Personal Details'),
              content: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Full Name *', border: OutlineInputBorder()),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Mobile Number *', border: OutlineInputBorder()),
                    validator: (v) => v!.length < 10 ? 'Valid number required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _altPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Alternate Number (Optional)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email *', border: OutlineInputBorder()),
                    validator: (v) => !v!.contains('@') ? 'Valid email required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password *', border: OutlineInputBorder()),
                    validator: (v) => v!.length < 6 ? 'Min 6 chars' : null,
                  ),
                ],
              ),
              isActive: _currentStep >= 0,
            ),
            Step(
              title: const Text('KYC & Documents'),
              content: Column(
                children: [
                  TextFormField(
                    controller: _aadhaarController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Aadhaar Number *', border: OutlineInputBorder()),
                    validator: (v) => v!.length != 12 ? '12-digit Aadhaar required' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildImageUploadItem('Aadhaar Front *', 'aadhaarFront', _aadhaarFront),
                  _buildImageUploadItem('Aadhaar Back *', 'aadhaarBack', _aadhaarBack),
                  _buildImageUploadItem('Live Selfie *', 'selfie', _selfie),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _vehicleType,
                    items: ['Bike', 'Cycle', 'Van'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => setState(() => _vehicleType = v!),
                    decoration: const InputDecoration(labelText: 'Vehicle Type', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _vehicleNumberController,
                    decoration: const InputDecoration(labelText: 'Vehicle Number *', border: OutlineInputBorder()),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _licenseNumberController,
                    decoration: const InputDecoration(labelText: 'Driving License Number *', border: OutlineInputBorder()),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildImageUploadItem('License Image *', 'license', _licenseImage),
                ],
              ),
              isActive: _currentStep >= 1,
            ),
            Step(
              title: const Text('Address Details'),
              content: Column(
                children: [
                  TextFormField(
                    controller: _addressController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Current Address *', border: OutlineInputBorder()),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _cityController,
                          decoration: const InputDecoration(labelText: 'City *', border: OutlineInputBorder()),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _pincodeController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Pincode *', border: OutlineInputBorder()),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              isActive: _currentStep >= 2,
            ),
            Step(
              title: const Text('Bank Details'),
              content: Column(
                children: [
                  TextFormField(
                    controller: _accountNameController,
                    decoration: const InputDecoration(labelText: 'Account Holder Name *', border: OutlineInputBorder()),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _accountNumberController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Bank Account Number *', border: OutlineInputBorder()),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _ifscController,
                    decoration: const InputDecoration(labelText: 'IFSC Code *', border: OutlineInputBorder()),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _upiController,
                    decoration: const InputDecoration(labelText: 'UPI ID (Optional)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 24),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    const SizedBox.shrink(),
                ],
              ),
              isActive: _currentStep >= 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageUploadItem(String label, String source, XFile? file) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
          OutlinedButton.icon(
            icon: file != null ? const Icon(Icons.check, color: Colors.green) : const Icon(Icons.upload),
            label: Text(file != null ? 'Uploaded' : 'Upload'),
            onPressed: () => _pickImage(source),
          ),
        ],
      ),
    );
  }
}
