import 'dart:async';

import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/seller_auth_provider.dart';
import 'email_sign_in_screen.dart';
import 'widgets/auth_brand_panel.dart';
import 'widgets/auth_error_banner.dart';

/// A-01 Sign in + A-02 Verify OTP + A-03 Google linking (ADR §10.1).
///
/// One screen, two steps driven by [SellerAuthProvider.pendingPhone]. The
/// auth gate in `app.dart` routes away on success.
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

  // ── Actions ────────────────────────────────────────────────────────────────

  String? _validatePhone(String? value, AppLocalizations l10n) {
    final v = value?.trim() ?? '';
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
      _otpController.text = code; // WsOtpInput.onCompleted submits it
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

  Future<void> _open(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<SellerAuthProvider>();
    final layout = wsLayoutFor(MediaQuery.sizeOf(context).width);
    final wide = layout == WsLayout.expanded || layout == WsLayout.large;

    final form = _FormColumn(
      child: auth.pendingPhone == null ? _phoneStep(context, auth) : _otpStep(context, auth),
    );

    return Scaffold(
      body: SafeArea(
        child: wide
            ? Row(
                children: [
                  const Expanded(child: AuthBrandPanel()),
                  Expanded(child: Center(child: form)),
                ],
              )
            : form,
      ),
    );
  }

  Widget _phoneStep(BuildContext context, SellerAuthProvider auth) {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    final text = context.wsText;
    final google = auth.pendingGoogle;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthWordmark(),
          const SizedBox(height: WsSpace.s32),
          Text(l10n.authHeadline, style: text.headlineMedium),
          const SizedBox(height: WsSpace.s8),
          Text(l10n.authSubhead, style: text.bodyLarge!.copyWith(color: t.textSecondary)),
          const SizedBox(height: WsSpace.s32),
          if (google != null) ...[
            SaInfoBanner(
              variant: SaBannerVariant.info,
              title: l10n.googleLinkingTitle,
              message: l10n.googleLinkingBody(google.email ?? ''),
              actionLabel: l10n.googleLinkingCancel,
              onAction: auth.cancelGoogleLink,
            ),
            const SizedBox(height: WsSpace.s16),
          ],
          AuthErrorBanner(error: auth.lastError, serverMessage: auth.lastErrorMessage),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.telephoneNumberNational],
            maxLength: _nationalDigits,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: text.bodyLarge!.copyWith(fontFeatures: WsType.tabularFigures),
            decoration: InputDecoration(
              labelText: l10n.phoneLabel,
              hintText: l10n.phoneHint,
              prefixText: '${l10n.phonePrefix} ',
              prefixIcon: const Icon(AgIcons.phone, size: WsIconSize.control),
              counterText: '',
            ),
            validator: (v) => _validatePhone(v, l10n),
            onFieldSubmitted: (_) => _sendOtp(),
          ),
          const SizedBox(height: WsSpace.s16),
          SaLoadingButton(
            text: l10n.getOtpCta,
            loadingText: l10n.sendingOtp,
            isLoading: auth.isBusy,
            onPressed: auth.isBusy ? null : _sendOtp,
          ),
          if (google == null) ...[
            const SizedBox(height: WsSpace.s24),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: WsSpace.s12),
                  child: Text(l10n.orDivider, style: text.bodySmall),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: WsSpace.s24),
            SaLoadingButton(
              text: l10n.googleCta,
              variant: SaButtonVariant.outlined,
              icon: AgIcons.user,
              onPressed: auth.isBusy ? null : _google,
            ),
            const SizedBox(height: WsSpace.s8),
            TextButton(
              onPressed: auth.isBusy
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const EmailSignInScreen()),
                      ),
              child: Text(l10n.emailSignInLink),
            ),
          ],
          const SizedBox(height: WsSpace.s24),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(l10n.legalPrefix, style: text.bodySmall),
              TextButton(onPressed: () => _open(AppConstants.termsUrl), child: Text(l10n.legalTerms)),
              Text(l10n.legalAnd, style: text.bodySmall),
              TextButton(onPressed: () => _open(AppConstants.privacyPolicyUrl), child: Text(l10n.legalPrivacy)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _otpStep(BuildContext context, SellerAuthProvider auth) {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    final text = context.wsText;
    final masked = AgFormat.maskPhone(auth.pendingPhone ?? '');
    final sentCopy = auth.otpChannel == 'voice' ? l10n.otpSentVoice(masked) : l10n.otpSentSms(masked);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            tooltip: l10n.back,
            onPressed: auth.isBusy ? null : _changeNumber,
            icon: const Icon(AgIcons.arrowLeft),
          ),
        ),
        const SizedBox(height: WsSpace.s16),
        Text(l10n.otpTitle, style: text.headlineMedium),
        const SizedBox(height: WsSpace.s8),
        Row(
          children: [
            Flexible(child: Text(sentCopy, style: text.bodyLarge!.copyWith(color: t.textSecondary))),
            TextButton(onPressed: auth.isBusy ? null : _changeNumber, child: Text(l10n.otpChangeNumber)),
          ],
        ),
        const SizedBox(height: WsSpace.s24),
        if (auth.isTestMode) ...[
          WsTestModeRibbon(label: l10n.testModeRibbon),
          const SizedBox(height: WsSpace.s16),
        ],
        AuthErrorBanner(error: auth.lastError, serverMessage: auth.lastErrorMessage),
        WsOtpInput(
          controller: _otpController,
          length: _otpLength,
          enabled: !auth.isBusy,
          hasError: _otpIncomplete || auth.lastError == SellerAuthError.invalidCode,
          digitSemanticsLabel: (i) => l10n.otpDigitLabel(i),
          onCompleted: _verify,
        ),
        if (_otpIncomplete) ...[
          const SizedBox(height: WsSpace.s8),
          Text(l10n.otpErrorIncomplete, style: text.bodySmall!.copyWith(color: t.errorFg)),
        ],
        const SizedBox(height: WsSpace.s24),
        SaLoadingButton(
          text: l10n.otpVerifyCta,
          loadingText: l10n.otpVerifying,
          isLoading: auth.isBusy,
          onPressed: auth.isBusy ? null : _verify,
        ),
        const SizedBox(height: WsSpace.s16),
        if (_resendLeft > 0)
          Text(
            l10n.otpResendIn(_resendLeft),
            textAlign: TextAlign.center,
            style: text.bodySmall!.copyWith(fontFeatures: WsType.tabularFigures),
          )
        else
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              TextButton(onPressed: auth.isBusy ? null : () => _sendOtp(), child: Text(l10n.otpResend)),
              TextButton(
                onPressed: auth.isBusy ? null : () => _sendOtp(channel: 'voice'),
                child: Text(l10n.otpCallInstead),
              ),
            ],
          ),
      ],
    );
  }
}

/// Scrollable, width-capped form column shared by the auth screens.
class _FormColumn extends StatelessWidget {
  const _FormColumn({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: WsSpace.page, vertical: WsSpace.s32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: WsSize.formMaxWidth),
          child: child,
        ),
      ),
    );
  }
}
