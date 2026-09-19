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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../providers/auth_provider.dart';
import '../../utils/sa_formatters.dart';

const int _kOtpLength = 6;
const int _kResendCooldownSeconds = 30;

class AssociateOtpScreen extends StatefulWidget {
  /// E.164, +91-prefixed — exactly what was passed to sendPhoneOtp.
  final String phone;

  /// The EFFECTIVE channel the initial send actually used, threaded straight
  /// through from PhoneOtpSendResult.channel.
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
    if (value.isNotEmpty) {
      if (value.length > 1) {
        _handlePaste(value);
        return;
      }
      if (index < _kOtpLength - 1) {
        _focusNodes[index + 1].requestFocus();
      }
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    final code = _controllers.map((c) => c.text).join();
    if (code.length == _kOtpLength && !code.contains(RegExp(r'\D'))) {
      _handleVerify();
    }
  }

  void _handlePaste(String pastedText) {
    final digits = pastedText.replaceAll(RegExp(r'\D'), '');
    for (int i = 0; i < _kOtpLength; i++) {
      if (i < digits.length) {
        _controllers[i].text = digits[i];
      }
    }
    if (digits.length >= _kOtpLength) {
      _focusNodes.last.unfocus();
      _handleVerify();
    } else if (digits.isNotEmpty) {
      final nextIndex = digits.length.clamp(0, _kOtpLength - 1);
      _focusNodes[nextIndex].requestFocus();
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
      setState(() {
        _isVerifying = false;
        _errorMessage = auth.error ?? 'Invalid OTP. Please check the code and try again.';
      });
      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes.first.requestFocus();
      return;
    }

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
    final tokens = context.saTokens;
    final maskedPhone = SaFormatters.formatMaskedPhone(widget.phone);

    return Scaffold(
      backgroundColor: tokens.pageBackground,
      appBar: AppBar(
        title: const Text('Verify mobile number'),
        leading: IconButton(
          icon: const Icon(SaIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
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
                  Text(
                    'Enter verification code',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: tokens.textPrimary,
                        ),
                  ),
                  const SizedBox(height: SaTokens.space8),
                  Text.rich(
                    TextSpan(
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: tokens.textSecondary,
                            height: 1.5,
                          ),
                      children: [
                        TextSpan(
                          text: _isVoiceChannel
                              ? "We are calling you with a 6-digit code on\n"
                              : 'We have sent a 6-digit verification code to\n',
                        ),
                        TextSpan(
                          text: maskedPhone,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: tokens.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: SaTokens.space24),

                  if (_errorMessage != null) ...[
                    SaInfoBanner(
                      title: 'Verification failed',
                      message: _errorMessage!,
                      variant: SaBannerVariant.error,
                    ),
                    const SizedBox(height: SaTokens.space24),
                  ],

                  // 6-box OTP entry row
                  Row(
                    children: List.generate(
                      _kOtpLength,
                      (index) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _buildDigitBox(index, tokens),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: SaTokens.space32),

                  SaLoadingButton(
                    text: 'Verify code',
                    isLoading: _isVerifying,
                    onPressed: _handleVerify,
                  ),
                  const SizedBox(height: SaTokens.space24),

                  // Resend countdown and triggers
                  Center(
                    child: GestureDetector(
                      onTap: _resendSecondsLeft == 0 ? _handleResend : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text.rich(
                          TextSpan(
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: tokens.textSecondary,
                                ),
                            children: [
                              const TextSpan(text: "Didn't receive the code? "),
                              TextSpan(
                                text: _resendSecondsLeft > 0
                                    ? 'Resend in ${_resendSecondsLeft}s'
                                    : (_isResending
                                        ? 'Resending...'
                                        : 'Resend ${_isVoiceChannel ? 'call' : 'code'}'),
                                style: TextStyle(
                                  color: _resendSecondsLeft > 0
                                      ? tokens.disabledContent
                                      : tokens.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  if (_resendSecondsLeft == 0 && !_isVoiceChannel) ...[
                    const SizedBox(height: SaTokens.space8),
                    Center(
                      child: GestureDetector(
                        onTap: _isRequestingVoice ? null : _handleVoiceResend,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            'Call me instead',
                            style: TextStyle(
                              fontSize: SaTokens.fsCaption,
                              color: tokens.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: SaTokens.space24),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(SaIcons.arrowLeft, size: 16),
                      label: const Text('Use a different number'),
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

  Widget _buildDigitBox(int index, SalesAssociateTokens tokens) {
    return SizedBox(
      height: 56,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: tokens.textPrimary,
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          filled: true,
          fillColor: tokens.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SaTokens.radiusInput),
            borderSide: BorderSide(color: tokens.inputBorder, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SaTokens.radiusInput),
            borderSide: BorderSide(color: tokens.inputBorder, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SaTokens.radiusInput),
            borderSide: BorderSide(color: tokens.primary, width: 2),
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
