// ============================================================
//  AGRIMORE - COMPLETE PROFILE SCREEN (Premium Design)
// ============================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

class CompleteProfileScreen extends StatefulWidget {
  final String email;

  const CompleteProfileScreen({Key? key, required this.email}) : super(key: key);

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _animController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your name';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    if (value.length < 10) {
      return 'Please enter a valid 10-digit phone number';
    }
    if (value.length > 10) {
      return 'Phone number should be 10 digits';
    }
    return null;
  }

  Future<void> _handleComplete() async {
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();

      await user.updateDisplayName(name);

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'name': name,
        'phone': '+91$phone',
        'profileCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      resizeToAvoidBottomInset: true, // Let Flutter resize with keyboard
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      body: Stack(
        children: [
          // Premium background
          Positioned.fill(child: _buildBackground(isDark)),
          
          // Decorative elements
          _buildDecorativeElements(isDark),

          // Main content
          SafeArea(
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, child) => Opacity(
                opacity: _fadeAnimation.value,
                child: Transform.translate(
                  offset: Offset(0, _slideAnimation.value),
                  child: child,
                ),
              ),
              child: SingleChildScrollView(
                // ✅ Dismiss keyboard when dragging
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.symmetric(
                  horizontal: size.width > 600 ? size.width * 0.2 : 24,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      SizedBox(height: size.height * 0.06),

                      // Logo
                      _buildLogo(isDark),

                      const SizedBox(height: 32),

                      // Header
                      _buildHeader(isDark),

                      const SizedBox(height: 36),

                      // Profile Card
                      _buildProfileCard(isDark),

                      const SizedBox(height: 24),

                      // Error message
                      if (_errorMessage != null) _buildErrorMessage(),

                      // Complete button
                      _buildCompleteButton(isDark),

                      const SizedBox(height: 32),

                      // Security note
                      _buildSecurityNote(isDark),

                      SizedBox(height: size.height * 0.05),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground(bool isDark) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  AppColors.primaryDark.withOpacity(0.25),
                  AppColors.backgroundDark,
                  AppColors.backgroundDark,
                ]
              : [
                  AppColors.primaryLight.withOpacity(0.08),
                  AppColors.background,
                  AppColors.surface,
                ],
        ),
      ),
    );
  }

  Widget _buildDecorativeElements(bool isDark) {
    return Stack(
      children: [
        Positioned(
          top: -100,
          left: -100,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.secondary.withOpacity(isDark ? 0.1 : 0.12),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: -50,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primary.withOpacity(isDark ? 0.12 : 0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogo(bool isDark) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.35),
            blurRadius: 25,
            spreadRadius: 3,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Image.asset(
          'assets/icons/logo_icon.png',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(26),
            ),
            child: const Icon(
              Icons.person_rounded,
              size: 50,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      children: [
        Text(
          'Complete Your Profile',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.textLight : AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Tell us about yourself to personalize your experience',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: isDark ? AppColors.textLightSecondary : AppColors.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard(bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : AppColors.border,
            ),
            boxShadow: isDark ? null : [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Email (verified)
              _buildEmailDisplay(isDark),

              const SizedBox(height: 20),

              // Name field
              _buildSectionLabel('Full Name', Icons.person_rounded, isDark),
              const SizedBox(height: 10),
              _buildInputField(
                controller: _nameController,
                hint: 'Enter your full name',
                validator: _validateName,
                isDark: isDark,
                textCapitalization: TextCapitalization.words,
              ),

              const SizedBox(height: 20),

              // Phone field
              _buildSectionLabel('Phone Number', Icons.phone_rounded, isDark, isRequired: true),
              const SizedBox(height: 10),
              _buildPhoneField(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailDisplay(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.success.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.email_rounded,
              color: AppColors.success,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Email Verified',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.email,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.textLight : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.verified_rounded,
            color: AppColors.success,
            size: 22,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label, IconData icon, bool isDark, {bool isRequired = false}) {
    return Row(
      children: [
        Icon(
          icon,
          color: AppColors.primary,
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.textLight : AppColors.textPrimary,
          ),
        ),
        if (isRequired) ...[
          const SizedBox(width: 4),
          Text(
            '*',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.error,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required String? Function(String?) validator,
    required bool isDark,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : AppColors.borderLight,
        ),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        textCapitalization: textCapitalization,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: isDark ? AppColors.textLight : AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: isDark ? AppColors.textLightTertiary : AppColors.textHint,
            fontWeight: FontWeight.w400,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildPhoneField(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : AppColors.borderLight,
        ),
      ),
      child: Row(
        children: [
          // Country code
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : AppColors.borderLight,
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  '🇮🇳',
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 6),
                Text(
                  '+91',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textLight : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          // Phone input
          Expanded(
            child: TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.textLight : AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Enter 10-digit mobile number',
                hintStyle: TextStyle(
                  color: isDark ? AppColors.textLightTertiary : AppColors.textHint,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              validator: _validatePhone,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: AppColors.error, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: AppColors.error, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteButton(bool isDark) {
    return Container(
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.4),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleComplete,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    'Get Started',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  SizedBox(width: 10),
                  Icon(Icons.arrow_forward_rounded, size: 22),
                ],
              ),
      ),
    );
  }

  Widget _buildSecurityNote(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.lock_rounded,
          size: 14,
          color: isDark ? AppColors.textLightTertiary : AppColors.textTertiary,
        ),
        const SizedBox(width: 6),
        Text(
          'Your information is secure and private',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.textLightTertiary : AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}
