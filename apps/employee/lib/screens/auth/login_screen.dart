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
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../providers/auth_provider.dart';
import 'associate_otp_screen.dart';
import 'forgot_password_screen.dart';

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
    // Clear any error from the other path
    context.read<EmployeeAuthProvider>().clearError();
    FocusScope.of(context).unfocus();
    setState(() => _mode = mode);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: SaTokens.pageBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: SaTokens.space24,
              vertical: SaTokens.space32,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App branding
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: SaTokens.primarySubtle,
                        borderRadius: BorderRadius.circular(SaTokens.radiusCard),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(SaTokens.radiusCard),
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 48,
                          height: 48,
                          errorBuilder: (_, __, ___) => const Icon(
                            SaIcons.shoppingBag,
                            size: 32,
                            color: SaTokens.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: SaTokens.space16),
                  Text(
                    'AgriMore',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: SaTokens.space4),
                  Text(
                    'Sales Associate Portal',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: SaTokens.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: SaTokens.space32),

                  // Login Surface Card
                  Container(
                    padding: const EdgeInsets.all(SaTokens.space24),
                    decoration: BoxDecoration(
                      color: SaTokens.surface,
                      borderRadius: BorderRadius.circular(SaTokens.radiusCard),
                      border: Border.all(color: SaTokens.divider),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Sign In',
                          style: textTheme.titleMedium?.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: SaTokens.space4),
                        Text(
                          _mode == _LoginMode.phone
                              ? 'Enter the mobile number registered with your associate account'
                              : 'Enter the email and password provided by your administrator',
                          style: textTheme.bodySmall?.copyWith(
                            color: SaTokens.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: SaTokens.space24),

                        _buildModeToggle(),
                        const SizedBox(height: SaTokens.space24),

                        // Shared error banner
                        Consumer<EmployeeAuthProvider>(
                          builder: (context, auth, _) {
                            if (auth.error == null) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: SaTokens.space16,
                              ),
                              child: SaInfoBanner(
                                title: 'Sign in failed',
                                message: auth.error!,
                                variant: SaBannerVariant.error,
                              ),
                            );
                          },
                        ),

                        if (_mode == _LoginMode.phone)
                          _buildPhoneForm()
                        else
                          _buildEmailForm(),
                      ],
                    ),
                  ),

                  const SizedBox(height: SaTokens.space32),

                  // Footer info
                  Text(
                    'New associate? Apply for an account from the\nAgriMore customer app under Profile.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: SaTokens.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: SaTokens.pageBackground,
        borderRadius: BorderRadius.circular(SaTokens.radiusInput),
        border: Border.all(color: SaTokens.divider),
      ),
      child: Row(
        children: [
          _buildModeTab(
            label: 'Mobile number',
            mode: _LoginMode.phone,
            icon: SaIcons.phone,
          ),
          _buildModeTab(
            label: 'Email',
            mode: _LoginMode.email,
            icon: SaIcons.mail,
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab({
    required String label,
    required _LoginMode mode,
    required IconData icon,
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
            color: selected ? SaTokens.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(SaTokens.radiusInput - 3),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? SaTokens.primary : SaTokens.textSecondary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: SaTokens.fsLabel,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? SaTokens.primary : SaTokens.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================
  // PHONE + OTP
  // ============================================

  Widget _buildPhoneForm() {
    return Form(
      key: _phoneFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Mobile number',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: SaTokens.space4),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleSendOtp(),
            decoration: const InputDecoration(
              hintText: '98765 43210',
              counterText: '',
              prefixIcon: Icon(SaIcons.phone),
              prefixText: '+91 ',
            ),
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
          const SizedBox(height: SaTokens.space24),
          SaLoadingButton(
            text: 'Send code',
            isLoading: _isSendingOtp,
            onPressed: _handleSendOtp,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Failed to send OTP. Please try again.'),
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

  Widget _buildEmailForm() {
    final auth = context.watch<EmployeeAuthProvider>();

    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Email address',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: SaTokens.space4),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'name@agrimore.in',
              prefixIcon: Icon(SaIcons.mail),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email';
              }
              if (!value.contains('@')) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: SaTokens.space16),
          Text(
            'Password',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: SaTokens.space4),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleLogin(),
            decoration: InputDecoration(
              hintText: 'Enter your password',
              prefixIcon: const Icon(SaIcons.lockKeyhole),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? SaIcons.eyeOff : SaIcons.eye,
                  size: 20,
                  color: SaTokens.textSecondary,
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              return null;
            },
          ),
          const SizedBox(height: SaTokens.space8),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: auth.isLoading
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ForgotPasswordScreen(),
                        ),
                      );
                    },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Forgot password?',
                  style: TextStyle(
                    fontSize: SaTokens.fsCaption,
                    fontWeight: FontWeight.w600,
                    color: auth.isLoading
                        ? SaTokens.disabledContent
                        : SaTokens.primary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: SaTokens.space24),
          SaLoadingButton(
            text: 'Sign In',
            isLoading: auth.isLoading,
            onPressed: _handleLogin,
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
}
