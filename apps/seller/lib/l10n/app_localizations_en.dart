// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'AgriMore Seller';

  @override
  String get appTagline => 'Seller workspace';

  @override
  String get authHeadline => 'Sell to farms and families across your district';

  @override
  String get authSubhead => 'Manage orders, stock and payments in one place.';

  @override
  String get authValueOrders => 'Accept orders before they\'re due';

  @override
  String get authValueStock => 'Keep stock and prices up to date';

  @override
  String get authValuePayments => 'Track every settlement to your bank';

  @override
  String get phoneLabel => 'Mobile number';

  @override
  String get phonePrefix => '+91';

  @override
  String get phoneHint => '10-digit mobile number';

  @override
  String get phoneErrorEmpty => 'Enter your mobile number';

  @override
  String get phoneErrorInvalid => 'Enter a valid 10-digit Indian mobile number';

  @override
  String get getOtpCta => 'Get OTP';

  @override
  String get sendingOtp => 'Sending OTP…';

  @override
  String get orDivider => 'or';

  @override
  String get googleCta => 'Continue with Google';

  @override
  String get googleLinkingTitle => 'Verify your mobile once';

  @override
  String googleLinkingBody(String email) {
    return '$email isn\'t linked to a seller account yet. Verify your mobile number and we\'ll link Google to it.';
  }

  @override
  String get googleLinkingCancel => 'Cancel';

  @override
  String get googleLinkedConflict =>
      'Signed in. Your Google account is already linked to another AgriMore account, so it wasn\'t added.';

  @override
  String get emailSignInLink => 'Sign in with email instead';

  @override
  String get legalPrefix => 'By continuing you agree to our';

  @override
  String get legalTerms => 'Terms';

  @override
  String get legalAnd => 'and';

  @override
  String get legalPrivacy => 'Privacy Policy';

  @override
  String get otpTitle => 'Enter the 6-digit code';

  @override
  String otpSentSms(String phone) {
    return 'Sent by SMS to $phone';
  }

  @override
  String otpSentVoice(String phone) {
    return 'You\'ll get a call on $phone with your code';
  }

  @override
  String get otpChangeNumber => 'Change';

  @override
  String otpDigitLabel(int index) {
    return 'Digit $index of 6';
  }

  @override
  String get otpVerifyCta => 'Verify and continue';

  @override
  String get otpVerifying => 'Verifying…';

  @override
  String otpResendIn(int seconds) {
    return 'Resend code in ${seconds}s';
  }

  @override
  String get otpResend => 'Resend code';

  @override
  String get otpCallInstead => 'Get a call instead';

  @override
  String get otpErrorIncomplete => 'Enter all 6 digits';

  @override
  String get testModeRibbon => 'Test mode — code filled in automatically';

  @override
  String get emailTitle => 'Sign in with email';

  @override
  String get emailSubhead =>
      'For seller accounts created by AgriMore with an email and password.';

  @override
  String get emailLabel => 'Email address';

  @override
  String get emailErrorInvalid => 'Enter a valid email address';

  @override
  String get passwordLabel => 'Password';

  @override
  String get passwordErrorEmpty => 'Enter your password';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get emailSignInCta => 'Sign in';

  @override
  String get signingIn => 'Signing in…';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get resetSheetTitle => 'Reset your password';

  @override
  String resetSheetBody(String email) {
    return 'We\'ll email a reset link to $email.';
  }

  @override
  String get resetSendCta => 'Send reset link';

  @override
  String get resetSent => 'Reset link sent. Check your inbox.';

  @override
  String get resetNeedsEmail => 'Enter your email address first';

  @override
  String get addPhoneNudge =>
      'Tip: after signing in, add your mobile number so you can sign in with OTP next time.';

  @override
  String get back => 'Back';

  @override
  String get statusTitle => 'Application under review';

  @override
  String get statusSubhead =>
      'We\'re checking your details. You\'ll get a notification when there\'s a decision.';

  @override
  String get statusStepSubmitted => 'Application submitted';

  @override
  String get statusStepReview => 'Documents and details reviewed';

  @override
  String get statusStepApproved => 'Approved — start selling';

  @override
  String get statusRefresh => 'Check status';

  @override
  String get statusRefreshing => 'Checking…';

  @override
  String get statusStillPending =>
      'Still under review. We\'ll notify you as soon as it changes.';

  @override
  String get restrictedRejectedTitle => 'Application not approved';

  @override
  String get restrictedRejectedBody =>
      'Your seller application wasn\'t approved. Contact us to find out what to change before applying again.';

  @override
  String get restrictedSuspendedTitle => 'Seller account suspended';

  @override
  String get restrictedSuspendedBody =>
      'Your listings are hidden and new orders are paused. Contact us to resolve this.';

  @override
  String get restrictedNoAccountTitle => 'No seller account on this number';

  @override
  String restrictedNoAccountBody(String phone) {
    return '$phone isn\'t registered as an AgriMore seller yet. Contact us to set up your seller account.';
  }

  @override
  String get restrictedNoAccountBodyGeneric =>
      'This account isn\'t registered as an AgriMore seller yet. Contact us to set up your seller account.';

  @override
  String get supportTitle => 'Contact AgriMore';

  @override
  String supportCall(String phone) {
    return 'Call $phone';
  }

  @override
  String supportEmail(String email) {
    return 'Email $email';
  }

  @override
  String get signOut => 'Sign out';

  @override
  String get signOutConfirmTitle => 'Sign out?';

  @override
  String get signOutConfirmBody =>
      'You\'ll need to verify your mobile number again to sign in.';

  @override
  String get cancel => 'Cancel';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get errorNetwork => 'Network is too slow right now. Please try again.';

  @override
  String get loadingAccount => 'Loading your seller account';
}
