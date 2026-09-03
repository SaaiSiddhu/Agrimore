// ============================================================
//  AGRIMORE - LOGIN / SIGNUP SCREEN (Mobile Number + OTP)
//  Single unified screen for both new and returning users.
//  Zomato-style layout: dark hero header + phone number sheet.
// ============================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import 'otp_verification_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _phoneFocusNode = FocusNode();
  final _formKey = GlobalKey<FormState>();

  List<String> _recentNumbers = [];
  bool _autofillSheetShown = false;
  bool _isSubmitting = false;

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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _SendingOtpDialog(),
    );

    final result = await authProvider.sendPhoneOTP(phone);

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // dismiss "Sending OTP"
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

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OtpVerificationScreen(phone: phone, channel: result.channel),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            Expanded(flex: 6, child: _buildHeroHeader()),
            Expanded(flex: 5, child: _buildPhoneSheet()),
          ],
        ),
      ),
    );
  }

  // Full-bleed image (edge-to-edge, no letterboxing) with the headline/ribbon
  // overlaid on top via a Stack — this also makes the header immune to
  // RenderFlex overflow on short viewports, since a Stack sizes its
  // non-positioned children to their own natural size instead of demanding
  // they all fit within a fixed-size Column.
  Widget _buildHeroHeader() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/login_hero.png',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withValues(alpha: 0.85), Colors.black.withValues(alpha: 0.35), Colors.transparent],
              stops: const [0.0, 0.5, 0.85],
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.only(top: 20, left: 24, right: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "INDIA'S FARM-TO-\nTABLE MARKETPLACE",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Transform.rotate(
                    angle: -0.04,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: const Text(
                        'AgriMore',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static const double _fieldHeight = 52;

  Widget _buildPhoneSheet() {
    final topGroup = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Log in or sign up',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
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
    );

    final termsText = Center(
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

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      // LayoutBuilder + ConstrainedBox(minHeight) + spaceBetween (not Expanded/
      // Spacer, which would need bounded height) pushes the terms text down to
      // just above the bottom edge when there's room, and — since the whole
      // thing is wrapped in a SingleChildScrollView — degrades to a scrollable
      // sheet instead of overflowing when the space is squeezed (small screens,
      // keyboard open).
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: (constraints.maxHeight - 44).clamp(0.0, double.infinity)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    topGroup,
                    const SizedBox(height: 16),
                    termsText,
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SendingOtpDialog extends StatelessWidget {
  const _SendingOtpDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
            ),
            const SizedBox(width: 18),
            const Text('Sending OTP', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
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
