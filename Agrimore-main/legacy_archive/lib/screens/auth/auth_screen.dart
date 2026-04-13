// lib/screens/auth/auth_screen.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../app/themes/app_colors.dart';
import '../../app/themes/app_text_styles.dart';
import '../../app/routes.dart';
import '../../providers/auth_provider.dart';
import '../../core/utils/validators.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/constants/storage_constants.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/loading_overlay.dart';
import '../../helpers/ad_helper.dart';

enum AuthStep { email, login, register }

class _Debouncer {
  _Debouncer(this.duration);
  final Duration duration;
  Timer? _t;

  void run(void Function() action) {
    _t?.cancel();
    _t = Timer(duration, action);
  }

  void dispose() => _t?.cancel();
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // Controllers
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Focus nodes
  final _pwdFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _nameFocus = FocusNode();
  final _phoneFocus = FocusNode();

  // Animation controllers
  late AnimationController _fadeCtrl;
  late AnimationController _slideCtrl;

  // State
  AuthStep _step = AuthStep.email;
  bool _obscure = true;
  bool _acceptTerms = false;
  bool _rememberMe = false;
  SharedPreferences? _prefs;
  bool _prefsReady = false;
  List<String> _emailSuggestions = [];
  bool _showSuggestions = false;
  double _passwordStrength = 0.0;
  String _phoneCountry = '+91';
  bool _phoneValid = false;
  bool _isKeyboardVisible = false;
  double _formProgress = 0.0;

  // AdMob
  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;

  final _continueDebouncer = _Debouncer(const Duration(milliseconds: 250));

  static const List<String> _emailDomains = [
    'gmail.com', 'yahoo.com', 'outlook.com', 'hotmail.com',
    'aol.com', 'icloud.com', 'protonmail.com', 'zoho.com',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAnimations();
    _initPrefs();
    _setupListeners();
    if (!kIsWeb) _initializeAdMob();
  }

  void _initializeAnimations() {
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeCtrl.forward();
    _slideCtrl.forward();
  }

  void _setupListeners() {
    _email.addListener(_onEmailChanged);
    _password.addListener(_onPasswordChanged);
    _phone.addListener(_onPhoneChanged);
    _name.addListener(_updateFormProgress);
  }

  void _initializeAdMob() {
    MobileAds.instance.initialize().then((_) {
      if (mounted) _createBannerAd();
    }).catchError((e) => debugPrint('AdMob init error: $e'));
  }

