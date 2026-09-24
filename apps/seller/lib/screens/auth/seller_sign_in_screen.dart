import 'dart:async';

import 'package:agrimore_core/agrimore_core.dart' show AppConstants;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/seller_auth_provider.dart';
import 'email_sign_in_screen.dart';
import 'widgets/auth_brand_panel.dart';
import 'widgets/auth_error_banner.dart';

/// A-01 Sign in (board 16-01) + A-02 Verify OTP (16-02) + A-03 Google
/// mobile verification (16-01 panel 03).
///
/// One screen, two steps driven by [SellerAuthProvider.pendingPhone]. The
/// auth gate in `app.dart` routes away on success. Only the look changed in
/// the redesign; every call into [SellerAuthProvider] is as before.
class SellerSignInScreen extends StatefulWidget {
  const SellerSignInScreen({super.key});

  @override
  State<SellerSignInScreen> createState() => _SellerSignInScreenState();
}

class _SellerSignInScreenState extends State<SellerSignInScreen> {
  static const String _countryCode = '+91';
  static const int _nationalDigits = 10;
  static const int _otpLength = 6;
  static const int _resendCooldownSeconds = 30;
  static const int _tickSeconds = 1;
  static final RegExp _indianMobile = RegExp(r'^[6-9]\d{9}$');

  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  Timer? _resendTimer;
  int _resendLeft = 0;
  bool _otpIncomplete = false;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // ── Actions (unchanged by the redesign) ───────────────────────────────────

  String? _validatePhone(String value, AppLocalizations l10n) {
    final v = value.trim();
    if (v.isEmpty) return l10n.phoneErrorEmpty;
    if (!_indianMobile.hasMatch(v)) return l10n.phoneErrorInvalid;
    return null;
  }

