// lib/screens/auth/login_screen.dart
//
// Phase DLV-A1 — sign-in on the Workspace foundation: typed problems from the
// ARB file (never a raw FirebaseAuthException message), the password used
// exactly as typed, forgot-password with an account-safe reply, and the
// server-owned registration. The layout is the existing one (logo, title,
// card); the visual redesign is a separate, later pass.
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../auth/auth_copy.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import 'rider_registration_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();
    final auth = context.read<DeliveryAuthProvider>()..clearError();
    await auth.signIn(_emailController.text, _passwordController.text);
  }

  Future<void> _forgotPassword() async {
    final l = AppLocalizations.of(context);
    final email = TextEditingController(text: _emailController.text.trim());
    final auth = context.read<DeliveryAuthProvider>();
    RiderAuthProblem? problem;
    var sending = false;
    final sent = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(l.resetTitle),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.resetBody),
            const SizedBox(height: WsSpace.s12),
            TextField(
              key: const ValueKey('reset-email'),
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: l.fieldEmail,
                errorText: problem == null
                    ? null
                    : (problem == RiderAuthProblem.unknown ? l.resetFailed : authProblemText(l, problem!)),
              ),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.resetCancel)),
            FilledButton(
              key: const ValueKey('reset-send'),
              onPressed: sending
                  ? null
                  : () async {
                      setD(() => sending = true);
                      final p = await auth.sendPasswordReset(email.text);
                      if (!ctx.mounted) return;
                      if (p == null) {
                        Navigator.pop(ctx, true);
                      } else {
                        setD(() {
                          problem = p;
                          sending = false;
                        });
                      }
                    },
              child: Text(l.resetSend),
            ),
          ],
        ),
      ),
    );
    email.dispose();
    if (sent == true && mounted) WsToast.show(context, l.resetSent, tone: WsToastTone.success);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.ws;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(WsSpace.page),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: WsSize.formMaxWidth),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset('assets/images/logo.png', width: WsSize.thumbLg, height: WsSize.thumbLg),
                    const SizedBox(height: WsSpace.s16),
                    Text(l.appName, textAlign: TextAlign.center, style: text.headlineMedium?.copyWith(color: t.textPrimary)),
                    Text(l.splashTagline, textAlign: TextAlign.center, style: text.bodyLarge?.copyWith(color: t.textSecondary)),
                    const SizedBox(height: WsSpace.s32),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(WsSpace.s24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(l.signInTitle, style: text.titleLarge?.copyWith(color: t.textPrimary)),
                            const SizedBox(height: WsSpace.s4),
                            Text(l.signInSubtitle, style: text.bodyMedium?.copyWith(color: t.textSecondary)),
                            const SizedBox(height: WsSpace.s24),
                            TextFormField(
                              key: const ValueKey('login-email'),
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              decoration: InputDecoration(labelText: l.fieldEmail, prefixIcon: const Icon(AgIcons.mail)),
                              validator: (v) => (v == null || !v.contains('@')) ? l.errEmail : null,
                            ),
                            const SizedBox(height: WsSpace.s16),
                            TextFormField(
                              key: const ValueKey('login-password'),
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              autofillHints: const [AutofillHints.password],
                              onFieldSubmitted: (_) => _handleLogin(),
                              decoration: InputDecoration(
                                labelText: l.fieldPassword,
                                prefixIcon: const Icon(AgIcons.lock),
                                suffixIcon: IconButton(
                                  tooltip: _obscurePassword ? l.showPassword : l.hidePassword,
                                  icon: Icon(_obscurePassword ? AgIcons.eye : AgIcons.eyeOff),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              validator: (v) => (v == null || v.isEmpty) ? l.errPasswordEmpty : null,
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                key: const ValueKey('forgot-password'),
                                onPressed: _forgotPassword,
                                child: Text(l.forgotPassword),
                              ),
                            ),
                            Consumer<DeliveryAuthProvider>(builder: (context, auth, _) {
                              final problem = auth.problem;
                              if (problem == null) return const SizedBox.shrink();
                              return Semantics(
                                liveRegion: true,
                                child: Container(
                                  padding: const EdgeInsets.all(WsSpace.s12),
                                  margin: const EdgeInsets.only(bottom: WsSpace.s16),
                                  decoration: BoxDecoration(
                                    color: t.errorBg,
                                    borderRadius: BorderRadius.circular(WsRadius.input),
                                  ),
                                  child: Row(children: [
                                    Icon(AgIcons.error, color: t.errorFg, size: WsIconSize.control),
                                    const SizedBox(width: WsSpace.s8),
                                    Expanded(
                                      child: Text(authProblemText(l, problem),
                                          style: text.bodyMedium?.copyWith(color: t.errorFg)),
                                    ),
                                  ]),
                                ),
                              );
                            }),
                            Consumer<DeliveryAuthProvider>(
                              builder: (context, auth, _) => FilledButton(
                                key: const ValueKey('login-submit'),
                                onPressed: auth.signingIn ? null : _handleLogin,
                                child: auth.signingIn
                                    ? Semantics(label: l.signingIn, child: const CircularProgressIndicator.adaptive())
                                    : Text(l.signInAction),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: WsSpace.s24),
                    OutlinedButton(
                      key: const ValueKey('register'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const RiderRegistrationScreen()),
                      ),
                      child: Text(l.registerAction),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