  void _createBannerAd() {
    try {
      _bannerAd = BannerAd(
        adUnitId: AdHelper.bannerAdUnitId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            if (mounted) setState(() => _isBannerAdReady = true);
            debugPrint('✅ Auth Banner Ad Loaded');
          },
          onAdFailedToLoad: (ad, err) {
            ad.dispose();
            if (mounted) setState(() => _isBannerAdReady = false);
            debugPrint('❌ Auth Banner Ad Failed: ${err.message}');
          },
        ),
      )..load();
    } catch (e) {
      debugPrint('Auth Banner Ad Error: $e');
    }
  }

  @override
  void didChangeMetrics() {
    final bottomInset = WidgetsBinding.instance.window.viewInsets.bottom;
    final newKeyboardVisible = bottomInset > 0;
    if (_isKeyboardVisible != newKeyboardVisible) {
      setState(() => _isKeyboardVisible = newKeyboardVisible);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _phone.dispose();
    _pwdFocus.dispose();
    _emailFocus.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    _continueDebouncer.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  void _updateFormProgress() {
    if (_step != AuthStep.register) return;
    int filled = 0;
    if (_email.text.trim().isNotEmpty && Validators.validateEmail(_email.text.trim()) == null) filled++;
    if (_password.text.isNotEmpty && _passwordValidator(_password.text) == null) filled++;
    if (_name.text.trim().isNotEmpty && Validators.validateName(_name.text.trim()) == null) filled++;
    if (_phone.text.trim().isNotEmpty && _phoneValid) filled++;
    setState(() => _formProgress = filled / 4);
  }

  void _onPhoneChanged() {
    final phone = _phone.text.trim();
    final valid = phone.isEmpty ? false : RegExp(r'^[6-9]\d{9}$').hasMatch(phone);
    setState(() => _phoneValid = valid);
    _updateFormProgress();
  }

  void _onPasswordChanged() {
    final pwd = _password.text;
    if (pwd.isEmpty) {
      setState(() => _passwordStrength = 0.0);
      _updateFormProgress();
      return;
    }

    double strength = 0.0;
    strength += pwd.length >= 8 ? 0.2 : 0;
    strength += pwd.length >= 12 ? 0.1 : 0;
    strength += pwd.contains(RegExp(r'[A-Z]')) ? 0.2 : 0;
    strength += pwd.contains(RegExp(r'[a-z]')) ? 0.2 : 0;
    strength += pwd.contains(RegExp(r'\d')) ? 0.2 : 0;
    strength += pwd.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]')) ? 0.1 : 0;

    setState(() => _passwordStrength = strength.clamp(0.0, 1.0));
    _updateFormProgress();
  }

  void _onEmailChanged() {
    final text = _email.text.trim();
    if (!text.contains('@')) {
      setState(() => _showSuggestions = false);
      return;
    }

    final parts = text.split('@');
    if (parts.length != 2) return;

    final suggestions = _emailDomains
        .where((d) => d.startsWith(parts[1].toLowerCase()))
        .map((d) => '${parts[0]}@$d')
        .take(4)
        .toList();

    if (mounted) {
      setState(() {
        _emailSuggestions = suggestions;
        _showSuggestions = suggestions.isNotEmpty;
      });
    }
    _updateFormProgress();
  }

  void _selectEmailSuggestion(String email) {
    HapticFeedback.lightImpact();
    _email.text = email;
    setState(() => _showSuggestions = false);
  }

  Future<void> _initPrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _prefs = p;
        _prefsReady = true;
        _rememberMe = p.getBool(StorageConstants.keyRememberMe) ?? false;
        final savedEmail = p.getString(StorageConstants.keyRememberEmail);
        if (savedEmail != null) _email.text = savedEmail;
      });
    } catch (e) {
      debugPrint('SharedPreferences error: $e');
    }
  }

  Future<void> _handleContinueWithEmail() async {
    HapticFeedback.mediumImpact();
    _continueDebouncer.run(() async {
      final email = _email.text.trim();

      if (email.isEmpty || Validators.validateEmail(email) != null) {
        if (mounted) {
          SnackbarHelper.showError(context, 'Enter a valid email');
        }
        return;
      }

      final auth = context.read<AuthProvider>();
      bool exists = false;

      try {
        exists = await auth.checkUserExists(email);
      } catch (e) {
        if (mounted) {
          SnackbarHelper.showError(context, 'Email verification failed');
        }
        return;
      }

      if (!mounted) return;
      setState(() {
        _step = exists ? AuthStep.login : AuthStep.register;
        _showSuggestions = false;
        _formProgress = 0.25;
      });

      _fadeCtrl.reset();
      _fadeCtrl.forward();
      FocusScope.of(context).requestFocus(_pwdFocus);
    });
  }

  String? _passwordValidator(String? v) {
    if (v == null || v.isEmpty) return 'Password required';
    if (v.length < 8) return 'Minimum 8 characters';
    final hasUpper = v.contains(RegExp(r'[A-Z]'));
    final hasLower = v.contains(RegExp(r'[a-z]'));
    final hasDigit = v.contains(RegExp(r'\d'));
    if (!(hasUpper && hasLower && hasDigit)) {
      return 'Include uppercase, lowercase, numbers';
    }
    return null;
  }

  String? _phoneValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Phone required';
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(v.trim())) {
      return 'Valid 10-digit Indian number';
    }
    return null;
  }

  Future<void> _handleSubmit() async {
    HapticFeedback.mediumImpact();
    if (!_prefsReady) await _initPrefs();
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      return;
    }

    if (_step == AuthStep.register && !_acceptTerms) {
      SnackbarHelper.showError(context, 'Accept Terms & Conditions');
      return;
    }

    final auth = context.read<AuthProvider>();
    final email = _email.text.trim();
    bool ok = false;

    try {
      if (_step == AuthStep.login) {
        ok = await auth.signInWithEmail(email: email, password: _password.text);
      } else {
        ok = await auth.registerWithEmail(
          email: email,
          password: _password.text,
          name: _name.text.trim(),
          phone: '$_phoneCountry${_phone.text.trim()}',
        );
      }
    } catch (e) {
      debugPrint('Auth error: $e');
    }

    if (!mounted) return;

    if (ok) {
      try {
        if (_rememberMe && _prefsReady && _prefs != null) {
          await _prefs!.setBool(StorageConstants.keyRememberMe, true);
          await _prefs!.setString(StorageConstants.keyRememberEmail, email);
        }
      } catch (e) {
        debugPrint('Prefs error: $e');
      }

      HapticFeedback.heavyImpact();
      SnackbarHelper.showSuccess(
        context,
        _step == AuthStep.login ? '✅ Welcome back!' : '🎉 Account created!',
      );

      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) AppRoutes.navigateAndRemoveUntil(context, AppRoutes.main);
    } else {
      HapticFeedback.vibrate();
      SnackbarHelper.showError(context, auth.error ?? 'Authentication failed');
    }
  }

  void _resetAll() {
    HapticFeedback.lightImpact();
    setState(() {
      _step = AuthStep.email;
      _obscure = true;
      _acceptTerms = false;
      _showSuggestions = false;
      _passwordStrength = 0.0;
      _phoneValid = false;
      _formProgress = 0.0;
    });
    _email.clear();
    _password.clear();
    _name.clear();
    _phone.clear();
    _emailFocus.requestFocus();
    _fadeCtrl.reset();
    _fadeCtrl.forward();
  }

  void _showForgotPasswordDialog() {
    HapticFeedback.lightImpact();
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Reset Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: c,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  hintText: 'you@example.com',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (c.text.isEmpty) {
                  SnackbarHelper.showError(context, 'Enter email');
                  return;
                }
                Navigator.pop(context);
                final auth = context.read<AuthProvider>();
                final ok = await auth.sendPasswordResetEmail(c.text.trim());
                if (mounted) {
                  ok
                      ? SnackbarHelper.showSuccess(context, '✉️ Reset link sent!')
                      : SnackbarHelper.showError(context, auth.error ?? 'Failed');
                }
              },
              child: const Text('Send Link'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (_, auth, __) {
        return LoadingOverlay(
          isLoading: auth.isLoading,
          child: Scaffold(
            backgroundColor: Colors.white,
            body: Column(
              children: [
                Expanded(
                  child: SafeArea(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      child: FadeTransition(
                        opacity: _fadeCtrl.drive(Tween(begin: 0.0, end: 1.0)),
                        child: Form(
                          key: _formKey,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (!_isKeyboardVisible) ...[
                                const SizedBox(height: 20),
                                _buildLogo(),
                                const SizedBox(height: 40),
                              ] else
                                const SizedBox(height: 16),
                              _buildHeader(),
                              const SizedBox(height: 36),
                              if (_step == AuthStep.register && _formProgress > 0)
                                _buildProgressIndicator(),
                              _buildEmailField(),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeInOutCubic,
                                child: _buildStepContent(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Banner Ad at Bottom
                if (!kIsWeb && _isBannerAdReady && _bannerAd != null)
                  _buildAdBanner(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogo() {
    return Center(
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.7)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Image.asset(
            'assets/icons/app_icon.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Icon(
              Icons.eco_rounded,
              size: 50,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          _step == AuthStep.email
              ? 'Welcome'
              : (_step == AuthStep.login ? 'Welcome Back' : 'Create Account'),
          style: AppTextStyles.displaySmall.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 32,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          _step == AuthStep.email
              ? 'Agricultural Marketplace'
              : (_step == AuthStep.login
                  ? 'Sign in to your account'
                  : 'Join our farming community'),
          style: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: _formProgress,
            backgroundColor: Colors.grey.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation(
              _formProgress < 0.5
                  ? Colors.orange
                  : _formProgress < 0.75
                      ? Colors.blue
                      : Colors.green,
            ),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _buildEmailField() {
    return Column(
      children: [
        CustomTextField(
          controller: _email,
          label: 'Email Address',
          hint: 'you@example.com',
          keyboardType: TextInputType.emailAddress,
          prefixIcon: Icons.mail_outline_rounded,
          enabled: _step == AuthStep.email,
          validator: Validators.validateEmail,
          focusNode: _emailFocus,
        ),
        if (_showSuggestions && _emailSuggestions.isNotEmpty)
          _buildEmailSuggestions(),
      ],
    );
  }

  Widget _buildEmailSuggestions() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: _emailSuggestions.asMap().entries.map((e) {
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _selectEmailSuggestion(e.value),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.alternate_email_rounded,
                        size: 18, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(e.value,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStepContent() {
    if (_step == AuthStep.email) {
      return Column(
        children: [
          const SizedBox(height: 32),
          _buildPrimaryButton('Continue', Icons.arrow_forward_rounded,
              _handleContinueWithEmail),
        ],
      );
    }

    return Column(
      children: [
        const SizedBox(height: 24),
        CustomTextField(
          controller: _password,
          label: 'Password',
          hint: 'Min. 8 characters',
          obscureText: _obscure,
          prefixIcon: Icons.lock_outline_rounded,
          focusNode: _pwdFocus,
          validator: _passwordValidator,
          suffixIcon: IconButton(
            icon: Icon(_obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined),
            onPressed: () =>
                setState(() => _obscure = !_obscure),
          ),
        ),
        if (_step == AuthStep.register) ...[
          const SizedBox(height: 20),
          CustomTextField(
            controller: _name,
            label: 'Full Name',
            hint: 'Your full name',
            prefixIcon: Icons.person_outline_rounded,
            validator: Validators.validateName,
            focusNode: _nameFocus,
          ),
          const SizedBox(height: 20),
          _buildPhoneField(),
          const SizedBox(height: 20),
          _buildTermsCheckbox(),
        ] else ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: _rememberMe,
                    onChanged: (_) =>
                        setState(() => _rememberMe = !_rememberMe),
                  ),
                  const Text('Remember me'),
                ],
              ),
              TextButton(
                onPressed: _showForgotPasswordDialog,
                child: const Text('Forgot?'),
              ),
            ],
          ),
        ],
        const SizedBox(height: 28),
        _buildPrimaryButton(
          _step == AuthStep.register ? 'Create Account' : 'Sign In',
          _step == AuthStep.register
              ? Icons.rocket_launch_rounded
              : Icons.login_rounded,
          _handleSubmit,
        ),
        const SizedBox(height: 12),
        _buildSecondaryButton(),
      ],
    );
  }

  Widget _buildPhoneField() {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🇮🇳', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(_phoneCountry,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: CustomTextField(
            controller: _phone,
            label: 'Phone',
            hint: '98765 43210',
            keyboardType: TextInputType.phone,
            validator: _phoneValidator,
            focusNode: _phoneFocus,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTermsCheckbox() {
    return InkWell(
      onTap: () => setState(() => _acceptTerms = !_acceptTerms),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: _acceptTerms ? AppColors.primary : Colors.grey.withOpacity(0.3),
            width: _acceptTerms ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: _acceptTerms
              ? AppColors.primary.withOpacity(0.05)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Checkbox(
              value: _acceptTerms,
              onChanged: (_) =>
                  setState(() => _acceptTerms = !_acceptTerms),
            ),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: 'I agree to ',
                  children: [
                    TextSpan(
                      text: 'Terms',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () =>
                            SnackbarHelper.showInfo(
                                context, 'Terms page coming soon'),
                    ),
                    const TextSpan(text: ' & '),
                    TextSpan(
                      text: 'Privacy',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () =>
                            SnackbarHelper.showInfo(
                                context, 'Privacy page coming soon'),
                    ),
                  ],
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryButton(
      String label, IconData icon, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
                const SizedBox(width: 8),
                Icon(icon, color: Colors.white, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton() {
    return OutlinedButton(
      onPressed: _resetAll,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.arrow_back_rounded, size: 18),
          SizedBox(width: 8),
          Text('Use Different Email', style: TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildAdBanner() {
    return Container(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Colors.grey.withOpacity(0.15),
            width: 1,
          ),
        ),
      ),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}