import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../providers/auth_provider.dart' as app_auth;
import '../../../providers/theme_provider.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({Key? key}) : super(key: key);

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  // Password strength indicator
  double _passwordStrength = 0;
  String _strengthLabel = '';
  Color _strengthColor = Colors.grey;

  // --- Animation ---
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // --- Toast ---
  bool _showToast = false;
  String _toastMessage = '';
  IconData _toastIcon = Icons.check_circle;
  Color _toastColor = const Color(0xFF2D7D3C);
  Timer? _toastTimer;
  late AnimationController _toastAnimationController;
  late Animation<Offset> _toastSlideAnimation;
  late Animation<double> _toastFadeAnimation;
  late Animation<double> _toastScaleAnimation;
  // --- End Toast ---

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    // --- Toast Animations ---
    _toastAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _toastSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _toastAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _toastFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _toastAnimationController, curve: Curves.easeOut),
    );

    _toastScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _toastAnimationController, curve: Curves.elasticOut),
    );
    // --- End Toast Animations ---

    _animationController.forward();
    _newPasswordController.addListener(_updatePasswordStrength);
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    _toastAnimationController.dispose();
    _toastTimer?.cancel();
    super.dispose();
  }

  void _updatePasswordStrength() {
    final password = _newPasswordController.text;
    double strength = 0;
    String label = '';
    Color color = Colors.grey;

    if (password.isEmpty) {
      strength = 0;
      label = '';
    } else if (password.length < 6) {
      strength = 1 / 5;
      label = 'Weak';
      color = Colors.red;
    } else {
      strength = 2 / 5;
      label = 'Fair';
      color = Colors.orange;

      if (password.length >= 8) {
        strength = 3 / 5;
        label = 'Good';
        color = Colors.yellow.shade700;
      }
      
      bool hasUpper = password.contains(RegExp(r'[A-Z]'));
      bool hasLower = password.contains(RegExp(r'[a-z]'));
      bool hasDigit = password.contains(RegExp(r'[0-9]'));
      bool hasSpecial = password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));

      if (password.length >= 8 && hasUpper && hasLower && hasDigit) {
        strength = 4 / 5;
        label = 'Strong';
        color = AppColors.primary;
      }
      
      if (password.length >= 10 && hasUpper && hasLower && hasDigit && hasSpecial) {
        strength = 5 / 5;
        label = 'Very Strong';
        color = const Color(0xFF2D7D3C);
      }
    }

    setState(() {
      _passwordStrength = strength;
      _strengthLabel = label;
      _strengthColor = color;
    });
  }

  void _showToastMessage(String message, {bool isSuccess = true}) {
    if (!mounted) return;
    _toastTimer?.cancel();

    setState(() {
      _toastMessage = message;
      _toastIcon = isSuccess ? Icons.check_circle_rounded : Icons.error_rounded;
      _toastColor = isSuccess ? const Color(0xFF2D7D3C) : Colors.red;
      _showToast = true;
    });

    _toastAnimationController.forward();

    _toastTimer = Timer(const Duration(milliseconds: 2800), () {
      if (mounted) {
        _toastAnimationController.reverse().then((_) {
          if (mounted) setState(() => _showToast = false);
        });
      }
    });
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  String? _validateNewPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter new password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    if (value == _currentPasswordController.text) {
      return 'New password cannot be same as current password';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm password';
    }
    if (value != _newPasswordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) {
      _showToastMessage('⚠️ Please fix the errors in the form', isSuccess: false);
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      final authProvider =
          Provider.of<app_auth.AuthProvider>(context, listen: false);

      debugPrint('🔐 Changing password...');

      final success = await authProvider.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      if (!mounted) return;

      if (success) {
        _showToastMessage('✅ Password changed successfully!');

        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();

        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      } else {
        _showToastMessage(
          '❌ ${authProvider.error ?? 'Failed to change password'}', isSuccess: false
        );
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('❌ Error: $e');
      if (mounted) {
        _showToastMessage('❌ Error: ${e.toString()}', isSuccess: false);
        setState(() => _isLoading = false);
      }
    }
  }

  // --- New Widgets matching Profile/Edit Screen ---

  Widget _buildCompactHeader(bool isDark) {
    final double topPadding = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 16 + topPadding, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1E1E1E),
                  const Color(0xFF2D3A2D),
                  const Color(0xFF3A4D3A),
                ]
              : [
                  const Color(0xFF2D7D3C),
                  const Color(0xFF3DA34E),
                  const Color(0xFF4DB85F),
                ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (!_isLoading) {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Change Password',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordFormCard({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool obscure,
    required VoidCallback onObscureToggle,
    String? Function(String?)? validator,
    required bool isDark,
  }) {
    final tileColor = isDark ? AppColors.primaryLight : const Color(0xFF2D7D3C);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8), // Note right padding
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: tileColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: tileColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: TextFormField(
                controller: controller,
                obscureText: obscure,
                validator: validator,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  labelText: label,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  errorStyle: const TextStyle(height: 0.1, fontSize: 10),
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
                size: 20,
              ),
              onPressed: onObscureToggle,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordStrengthIndicator({required bool isDark}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Password Strength',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              Text(
                _strengthLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _strengthColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _passwordStrength,
              backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
              color: _strengthColor,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  // --- End New Widgets ---

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50],
      body: Stack(
        children: [
          FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildCompactHeader(isDark)),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 10),
                            Text(
                              'Update Your Password',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.grey[400] : Colors.grey[700],
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildPasswordFormCard(
                              controller: _currentPasswordController,
                              label: 'Current Password',
                              icon: Icons.lock_open_rounded,
                              obscure: _obscureCurrentPassword,
                              onObscureToggle: () {
                                setState(() =>
                                    _obscureCurrentPassword = !_obscureCurrentPassword);
                              },
                              validator: _validatePassword,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Set New Password',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.grey[400] : Colors.grey[700],
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildPasswordFormCard(
                              controller: _newPasswordController,
                              label: 'New Password',
                              icon: Icons.lock_outline_rounded,
                              obscure: _obscureNewPassword,
                              onObscureToggle: () {
                                setState(() =>
                                    _obscureNewPassword = !_obscureNewPassword);
                              },
                              validator: _validateNewPassword,
                              isDark: isDark,
                            ),

                            // Show strength indicator only when typing
                            if (_newPasswordController.text.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: _buildPasswordStrengthIndicator(isDark: isDark),
                              ),

                            _buildPasswordFormCard(
                              controller: _confirmPasswordController,
                              label: 'Confirm New Password',
                              icon: Icons.check_circle_outline_rounded,
                              obscure: _obscureConfirmPassword,
                              onObscureToggle: () {
                                setState(() =>
                                    _obscureConfirmPassword = !_obscureConfirmPassword);
                              },
                              validator: _validateConfirmPassword,
                              isDark: isDark,
                            ),
                            
                            const SizedBox(height: 24),

                            // Save Button
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    (isDark ? AppColors.primaryLight : const Color(0xFF2D7D3C)).withOpacity(_isLoading ? 0.7 : 1.0),
                                    (isDark ? AppColors.primaryLight : const Color(0xFF2D7D3C)).withOpacity(_isLoading ? 0.5 : 0.8),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: (isDark ? AppColors.primaryLight : const Color(0xFF2D7D3C)).withOpacity(0.25),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _isLoading ? null : _changePassword,
                                  borderRadius: BorderRadius.circular(14),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        if (_isLoading)
                                          const SizedBox(
                                            width: 18, 
                                            height: 18, 
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                                          )
                                        else
                                          const Icon(Icons.lock_reset_rounded, color: Colors.white, size: 18),
                                        
                                        const SizedBox(width: 10),
                                        
                                        Text(
                                          _isLoading ? 'Changing...' : 'Change Password',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Enhanced Toast (from Profile Screen)
          if (_showToast)
            SafeArea(
              bottom: false,
              child: SlideTransition(
                position: _toastSlideAnimation,
                child: FadeTransition(
                  opacity: _toastFadeAnimation,
                  child: ScaleTransition(
                    scale: _toastScaleAnimation,
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_toastColor, _toastColor.withOpacity(0.9)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: _toastColor.withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(_toastIcon, color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _toastMessage,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}