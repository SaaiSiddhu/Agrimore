// ============================================================
//  AGRIMORE - LOGIN SCREEN (Professional Email/Password Login)
// ============================================================

import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_services/agrimore_services.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {

  // Platform detection for web keyboard fix
  bool get isWebMobile => kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
       defaultTargetPlatform == TargetPlatform.android);

  bool _isKeyboardVisible = false;
  Key _contentKey = UniqueKey();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  bool _isEmailFocused = false;
  bool _isPasswordFocused = false;
  
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    if (isWebMobile) {
      WidgetsBinding.instance.addObserver(this);
    }

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );

    _emailFocusNode.addListener(() {
      setState(() => _isEmailFocused = _emailFocusNode.hasFocus);
    });

    _passwordFocusNode.addListener(() {
      setState(() => _isPasswordFocused = _passwordFocusNode.hasFocus);
    });

    _fadeController.forward();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (isWebMobile) {
      final bottomInset = View.of(context).viewInsets.bottom;
      final newKeyboardState = bottomInset > 0;

      if (_isKeyboardVisible && !newKeyboardState) {
        _isKeyboardVisible = false;
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) {
            setState(() {
              _contentKey = UniqueKey();
            });
          }
        });
      } else if (!_isKeyboardVisible && newKeyboardState) {
        _isKeyboardVisible = true;
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    if (isWebMobile) {
      WidgetsBinding.instance.removeObserver(this);
    }
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _fadeController.dispose();
    super.dispose();
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

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('🔐 Attempting login for: ${_emailController.text.trim()}');
      
      final authService = AuthService();
      await authService.signInWithEmail(
        email: _emailController.text.trim().toLowerCase(),
        password: _passwordController.text,
      );
      
      debugPrint('✅ Login successful, navigating to /home');
      
      if (mounted) {
        // Use post-frame callback to ensure navigation happens after current build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            // ✅ Navigate to main screen and clear the entire navigation stack
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/main',
              (route) => false,
            );
          }
        });
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ FirebaseAuthException: ${e.message}');
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      debugPrint('❌ Login error: $e');
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = AuthService();
      final userExists = await authService.signInWithGoogle();
      
      // Check if user profile is complete
      if (userExists.name.isEmpty || userExists.phone == null || userExists.phone!.isEmpty) {
        // Redirect to complete profile
        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            '/complete-profile',
            arguments: {'email': userExists.email},
          );
        }
      } else {
        if (mounted) {
          // ✅ Navigate to main screen and clear the entire navigation stack
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/main',
            (route) => false,
          );
        }
      }
    } on AuthException catch (e) {
      // Check if it's an unregistered user
      if (e.message.contains('not found') || e.message.contains('not registered')) {
        // Sign out and redirect to signup
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          final email = FirebaseAuth.instance.currentUser?.email;
          Navigator.pushReplacementNamed(
            context,
            '/signup',
            arguments: {'email': email, 'fromGoogle': true},
          );
        }
      } else {
        setState(() {
          _errorMessage = e.message;
        });
      }
    } catch (e) {
      // Handle unregistered Google user
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final email = currentUser.email;
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            '/signup',
            arguments: {'email': email, 'fromGoogle': true},
          );
        }
        return;
      }
      
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email address first';
      });
      return;
    }

    try {
      final authService = AuthService();
      await authService.sendPasswordResetEmail(email);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password reset email sent to $email'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 900;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: isDark ? AppColors.authBackgroundDark : AppColors.authBackgroundLight,
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
        gradient: AppColors.authBrandingGradient,
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
                    'India\'s Largest\nAgricultural\nMarketplace',
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
                    'Connect with verified sellers, discover quality products,\nand grow your agricultural business.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.85),
                      height: 1.6,
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  Row(
                    children: [
                      _buildTrustBadge(Icons.verified_user_rounded, 'Verified\nSellers'),
                      const SizedBox(width: 24),
                      _buildTrustBadge(Icons.people_rounded, '10,000+\nUsers'),
                      const SizedBox(width: 24),
                      _buildTrustBadge(Icons.shield_rounded, 'Secure\nPayments'),
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
      color: isDark ? AppColors.authFormPanelDark : Colors.white,
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
    final viewInsets = MediaQuery.of(context).viewInsets;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    // Use Stack: fixed gradient background + scrollable content on top
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Stack(
        key: _contentKey,
        children: [
          // Fixed gradient background that never moves
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: isDark
                    ? AppColors.authMobileGradientDark
                    : AppColors.authMobileGradientLight,
              ),
            ),
          ),
          // Scrollable content with proper padding
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: ListView(
                physics: const ClampingScrollPhysics(),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 20,
                  bottom: _isKeyboardVisible ? viewInsets.bottom + 20 : bottomPadding + 40,
                ),
                children: [
                  const SizedBox(height: 20),
                  _buildMobileLogo(isDark),
                  const SizedBox(height: 32),
                  _buildFormContent(isDark),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLogo(bool isDark) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.2),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/icons/logo_icon.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
                ),
                child: const Center(child: Text('🌱', style: TextStyle(fontSize: 36))),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Agrimore',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Agricultural Marketplace',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white60 : AppColors.textSecondary,
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
            'Sign in to your account',
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
                'New to Agrimore? ',
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white60 : AppColors.textSecondary,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/signup'),
                child: Text(
                  'Create an account',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 36),
          
          // Email Label
          Text(
            'Email address',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          
          // Email Input
          _buildInputField(
            controller: _emailController,
            focusNode: _emailFocusNode,
            isFocused: _isEmailFocused,
            isDark: isDark,
            hintText: 'you@example.com',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: _validateEmail,
            onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
          ),
          
          const SizedBox(height: 20),
          
          // Password Label with Forgot Password
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Password',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: _handleForgotPassword,
                child: Text(
                  'Forgot password?',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Password Input
          _buildInputField(
            controller: _passwordController,
            focusNode: _passwordFocusNode,
            isFocused: _isPasswordFocused,
            isDark: isDark,
            hintText: '••••••••',
            prefixIcon: Icons.lock_outline,
            obscureText: _obscurePassword,
            validator: _validatePassword,
            onFieldSubmitted: (_) => _handleLogin(),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: isDark ? Colors.white54 : AppColors.textSecondary,
                size: 20,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
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

          // Sign In Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
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
                          'Sign In',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
            ),
          ),
          
          const SizedBox(height: 28),
          
          // Divider
          Row(
            children: [
              Expanded(child: Divider(color: isDark ? Colors.white24 : Colors.grey.shade300)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'or continue with',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : AppColors.textSecondary,
                  ),
                ),
              ),
              Expanded(child: Divider(color: isDark ? Colors.white24 : Colors.grey.shade300)),
            ],
          ),
          
          const SizedBox(height: 28),
          
          // Google Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: (_isLoading || _isGoogleLoading) ? null : _handleGoogleSignIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isGoogleLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/icons/google.png',
                          width: 20,
                          height: 20,
                          errorBuilder: (_, __, ___) => Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Center(
                              child: Text('G', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Continue with Google',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          
          const SizedBox(height: 36),
          
          // Security badge
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 14, color: isDark ? Colors.white38 : AppColors.textTertiary),
                const SizedBox(width: 6),
                Text(
                  'Secured with 256-bit SSL encryption',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : AppColors.textTertiary),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Terms
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              children: [
                Text(
                  'By signing in, you agree to our ',
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

  Widget _buildInputField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool isFocused,
    required bool isDark,
    required String hintText,
    required IconData prefixIcon,
    TextInputType? keyboardType,
    bool obscureText = false,
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
        color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFFAFAFA),
        boxShadow: isFocused
            ? [BoxShadow(color: AppColors.primary.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))]
            : null,
      ),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        obscureText: obscureText,
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
