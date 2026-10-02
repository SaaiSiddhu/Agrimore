// lib/screens/user/profile/change_phone_screen.dart
// Change mobile number with real, server-verified OTP (2Factor via
// sendPhoneOTP.ts, verified server-side by changePhoneNumber.ts — see that
// file's header comment for why it is not the login-purpose verifyPhoneOTP).
//
// PROFILE-10 rebuilt this into the 4-step wizard (Intro -> Enter number ->
// Verify -> Success) the owner's reference mockup shows, with a custom
// in-app numeric keypad replacing the system keyboard for OTP entry. Every
// real call below (_checkPhoneRoleCollision, _handleSendOtp,
// _handleVerifyAndSave) is unchanged from the screen PROFILE-10 replaced —
// only the step chrome and OTP input mechanism are new; see
// widgets/verification_flow_widgets.dart for the shared pieces.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

import '../../../providers/auth_provider.dart' as app_auth;
import '../../../providers/theme_provider.dart';
import 'widgets/verification_flow_widgets.dart';

enum _PhoneStep { intro, enterNumber, verify, success }

class ChangePhoneScreen extends StatefulWidget {
  final String currentPhone;

  const ChangePhoneScreen({
    super.key,
    required this.currentPhone,
  });

  @override
  State<ChangePhoneScreen> createState() => _ChangePhoneScreenState();
}

class _ChangePhoneScreenState extends State<ChangePhoneScreen> {
  late app_auth.AuthProvider _openingProvider;
  String? _openingOwner;
  int _openingVersion = -1;
  String _sentTarget = '';
  bool get _ownsForm => mounted &&
      _openingOwner != null &&
      identical(context.read<app_auth.AuthProvider>(), _openingProvider) &&
      _openingProvider.isSessionCurrent(_openingOwner!, _openingVersion);

  final _phoneController = TextEditingController();
  String _otp = '';

  _PhoneStep _step = _PhoneStep.intro;
  bool _isLoading = false;
  String? _errorMessage;
  String? _roleCollisionWarning;
  int _resendCountdown = 30;
  Timer? _countdownTimer;
  String _savedPhone = '';

  @override
  void initState() {
    super.initState();
    _openingProvider = context.read<app_auth.AuthProvider>();
    _openingOwner = _openingProvider.currentUser?.uid;
    _openingVersion = _openingProvider.sessionVersion;
    _phoneController.addListener(() {
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
    _phoneController.dispose();
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

  // Fail-fast UX only — changePhoneNumber.ts runs the same check
  // server-side and is the actual enforcement. This just avoids sending an
  // OTP for a number the server would reject anyway.
  Future<String?> _checkPhoneRoleCollision(String phone) async {
    if (!_ownsForm) return null;
    final currentUid = _openingOwner;
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');

    try {
      final sellerSnap = await FirebaseFirestore.instance
          .collection('sellers')
          .where('phone', isEqualTo: cleanPhone)
          .limit(1)
          .get();
      if (!_ownsForm) return null;
      if (sellerSnap.docs.isNotEmpty && sellerSnap.docs.first.id != currentUid) {
        return 'This phone number is already registered as an Agrimore Seller account.';
      }

      final employeeSnap = await FirebaseFirestore.instance
          .collection('employees')
          .where('phone', isEqualTo: cleanPhone)
          .limit(1)
          .get();
      if (!_ownsForm) return null;
      if (employeeSnap.docs.isNotEmpty && employeeSnap.docs.first.id != currentUid) {
        return 'This phone number is already registered as an Agrimore Sales Associate / Staff account.';
      }

      final usersSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: cleanPhone)
          .limit(1)
          .get();
      if (!_ownsForm) return null;
      if (usersSnap.docs.isNotEmpty && usersSnap.docs.first.id != currentUid) {
        return 'This phone number is already registered to another Customer account.';
      }

      return null;
    } catch (e) {
      debugPrint('Phone collision check error: $e');
      return null;
    }
  }

  Future<void> _handleSendOtp() async {
    if (!_ownsForm || _isLoading) return;
    final newPhone = _step == _PhoneStep.verify
        ? _sentTarget : _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (newPhone.isEmpty) {
      setState(() => _errorMessage = 'Please enter a mobile number');
      return;
    }
    if (newPhone.length < 10) {
      setState(() => _errorMessage = 'Please enter a valid 10-digit mobile number');
      return;
    }
    if (newPhone == widget.currentPhone.replaceAll(RegExp(r'[^0-9]'), '')) {
      setState(() =>
          _errorMessage = 'New mobile number cannot be the same as your current number');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _roleCollisionWarning = null;
    });
    HapticFeedback.mediumImpact();
    try {
      final collisionWarning = await _checkPhoneRoleCollision(newPhone);
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
      // Real send: 2Factor via sendPhoneOTP.ts. Effective channel (SMS or
      // voice — see Phase 22) is whatever the server actually used; this
      // screen doesn't need to know which.
      final result = await authProvider.sendPhoneOTP('+91$newPhone');

      if (!_ownsForm) return;

      if (result == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not send a verification code. Please try again.';
        });
        return;
      }

      setState(() {
        _isLoading = false;
        _sentTarget = newPhone;
        _otp = '';
        _step = _PhoneStep.verify;
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
      final newPhone = _sentTarget;
      final authProvider = _openingProvider;

      // Real, server-side verification — changePhoneNumber.ts checks
      // enteredOtp against the actual phone_otp_codes/{+91newPhone} document
      // and, only on a real match, writes it onto this account.
      final success = await authProvider.changePhoneNumber(
        phone: '+91$newPhone',
        otp: _otp,
      );

      if (!_ownsForm) return;

      if (!success) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not update your mobile number. Please try again.';
          _otp = '';
        });
        return;
      }

