import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/seller_auth_provider.dart';
import 'widgets/auth_brand_panel.dart';
import 'widgets/auth_error_banner.dart';

/// A-04 Sign in with email (ADR §10.1) — legacy, admin-created accounts only.
/// New sellers are never offered email sign-up.
class EmailSignInScreen extends StatefulWidget {
  const EmailSignInScreen({super.key});

  @override
  State<EmailSignInScreen> createState() => _EmailSignInScreenState();
}

class _EmailSignInScreenState extends State<EmailSignInScreen> {
  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  String? _notice;
  SaBannerVariant _noticeVariant = SaBannerVariant.info;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final ok = await context
        .read<SellerAuthProvider>()
        .signInWithEmail(_emailController.text.trim(), _passwordController.text);
    if (ok && mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _reset() async {
    final l10n = AppLocalizations.of(context);
    final email = _emailController.text.trim();
    if (!_email.hasMatch(email)) {
      setState(() {
        _notice = l10n.resetNeedsEmail;
        _noticeVariant = SaBannerVariant.warning;
      });
      return;
    }
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => _ResetSheet(email: email),
    );
    if (confirmed != true || !mounted) return;
    final ok = await context.read<SellerAuthProvider>().sendPasswordReset(email);
    if (ok && mounted) {
      setState(() {
        _notice = l10n.resetSent;
        _noticeVariant = SaBannerVariant.success;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = context.watch<SellerAuthProvider>();
    final t = context.ws;
    final text = context.wsText;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.back,
          icon: const Icon(AgIcons.arrowLeft),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: WsSpace.page, vertical: WsSpace.s16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: WsSize.formMaxWidth),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AuthWordmark(),
                      const SizedBox(height: WsSpace.s32),
                      Text(l10n.emailTitle, style: text.headlineMedium),
                      const SizedBox(height: WsSpace.s8),
                      Text(l10n.emailSubhead, style: text.bodyLarge!.copyWith(color: t.textSecondary)),
                      const SizedBox(height: WsSpace.s24),
                      AuthErrorBanner(error: auth.lastError, serverMessage: auth.lastErrorMessage),
                      if (_notice != null) ...[
                        SaInfoBanner(variant: _noticeVariant, message: _notice!),
                        const SizedBox(height: WsSpace.s16),
                      ],
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        decoration: InputDecoration(
                          labelText: l10n.emailLabel,
                          prefixIcon: const Icon(AgIcons.mail, size: WsIconSize.control),
                        ),
                        validator: (v) => _email.hasMatch(v?.trim() ?? '') ? null : l10n.emailErrorInvalid,
                      ),
                      const SizedBox(height: WsSpace.s16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: l10n.passwordLabel,
                          prefixIcon: const Icon(AgIcons.lock, size: WsIconSize.control),
                          suffixIcon: IconButton(
                            tooltip: _obscure ? l10n.showPassword : l10n.hidePassword,
                            icon: Icon(_obscure ? AgIcons.eye : AgIcons.eyeOff, size: WsIconSize.control),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => (v ?? '').isEmpty ? l10n.passwordErrorEmpty : null,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: auth.isBusy ? null : _reset,
                          child: Text(l10n.forgotPassword),
                        ),
                      ),
                      const SizedBox(height: WsSpace.s8),
                      SaLoadingButton(
                        text: l10n.emailSignInCta,
                        loadingText: l10n.signingIn,
                        isLoading: auth.isBusy,
                        onPressed: auth.isBusy ? null : _submit,
                      ),
                      const SizedBox(height: WsSpace.s24),
                      SaInfoBanner(variant: SaBannerVariant.info, message: l10n.addPhoneNudge),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResetSheet extends StatelessWidget {
  const _ResetSheet({required this.email});
  final String email;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = context.wsText;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(WsSpace.page, 0, WsSpace.page, WsSpace.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.resetSheetTitle, style: text.titleMedium),
            const SizedBox(height: WsSpace.s8),
            Text(l10n.resetSheetBody(email), style: text.bodyLarge),
            const SizedBox(height: WsSpace.s24),
            SaLoadingButton(text: l10n.resetSendCta, onPressed: () => Navigator.of(context).pop(true)),
            const SizedBox(height: WsSpace.s8),
            SaLoadingButton(
              text: l10n.cancel,
              variant: SaButtonVariant.outlined,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}
