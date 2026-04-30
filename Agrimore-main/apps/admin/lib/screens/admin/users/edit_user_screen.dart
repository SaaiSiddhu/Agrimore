import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

import '../../../providers/admin_provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

class EditUserScreen extends StatefulWidget {
  final UserModel user;

  const EditUserScreen({
    Key? key,
    required this.user,
  }) : super(key: key);

  @override
  State<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends State<EditUserScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  
  late String _selectedRole;
  late bool _isActive;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _emailController = TextEditingController(text: widget.user.email);
    _phoneController = TextEditingController(text: widget.user.phone ?? '');
    _selectedRole = widget.user.role;
    _isActive = widget.user.isActive;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdate() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isProcessing = true);

      try {
        final adminProvider = Provider.of<AdminProvider>(context, listen: false);
        
        // Update user role
        await adminProvider.updateUserRole(widget.user.uid, _selectedRole);
        
        // Update name, phone, and status
        await adminProvider.updateUserInfo(widget.user.uid, {
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
        });
        
        // Update active status
        await adminProvider.toggleUserStatus(widget.user.uid, _isActive);

        if (context.mounted) {
          setState(() => _isProcessing = false);
          SnackbarHelper.showSuccess(context, 'User updated successfully');
          Navigator.pop(context);
        }
      } catch (e) {
        setState(() => _isProcessing = false);
        if (context.mounted) {
          SnackbarHelper.showError(context, 'Failed to update user: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Edit User'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // User Avatar
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.7)],
                      ),
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: widget.user.photoUrl != null
                        ? ClipOval(
                            child: Image.network(
                              widget.user.photoUrl!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Center(
                            child: Text(
                              widget.user.initials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Name Field
            _buildSectionTitle('Full Name', isRequired: true),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'Enter full name',
                prefixIcon: const Icon(Icons.person_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter name';
                }
                return null;
              },
            ),

            const SizedBox(height: 24),

            // Email Field (Read-only)
            _buildSectionTitle('Email'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailController,
              enabled: false,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.email_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),

            const SizedBox(height: 24),

            // Phone Field
            _buildSectionTitle('Phone Number'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                hintText: 'Enter phone number',
                prefixIcon: const Icon(Icons.phone_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              keyboardType: TextInputType.phone,
            ),

            const SizedBox(height: 24),

            // Role Selection
            _buildSectionTitle('User Role', isRequired: true),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildRoleOption('user', 'User', 'Regular user with standard permissions'),
                  Divider(height: 1, color: Colors.grey.shade300),
                  _buildRoleOption('admin', 'Admin', 'Administrator with full access'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Status Toggle
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isActive ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isActive ? Colors.green.shade200 : Colors.red.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isActive ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: _isActive ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Account Status',
                          style: AppTextStyles.titleSmall.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _isActive ? 'User can access the platform' : 'User is blocked',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isActive,
                    onChanged: (value) {
                      setState(() => _isActive = value);
                    },
                    activeColor: Colors.green,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Update Button
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _handleUpdate,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(
                  _isProcessing ? 'Updating...' : 'Update User',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, {bool isRequired = false}) {
    return Row(
      children: [
        Text(
          title,
          style: AppTextStyles.titleSmall.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        if (isRequired) ...[
          const SizedBox(width: 4),
          const Text(
            '*',
            style: TextStyle(color: Colors.red, fontSize: 16),
          ),
        ],
      ],
    );
  }

  Widget _buildRoleOption(String value, String title, String subtitle) {
    final isSelected = _selectedRole == value;
    return InkWell(
      onTap: () => setState(() => _selectedRole = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: _selectedRole,
              onChanged: (val) => setState(() => _selectedRole = val!),
              activeColor: AppColors.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppColors.primary : Colors.grey.shade800,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
