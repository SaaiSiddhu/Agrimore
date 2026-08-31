// lib/screens/user/profile/change_phone_screen.dart
// Change mobile number with real, server-verified OTP (2Factor via
// sendPhoneOTP.ts, verified server-side by changePhoneNumber.ts — see that
// file's header comment for why it is not the login-purpose verifyPhoneOTP).
//
// UI/UX ported from the reference build's screen of the same name; the
// verification step was rebuilt from scratch. The reference screen's
// "verify" step compared the entered code to a hardcoded local constant
// ('123456') and auto-filled the OTP boxes with it after "sending" — the
// exact account-takeover shape this codebase's Phase 14 removed from the
// login flow. Neither is present here: every code is checked against the
// real phone_otp_codes/{phone} document sendPhoneOTP.ts writes, entirely
// server-side.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:agrimore_ui/agrimore_ui.dart';

import '../../../providers/auth_provider.dart' as app_auth;
import '../../../providers/theme_provider.dart';

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
  final _phoneController = TextEditingController();
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  String? _errorMessage;
  String? _roleCollisionWarning;
  bool _isOtpSent = false;
  int _resendCountdown = 30;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() {
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
    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var f in _otpFocusNodes) {
      f.dispose();
    }
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _resendCountdown = 30);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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
    final currentUid = auth.FirebaseAuth.instance.currentUser?.uid;
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');

    try {
      final sellerSnap = await FirebaseFirestore.instance
          .collection('sellers')
          .where('phone', isEqualTo: cleanPhone)
          .limit(1)
          .get();
      if (sellerSnap.docs.isNotEmpty && sellerSnap.docs.first.id != currentUid) {
        return 'This phone number is already registered as an Agrimore Seller account.';
      }

      final employeeSnap = await FirebaseFirestore.instance
          .collection('employees')
          .where('phone', isEqualTo: cleanPhone)
          .limit(1)
          .get();
      if (employeeSnap.docs.isNotEmpty && employeeSnap.docs.first.id != currentUid) {
        return 'This phone number is already registered as an Agrimore Employee / Staff account.';
      }

      final usersSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: cleanPhone)
          .limit(1)
          .get();
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
    final newPhone = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');

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

    final collisionWarning = await _checkPhoneRoleCollision(newPhone);
    if (collisionWarning != null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _roleCollisionWarning = collisionWarning;
      });
      return;
    }

    if (!mounted) return;
    final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
    // Real send: 2Factor via sendPhoneOTP.ts. Effective channel (SMS or
    // voice — see Phase 22) is whatever the server actually used; this
    // screen doesn't need to know which.
    final result = await authProvider.sendPhoneOTP('+91$newPhone');

    if (!mounted) return;

    if (result == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = authProvider.error ?? 'Failed to send verification code';
      });
      return;
    }

    setState(() {
      _isLoading = false;
      _isOtpSent = true;
    });
    _startCountdown();
  }

  Future<void> _handleVerifyAndSave() async {
    final enteredOtp = _otpControllers.map((c) => c.text).join();
    if (enteredOtp.length != 6) {
      setState(() => _errorMessage = 'Please enter the 6-digit OTP');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    HapticFeedback.mediumImpact();

    final newPhone = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);

    // Real, server-side verification — changePhoneNumber.ts checks
    // enteredOtp against the actual phone_otp_codes/{+91newPhone} document
    // and, only on a real match, writes it onto this account.
    final success = await authProvider.changePhoneNumber(
      phone: '+91$newPhone',
      otp: enteredOtp,
    );

    if (!mounted) return;

    if (!success) {
      setState(() {
        _isLoading = false;
        _errorMessage = authProvider.error ?? 'Failed to update mobile number';
      });
      return;
    }

    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text(
              'Mobile number updated successfully!',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) Navigator.pop(context, '+91$newPhone');
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final hasInput = _phoneController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : Colors.white,
      appBar: AppBar(
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
          'Change mobile number',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.textLight : AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            height: 1,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isOtpSent
                          ? 'Enter the 6-digit OTP sent to +91 ${_phoneController.text.trim()} for verification.'
                          : 'Enter a new mobile number, and we will send an OTP for verification.',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? AppColors.textLightSecondary : const Color(0xFF334155),
                        fontWeight: FontWeight.w600,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 36),
                    if (!_isOtpSent) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mobile number',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                '+91  ',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? AppColors.textLight : AppColors.textPrimary,
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _phoneController,
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
                                  decoration: InputDecoration(
                                    counterText: '',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                    hintText: 'Enter 10-digit mobile',
                                    hintStyle: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    enabledBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                                    ),
                                    focusedBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(color: AppColors.primaryDark, width: 2.2),
                                    ),
                                    suffixIcon: _phoneController.text.isNotEmpty
                                        ? GestureDetector(
                                            onTap: () => _phoneController.clear(),
                                            child: Padding(
                                              padding: const EdgeInsets.all(4),
                                              child: Icon(
                                                Icons.close_rounded,
                                                size: 18,
                                                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                              ),
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ] else ...[
                      _buildOtpBoxes(isDark),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () => setState(() => _isOtpSent = false),
                            child: Text(
                              'Change number',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          _resendCountdown > 0
                              ? Text(
                                  'Resend OTP in ${_resendCountdown}s',
                                  style: TextStyle(
                                    color: isDark
                                        ? AppColors.textLightTertiary
                                        : const Color(0xFF94A3B8),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              : GestureDetector(
                                  onTap: _handleSendOtp,
                                  child: Text(
                                    'Resend OTP',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                        ],
                      ),
                    ],
                    if (_roleCollisionWarning != null) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF3B1E1E) : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _roleCollisionWarning!,
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
                      ),
                    ],
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 18),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: (_isLoading || (!hasInput && !_isOtpSent))
                      ? null
                      : (_isOtpSent ? _handleVerifyAndSave : _handleSendOtp),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor:
                        isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Text(
                          _isOtpSent ? 'Verify & Update' : 'Send OTP',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: (_isOtpSent || hasInput)
                                ? Colors.white
                                : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                            letterSpacing: 0.2,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtpBoxes(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (index) {
        return SizedBox(
          width: 46,
          height: 54,
          child: TextField(
            controller: _otpControllers[index],
            focusNode: _otpFocusNodes[index],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 1,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: isDark ? AppColors.textLight : AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: isDark ? AppColors.surfaceDarkVariant : const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
            onChanged: (val) {
              if (val.isNotEmpty && index < 5) {
                _otpFocusNodes[index + 1].requestFocus();
              } else if (val.isEmpty && index > 0) {
                _otpFocusNodes[index - 1].requestFocus();
              }
              setState(() {});
            },
          ),
        );
      }),
    );
  }
}