      _countdownTimer?.cancel();
      setState(() {
        _isLoading = false;
        _savedPhone = '+91$newPhone';
        _step = _PhoneStep.success;
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
      appBar: _step == _PhoneStep.success
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
                'Change Phone Number',
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
      case _PhoneStep.intro:
        return _buildIntroStep(isDark);
      case _PhoneStep.enterNumber:
        return _buildEnterNumberStep(isDark);
      case _PhoneStep.verify:
        return _buildVerifyStep(isDark);
      case _PhoneStep.success:
        return VerificationSuccessView(
          title: 'Phone Number Updated!',
          subtitle: 'Your new phone number has been successfully linked to your account.',
          valueIcon: Icons.phone_outlined,
          valueLabel: 'New Phone Number',
          value: _savedPhone,
          isDark: isDark,
          onDone: () {
            if (_ownsForm && ModalRoute.of(context)?.isCurrent == true) {
              Navigator.pop(context, _savedPhone);
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
            icon: Icons.phonelink_lock_rounded,
            title: 'Keep your account secure',
            subtitle: "We'll verify your new phone number with an OTP before updating.",
            isDark: isDark,
          ),
          const SizedBox(height: 28),
          LockedValueCard(
            icon: Icons.phone_outlined,
            label: 'Current Phone Number',
            value: widget.currentPhone,
            isDark: isDark,
          ),
          const SizedBox(height: 28),
          VerificationPrimaryButton(
            label: 'Continue',
            isLoading: false,
            enabled: true,
            isDark: isDark,
            onPressed: () {
              if (_ownsForm) setState(() => _step = _PhoneStep.enterNumber);
            },
          ),
          const SizedBox(height: 14),
          Text(
            'Your current number will remain active until the new number is verified.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildEnterNumberStep(bool isDark) {
    final hasInput = _phoneController.text.trim().isNotEmpty;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          VerificationStepHeader(
            icon: Icons.smartphone_rounded,
            title: 'Enter New Phone Number',
            subtitle: 'Enter the phone number you want to link to your account.',
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
            child: Row(
              children: [
                Text(
                  '+91',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.textLight : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Container(width: 1, height: 24, color: isDark ? Colors.grey[800] : Colors.grey.shade300),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    enabled: !_isLoading,
                    keyboardType: TextInputType.phone,
                    autofocus: true,
                    maxLength: 10,
                    cursorColor: AppColors.primary,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.textLight : AppColors.textPrimary,
                      letterSpacing: 0.5,
                    ),
                    decoration: const InputDecoration(
                      counterText: '',
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 16),
                      hintText: 'Enter new phone number',
                      hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          InfoCallout(
            isDark: isDark,
            bullets: const [
              'Enter a valid and active number',
              "You'll receive an OTP for verification",
              'Your current number will remain active until the new number is verified',
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
            label: 'Send OTP',
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
            icon: Icons.sms_outlined,
            title: 'Verify Phone Number',
            subtitle: 'We\'ve sent a 6-digit OTP to\n+91 $_sentTarget',
            isDark: isDark,
          ),
          const SizedBox(height: 28),
          OtpBoxesDisplay(otp: _otp, isDark: isDark),
          const SizedBox(height: 14),
          Center(
            child: _resendCountdown > 0
                ? Text(
                    "Didn't receive the OTP? Resend in ${_resendCountdown.toString().padLeft(2, '0')}s",
                    style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600], fontSize: 12.5, fontWeight: FontWeight.w600),
                  )
                : GestureDetector(
                    onTap: () {
                      if (!_ownsForm || _isLoading) return;
                      setState(() => _otp = '');
                      _handleSendOtp();
                    },
                    child: Text(
                      "Didn't receive the OTP? Resend now",
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
