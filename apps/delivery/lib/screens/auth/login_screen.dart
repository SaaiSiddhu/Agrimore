// lib/screens/auth/login_screen.dart
//
// Phase DLV-A1 / Phase 15 — sign-in on the burnt-orange Delivery Design System:
// typed problems from the ARB file (never a raw FirebaseAuthException message),
// the password used exactly as typed, forgot-password with an account-safe
// reply, and the server-owned registration.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../auth/auth_copy.dart';
import '../../design_system/design_system.dart';
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
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final c = ctx.colors;
          final t = ctx.text;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              DeliverySpace.page,
              DeliverySpace.xxs,
              DeliverySpace.page,
              MediaQuery.of(ctx).viewInsets.bottom + DeliverySpace.xxl,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l.resetTitle,
                    style: t.headlineSmall.copyWith(color: c.textPrimary),
                  ),
                  const SizedBox(height: DeliverySpace.sm),
                  Text(
                    l.resetBody,
                    style: t.bodyMedium.copyWith(color: c.textSecondary),
                  ),
                  const SizedBox(height: DeliverySpace.md),
                  TextField(
                    key: const ValueKey('reset-email'),
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: l.fieldEmail,
                      prefixIcon: const Icon(DeliveryIcons.mail),
                      errorText: problem == null
                          ? null
                          : (problem == RiderAuthProblem.unknown
                              ? l.resetFailed
                              : authProblemText(l, problem!)),
                    ),
                  ),
                  const SizedBox(height: DeliverySpace.lg),
                  DeliveryButton.primary(
                    key: const ValueKey('reset-send'),
                    label: l.resetSend,
                    isLoading: sending,
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
                  ),
                  const SizedBox(height: DeliverySpace.sm),
                  DeliveryButton.ghost(
                    label: l.resetCancel,
                    onPressed: () => Navigator.pop(ctx, false),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    email.dispose();
    if (sent == true && mounted) {
      showDeliveryToast(
        context,
        message: l.resetSent,
        tone: DeliveryBannerTone.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final t = context.text;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(DeliverySpace.page),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: DeliverySize.formMaxWidth,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: DeliveryLogo(
                        title: l.appName,
                        subtitle: l.splashTagline,
                        markSize: DeliverySize.avatarXl,
                      ),
                    ),
                    const SizedBox(height: DeliverySpace.lg),
                    const DeliveryHeroIllustration(
                      height: DeliverySize.illustration,
                    ),
                    const SizedBox(height: DeliverySpace.lg),
                    DeliveryCard(
                      padding: const EdgeInsets.all(DeliverySpace.xxl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l.signInTitle,
                            style:
                                t.headlineSmall.copyWith(color: c.textPrimary),
                          ),
                          const SizedBox(height: DeliverySpace.xxs),
                          Text(
                            l.signInSubtitle,
                            style:
                                t.bodyMedium.copyWith(color: c.textSecondary),
                          ),
                          const SizedBox(height: DeliverySpace.xxl),
                          TextFormField(
                            key: const ValueKey('login-email'),
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            decoration: InputDecoration(
                              labelText: l.fieldEmail,
                              prefixIcon: const Icon(DeliveryIcons.mail),
                            ),
                            validator: (v) =>
                                (v == null || !v.contains('@')) ? l.errEmail : null,
                          ),
                          const SizedBox(height: DeliverySpace.lg),
                          TextFormField(
                            key: const ValueKey('login-password'),
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) => _handleLogin(),
                            decoration: InputDecoration(
                              labelText: l.fieldPassword,
                              prefixIcon: const Icon(DeliveryIcons.lock),
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? l.showPassword
                                    : l.hidePassword,
                                icon: Icon(
                                  _obscurePassword
                                      ? DeliveryIcons.eye
                                      : DeliveryIcons.eyeOff,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                            validator: (v) => (v == null || v.isEmpty)
                                ? l.errPasswordEmpty
                                : null,
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              key: const ValueKey('forgot-password'),
                              onPressed: _forgotPassword,
                              child: Text(l.forgotPassword),
                            ),
                          ),
                          Consumer<DeliveryAuthProvider>(
                            builder: (context, auth, _) {
                              final problem = auth.problem;
                              if (problem == null) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(
                                  bottom: DeliverySpace.lg,
                                ),
                                child: DeliveryBanner(
                                  tone: DeliveryBannerTone.danger,
                                  body: authProblemText(l, problem),
                                ),
                              );
                            },
                          ),
                          Consumer<DeliveryAuthProvider>(
                            builder: (context, auth, _) =>
                                DeliveryButton.primary(
                              key: const ValueKey('login-submit'),
                              label: l.signInAction,
                              icon: DeliveryIcons.login,
                              isLoading: auth.signingIn,
                              onPressed: auth.signingIn ? null : _handleLogin,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: DeliverySpace.xxl),
                    DeliveryButton.secondary(
                      key: const ValueKey('register'),
                      label: l.registerAction,
                      icon: DeliveryIcons.rider,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const RiderRegistrationScreen(),
                        ),
                      ),
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
