// ============================================================
//  AGRIMORE - OTP VERIFICATION SCREEN
//  6-digit code entry. In dev (no SMS provider wired yet) the code is
//  silently auto-filled after a short delay, simulating SMS auto-read —
//  this fallback is never surfaced anywhere in the UI copy.
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app/routes.dart';
import '../../providers/auth_provider.dart';
import 'enable_notifications_screen.dart';

const int _kOtpLength = 6;
const int _kResendCooldownSeconds = 30;
// Dev-only: no SMS provider is wired up yet, so the backend always issues
// this fixed code. Flip this off (and delete the auto-fill timer below)
// once a real SMS provider is connected server-side.
const String _kDevAutofillOtp = '123456';
const Duration _kAutofillDelay = Duration(milliseconds: 800);

class OtpVerificationScreen extends StatefulWidget {
  final String phone;
  const OtpVerificationScreen({Key? key, required this.phone}) : super(key: key);

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers =
      List.generate(_kOtpLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(_kOtpLength, (_) => FocusNode());

  Timer? _autofillTimer;
  Timer? _resendTimer;
  int _resendSecondsLeft = _kResendCooldownSeconds;
  bool _isVerifying = false;
  bool _isResending = false;
  bool _userEdited = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startResendCountdown();
    _autofillTimer = Timer(_kAutofillDelay, _autofillOtp);
  }

  @override
  void dispose() {
    _autofillTimer?.cancel();
    _resendTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
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

  void _autofillOtp() {
    if (!mounted || _userEdited) return;
    for (int i = 0; i < _kOtpLength; i++) {
      _controllers[i].text = _kDevAutofillOtp[i];
    }
    setState(() {});
    _handleVerify();
  }

  void _onDigitChanged(int index, String value) {
    _userEdited = true;
    if (value.isNotEmpty && index < _kOtpLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    final code = _controllers.map((c) => c.text).join();
    if (code.length == _kOtpLength && !code.contains(RegExp(r'\D'))) {
      _handleVerify();
    }
  }

  Future<void> _handleVerify() async {
    if (_isVerifying) return;
    final code = _controllers.map((c) => c.text).join();
    if (code.length != _kOtpLength) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.verifyPhoneOTP(phone: widget.phone, otp: code);

    if (!mounted) return;

    if (!success) {
      setState(() {
        _isVerifying = false;
        _errorMessage = authProvider.error ?? 'Invalid OTP. Please try again.';
      });
      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes.first.requestFocus();
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
      final national = widget.phone.replaceFirst('+91', '');
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
        MaterialPageRoute(builder: (_) => EnableNotificationsScreen(isNewUser: isNewUser)),
        (route) => false,
      );
      return;
    }

    Navigator.of(context).pushNamedAndRemoveUntil(
      isNewUser ? AppRoutes.onboardingAddress : AppRoutes.main,
      (route) => false,
    );
  }

  Future<void> _handleResend() async {
    if (_resendSecondsLeft > 0 || _isResending) return;

    setState(() => _isResending = true);
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.sendPhoneOTP(widget.phone);

    if (!mounted) return;
    setState(() => _isResending = false);

    if (success) {
      _userEdited = false;
      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes.first.requestFocus();
      _startResendCountdown();
      _autofillTimer?.cancel();
      _autofillTimer = Timer(_kAutofillDelay, _autofillOtp);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authProvider.error ?? 'Failed to resend OTP')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final topGroup = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            children: [
              const TextSpan(text: 'We have sent a verification code to\n'),
              TextSpan(
                text: widget.phone,
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
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
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(_errorMessage!, style: const TextStyle(color: AppColors.error, fontSize: 13), textAlign: TextAlign.center),
        ],
        const SizedBox(height: 28),
        GestureDetector(
          onTap: _handleResend,
          child: Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
              children: [
                const TextSpan(text: "Didn't get the OTP? "),
                TextSpan(
                  text: _resendSecondsLeft > 0
                      ? 'Resend SMS in ${_resendSecondsLeft}s'
                      : (_isResending ? 'Resending...' : 'Resend SMS'),
                  style: TextStyle(
                    color: _resendSecondsLeft > 0 ? AppColors.textTertiary : AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    final bottomGroup = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Go back to login methods',
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 14)),
        ),
        if (_isVerifying) ...[
          const SizedBox(height: 8),
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: const Text('OTP Verification', style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      // LayoutBuilder + ConstrainedBox(minHeight) + spaceBetween pins
      // bottomGroup near the bottom edge when there's room, and — since it's
      // wrapped in a SingleChildScrollView — degrades to a scrollable page
      // instead of overflowing when the space is squeezed.
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: (constraints.maxHeight - 64).clamp(0.0, double.infinity)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [topGroup, bottomGroup],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDigitBox(int index) {
    return SizedBox(
      height: 56,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
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
        onChanged: (value) => _onDigitChanged(index, value),
        onTap: () {
          _controllers[index].selection = TextSelection(
            baseOffset: 0,
            extentOffset: _controllers[index].text.length,
          );
        },
      ),
    );
  }
}
