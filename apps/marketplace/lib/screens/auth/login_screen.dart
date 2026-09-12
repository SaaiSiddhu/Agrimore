// ============================================================
//  AGRIMORE - LOGIN / SIGNUP SCREEN (Mobile Number + OTP)
//  One hero + bottom-sheet shell. AUTH-2: the sheet's CONTENT switches
//  internally between phone entry and OTP entry (an AnimatedSwitcher)
//  instead of pushing a second screen — the reference's own "same hero,
//  same sheet, smooth internal transition" over a separate page. Every
//  AuthProvider call below is unchanged from the pre-AUTH-2 two-screen
//  version; only the widget tree and navigation are restructured.
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import 'enable_notifications_screen.dart';
import 'post_auth_router.dart';

enum _AuthSheetState { phoneEntry, otpEntry }

const int _kOtpLength = 6;
const int _kResendCooldownSeconds = 30;

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  _AuthSheetState _sheetState = _AuthSheetState.phoneEntry;

  // ── Phone entry ──
  final _phoneController = TextEditingController();
  final _phoneFocusNode = FocusNode();
  final _formKey = GlobalKey<FormState>();
  List<String> _recentNumbers = [];
  bool _autofillSheetShown = false;
  bool _isSubmitting = false;

  // ── OTP entry — same fields/logic _OtpVerificationScreenState used to
  // own, now living alongside the phone-entry fields in one State. ──
  final List<TextEditingController> _otpControllers =
      List.generate(_kOtpLength, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(_kOtpLength, (_) => FocusNode());
  Timer? _resendTimer;
  int _resendSecondsLeft = _kResendCooldownSeconds;
  bool _isVerifying = false;
  bool _isResending = false;
  bool _isRequestingVoice = false;
  String? _otpErrorMessage;
  String _channel = 'sms';
  // The phone number the current/last OTP was sent to — set once
  // sendPhoneOTP succeeds, replacing the old OtpVerificationScreen's
  // required constructor argument.
  String _pendingPhone = '';
  bool get _isVoiceChannel => _channel == 'voice';

  @override
  void initState() {
    super.initState();
    _loadRecentNumbers();
    _phoneFocusNode.addListener(_onPhoneFocusChange);
  }

  @override
  void dispose() {
    _phoneFocusNode.removeListener(_onPhoneFocusChange);
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    _resendTimer?.cancel();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _loadRecentNumbers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(StorageConstants.keyRecentPhoneNumbers);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = (jsonDecode(raw) as List).cast<String>();
      if (mounted) setState(() => _recentNumbers = list);
    } catch (_) {
      // Ignore malformed local cache
    }
  }

  // Numbers previously used to sign in on THIS device are offered as quick-pick
  // suggestions, mirroring the OS "phone number hint" UX without needing any
  // SIM/telephony permissions.
  void _onPhoneFocusChange() {
    if (_phoneFocusNode.hasFocus && !_autofillSheetShown && _recentNumbers.isNotEmpty) {
      _autofillSheetShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showAutofillSheet());
    }
  }

  Future<void> _showAutofillSheet() async {
    _phoneFocusNode.unfocus();
    if (!mounted) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AutofillNumberSheet(numbers: _recentNumbers),
    );

    if (!mounted) return;

    if (selected != null) {
      setState(() => _phoneController.text = selected);
    } else {
      _phoneFocusNode.requestFocus();
    }
  }

  String? _validatePhone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your mobile number';
    if (v.length != 10) return 'Enter a valid 10-digit mobile number';
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(v)) return 'Enter a valid Indian mobile number';
    return null;
  }

  Future<void> _handleContinue() async {
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.mediumImpact();
    FocusScope.of(context).unfocus();

    final phone = '+91${_phoneController.text.trim()}';
    final authProvider = context.read<AuthProvider>();

    setState(() => _isSubmitting = true);
    final result = await authProvider.sendPhoneOTP(phone);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.error ?? 'Failed to send OTP. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    _pendingPhone = phone;
    _enterOtpState(result.channel);
  }

  void _enterOtpState(String channel) {
    for (final c in _otpControllers) {
      c.clear();
    }
    setState(() {
      _channel = channel;
      _otpErrorMessage = null;
      _sheetState = _AuthSheetState.otpEntry;
    });
    _startResendCountdown();
    // Auto-focus the first OTP cell once the transition has had a frame to
    // mount the new content — matches the previous screen's own behavior
    // (autofocus was implicit there because the whole screen was fresh).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _otpFocusNodes.first.requestFocus();
    });
  }

  // "Change number" (and the system/OS back gesture while on the OTP step,
  // see build()'s PopScope) — returns to phone entry, keeping the typed
  // number so the customer doesn't retype it, and discards in-progress OTP
  // state so a stale resend timer can't keep running underneath.
  void _handleChangeNumber() {
    _resendTimer?.cancel();
    setState(() {
      _sheetState = _AuthSheetState.phoneEntry;
      _otpErrorMessage = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _phoneFocusNode.requestFocus();
    });
  }

  void _startResendCountdown() {
    _resendSecondsLeft = _kResendCooldownSeconds;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendSecondsLeft <= 1) {
        timer.cancel();
        setState(() => _resendSecondsLeft = 0);
      } else {
        setState(() => _resendSecondsLeft--);
      }
    });
  }

  void _onOtpDigitChanged(int index, String value) {
    if (value.isNotEmpty && index < _kOtpLength - 1) {
      _otpFocusNodes[index + 1].requestFocus();
    }
    final code = _otpControllers.map((c) => c.text).join();
    if (code.length == _kOtpLength && !code.contains(RegExp(r'\D'))) {
      _handleVerify();
    }
  }

  Future<void> _handleVerify() async {
    if (_isVerifying) return;
    final code = _otpControllers.map((c) => c.text).join();
    if (code.length != _kOtpLength) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _isVerifying = true;
      _otpErrorMessage = null;
    });

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.verifyPhoneOTP(phone: _pendingPhone, otp: code);

    if (!mounted) return;

    if (!success) {
      setState(() {
        _isVerifying = false;
        _otpErrorMessage = authProvider.error ?? 'Invalid OTP. Please try again.';
      });
      for (final c in _otpControllers) {
        c.clear();
      }
      _otpFocusNodes.first.requestFocus();
      return;
    }

    await _rememberPhoneNumber();
    await _proceedAfterLogin(isNewUser: authProvider.isNewUser);
  }

  Future<void> _rememberPhoneNumber() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(StorageConstants.keyRecentPhoneNumbers);
      final list = raw != null ? (jsonDecode(raw) as List).cast<String>() : <String>[];
      final national = _pendingPhone.replaceFirst('+91', '');
      list.remove(national);
      list.insert(0, national);
      await prefs.setString(
        StorageConstants.keyRecentPhoneNumbers,
        jsonEncode(list.take(4).toList()),
      );
    } catch (_) {
      // Non-critical convenience cache — safe to ignore failures
    }
  }

  Future<void> _proceedAfterLogin({required bool isNewUser}) async {
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final alreadyPrimed = prefs.getBool(StorageConstants.keyNotificationsPrimed) ?? false;

    if (!mounted) return;

    if (!alreadyPrimed) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => EnableNotificationsScreen(isNewUser: isNewUser, phone: _pendingPhone),
        ),
        (route) => false,
      );
      return;
    }

    PostAuthRouter.routeAfterAuth(context, phone: _pendingPhone, isNewUser: isNewUser);
  }

  Future<void> _handleResend() async {
    if (_resendSecondsLeft > 0 || _isResending) return;

    setState(() => _isResending = true);
    final authProvider = context.read<AuthProvider>();
    final result = await authProvider.sendPhoneOTP(_pendingPhone);

    if (!mounted) return;
    setState(() => _isResending = false);

    if (result != null) {
      setState(() => _channel = result.channel);
      for (final c in _otpControllers) {
        c.clear();
      }
      _otpFocusNodes.first.requestFocus();
      _startResendCountdown();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authProvider.error ?? 'Failed to resend OTP')),
      );
    }
  }

  // Offered once the SMS resend cooldown has elapsed — server-side, this
  // redelivers the SAME code the SMS already carries (see
  // sendPhoneOTP.ts's voice-reuse logic), so requesting a call never
  // invalidates a pending SMS.
  Future<void> _handleVoiceResend() async {
    if (_resendSecondsLeft > 0 || _isRequestingVoice) return;

    setState(() => _isRequestingVoice = true);
    final authProvider = context.read<AuthProvider>();
    final result = await authProvider.sendPhoneOTP(_pendingPhone, channel: 'voice');

    if (!mounted) return;
    setState(() => _isRequestingVoice = false);

    if (result != null) {
      setState(() => _channel = result.channel);
      _startResendCountdown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("We're calling you now with your code")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authProvider.error ?? 'Failed to place the call')),
      );
    }
  }

  // Masks the first half of the national number for display, matching the
  // reference design ("+91 ••••• 43210") — cosmetic only; every request
  // still uses the full, unmasked _pendingPhone value.
  String _maskedPhone() {
    final digits = _pendingPhone.replaceFirst('+91', '');
    if (digits.length != 10) return _pendingPhone;
    return '+91 ••••• ${digits.substring(5)}';
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: PopScope(
        // System/OS back while on the OTP step returns to phone entry
        // first, instead of leaving the screen (and, pre-login, the app) —
        // the reference's own explicit requirement for this transition.
        canPop: _sheetState == _AuthSheetState.phoneEntry,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && _sheetState == _AuthSheetState.otpEntry) {
            _handleChangeNumber();
          }
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          resizeToAvoidBottomInset: true,
          // Stack, not a Column split into two adjacent regions: the hero
          // image is the full-screen background and the sheet floats OVER
          // its lower portion, overlapping — matching the reference
          // composition. The sheet sizes itself to its own content and is
          // capped at a fraction of the screen so the taller OTP state can
          // grow without ever swallowing the whole hero.
          body: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    Positioned.fill(child: _buildHeroHeader()),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: constraints.maxHeight * 0.72),
                        child: _buildSheet(),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // Full-bleed image (edge-to-edge, no letterboxing), top-aligned so the
  // brand content baked into login_full_hero.png (wordmark, tagline, the
  // three value-prop icons) stays in frame across aspect ratios.
  Widget _buildHeroHeader() {
    return Semantics(
      label: 'AgriMore — Fresh from farms, faster to you',
      image: true,
      child: Image.asset(
        'assets/images/login_full_hero.png',
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        excludeFromSemantics: true,
        errorBuilder: (_, __, ___) => const ColoredBox(color: AppColors.primaryDark),
      ),
    );
  }

  static const double _fieldHeight = 52;

  Widget _buildSheet() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        // A floating shadow, not a border — the sheet sits ON TOP of the
        // hero image, so it needs to visually lift off the photo behind it.
        boxShadow: [
          BoxShadow(color: AppColors.shadowLight, blurRadius: 28, offset: Offset(0, -8)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Decorative affordance matching the reference composition only —
            // this sheet is a fixed part of the screen layout, not an actual
            // drag-to-dismiss sheet, so it carries no gesture handler.
            const Padding(
              padding: EdgeInsets.only(top: 10, bottom: 4),
              child: SizedBox(
                width: 40,
                height: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.all(Radius.circular(2)),
                  ),
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                // AnimatedSwitcher, not Navigator.push — the whole point of
                // AUTH-2 is one persistent sheet with an internal content
                // swap. Distinct ValueKeys per state are required so the
                // switcher treats phone/OTP content as different children.
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
                          .animate(animation),
                      child: child,
                    ),
                  ),
                  child: _sheetState == _AuthSheetState.phoneEntry
                      ? _buildPhoneContent(key: const ValueKey('phone'))
                      : _buildOtpContent(key: const ValueKey('otp')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneContent({required Key key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Login / Sign in',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              const Text(
                'Enter your mobile number to receive an OTP',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Flag-only box — the +91 code now lives inside the phone field itself.
                  Container(
                    height: _fieldHeight,
                    width: _fieldHeight,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('🇮🇳', style: TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: _fieldHeight,
                      child: TextFormField(
                        controller: _phoneController,
                        focusNode: _phoneFocusNode,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: InputDecoration(
                          prefixText: '+91  ',
                          prefixStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          hintText: 'Enter Phone Number',
                          hintStyle: const TextStyle(color: AppColors.textHint, fontWeight: FontWeight.w400),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.primary, width: 2),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.error),
                          ),
                        ),
                        validator: _validatePhone,
                        onFieldSubmitted: (_) => _handleContinue(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: _fieldHeight,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildTermsText(),
      ],
    );
  }

  Widget _buildTermsText() {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        children: [
          Text('By continuing, you agree to our ', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/terms'),
            child: const Text('Terms of Service',
                style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
          Text(' and ', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/privacy-policy'),
            child: const Text('Privacy Policy',
                style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpContent({required Key key}) {
    return Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            children: [
              TextSpan(
                text: _isVoiceChannel
                    ? "We're calling you now with your code, on\n"
                    : 'We have sent a verification code to\n',
              ),
              TextSpan(
                text: _maskedPhone(),
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        // Expanded per box (not a fixed width) so the row always fits exactly
        // within the screen width, on any device — no overflow possible.
        Row(
          children: List.generate(
            _kOtpLength,
            (index) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _buildDigitBox(index),
              ),
            ),
          ),
        ),
        if (_otpErrorMessage != null) ...[
          const SizedBox(height: 14),
          Text(_otpErrorMessage!, style: const TextStyle(color: AppColors.error, fontSize: 13), textAlign: TextAlign.center),
        ],
        const SizedBox(height: 22),
        GestureDetector(
          onTap: _handleResend,
          child: Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
              children: [
                const TextSpan(text: "Didn't get the OTP? "),
                TextSpan(
                  text: _resendSecondsLeft > 0
                      ? 'Resend ${_isVoiceChannel ? 'call' : 'SMS'} in ${_resendSecondsLeft}s'
                      : (_isResending ? 'Resending...' : 'Resend ${_isVoiceChannel ? 'call' : 'SMS'}'),
                  style: TextStyle(
                    color: _resendSecondsLeft > 0 ? AppColors.textTertiary : AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Voice fallback — only offered once the cooldown has elapsed, so
        // it's never shown as an option before the SMS has even had a
        // chance to arrive; meaningless (and hidden) when voice is already
        // the primary channel.
        if (_resendSecondsLeft == 0 && !_isVoiceChannel) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _handleVoiceResend,
            child: Text(
              _isRequestingVoice ? 'Calling you...' : 'Call me instead',
              style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w700),
            ),
          ),
        ],
        const SizedBox(height: 18),
        TextButton(
          onPressed: _handleChangeNumber,
          child: const Text('Change number',
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 14)),
        ),
        if (_isVerifying) ...[
          const SizedBox(height: 4),
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
          ),
        ],
      ],
    );
  }

  Widget _buildDigitBox(int index) {
    return SizedBox(
      height: 56,
      child: TextField(
        controller: _otpControllers[index],
        focusNode: _otpFocusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          filled: true,
          fillColor: AppColors.surfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.textTertiary, width: 1.4),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.textTertiary, width: 1.4),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
        onChanged: (value) => _onOtpDigitChanged(index, value),
        onTap: () {
          _otpControllers[index].selection = TextSelection(
            baseOffset: 0,
            extentOffset: _otpControllers[index].text.length,
          );
        },
      ),
    );
  }
}

class _AutofillNumberSheet extends StatelessWidget {
  final List<String> numbers;
  const _AutofillNumberSheet({required this.numbers});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('Continue with', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ),
            const SizedBox(height: 8),
            ...numbers.map(
              (number) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.surfaceContainer,
                  child: const Icon(Icons.phone_outlined, color: AppColors.textSecondary),
                ),
                title: Text(number, style: const TextStyle(fontSize: 16)),
                onTap: () => Navigator.pop(context, number),
              ),
            ),
            const SizedBox(height: 4),
            ListTile(
              title: const Text(
                'NONE OF THE ABOVE',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.info, letterSpacing: 0.3),
              ),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
