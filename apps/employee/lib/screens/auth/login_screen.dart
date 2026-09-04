// lib/screens/auth/login_screen.dart
//
// Phase 18, Workstream 2 — two sign-in paths, because Agrimore has two
// genuinely different associate populations and neither can use the other's
// credentials:
//
//   • SELF-APPLIED associates signed up in apps/marketplace by phone OTP, so
//     verifyPhoneOTP.ts created their Auth record with `phoneNumber` only —
//     no email, no password. Before this phase they could not sign in here at
//     all: this screen asked for an email and password they had never had.
//     They are the associates who pay the ₹500 onboarding fee, so they are
//     also the ones for whom being locked out mattered most.
//
//   • ADMIN-CREATED associates were made by createEmployeeByAdmin.ts, which
//     does mint a real email/password credential. They are the only people
//     who could sign in before this phase, so email/password is RETAINED —
//     removing it to make phone OTP "the" path would have locked out
//     everyone who can currently get in.
//
// Phone is presented first because self-apply is the volume path.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'associate_otp_screen.dart';

enum _LoginMode { phone, email }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _phoneFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSendingOtp = false;
  _LoginMode _mode = _LoginMode.phone;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _switchMode(_LoginMode mode) {
    if (_mode == mode) return;
    // Clear any error from the other path — leaving "wrong password" visible
    // above a mobile-number field would be nonsense.
    context.read<EmployeeAuthProvider>().clearError();
    FocusScope.of(context).unfocus();
    setState(() => _mode = mode);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary,
              colorScheme.primary.withValues(alpha: 0.8),
              colorScheme.primaryContainer,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),

                // Logo & Title
                Image.asset(
                  'assets/images/logo.png',
                  width: 80,
                  height: 80,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Agrimore',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                ),
                Text(
                  'Sales Associate',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),

                const SizedBox(height: 40),

                // Login Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Sign In',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _mode == _LoginMode.phone
                            ? 'Use the mobile number registered with your associate account'
                            : 'Enter the email and password your administrator gave you',
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),

                      _buildModeToggle(colorScheme),
                      const SizedBox(height: 20),

                      // Shared error banner — both paths report through the
                      // provider's single `error`.
                      Consumer<EmployeeAuthProvider>(
                        builder: (context, auth, _) {
                          if (auth.error == null) {
                            return const SizedBox.shrink();
                          }
                          return Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.error_outline,
                                    color: Colors.red, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    auth.error!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      if (_mode == _LoginMode.phone)
                        _buildPhoneForm(colorScheme)
                      else
                        _buildEmailForm(colorScheme),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Self-apply happens in the Agrimore customer app, not here.
                Text(
                  'New associate? Apply for an account from the\nAgrimore customer app under Profile.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeToggle(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildModeTab(
            colorScheme,
            label: 'Mobile number',
            mode: _LoginMode.phone,
          ),
          _buildModeTab(
            colorScheme,
            label: 'Email',
            mode: _LoginMode.email,
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab(
    ColorScheme colorScheme, {
    required String label,
    required _LoginMode mode,
  }) {
    final selected = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchMode(mode),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color:
                  selected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================
  // PHONE + OTP
  // ============================================

  Widget _buildPhoneForm(ColorScheme colorScheme) {
    return Form(
      key: _phoneFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Mobile number',
              counterText: '',
              prefixIcon: const Icon(Icons.phone_outlined),
              prefixText: '+91 ',
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            // Mirrors apps/marketplace's _validatePhone exactly, so the two
            // apps accept precisely the same set of numbers.
            validator: (value) {
              final v = value?.trim() ?? '';
              if (v.isEmpty) return 'Enter your mobile number';
              if (v.length != 10) {
                return 'Enter a valid 10-digit mobile number';
              }
              if (!RegExp(r'^[6-9]\d{9}$').hasMatch(v)) {
                return 'Enter a valid Indian mobile number';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _isSendingOtp ? null : _handleSendOtp,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSendingOtp
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Send code',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSendOtp() async {
    if (!_phoneFormKey.currentState!.validate()) return;

    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();

    final phone = '+91${_phoneController.text.trim()}';
    final auth = context.read<EmployeeAuthProvider>();
    auth.clearError();

    setState(() => _isSendingOtp = true);
    final result = await auth.sendPhoneOtp(phone);

    if (!mounted) return;
    setState(() => _isSendingOtp = false);

    if (result == null) {
      // auth.error is already set and rendered by the banner above; a
      // SnackBar as well makes the failure impossible to miss.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(auth.error ?? 'Failed to send OTP. Please try again.'),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            AssociateOtpScreen(phone: phone, channel: result.channel),
      ),
    );
  }

  // ============================================
  // EMAIL + PASSWORD
  // ============================================

  Widget _buildEmailForm(ColorScheme colorScheme) {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email',
              prefixIcon: const Icon(Icons.email_outlined),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              if (!value.contains('@')) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          // Phase 21, Workstream 3: only reachable on this tab. A
          // self-applied associate signs in by phone OTP and has never had
          // a password to forget — this deliberately has no phone-tab
          // equivalent. Own Consumer (not the button's) so it shares the
          // exact same auth.isLoading guard the Sign In button already
          // uses, rather than a second, separate loading flag.
          Consumer<EmployeeAuthProvider>(
            builder: (context, auth, _) {
              return Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: auth.isLoading ? null : _handleForgotPassword,
                  child: Text(
                    'Forgot password?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: auth.isLoading
                          ? colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                          : colorScheme.primary,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Consumer<EmployeeAuthProvider>(
            builder: (context, auth, _) {
              return FilledButton(
                onPressed: auth.isLoading ? null : _handleLogin,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: auth.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Sign In',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _handleLogin() async {
    if (_emailFormKey.currentState!.validate()) {
      HapticFeedback.lightImpact();
      final auth = context.read<EmployeeAuthProvider>();
      auth.clearError();
      await auth.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email first')),
      );
      return;
    }

    HapticFeedback.lightImpact();
    final auth = context.read<EmployeeAuthProvider>();
    auth.clearError();
    final sent = await auth.sendPasswordReset(email);

    if (!mounted) return;

    if (sent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset link sent to $email')),
      );
    } else {
      // auth.error is already set and rendered by the banner above; a
      // SnackBar as well makes the failure impossible to miss.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              auth.error ?? 'Failed to send reset email. Please try again.'),
        ),
      );
    }
  }
}
