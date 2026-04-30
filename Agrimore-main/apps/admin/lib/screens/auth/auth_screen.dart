// ============================================================
//  AGRIMORE ADMIN - LOGIN SCREEN (Matching Marketplace Design)
// ============================================================

import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:go_router/go_router.dart';
import '../../app/app_router.dart';
import '../../providers/auth_provider.dart';
import 'package:agrimore_core/agrimore_core.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
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
  bool _obscurePassword = true;
  String? _errorMessage;
  bool _isEmailFocused = false;
  bool _isPasswordFocused = false;
  bool _rememberMe = false;
  SharedPreferences? _prefs;

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
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _prefs = p;
        _rememberMe = p.getBool(StorageConstants.keyRememberMe) ?? false;
        final savedEmail = p.getString(StorageConstants.keyRememberEmail);
        if (savedEmail != null) _emailController.text = savedEmail;
      });
    } catch (e) {
      debugPrint('SharedPreferences error: $e');
    }
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

    final auth = context.read<AuthProvider>();
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();
    
    try {
      bool userExists = await auth.checkUserExists(email);
      bool ok = false;
      bool isNewUser = false;

      if (!userExists) {
        // Register user if they don't exist
        ok = await auth.registerWithEmail(
          email: email, 
          password: password, 
          name: 'New Seller'
        );
        isNewUser = true;
      } else {
        ok = await auth.signInWithEmail(
          email: email,
          password: password,
        );
      }

      if (!mounted) return;

      if (ok) {
        // Save remember me
        if (_rememberMe && _prefs != null) {
          await _prefs!.setBool(StorageConstants.keyRememberMe, true);
          await _prefs!.setString(StorageConstants.keyRememberEmail, email);
        }

        HapticFeedback.heavyImpact();
        
        if (auth.isAdmin) {
          SnackbarHelper.showSuccess(context, '✅ Welcome back, Admin!');
          await Future.delayed(const Duration(milliseconds: 600));
          if (mounted) context.go(AdminRoutes.dashboard);
        } else {
          SnackbarHelper.showSuccess(context, '✅ Welcome!');
          await Future.delayed(const Duration(milliseconds: 600));
          if (!mounted) return;
          if (isNewUser || !auth.isSeller) {
             context.go(AdminRoutes.sellerApply);
          } else {
             context.go(AdminRoutes.sellerPanel);
          }
        }
      } else {
        HapticFeedback.vibrate();
        setState(() {
          _errorMessage = auth.error ?? 'Authentication failed';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
      final auth = context.read<AuthProvider>();
      final ok = await auth.sendPasswordResetEmail(email);
      if (mounted) {
        if (ok) {
          SnackbarHelper.showSuccess(context, '✉️ Reset link sent to $email');
        } else {
          setState(() => _errorMessage = auth.error ?? 'Failed to send reset email');
        }
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
      backgroundColor: isDark ? const Color(0xFF1B2A3A) : const Color(0xFFE3F2FD),
      body: Consumer<AuthProvider>(
        builder: (_, auth, __) {
          return Stack(
            children: [
              isDesktop
                  ? Row(
                      children: [
                        Expanded(flex: 5, child: _buildBrandingPanel(isDark)),
                        Expanded(flex: 4, child: _buildFormPanel(isDark)),
                      ],
                    )
                  : _buildMobileLayout(isDark),
              if (auth.isLoading)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBrandingPanel(bool isDark) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1565C0), Color(0xFF1976D2), Color(0xFF2196F3)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _PatternPainter())),
          
          // Floating icons
          Positioned(top: 80, right: 60, child: _buildFloatingIcon('🛡️', 48)),
          Positioned(top: 200, left: 40, child: _buildFloatingIcon('⚙️', 40)),
          Positioned(bottom: 180, right: 80, child: _buildFloatingIcon('📊', 44)),
          Positioned(bottom: 100, left: 60, child: _buildFloatingIcon('👨‍💼', 36)),
          
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
                            'assets/icons/app_icon.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Text('🛡️', style: TextStyle(fontSize: 28)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Agrimore',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'Admin Panel',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  const Spacer(),
                  
                  const Text(
                    'Admin\nControl\nCenter',
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
                    'Manage products, users, orders, and analytics\nfrom a single powerful dashboard.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.85),
                      height: 1.6,
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  Row(
                    children: [
                      _buildTrustBadge(Icons.admin_panel_settings_rounded, 'Full\nAccess'),
                      const SizedBox(width: 24),
                      _buildTrustBadge(Icons.analytics_rounded, 'Real-time\nAnalytics'),
                      const SizedBox(width: 24),
                      _buildTrustBadge(Icons.security_rounded, 'Secure\nAccess'),
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
    final viewInsets = MediaQuery.of(context).viewInsets;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Stack(
        key: _contentKey,
        children: [
          // Fixed gradient background
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [const Color(0xFF1B2A3A), const Color(0xFF0F0F0F)]
                      : [const Color(0xFFE3F2FD), Colors.white],
                ),
              ),
            ),
          ),
          // Scrollable content
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
                color: const Color(0xFF1976D2).withOpacity(0.2),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/icons/app_icon.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF2196F3)]),
                ),
                child: const Center(child: Text('🛡️', style: TextStyle(fontSize: 36))),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Agrimore Admin',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Control Panel',
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
          // Admin Badge
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.admin_panel_settings_rounded, size: 16, color: Colors.red.shade700),
                  const SizedBox(width: 6),
                  Text(
                    'ADMIN ACCESS ONLY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.red.shade700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Header
          Center(
            child: Text(
              'Sign in to Admin Panel',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Enter your credentials to access the dashboard',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white60 : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (AdminAccessConfig.bootstrapAdminEmailsLower.isNotEmpty) ...[
            const SizedBox(height: 10),
            Center(
              child: Text(
                'Bootstrap admin emails (build-time): ${AdminAccessConfig.bootstrapAdminEmailsLower.join(", ")}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : AppColors.textSecondary,
                ),
              ),
            ),
          ],
          
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
            hintText: 'admin@agrimore.com',
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
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1976D2),
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
          
          const SizedBox(height: 16),
          
          // Remember me
          Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _rememberMe,
                  onChanged: (_) => setState(() => _rememberMe = !_rememberMe),
                  activeColor: const Color(0xFF1976D2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Remember me',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : AppColors.textSecondary,
                ),
              ),
            ],
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
                  const Icon(Icons.error_outline, color: AppColors.error, size: 20),
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
                backgroundColor: const Color(0xFF1976D2),
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
                          'Sign In to Dashboard',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Or Divider
          Row(
            children: [
              Expanded(child: Divider(color: isDark ? Colors.white24 : AppColors.divider)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'OR',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white54 : AppColors.textSecondary,
                  ),
                ),
              ),
              Expanded(child: Divider(color: isDark ? Colors.white24 : AppColors.divider)),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Google Sign In Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: _isLoading ? null : () async {
                setState(() => _isLoading = true);
                final auth = context.read<AuthProvider>();
                final success = await auth.signInWithGoogle();
                
                if (!mounted) return;
                
                if (success) {
                  HapticFeedback.heavyImpact();
                  if (auth.isAdmin) {
                    SnackbarHelper.showSuccess(context, '✅ Welcome back, Admin!');
                    await Future.delayed(const Duration(milliseconds: 600));
                    if (mounted) context.go(AdminRoutes.dashboard);
                  } else {
                    SnackbarHelper.showSuccess(context, '✅ Welcome!');
                    await Future.delayed(const Duration(milliseconds: 600));
                    if (!mounted) return;
                    if (!auth.isSeller) {
                       context.go(AdminRoutes.sellerApply);
                    } else {
                       context.go(AdminRoutes.sellerPanel);
                    }
                  }
                } else {
                  setState(() {
                    _errorMessage = auth.error ?? 'Google Sign-In failed';
                    _isLoading = false;
                  });
                }
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: isDark ? Colors.white24 : AppColors.divider),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Google G logo (simple version since we don't have SVG handy, or we can use Image.asset if available)
                        // Using a simple styled text for G if no asset
                        Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text(
                              'G',
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Continue with Google',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : AppColors.textPrimary,
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
          
          const SizedBox(height: 16),
          
          // Admin notice
          Center(
            child: Text(
              'Only authorized administrators can access this panel.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
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
              ? const Color(0xFF1976D2)
              : (isDark ? Colors.white24 : const Color(0xFFE0E0E0)),
          width: isFocused ? 2 : 1,
        ),
        color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFFAFAFA),
        boxShadow: isFocused
            ? [BoxShadow(color: const Color(0xFF1976D2).withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))]
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
            color: isFocused ? const Color(0xFF1976D2) : (isDark ? Colors.white54 : AppColors.textSecondary),
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