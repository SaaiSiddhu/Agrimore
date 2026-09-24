import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/seller_auth_provider.dart';
import 'widgets/auth_error_banner.dart';

/// A-04 Sign in with email (board 16-01 panel 02; reset sheet 16-02 panel 03)
/// — legacy, admin-created accounts only. New sellers are never offered email
/// sign-up. Only the look changed in the redesign.
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
  String? _notice;
  SellerTone _noticeTone = SellerTone.info;

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
        _noticeTone = SellerTone.warning;
      });
      return;
    }
    final confirmed = await showSellerSheet<bool>(
      context,
      title: l10n.resetSheetTitle,
      builder: (ctx) => Text(l10n.resetSheetBody(email), style: ctx.text.bodyLarge),
      footer: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SellerButton(label: l10n.resetSendCta, onPressed: () => Navigator.of(ctx).pop(true)),
          const SizedBox(height: SellerSpace.s8),
          SellerButton.secondary(label: l10n.cancel, onPressed: () => Navigator.of(ctx).pop(false)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await context.read<SellerAuthProvider>().sendPasswordReset(email);
    if (!mounted) return;
    setState(() {
      _notice = ok ? l10n.resetSent : l10n.resetFailed;
      _noticeTone = ok ? SellerTone.success : SellerTone.danger;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = context.watch<SellerAuthProvider>();
    final c = context.colors;
    final text = context.text;
    final inset = context.pageInset;

    return Scaffold(
      appBar: SellerAppBar.backOnly(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(inset, SellerSpace.s8, inset, SellerSpace.s32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: SellerSize.formMaxWidth),
              child: Form(
                key: _formKey,
                child: SellerFormScope(
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(l10n.emailTitle, style: text.headlineMedium, textAlign: TextAlign.center),
                        ),
                        const SizedBox(height: SellerSpace.s8),
                        Text(
                          l10n.emailSubhead,
                          style: text.bodyLarge!.copyWith(color: c.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: SellerSpace.s32),
                        AuthErrorBanner(error: auth.lastError, serverMessage: auth.lastErrorMessage),
                        if (_notice != null) ...[
                          SellerBanner(tone: _noticeTone, message: _notice!, announce: true),
                          const SizedBox(height: SellerSpace.s16),
                        ],
                        SellerTextField(
                          label: l10n.emailLabel,
                          hint: l10n.emailHint,
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          prefixIcon: SellerIcons.mail,
                          enabled: !auth.isBusy,
                          validator: (v) => _email.hasMatch(v.trim()) ? null : l10n.emailErrorInvalid,
                        ),
                        const SizedBox(height: SellerSpace.s16),
                        SellerTextField(
                          label: l10n.passwordLabel,
                          controller: _passwordController,
                          obscure: true,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          prefixIcon: SellerIcons.lock,
                          enabled: !auth.isBusy,
                          validator: (v) => v.isEmpty ? l10n.passwordErrorEmpty : null,
                          onSubmitted: (_) => _submit(),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: SellerButton.tertiary(label: l10n.forgotPassword, onPressed: auth.isBusy ? null : _reset),
                        ),
                        const SizedBox(height: SellerSpace.s8),
                        SellerButton(
                          label: l10n.emailSignInCta,
                          loadingLabel: l10n.signingIn,
                          loading: auth.isBusy,
                          onPressed: auth.isBusy ? null : _submit,
                        ),
                        const SizedBox(height: SellerSpace.s24),
                        SellerBanner(tone: SellerTone.brand, icon: SellerIcons.info, message: l10n.addPhoneNudge),
                      ],
                    ),
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