  Future<void> _sendOtp({String channel = 'sms'}) async {
    final auth = context.read<SellerAuthProvider>();
    if (auth.pendingPhone == null && !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();
    final phone = auth.pendingPhone ?? '$_countryCode${_phoneController.text.trim()}';
    final ok = await auth.sendOtp(phone, channel: channel);
    if (!mounted || !ok) return;
    _otpController.clear();
    setState(() => _otpIncomplete = false);
    _startResendCountdown();
    final code = auth.testOtp;
    if (code != null && code.length == _otpLength) {
      _otpController.text = code; // SellerOtpInput.onCompleted submits it
    }
  }

  Future<void> _verify([String? code]) async {
    final value = code ?? _otpController.text;
    if (value.length != _otpLength) {
      setState(() => _otpIncomplete = true);
      return;
    }
    setState(() => _otpIncomplete = false);
    final auth = context.read<SellerAuthProvider>();
    final ok = await auth.verifyOtp(value);
    if (!mounted) return;
    if (ok) {
      HapticFeedback.lightImpact();
    } else {
      _otpController.clear();
    }
  }

  Future<void> _google() async {
    final auth = context.read<SellerAuthProvider>();
    FocusScope.of(context).unfocus();
    await auth.continueWithGoogle();
  }

  void _changeNumber() {
    _resendTimer?.cancel();
    _otpController.clear();
    context.read<SellerAuthProvider>().resetOtp();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendLeft = _resendCooldownSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: _tickSeconds), (timer) {
      if (!mounted) return timer.cancel();
      if (_resendLeft <= _tickSeconds) {
        timer.cancel();
        setState(() => _resendLeft = 0);
      } else {
        setState(() => _resendLeft -= _tickSeconds);
      }
    });
  }

  void _openEmail() => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const EmailSignInScreen()));

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<SellerAuthProvider>();
    final layout = context.layout;
    final wide = layout == SellerLayout.expanded || layout == SellerLayout.large;
    final otp = auth.pendingPhone != null;
    final linking = !otp && auth.pendingGoogle != null;

    // Test mode: the cells always show the code the banner says was filled in.
    final code = auth.testOtp;
    if (otp && code != null && _otpController.text.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _otpController.text.isEmpty) _otpController.text = code;
      });
    }

    final Widget step = otp
        ? _otpStep(context, auth)
        : linking
            ? _googleStep(context, auth)
            : _phoneStep(context, auth, showIntro: !wide);

    final form = _FormColumn(child: step);
    return Scaffold(
      appBar: otp || linking
          ? SellerAppBar.backOnly(context, onBack: auth.isBusy ? () {} : (otp ? _changeNumber : auth.cancelGoogleLink))
          : null,
      body: SafeArea(
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Expanded(child: AuthBrandPanel()),
                  Expanded(child: Center(child: form)),
                ],
              )
            : form,
      ),
    );
  }

  Widget _phoneField(AppLocalizations l10n, SellerAuthProvider auth) {
    return SellerTextField(
      label: l10n.phoneLabel,
      hint: l10n.phoneHint,
      controller: _phoneController,
      prefixText: l10n.phonePrefix,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.telephoneNumberNational],
      maxLength: _nationalDigits,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      tabular: true,
      enabled: !auth.isBusy,
      trailing: auth.isBusy ? const Padding(padding: EdgeInsets.all(SellerSpace.s12), child: SellerSpinner()) : null,
      validator: (v) => _validatePhone(v, l10n),
      onSubmitted: (_) => _sendOtp(),
    );
  }

  Widget _getOtpButton(AppLocalizations l10n, SellerAuthProvider auth) => SellerButton(
        label: l10n.getOtpCta,
        loadingLabel: l10n.sendingOtp,
        loading: auth.isBusy,
        onPressed: auth.isBusy ? null : _sendOtp,
      );

  /// Board 16-01 panel 01: logo, landscape, headline, number, Get OTP, OR,
  /// Google, email link, legal line.
  Widget _phoneStep(BuildContext context, SellerAuthProvider auth, {required bool showIntro}) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final text = context.text;

    return Form(
      key: _formKey,
      child: SellerFormScope(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // On wide layouts the brand panel already carries these.
            if (showIntro) ...[
              const Center(child: SellerLogo(large: true)),
              const SizedBox(height: SellerSpace.s16),
              const SellerFarmScene(),
              const SizedBox(height: SellerSpace.s16),
              Semantics(
                header: true,
                child: Text(l10n.authHeadline, style: text.headlineMedium, textAlign: TextAlign.center),
              ),
              const SizedBox(height: SellerSpace.s8),
              Text(
                l10n.authSubhead,
                style: text.bodyLarge!.copyWith(color: c.textSecondary),
                textAlign: TextAlign.center,
              ),
            ] else
              Semantics(header: true, child: Text(l10n.authSubhead, style: text.titleLarge)),
            const SizedBox(height: SellerSpace.s24),
            AuthErrorBanner(error: auth.lastError, serverMessage: auth.lastErrorMessage),
            _phoneField(l10n, auth),
            const SizedBox(height: SellerSpace.s16),
            _getOtpButton(l10n, auth),
            const SellerOrDivider(),
            SellerButton.secondary(
              label: l10n.googleCta,
              onPressed: auth.isBusy ? null : _google,
              leading: const SellerGoogleMark(),
            ),
            const SizedBox(height: SellerSpace.s8),
            Center(
              child: SellerButton.tertiary(label: l10n.emailSignInLink, onPressed: auth.isBusy ? null : _openEmail),
            ),
            const SizedBox(height: SellerSpace.s16),
            const _LegalLine(),
          ],
        ),
      ),
    );
  }

  /// Board 16-01 panel 03: Google account not linked yet — verify the mobile
  /// number once and the provider links Google to it.
  Widget _googleStep(BuildContext context, SellerAuthProvider auth) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final text = context.text;
    final google = auth.pendingGoogle!;

    return Form(
      key: _formKey,
      child: SellerFormScope(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: SellerGoogleMark(size: SellerIconSize.xl)),
            const SizedBox(height: SellerSpace.s16),
            Semantics(
              header: true,
              child: Text(l10n.googleLinkingTitle, style: text.headlineMedium, textAlign: TextAlign.center),
            ),
            const SizedBox(height: SellerSpace.s8),
            Text(
              l10n.googleLinkingIntro,
              style: text.bodyLarge!.copyWith(color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: SellerSpace.s24),
            SellerBanner(
              tone: SellerTone.brand,
              icon: SellerIcons.phone,
              message: l10n.googleLinkingBody(google.email ?? ''),
            ),
            const SizedBox(height: SellerSpace.s16),
            AuthErrorBanner(error: auth.lastError, serverMessage: auth.lastErrorMessage),
            _phoneField(l10n, auth),
            const SizedBox(height: SellerSpace.s16),
            _getOtpButton(l10n, auth),
            const SizedBox(height: SellerSpace.s8),
            Center(
              child: SellerButton.tertiary(
                label: l10n.googleLinkingCancel,
                onPressed: auth.isBusy ? null : auth.cancelGoogleLink,
              ),
            ),
            const SizedBox(height: SellerSpace.s24),
            const _LegalLine(),
          ],
        ),
      ),
    );
  }

  /// Board 16-02 panels 01–02: six boxes, verify, resend countdown, then
  /// "Resend code | Get a call instead"; a wrong code is said under the boxes.
  Widget _otpStep(BuildContext context, SellerAuthProvider auth) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final text = context.text;
    final masked = SellerFormat.maskPhone(auth.pendingPhone ?? '');
    final sentCopy = auth.otpChannel == 'voice' ? l10n.otpSentVoice(masked) : l10n.otpSentSms(masked);
    final wrong = auth.lastError == SellerAuthError.invalidCode;
    final String? inlineError = _otpIncomplete
        ? l10n.otpErrorIncomplete
        : wrong
            ? (auth.lastErrorMessage ?? l10n.otpErrorWrong)
            : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(header: true, child: Text(l10n.otpTitle, style: text.headlineMedium)),
        const SizedBox(height: SellerSpace.s4),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: SellerSpace.s4,
          children: [
            Text(sentCopy, style: text.bodyLarge!.copyWith(color: c.textSecondary).tabular),
            SellerButton.tertiary(label: l10n.otpChangeNumber, onPressed: auth.isBusy ? null : _changeNumber),
          ],
        ),
        const SizedBox(height: SellerSpace.s24),
        if (auth.isTestMode) ...[
          SellerBanner(tone: SellerTone.warning, message: l10n.testModeRibbon),
          const SizedBox(height: SellerSpace.s16),
        ],
        AuthErrorBanner(error: auth.lastError, serverMessage: auth.lastErrorMessage),
        SellerOtpInput(
          controller: _otpController,
          length: _otpLength,
          enabled: !auth.isBusy,
          hasError: inlineError != null,
          onCompleted: _verify,
        ),
        if (inlineError != null) ...[
          const SizedBox(height: SellerSpace.s12),
          AuthInlineError(message: inlineError),
        ],
        const SizedBox(height: SellerSpace.s24),
        SellerButton(
          label: l10n.otpVerifyCta,
          loadingLabel: l10n.otpVerifying,
          loading: auth.isBusy,
          onPressed: auth.isBusy ? null : _verify,
        ),
        const SizedBox(height: SellerSpace.s16),
        if (_resendLeft > 0)
          Text(
            l10n.otpResendIn(_resendLeft),
            textAlign: TextAlign.center,
            style: text.bodyMedium!.copyWith(color: c.textSecondary).tabular,
          )
        else
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: SellerSpace.s8,
            children: [
              SellerButton.tertiary(label: l10n.otpResend, onPressed: auth.isBusy ? null : () => _sendOtp()),
              ExcludeSemantics(
                child: SizedBox(
                  height: SellerSpace.s16,
                  child: VerticalDivider(width: SellerSize.hairline, thickness: SellerSize.hairline, color: c.border),
                ),
              ),
              SellerButton.tertiary(
                label: l10n.otpCallInstead,
                onPressed: auth.isBusy ? null : () => _sendOtp(channel: 'voice'),
              ),
            ],
          ),
      ],
    );
  }
}

