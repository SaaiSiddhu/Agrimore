// lib/screens/user/profile/change_email_screen.dart
// Change email address with real, server-verified OTP (Resend via
// sendEmailOTP.ts, verified server-side by the existing
// verifyEmailForProfile.ts, applied to this account by changeEmailAddress.ts
// — see that file's header comment for why it is two calls, not one).
//
// PROFILE-10 rebuilt this into the 4-step wizard (Intro -> Enter email ->
// Verify -> Success) the owner's reference mockup shows. That mockup's own
// verify step depicts a magic-link flow ("tap the link in your email") —
// this account does not have one; the real, working mechanism is a 6-digit
// OTP code (same as phone), so the verify step reuses the phone flow's
// OTP-box + in-app numeric keypad treatment with email-appropriate copy,
// rather than building a link-flow UI with no backend behind it. Every real
// call below (_checkEmailRoleCollision, _handleSendOtp,
// _handleVerifyAndSave) is unchanged from the screen PROFILE-10 replaced —
// see widgets/verification_flow_widgets.dart for the shared chrome.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

import '../../../providers/auth_provider.dart' as app_auth;
import '../../../providers/theme_provider.dart';
import 'widgets/verification_flow_widgets.dart';

enum _EmailStep { intro, enterEmail, verify, success }

class ChangeEmailScreen extends StatefulWidget {
  final String currentEmail;

  const ChangeEmailScreen({
    super.key,
    required this.currentEmail,
  });

