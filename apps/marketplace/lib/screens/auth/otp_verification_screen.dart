// ============================================================
//  AGRIMORE - OTP VERIFICATION SCREEN
//  6-digit code entry, with a "Call me instead" voice fallback offered
//  once the SMS resend cooldown elapses.
// ============================================================
//
// Phase 16, Workstream 6 fix: this screen used to silently auto-fill and
// submit a hardcoded "123456" 800ms after opening — a leftover from when
// the server had no real SMS provider and always issued that fixed code
// (the exact bug Phase 14 closed server-side). Left in place, it would now
// just auto-submit a wrong code against the real server on every open.
// Removed entirely, along with the timer that drove it.

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

const int _kOtpLength = 6;
const int _kResendCooldownSeconds = 30;

class OtpVerificationScreen extends StatefulWidget {
  final String phone;
  // Phase 22: the EFFECTIVE channel the initial send actually used (from
  // PhoneOtpSendResult.channel) — never guessed or re-queried, threaded
  // straight through from the login screen's send call. Defaults to 'sms'
  // only as a safety net for any caller that doesn't pass it.
  final String channel;
  const OtpVerificationScreen({Key? key, required this.phone, this.channel = 'sms'})
      : super(key: key);

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers =
      List.generate(_kOtpLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(_kOtpLength, (_) => FocusNode());

  Timer? _resendTimer;
  int _resendSecondsLeft = _kResendCooldownSeconds;
  bool _isVerifying = false;
  bool _isResending = false;
  bool _isRequestingVoice = false;
  String? _errorMessage;
  // Updated after every successful (re)send so the copy always reflects the
  // most recent EFFECTIVE channel, not just the one the screen opened with.
  late String _channel;
  bool get _isVoiceChannel => _channel == 'voice';

  @override
  void initState() {
    super.initState();
    _channel = widget.channel;
    _startResendCountdown();
  }

  @override
  void dispose() {
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

  void _onDigitChanged(int index, String value) {
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
        MaterialPageRoute(
          builder: (_) => EnableNotificationsScreen(isNewUser: isNewUser, phone: widget.phone),
        ),
        (route) => false,
      );
      return;
    }

    PostAuthRouter.routeAfterAuth(context, phone: widget.phone, isNewUser: isNewUser);
  }

  Future<void> _handleResend() async {
    if (_resendSecondsLeft > 0 || _isResending) return;

    setState(() => _isResending = true);
    final authProvider = context.read<AuthProvider>();
    final result = await authProvider.sendPhoneOTP(widget.phone);

    if (!mounted) return;
    setState(() => _isResending = false);

    if (result != null) {
      setState(() => _channel = result.channel);
      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes.first.requestFocus();
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
    final result = await authProvider.sendPhoneOTP(widget.phone, channel: 'voice');

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

  @override
  Widget build(BuildContext context) {
    final topGroup = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            children: [
              // Phase 22: say what actually happened — a call, not a text
              // — when the effective channel is voice.
              TextSpan(
                text: _isVoiceChannel
                    ? "We're calling you now with your code, on\n"
                    : 'We have sent a verification code to\n',
              ),
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
        // chance to arrive. Phase 22: meaningless (and hidden) when voice
        // is already the primary channel — "call me instead" makes no
        // sense when every resend is already a call. Left in the code
        // untouched otherwise, so it reappears exactly as-is the moment
        // SMS becomes available again.
        if (_resendSecondsLeft == 0 && !_isVoiceChannel) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _handleVoiceResend,
            child: Text(
              _isRequestingVoice ? 'Calling you...' : 'Call me instead',
              style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w700),
            ),
          ),
        ],
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
