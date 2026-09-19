import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../providers/auth_provider.dart';

/// Screen allowing admin-created associates (who sign in with email/password)
/// to request a password reset email via Firebase Auth.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isSubmitting = false;
  bool _isSuccess = false;
  String? _sentEmail;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();
    final auth = context.read<EmployeeAuthProvider>();
    auth.clearError();

    setState(() => _isSubmitting = true);
    final success = await auth.sendPasswordReset(email);

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      if (success) {
        _isSuccess = true;
        _sentEmail = email;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.saTokens;

    return Scaffold(
      backgroundColor: tokens.pageBackground,
      appBar: AppBar(
        title: const Text('Reset password'),
        leading: IconButton(
          icon: const Icon(SaIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(SaTokens.space24),
          child: _isSuccess ? _buildSuccessView(tokens) : _buildFormView(tokens),
        ),
      ),
    );
  }

  Widget _buildFormView(SalesAssociateTokens tokens) {
    final auth = context.watch<EmployeeAuthProvider>();

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: SaTokens.space16),
          Text(
            'Forgot your password?',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: SaTokens.space8),
          Text(
            'Enter the email associated with your administrator-issued account and we will send you a password reset link.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: tokens.textSecondary,
                ),
          ),
          const SizedBox(height: SaTokens.space24),

          // Contextual note for phone-based associates
          const SaInfoBanner(
            title: 'Using a mobile number?',
            message:
                'Associates who self-applied with a phone number sign in directly using an SMS/call OTP and do not have a password.',
            variant: SaBannerVariant.info,
          ),
          const SizedBox(height: SaTokens.space24),

          if (auth.error != null) ...[
            SaInfoBanner(
              title: 'Request failed',
              message: auth.error!,
              variant: SaBannerVariant.error,
            ),
            const SizedBox(height: SaTokens.space16),
          ],

          Text(
            'Email address',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: SaTokens.space4),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleReset(),
            decoration: const InputDecoration(
              hintText: 'name@example.com',
              prefixIcon: Icon(SaIcons.mail),
            ),
            validator: (value) {
              final v = value?.trim() ?? '';
              if (v.isEmpty) return 'Enter your email address';
              if (!v.contains('@') || !v.contains('.')) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: SaTokens.space32),

          SaLoadingButton(
            text: 'Send reset link',
            isLoading: _isSubmitting,
            onPressed: _handleReset,
          ),
          const SizedBox(height: SaTokens.space16),

          Center(
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(SaIcons.arrowLeft, size: 16),
              label: const Text('Back to sign in'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView(SalesAssociateTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: SaTokens.space32),
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: tokens.successBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              SaIcons.circleCheck,
              color: tokens.successFg,
              size: 32,
            ),
          ),
        ),
        const SizedBox(height: SaTokens.space24),
        Text(
          'Reset link sent',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: SaTokens.space8),
        Text(
          'We have sent password reset instructions to\n${_sentEmail ?? "your email"}.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: tokens.textSecondary,
              ),
        ),
        const SizedBox(height: SaTokens.space32),
        const SaInfoBanner(
          title: 'Check your inbox',
          message:
              'Click the link in the email to set a new password. If you do not see it within a few minutes, check your spam folder.',
          variant: SaBannerVariant.info,
        ),
        const SizedBox(height: SaTokens.space32),
        SaLoadingButton(
          text: 'Return to sign in',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
