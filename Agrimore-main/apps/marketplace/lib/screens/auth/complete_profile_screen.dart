// ============================================================
//  AGRIMORE - COMPLETE PROFILE SCREEN (Premium Design)
// ============================================================
//
// Phase 16, Workstream 6 rewrite. Previously took a required `email` arg
// (pre-verified by the now-legacy Google/email-signup path) and collected
// only Name + Phone, writing profileCompleted: true directly to Firestore
// from the client. Now takes `phone` (already verified via OTP before this
// screen is ever shown) and collects Name, Email (with an inline
// send/verify-OTP step — new users only get here with an empty email on
// file, see completeUserProfile.ts), Date of Birth, and Gender — submitted
// via the completeUserProfile callable, never a direct Firestore write.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_core/agrimore_core.dart';
import '../../app/routes.dart';
import '../../providers/auth_provider.dart';

class CompleteProfileScreen extends StatefulWidget {
  final String phone;

  const CompleteProfileScreen({Key? key, required this.phone}) : super(key: key);

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _emailOtpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isSendingCode = false;
  bool _isVerifyingCode = false;
  bool _emailVerified = false;
  bool _codeSent = false;
  String? _errorMessage;
  DateTime? _dateOfBirth;
  String? _gender;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  static const List<Map<String, String>> _genderOptions = [
    {'value': 'male', 'label': 'Male'},
    {'value': 'female', 'label': 'Female'},
    {'value': 'non_binary', 'label': 'Non-binary'},
    {'value': 'prefer_not_to_say', 'label': 'Prefer not to say'},
  ];

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
    _emailController.dispose();
    _emailOtpController.dispose();
    _animController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Please enter your name';
    if (v.length < 2) return 'Name must be at least 2 characters';
    return null;
  }

  String? _validateEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Please enter your email';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  bool get _canSubmit =>
      _dateOfBirth != null && _gender != null && _emailVerified && !_isLoading;

  Future<void> _handleSendCode() async {
    final emailError = _validateEmail(_emailController.text);
    if (emailError != null) {
      setState(() => _errorMessage = emailError);
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _isSendingCode = true;
      _errorMessage = null;
    });

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.sendEmailOtpForProfile(_emailController.text.trim());

    if (!mounted) return;
    setState(() {
      _isSendingCode = false;
      if (success) {
        _codeSent = true;
      } else {
        _errorMessage = authProvider.error ?? 'Failed to send verification code';
      }
    });
  }

  Future<void> _handleVerifyCode() async {
    final code = _emailOtpController.text.trim();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Enter the 6-digit code');
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _isVerifyingCode = true;
      _errorMessage = null;
    });

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.verifyEmailOtpForProfile(
      email: _emailController.text.trim(),
      otp: code,
    );

    if (!mounted) return;
    setState(() {
      _isVerifyingCode = false;
      if (success) {
        _emailVerified = true;
      } else {
        _errorMessage = authProvider.error ?? 'Invalid code. Please try again.';
      }
    });
  }

  Future<void> _handlePickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - kMinimumProfileAgeYears, now.month, now.day),
      firstDate: DateTime(now.year - 120),
      lastDate: DateTime(now.year - kMinimumProfileAgeYears, now.month, now.day),
      helpText: 'Select your date of birth',
    );
    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }

  Future<void> _handleComplete() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_canSubmit) {
      setState(() {
        _errorMessage = !_emailVerified
            ? 'Please verify your email first'
            : 'Please select your date of birth and gender';
      });
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.completeUserProfile(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      dateOfBirth: _dateOfBirth!,
      gender: _gender!,
    );

    if (!mounted) return;

    if (!success) {
      setState(() {
        _isLoading = false;
        _errorMessage = authProvider.error ?? 'Failed to complete profile';
      });
      return;
    }

    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.main, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      body: Stack(
        children: [
          Positioned.fill(child: _buildBackground(isDark)),
          _buildDecorativeElements(isDark),
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
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.symmetric(
                  horizontal: size.width > 600 ? size.width * 0.2 : 24,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      SizedBox(height: size.height * 0.06),
                      _buildLogo(isDark),
                      const SizedBox(height: 32),
                      _buildHeader(isDark),
                      const SizedBox(height: 36),
                      _buildProfileCard(isDark),
                      const SizedBox(height: 24),
                      if (_errorMessage != null) _buildErrorMessage(),
                      _buildCompleteButton(isDark),
                      const SizedBox(height: 32),
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
                  AppColors.primaryDark.withValues(alpha: 0.25),
                  AppColors.backgroundDark,
                  AppColors.backgroundDark,
                ]
              : [
                  AppColors.primaryLight.withValues(alpha: 0.08),
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
                  AppColors.secondary.withValues(alpha: isDark ? 0.1 : 0.12),
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
                  AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.15),
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
            color: AppColors.primary.withValues(alpha: 0.35),
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
            child: const Icon(Icons.person_rounded, size: 50, color: Colors.white),
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
          'Just a few details to personalize your experience',
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
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.border,
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPhoneDisplay(isDark),
              const SizedBox(height: 20),
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
              _buildSectionLabel('Email', Icons.email_rounded, isDark, isRequired: true),
              const SizedBox(height: 10),
              _buildEmailSection(isDark),
              const SizedBox(height: 20),
              _buildSectionLabel('Date of Birth', Icons.cake_rounded, isDark, isRequired: true),
              const SizedBox(height: 10),
              _buildDateOfBirthField(isDark),
              const SizedBox(height: 20),
              _buildSectionLabel('Gender', Icons.wc_rounded, isDark, isRequired: true),
              const SizedBox(height: 10),
              _buildGenderSelector(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneDisplay(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.phone_rounded, color: AppColors.success, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Phone Verified',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.phone,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.textLight : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.verified_rounded, color: AppColors.success, size: 22),
        ],
      ),
    );
  }

  Widget _buildEmailSection(bool isDark) {
    if (_emailVerified) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _emailController.text.trim(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.textLight : AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(Icons.verified_rounded, color: AppColors.success, size: 22),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildInputField(
                controller: _emailController,
                hint: 'you@example.com',
                validator: _validateEmail,
                isDark: isDark,
                keyboardType: TextInputType.emailAddress,
                enabled: !_codeSent,
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: (_isSendingCode || _codeSent) ? null : _handleSendCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: _isSendingCode
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_codeSent ? 'Sent' : 'Send Code', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
        if (_codeSent) ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildInputField(
                  controller: _emailOtpController,
                  hint: '6-digit code',
                  validator: null,
                  isDark: isDark,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isVerifyingCode ? null : _handleVerifyCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: _isVerifyingCode
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Verify', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: _isSendingCode
                ? null
                : () {
                    setState(() => _codeSent = false);
                    _handleSendCode();
                  },
            child: const Text('Resend code', style: TextStyle(color: AppColors.primary, fontSize: 13)),
          ),
        ],
      ],
    );
  }

  Widget _buildDateOfBirthField(bool isDark) {
    return InkWell(
      onTap: _handlePickDateOfBirth,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.borderLight,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _dateOfBirth == null
                    ? 'Select date of birth'
                    : '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: _dateOfBirth == null
                      ? (isDark ? AppColors.textLightTertiary : AppColors.textHint)
                      : (isDark ? AppColors.textLight : AppColors.textPrimary),
                ),
              ),
            ),
            Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderSelector(bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _genderOptions.map((option) {
        final selected = _gender == option['value'];
        return ChoiceChip(
          label: Text(option['label']!),
          selected: selected,
          onSelected: (_) => setState(() => _gender = option['value']),
          selectedColor: AppColors.primary,
          labelStyle: TextStyle(
            color: selected ? Colors.white : (isDark ? AppColors.textLight : AppColors.textPrimary),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.surfaceVariant,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: selected
                  ? AppColors.primary
                  : (isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.borderLight),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionLabel(String label, IconData icon, bool isDark, {bool isRequired = false}) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
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
          const Text('*', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.error)),
        ],
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required String? Function(String?)? validator,
    required bool isDark,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool enabled = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.borderLight,
        ),
      ),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
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

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.error, fontSize: 14, fontWeight: FontWeight.w500),
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
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleComplete,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text('Get Started', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
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
        Icon(Icons.lock_rounded, size: 14, color: isDark ? AppColors.textLightTertiary : AppColors.textTertiary),
        const SizedBox(width: 6),
        Text(
          'Your information is secure and private',
          style: TextStyle(fontSize: 13, color: isDark ? AppColors.textLightTertiary : AppColors.textTertiary),
        ),
      ],
    );
  }
}
