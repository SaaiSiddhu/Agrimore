// ============================================================
//  AGRIMORE - SIGNUP SCREEN (Professional Registration)
// ============================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_services/agrimore_services.dart';
import 'package:provider/provider.dart';
import '../../providers/wallet_provider.dart';

class SignupScreen extends StatefulWidget {
  final String? initialEmail;
  final bool fromGoogle;
  
  const SignupScreen({
    Key? key,
    this.initialEmail,
    this.fromGoogle = false,
  }) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _referralCodeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  final _nameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();
  final _referralFocusNode = FocusNode();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  
  // Focus states
  bool _isNameFocused = false;
  bool _isEmailFocused = false;
  bool _isPhoneFocused = false;
  bool _isPasswordFocused = false;
  bool _isConfirmPasswordFocused = false;
  bool _isReferralFocused = false;
  
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Pre-fill email if provided (from Google redirect)
    if (widget.initialEmail != null) {
      _emailController.text = widget.initialEmail!;
    }
    
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    
    // Setup focus listeners
    _nameFocusNode.addListener(() => setState(() => _isNameFocused = _nameFocusNode.hasFocus));
    _emailFocusNode.addListener(() => setState(() => _isEmailFocused = _emailFocusNode.hasFocus));
    _phoneFocusNode.addListener(() => setState(() => _isPhoneFocused = _phoneFocusNode.hasFocus));
    _passwordFocusNode.addListener(() => setState(() => _isPasswordFocused = _passwordFocusNode.hasFocus));
    _confirmPasswordFocusNode.addListener(() => setState(() => _isConfirmPasswordFocused = _confirmPasswordFocusNode.hasFocus));
    _referralFocusNode.addListener(() => setState(() => _isReferralFocused = _referralFocusNode.hasFocus));
    