  @override
  State<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends State<ChangeEmailScreen> {
  late app_auth.AuthProvider _openingProvider;
  String? _openingOwner;
  int _openingVersion = -1;
  String _sentTarget = '';
  bool get _ownsForm => mounted &&
      _openingOwner != null &&
      identical(context.read<app_auth.AuthProvider>(), _openingProvider) &&
      _openingProvider.isSessionCurrent(_openingOwner!, _openingVersion);

  final _emailController = TextEditingController();
  String _otp = '';

  _EmailStep _step = _EmailStep.intro;
  bool _isLoading = false;
  String? _errorMessage;
  String? _roleCollisionWarning;
  int _resendCountdown = 30;
  Timer? _countdownTimer;
  String _savedEmail = '';

  @override
  void initState() {
    super.initState();
    _openingProvider = context.read<app_auth.AuthProvider>();
    _openingOwner = _openingProvider.currentUser?.uid;
    _openingVersion = _openingProvider.sessionVersion;
    _emailController.addListener(() {
      if (!_ownsForm) return;
      if (_errorMessage != null || _roleCollisionWarning != null) {
        setState(() {
          _errorMessage = null;
          _roleCollisionWarning = null;
        });
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    if (!_ownsForm) return;
    _countdownTimer?.cancel();
    setState(() => _resendCountdown = 30);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_ownsForm) {
        timer.cancel();
        return;
      }
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  // Fail-fast UX only — changeEmailAddress.ts runs the definitive uniqueness
  // check server-side. This just avoids sending an OTP for an address the
  // server would reject anyway.
  Future<String?> _checkEmailRoleCollision(String email) async {
    if (!_ownsForm) return null;
    final currentUid = _openingOwner;
    final normalizedEmail = email.trim().toLowerCase();

    try {
      final sellerSnap = await FirebaseFirestore.instance
          .collection('sellers')
          .where('email', isEqualTo: normalizedEmail)
          .limit(1)
          .get();
      if (!_ownsForm) return null;
      if (sellerSnap.docs.isNotEmpty && sellerSnap.docs.first.id != currentUid) {
        return 'This email address is already registered as an Agrimore Seller account.';
      }

      final employeeSnap = await FirebaseFirestore.instance
          .collection('employees')
          .where('email', isEqualTo: normalizedEmail)
          .limit(1)
          .get();
      if (!_ownsForm) return null;
      if (employeeSnap.docs.isNotEmpty && employeeSnap.docs.first.id != currentUid) {
        return 'This email address is already registered as an Agrimore Sales Associate / Staff account.';
      }

      final usersSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: normalizedEmail)
          .limit(1)
          .get();
      if (!_ownsForm) return null;
      if (usersSnap.docs.isNotEmpty && usersSnap.docs.first.id != currentUid) {
        return 'This email address is already registered to another account.';
      }

      return null;
    } catch (e) {
      debugPrint('Email collision check error: $e');
      return null;
    }
  }

  Future<void> _handleSendOtp() async {
    if (!_ownsForm || _isLoading) return;
    final newEmail = _step == _EmailStep.verify
        ? _sentTarget : _emailController.text.trim().toLowerCase();

    if (newEmail.isEmpty) {
      setState(() => _errorMessage = 'Please enter an email address');
      return;
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(newEmail)) {
      setState(() => _errorMessage = 'Please enter a valid email address');
      return;
    }
    if (newEmail == widget.currentEmail.trim().toLowerCase()) {
      setState(() => _errorMessage = 'New email cannot be the same as your current email');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _roleCollisionWarning = null;
    });
    HapticFeedback.mediumImpact();
    try {
      final collisionWarning = await _checkEmailRoleCollision(newEmail);
      if (collisionWarning != null) {
        if (!_ownsForm) return;
        setState(() {
          _isLoading = false;
          _roleCollisionWarning = collisionWarning;
        });
        return;
      }

      if (!_ownsForm) return;
      final authProvider = _openingProvider;
      // Real send: Resend via sendEmailOTP.ts, plain-text OTP mail.
      final sent = await authProvider.sendEmailOtpForProfile(newEmail);

      if (!_ownsForm) return;

      if (!sent) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not send a verification code. Please try again.';
        });
        return;
      }

      setState(() {
        _isLoading = false;
        _sentTarget = newEmail;
        _otp = '';
        _step = _EmailStep.verify;
      });
      _startCountdown();
    } catch (_) {
      if (!_ownsForm) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not send a verification code. Please try again.';
      });
    }
  }

  Future<void> _handleVerifyAndSave() async {
    if (!_ownsForm || _isLoading || _sentTarget.isEmpty) return;
    if (_otp.length != 6) {
      setState(() => _errorMessage = 'Please enter the 6-digit OTP');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    HapticFeedback.mediumImpact();
    try {
      final newEmail = _sentTarget;
      final authProvider = _openingProvider;

      // Step 1: real, server-side OTP check against otp_codes/{newEmail}.
      final verified = await authProvider.verifyEmailOtpForProfile(
        email: newEmail,
        otp: _otp,
      );
      if (!_ownsForm) return;
      if (!verified) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not verify your code. Please try again.';
          _otp = '';
        });
        return;
      }

      // Step 2: apply the now-proven email to this account.
      final saved = await authProvider.changeEmailAddress(email: newEmail);
      if (!_ownsForm) return;

      if (!saved) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not update your email address. Please try again.';
        });
        return;
      }

      _countdownTimer?.cancel();
      setState(() {
        _isLoading = false;
        _savedEmail = newEmail;
        _step = _EmailStep.success;
      });
    } catch (_) {
      if (!_ownsForm) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not update your contact details. Please try again.';
      });
    }
  }

  void _onKeypadDigit(String digit) {
    if (!_ownsForm || _otp.length >= 6 || _isLoading) return;
    setState(() {
      _otp += digit;
      _errorMessage = null;
    });
    if (_otp.length == 6) {
      _handleVerifyAndSave();
    }
  }

  void _onKeypadBackspace() {
    if (!_ownsForm || _otp.isEmpty || _isLoading) return;
    setState(() => _otp = _otp.substring(0, _otp.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    context.watch<app_auth.AuthProvider>();
    if (!_ownsForm) {
      return Scaffold(
        appBar: AppBar(title: const Text('Update contact details')),
        body: const ErrorView(useThemeColors: true,
          message: 'Your session changed. Reopen your profile to continue.'),
      );
    }
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : Colors.white,
      appBar: _step == _EmailStep.success
          ? null
          : AppBar(
              backgroundColor: isDark ? AppColors.backgroundDark : Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: isDark ? AppColors.textLight : AppColors.textPrimary,
                  size: 22,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Change Email Address',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.textLight : AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: _buildStep(isDark),
        ),
      ),
    );
  }

  Widget _buildStep(bool isDark) {
    switch (_step) {
      case _EmailStep.intro:
        return _buildIntroStep(isDark);
      case _EmailStep.enterEmail:
        return _buildEnterEmailStep(isDark);
      case _EmailStep.verify:
        return _buildVerifyStep(isDark);
      case _EmailStep.success:
        return VerificationSuccessView(
          title: 'Email Address Updated!',
          subtitle: 'Your new email address has been successfully linked to your account.',
          valueIcon: Icons.email_outlined,
          valueLabel: 'New Email Address',
          value: _savedEmail,
          isDark: isDark,
          onDone: () {
            if (_ownsForm && ModalRoute.of(context)?.isCurrent == true) {
              Navigator.pop(context, _savedEmail);
            }
          },
        );
    }
  }

  Widget _buildIntroStep(bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          VerificationStepHeader(
            icon: Icons.mark_email_read_outlined,
            title: 'Keep your account secure',
            subtitle: "We'll verify your new email address with a one-time code before updating.",
            isDark: isDark,
          ),
          const SizedBox(height: 28),
          LockedValueCard(
            icon: Icons.email_outlined,
            label: 'Current Email Address',
            value: widget.currentEmail,
            isDark: isDark,
          ),
          const SizedBox(height: 28),
          VerificationPrimaryButton(
            label: 'Continue',
            isLoading: false,
            enabled: true,
            isDark: isDark,
            onPressed: () {
              if (_ownsForm) setState(() => _step = _EmailStep.enterEmail);
            },
          ),
          const SizedBox(height: 14),
          Text(
            'Your current email will remain active until the new email is verified.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildEnterEmailStep(bool isDark) {
    final hasInput = _emailController.text.trim().isNotEmpty;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          VerificationStepHeader(
            icon: Icons.alternate_email_rounded,
            title: 'Enter New Email Address',
            subtitle: 'Enter the email address you want to link to your account.',
            isDark: isDark,
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey.shade200),
            ),
            child: TextField(
              controller: _emailController,
              enabled: !_isLoading,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              cursorColor: AppColors.primary,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textLight : AppColors.textPrimary,
              ),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 16),
                hintText: 'youremail@example.com',
                hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(height: 18),
          InfoCallout(
            isDark: isDark,
            bullets: const [
              'Enter a valid and active email address',
              "We'll send a one-time verification code",
              'Your current email will remain active until the new one is verified',
            ],
          ),
          if (_roleCollisionWarning != null) ...[
            const SizedBox(height: 18),
            _buildWarningBox(_roleCollisionWarning!, isDark),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: 14),
            Text(_errorMessage!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13, fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 24),
          VerificationPrimaryButton(
            label: 'Send Code',
            isLoading: _isLoading,
            enabled: hasInput,
            isDark: isDark,
            onPressed: _handleSendOtp,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildVerifyStep(bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          VerificationStepHeader(
            icon: Icons.mark_email_unread_outlined,
            title: 'Verify Email Address',
            subtitle: "We've sent a 6-digit code to\n${_sentTarget}",
            isDark: isDark,
          ),
          const SizedBox(height: 28),
          OtpBoxesDisplay(otp: _otp, isDark: isDark),
          const SizedBox(height: 14),
          Center(
            child: _resendCountdown > 0
                ? Text(
                    "Didn't receive it? Check spam, or resend in ${_resendCountdown.toString().padLeft(2, '0')}s",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600], fontSize: 12.5, fontWeight: FontWeight.w600),
                  )
                : GestureDetector(
                    onTap: () {
                      if (!_ownsForm || _isLoading) return;
                      setState(() => _otp = '');
                      _handleSendOtp();
                    },
                    child: Text(
                      "Didn't receive it? Resend code",
                      style: TextStyle(color: isDark ? AppColors.primaryLight : AppColors.primary, fontSize: 12.5, fontWeight: FontWeight.w800),
                    ),
                  ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 14),
            Center(
              child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ],
          const SizedBox(height: 20),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
            )
          else
            NumericKeypad(onDigit: _onKeypadDigit, onBackspace: _onKeypadBackspace, isDark: isDark),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildWarningBox(String message, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF3B1E1E) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