/// "By continuing, you agree to our Terms of Service and Privacy Policy." —
/// one flowing sentence whose two links are real, focusable links.
class _LegalLine extends StatefulWidget {
  const _LegalLine();

  @override
  State<_LegalLine> createState() => _LegalLineState();
}

class _LegalLineState extends State<_LegalLine> {
  late final TapGestureRecognizer _terms = TapGestureRecognizer()..onTap = () => _open(AppConstants.termsUrl);
  late final TapGestureRecognizer _privacy = TapGestureRecognizer()
    ..onTap = () => _open(AppConstants.privacyPolicyUrl);

  Future<void> _open(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final base = context.text.bodySmall!.copyWith(color: c.textSecondary);
    final link = base.copyWith(color: c.primary, fontWeight: SellerType.semibold, decoration: TextDecoration.underline);
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: '${l10n.legalPrefix} '),
          TextSpan(text: l10n.legalTerms, style: link, recognizer: _terms),
          TextSpan(text: ' ${l10n.legalAnd} '),
          TextSpan(text: l10n.legalPrivacy, style: link, recognizer: _privacy),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// Scrollable, width-capped form column shared by the auth screens.
class _FormColumn extends StatelessWidget {
  const _FormColumn({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final inset = context.pageInset;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(inset, SellerSpace.s24, inset, SellerSpace.s32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: SellerSize.formMaxWidth),
          child: child,
        ),
      ),
    );
  }
}