    _fadeController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _phoneFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _referralCodeController.dispose();
    _referralFocusNode.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your full name';
    }
    if (value.length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your phone number';
    }
    if (value.length != 10) {
      return 'Phone number must be 10 digits';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = AuthService();
      await authService.registerWithEmail(
        email: _emailController.text.trim().toLowerCase(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
        phone: '+91${_phoneController.text.trim()}',
      );
      
      if (mounted) {
        // Apply referral code if provided
        final referralCode = _referralCodeController.text.trim().toUpperCase();
        if (referralCode.isNotEmpty) {
          try {
            final walletProvider = context.read<WalletProvider>();
            await walletProvider.loadWallet();
            await walletProvider.applyReferralCode(referralCode);
          } catch (e) {
            debugPrint('Referral error (non-blocking): $e');
          }
        }
        Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '').replaceAll('AuthException: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 900;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: true, // Let Flutter resize with keyboard
      backgroundColor: isDark ? const Color(0xFF1B3A2F) : const Color(0xFFE8F5E9),
      body: isDesktop
          ? Row(
              children: [
                Expanded(flex: 5, child: _buildBrandingPanel(isDark)),
                Expanded(flex: 4, child: _buildFormPanel(isDark)),
              ],
            )
          : _buildMobileLayout(isDark),
    );
  }

  Widget _buildBrandingPanel(bool isDark) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _PatternPainter())),
          
          // Floating icons
          Positioned(top: 80, right: 60, child: _buildFloatingIcon('🌾', 48)),
          Positioned(top: 200, left: 40, child: _buildFloatingIcon('🥬', 40)),
          Positioned(bottom: 180, right: 80, child: _buildFloatingIcon('🍅', 44)),
          Positioned(bottom: 100, left: 60, child: _buildFloatingIcon('🌽', 36)),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'assets/icons/logo_icon.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Text('🌱', style: TextStyle(fontSize: 28)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Agrimore',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  
                  const Spacer(),
                  
                  const Text(
                    'Join India\'s\nLargest Agri\nCommunity',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.1,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Create your account and start exploring\nthousands of quality agricultural products.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.85),
                      height: 1.6,
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  Row(
                    children: [
                      _buildTrustBadge(Icons.local_shipping_rounded, 'Fast\nDelivery'),
                      const SizedBox(width: 24),
                      _buildTrustBadge(Icons.support_agent_rounded, '24/7\nSupport'),
                      const SizedBox(width: 24),
                      _buildTrustBadge(Icons.verified_rounded, 'Quality\nAssured'),
                    ],
                  ),
                  
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingIcon(String emoji, double size) {
    return Container(
      width: size + 20,
      height: size + 20,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Center(child: Text(emoji, style: TextStyle(fontSize: size * 0.6))),
    );
  }

  Widget _buildTrustBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.95),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormPanel(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF0F0F0F) : Colors.white,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _buildFormContent(isDark),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(bool isDark) {
    // ✅ Proper keyboard-aware layout (following best practices)
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFF1B3A2F), const Color(0xFF0F0F0F)]
              : [const Color(0xFFE8F5E9), Colors.white],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          // ✅ Dismiss keyboard when dragging
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(24),
          physics: const ClampingScrollPhysics(),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                const SizedBox(height: 10),
                _buildMobileLogo(isDark),
                const SizedBox(height: 24),
                _buildFormContent(isDark),
                // ✅ Add extra padding at bottom for keyboard
                SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0 ? 20 : 0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLogo(bool isDark) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset(
              'assets/icons/logo_icon.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
                ),
                child: const Center(child: Text('🌱', style: TextStyle(fontSize: 32))),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Agrimore',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildFormContent(bool isDark) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Create your account',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Already have an account? ',
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white60 : AppColors.textSecondary,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pushReplacementNamed(context, '/login'),
                child: Text(
                  'Sign in',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 28),
          
          // Full Name
          _buildLabel('Full Name', isDark),
          const SizedBox(height: 8),
          _buildInputField(
            controller: _nameController,
            focusNode: _nameFocusNode,
            isFocused: _isNameFocused,
            isDark: isDark,
            hintText: 'John Doe',
            prefixIcon: Icons.person_outline,
            textCapitalization: TextCapitalization.words,
            validator: _validateName,
            onFieldSubmitted: (_) => _emailFocusNode.requestFocus(),
          ),
          
          const SizedBox(height: 16),
          
          // Email
          _buildLabel('Email address', isDark),
          const SizedBox(height: 8),
          _buildInputField(
            controller: _emailController,
            focusNode: _emailFocusNode,
            isFocused: _isEmailFocused,
            isDark: isDark,
            hintText: 'you@example.com',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            enabled: widget.initialEmail == null, // Disable if from Google
            validator: _validateEmail,
            onFieldSubmitted: (_) => _phoneFocusNode.requestFocus(),
          ),
          
          const SizedBox(height: 16),
          
          // Phone
          _buildLabel('Phone number', isDark),
          const SizedBox(height: 8),
          _buildPhoneField(isDark),
          
          const SizedBox(height: 16),
          
          // Password
          _buildLabel('Password', isDark),
          const SizedBox(height: 8),
          _buildInputField(
            controller: _passwordController,
            focusNode: _passwordFocusNode,
            isFocused: _isPasswordFocused,
            isDark: isDark,
            hintText: 'Min 6 characters',
            prefixIcon: Icons.lock_outline,
            obscureText: _obscurePassword,
            validator: _validatePassword,
            onFieldSubmitted: (_) => _confirmPasswordFocusNode.requestFocus(),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: isDark ? Colors.white54 : AppColors.textSecondary,
                size: 20,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Confirm Password
          _buildLabel('Confirm password', isDark),
          const SizedBox(height: 8),
          _buildInputField(
            controller: _confirmPasswordController,
            focusNode: _confirmPasswordFocusNode,
            isFocused: _isConfirmPasswordFocused,
            isDark: isDark,
            hintText: 'Re-enter password',
            prefixIcon: Icons.lock_outline,
            obscureText: _obscureConfirmPassword,
            validator: _validateConfirmPassword,
            onFieldSubmitted: (_) => _referralFocusNode.requestFocus(),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: isDark ? Colors.white54 : AppColors.textSecondary,
                size: 20,
              ),
              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Referral Code (Optional)
          Row(
            children: [
              _buildLabel('Referral Code', isDark),
              const SizedBox(width: 6),
              Text(
                '(Optional)',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildInputField(
            controller: _referralCodeController,
            focusNode: _referralFocusNode,
            isFocused: _isReferralFocused,
            isDark: isDark,
            hintText: 'e.g. AGR1X2Y3',
            prefixIcon: Icons.card_giftcard,
            textCapitalization: TextCapitalization.characters,
            onFieldSubmitted: (_) => _handleSignup(),
          ),
          
          const SizedBox(height: 24),
          
          // Error message
          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: AppColors.error, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppColors.error, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

          // Sign Up Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleSignup,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Create Account',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
            ),
          ),
          
          const SizedBox(height: 28),
          
          // Security badge
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 14, color: isDark ? Colors.white38 : AppColors.textTertiary),
                const SizedBox(width: 6),
                Text(
                  'Your data is encrypted and secure',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : AppColors.textTertiary),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Terms
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              children: [
                Text(
                  'By creating an account, you agree to our ',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : AppColors.textTertiary),
                ),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/terms'),
                  child: Text(
                    'Terms',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : AppColors.primary, fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  ' and ',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : AppColors.textTertiary),
                ),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/privacy-policy'),
                  child: Text(
                    'Privacy Policy',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : AppColors.primary, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : AppColors.textPrimary,
      ),
    );
  }

  Widget _buildPhoneField(bool isDark) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isPhoneFocused
              ? AppColors.primary
              : (isDark ? Colors.white24 : const Color(0xFFE0E0E0)),
          width: _isPhoneFocused ? 2 : 1,
        ),
        color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFFAFAFA),
        boxShadow: _isPhoneFocused
            ? [BoxShadow(color: AppColors.primary.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))]
            : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '🇮🇳',
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 6),
                Text(
                  '+91',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 30,
            color: isDark ? Colors.white24 : const Color(0xFFE0E0E0),
          ),
          Expanded(
            child: TextFormField(
              controller: _phoneController,
              focusNode: _phoneFocusNode,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              style: TextStyle(fontSize: 15, color: isDark ? Colors.white : AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: '9876543210',
                hintStyle: TextStyle(color: isDark ? Colors.white38 : AppColors.textHint),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              ),
              validator: _validatePhone,
              onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool isFocused,
    required bool isDark,
    required String hintText,
    required IconData prefixIcon,
    TextInputType? keyboardType,
    bool obscureText = false,
    bool enabled = true,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
    void Function(String)? onFieldSubmitted,
    Widget? suffixIcon,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFocused
              ? AppColors.primary
              : (isDark ? Colors.white24 : const Color(0xFFE0E0E0)),
          width: isFocused ? 2 : 1,
        ),
        color: enabled 
            ? (isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFFAFAFA))
            : (isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFEEEEEE)),
        boxShadow: isFocused
            ? [BoxShadow(color: AppColors.primary.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))]
            : null,
      ),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        obscureText: obscureText,
        enabled: enabled,
        textCapitalization: textCapitalization,
        style: TextStyle(fontSize: 15, color: isDark ? Colors.white : AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: isDark ? Colors.white38 : AppColors.textHint),
          prefixIcon: Icon(
            prefixIcon,
            color: isFocused ? AppColors.primary : (isDark ? Colors.white54 : AppColors.textSecondary),
            size: 20,
          ),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
        validator: validator,
        onFieldSubmitted: onFieldSubmitted,
      ),
    );
  }
}

class _PatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 20; i++) {
      for (int j = 0; j < 20; j++) {
        canvas.drawCircle(Offset(i * 100.0 + 50, j * 100.0 + 50), 3, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
