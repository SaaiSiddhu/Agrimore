// ============================================================
//  AGRIMORE SALES ASSOCIATE — OTP VERIFICATION
// ============================================================
//
// Phase 18, Workstream 2. Mirrors apps/marketplace's
// otp_verification_screen.dart: same 6-box entry, same auto-advance and
// auto-submit, same 30s resend cooldown, same "call me instead" voice
// fallback offered only once the cooldown elapses. Deliberately consistent
// with the app an associate already uses as a customer, rather than a second
// invented OTP interaction.
//
// What it does NOT carry over, because none of it applies here: the recent-
// phone-number cache, the notifications priming screen, and PostAuthRouter
// (this app routes purely through _AuthGate).

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

const int _kOtpLength = 6;
const int _kResendCooldownSeconds = 30;

class AssociateOtpScreen extends StatefulWidget {
  /// E.164, +91-prefixed — exactly what was passed to sendPhoneOtp.
  final String phone;

  /// The EFFECTIVE channel the initial send actually used, threaded straight
  /// through from PhoneOtpSendResult.channel. Never guessed, never
  /// re-queried. In production today SMS is disabled and this arrives as
  /// 'voice' — the copy below must say what really happened, not assume a
  /// text message the user will never receive.
  final String channel;

  const AssociateOtpScreen({
    super.key,
    required this.phone,
    this.channel = 'sms',
  });

  @override
  State<AssociateOtpScreen> createState() => _AssociateOtpScreenState();
}

class _AssociateOtpScreenState extends State<AssociateOtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(_kOtpLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(_kOtpLength, (_) => FocusNode());

  Timer? _resendTimer;
  int _resendSecondsLeft = _kResendCooldownSeconds;
  bool _isVerifying = false;
  bool _isResending = false;
  bool _isRequestingVoice = false;
  String? _errorMessage;
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

    final auth = context.read<EmployeeAuthProvider>();
    final verified = await auth.verifyPhoneOtpAndSignIn(
      phone: widget.phone,
      otp: code,
    );

    if (!mounted) return;

    if (!verified) {
      // The code itself was wrong / the request failed. Stay here so the
      // associate can retype or resend.
      setState(() {
        _isVerifying = false;
        _errorMessage = auth.error ?? 'Invalid OTP. Please try again.';
      });
      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes.first.requestFocus();
      return;
    }

    // The OTP verified. Whether this person turned out to be an approved
    // associate, a pending one, a suspended one, or not an associate at all
    // is _AuthGate's decision — it is already rebuilding on the provider's
    // state. Close this screen and let it route. Popping even when the gate
    // rejected is intentional: the explanation lives on the login screen's
    // error banner, and staying here would strand them with a correct code.
    Navigator.of(context).pop();
  }

  Future<void> _handleResend() async {
    if (_resendSecondsLeft > 0 || _isResending) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });
    final auth = context.read<EmployeeAuthProvider>();
    final result = await auth.sendPhoneOtp(widget.phone);

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
        SnackBar(content: Text(auth.error ?? 'Failed to resend OTP')),
      );
    }
  }

  /// Offered only once the cooldown has elapsed, and hidden entirely when
  /// voice is already the effective channel — "call me instead" is
  /// meaningless when every code is already delivered by call.
  Future<void> _handleVoiceResend() async {
    if (_resendSecondsLeft > 0 || _isRequestingVoice) return;

    setState(() {
      _isRequestingVoice = true;
      _errorMessage = null;
    });
    final auth = context.read<EmployeeAuthProvider>();
    final result = await auth.sendPhoneOtp(widget.phone, channel: 'voice');

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
        SnackBar(content: Text(auth.error ?? 'Failed to place the call')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify your number'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 64)
                      .clamp(0.0, double.infinity),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildTopGroup(colorScheme),
                    _buildBottomGroup(colorScheme),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopGroup(ColorScheme colorScheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurfaceVariant,
            ),
            children: [
              // Say what actually happened — a call, not a text — whenever
              // the effective channel is voice.
              TextSpan(
                text: _isVoiceChannel
                    ? "We're calling you now with your code, on\n"
                    : 'We have sent a verification code to\n',
              ),
              TextSpan(
                text: widget.phone,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        // Expanded per box (not a fixed width) so the row always fits within
        // the screen width on any device — no overflow possible.
        Row(
          children: List.generate(
            _kOtpLength,
            (index) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _buildDigitBox(index, colorScheme),
              ),
            ),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: TextStyle(color: colorScheme.error, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 28),
        GestureDetector(
          onTap: _handleResend,
          child: Text.rich(
            TextSpan(
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
              children: [
                const TextSpan(text: "Didn't get the code? "),
                TextSpan(
                  text: _resendSecondsLeft > 0
                      ? 'Resend ${_isVoiceChannel ? 'call' : 'SMS'} in ${_resendSecondsLeft}s'
                      : (_isResending
                          ? 'Resending...'
                          : 'Resend ${_isVoiceChannel ? 'call' : 'SMS'}'),
                  style: TextStyle(
                    color: _resendSecondsLeft > 0
                        ? colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                        : colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_resendSecondsLeft == 0 && !_isVoiceChannel) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _handleVoiceResend,
            child: Text(
              _isRequestingVoice ? 'Calling you...' : 'Call me instead',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBottomGroup(ColorScheme colorScheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Use a different number',
            style: TextStyle(
              color: colorScheme.primary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
        if (_isVerifying) ...[
          const SizedBox(height: 8),
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildDigitBox(int index, ColorScheme colorScheme) {
    return SizedBox(
      height: 56,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: colorScheme.outline, width: 1.4),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: colorScheme.outline, width: 1.4),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: colorScheme.primary, width: 2),
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
