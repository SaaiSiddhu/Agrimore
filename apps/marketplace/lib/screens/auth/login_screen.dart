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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,
        // Stack, not a Column split into two adjacent regions: the hero
        // image is the full-screen background and the sheet floats OVER
        // its lower portion, overlapping — matching the reference
        // composition ("the bottom sheet should visually feel like it is
        // resting over the hero image", never a separate flat region with
        // its own dead space below the photo). The sheet sizes itself to
        // its own content (see _buildPhoneSheet) and is capped at 62% of
        // the screen so it can grow for a taller state without ever
        // swallowing the whole hero.
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
                      constraints: BoxConstraints(maxHeight: constraints.maxHeight * 0.62),
                      child: _buildPhoneSheet(),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // Full-bleed image (edge-to-edge, no letterboxing), top-aligned so the
  // brand content baked into login_full_hero.png (wordmark, tagline, the
  // three value-prop icons) stays in frame across aspect ratios. That
  // content is part of the supplied image itself, not drawn here, so no
  // overlay text is rendered on top of it — nothing to duplicate or
  // compete with. Status bar icons are forced dark (see build()) since the
  // image's top is bright sky/greenery, not the dark hero this replaces.
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

  Widget _buildPhoneSheet() {
    final topGroup = Form(
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        // A floating shadow, not a border — this sheet now sits ON TOP of
        // the hero image (see build()'s Stack), so it needs to visually
        // lift off the photo behind it rather than blend into an adjacent
        // flat background.
        boxShadow: [
          BoxShadow(color: AppColors.shadowLight, blurRadius: 28, offset: Offset(0, -8)),
        ],
      ),
      // Sized to its own content (mainAxisSize.min), not stretched to fill a
      // fixed region — a short state (phone entry) overlaps only a little of
      // the hero; a taller state (after AUTH-2 adds inline OTP entry) will
      // naturally overlap more, exactly as the reference intends. Still
      // wrapped in SingleChildScrollView so it degrades to a scrollable sheet
      // rather than overflowing if content ever exceeds the maxHeight cap
      // build() applies (heavy accessibility text scaling, a short device).
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    topGroup,
                    const SizedBox(height: 16),
                    termsText,
                  ],
                ),
              ),
            ),
          ],
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
