import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'AgriMore Seller'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Seller workspace'**
  String get appTagline;

  /// No description provided for @authHeadline.
  ///
  /// In en, this message translates to:
  /// **'Sell to farms and families across your district'**
  String get authHeadline;

  /// No description provided for @authSubhead.
  ///
  /// In en, this message translates to:
  /// **'Manage orders, stock and payments in one place.'**
  String get authSubhead;

  /// No description provided for @authValueOrders.
  ///
  /// In en, this message translates to:
  /// **'Accept orders before they\'re due'**
  String get authValueOrders;

  /// No description provided for @authValueStock.
  ///
  /// In en, this message translates to:
  /// **'Keep stock and prices up to date'**
  String get authValueStock;

  /// No description provided for @authValuePayments.
  ///
  /// In en, this message translates to:
  /// **'Track every settlement to your bank'**
  String get authValuePayments;

  /// No description provided for @phoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get phoneLabel;

  /// No description provided for @phonePrefix.
  ///
  /// In en, this message translates to:
  /// **'+91'**
  String get phonePrefix;

  /// No description provided for @phoneHint.
  ///
  /// In en, this message translates to:
  /// **'10-digit mobile number'**
  String get phoneHint;

  /// No description provided for @phoneErrorEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter your mobile number'**
  String get phoneErrorEmpty;

  /// No description provided for @phoneErrorInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 10-digit Indian mobile number'**
  String get phoneErrorInvalid;

  /// No description provided for @getOtpCta.
  ///
  /// In en, this message translates to:
  /// **'Get OTP'**
  String get getOtpCta;

  /// No description provided for @sendingOtp.
  ///
  /// In en, this message translates to:
  /// **'Sending OTP…'**
  String get sendingOtp;

  /// No description provided for @orDivider.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get orDivider;

  /// No description provided for @googleCta.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get googleCta;

  /// No description provided for @googleLinkingTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your mobile once'**
  String get googleLinkingTitle;

  /// No description provided for @googleLinkingBody.
  ///
  /// In en, this message translates to:
  /// **'{email} isn\'t linked to a seller account yet. Verify your mobile number and we\'ll link Google to it.'**
  String googleLinkingBody(String email);

  /// No description provided for @googleLinkingCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get googleLinkingCancel;

  /// No description provided for @googleLinkedConflict.
  ///
  /// In en, this message translates to:
  /// **'Signed in. Your Google account is already linked to another AgriMore account, so it wasn\'t added.'**
  String get googleLinkedConflict;

  /// No description provided for @emailSignInLink.
  ///
  /// In en, this message translates to:
  /// **'Sign in with email instead'**
  String get emailSignInLink;

  /// No description provided for @legalPrefix.
  ///
  /// In en, this message translates to:
  /// **'By continuing you agree to our'**
  String get legalPrefix;

  /// No description provided for @legalTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get legalTerms;

  /// No description provided for @legalAnd.
  ///
  /// In en, this message translates to:
  /// **'and'**
  String get legalAnd;

  /// No description provided for @legalPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get legalPrivacy;

  /// No description provided for @otpTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code'**
  String get otpTitle;

  /// No description provided for @otpSentSms.
  ///
  /// In en, this message translates to:
  /// **'Sent by SMS to {phone}'**
  String otpSentSms(String phone);

  /// No description provided for @otpSentVoice.
  ///
  /// In en, this message translates to:
  /// **'You\'ll get a call on {phone} with your code'**
  String otpSentVoice(String phone);

  /// No description provided for @otpChangeNumber.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get otpChangeNumber;

  /// No description provided for @otpDigitLabel.
  ///
  /// In en, this message translates to:
  /// **'Digit {index} of 6'**
  String otpDigitLabel(int index);

  /// No description provided for @otpVerifyCta.
  ///
  /// In en, this message translates to:
  /// **'Verify and continue'**
  String get otpVerifyCta;

  /// No description provided for @otpVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying…'**
  String get otpVerifying;

  /// No description provided for @otpResendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend code in {seconds}s'**
  String otpResendIn(int seconds);

  /// No description provided for @otpResend.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get otpResend;

  /// No description provided for @otpCallInstead.
  ///
  /// In en, this message translates to:
  /// **'Get a call instead'**
  String get otpCallInstead;

  /// No description provided for @otpErrorIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Enter all 6 digits'**
  String get otpErrorIncomplete;

  /// No description provided for @testModeRibbon.
  ///
  /// In en, this message translates to:
  /// **'Test mode — code filled in automatically'**
  String get testModeRibbon;

  /// No description provided for @emailTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with email'**
  String get emailTitle;

  /// No description provided for @emailSubhead.
  ///
  /// In en, this message translates to:
  /// **'For seller accounts created by AgriMore with an email and password.'**
  String get emailSubhead;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get emailLabel;

  /// No description provided for @emailErrorInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get emailErrorInvalid;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @passwordErrorEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get passwordErrorEmpty;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @emailSignInCta.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get emailSignInCta;

  /// No description provided for @signingIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in…'**
  String get signingIn;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @resetSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get resetSheetTitle;

  /// No description provided for @resetSheetBody.
  ///
  /// In en, this message translates to:
  /// **'We\'ll email a reset link to {email}.'**
  String resetSheetBody(String email);

  /// No description provided for @resetSendCta.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get resetSendCta;

  /// No description provided for @resetSent.
  ///
  /// In en, this message translates to:
  /// **'Reset link sent. Check your inbox.'**
  String get resetSent;

  /// No description provided for @resetNeedsEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address first'**
  String get resetNeedsEmail;

  /// No description provided for @addPhoneNudge.
  ///
  /// In en, this message translates to:
  /// **'Tip: after signing in, add your mobile number so you can sign in with OTP next time.'**
  String get addPhoneNudge;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @statusTitle.
  ///
  /// In en, this message translates to:
  /// **'Application under review'**
  String get statusTitle;

  /// No description provided for @statusSubhead.
  ///
  /// In en, this message translates to:
  /// **'We\'re checking your details. You\'ll get a notification when there\'s a decision.'**
  String get statusSubhead;

  /// No description provided for @statusStepSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Application submitted'**
  String get statusStepSubmitted;

  /// No description provided for @statusStepReview.
  ///
  /// In en, this message translates to:
  /// **'Documents and details reviewed'**
  String get statusStepReview;

  /// No description provided for @statusStepApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved — start selling'**
  String get statusStepApproved;

  /// No description provided for @statusRefresh.
  ///
  /// In en, this message translates to:
  /// **'Check status'**
  String get statusRefresh;

  /// No description provided for @statusRefreshing.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get statusRefreshing;

  /// No description provided for @statusStillPending.
  ///
  /// In en, this message translates to:
  /// **'Still under review. We\'ll notify you as soon as it changes.'**
  String get statusStillPending;

  /// No description provided for @restrictedRejectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Application not approved'**
  String get restrictedRejectedTitle;

  /// No description provided for @restrictedRejectedBody.
  ///
  /// In en, this message translates to:
  /// **'Your seller application wasn\'t approved. Contact us to find out what to change before applying again.'**
  String get restrictedRejectedBody;

  /// No description provided for @restrictedSuspendedTitle.
  ///
  /// In en, this message translates to:
  /// **'Seller account suspended'**
  String get restrictedSuspendedTitle;

  /// No description provided for @restrictedSuspendedBody.
  ///
  /// In en, this message translates to:
  /// **'Your listings are hidden and new orders are paused. Contact us to resolve this.'**
  String get restrictedSuspendedBody;

  /// No description provided for @restrictedNoAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'No seller account on this number'**
  String get restrictedNoAccountTitle;

  /// No description provided for @restrictedNoAccountBody.
  ///
  /// In en, this message translates to:
  /// **'{phone} isn\'t registered as an AgriMore seller yet. Contact us to set up your seller account.'**
  String restrictedNoAccountBody(String phone);

  /// No description provided for @restrictedNoAccountBodyGeneric.
  ///
  /// In en, this message translates to:
  /// **'This account isn\'t registered as an AgriMore seller yet. Contact us to set up your seller account.'**
  String get restrictedNoAccountBodyGeneric;

  /// No description provided for @supportTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact AgriMore'**
  String get supportTitle;

  /// No description provided for @supportCall.
  ///
  /// In en, this message translates to:
  /// **'Call {phone}'**
  String supportCall(String phone);

  /// No description provided for @supportEmail.
  ///
  /// In en, this message translates to:
  /// **'Email {email}'**
  String supportEmail(String email);

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @signOutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get signOutConfirmTitle;

  /// No description provided for @signOutConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ll need to verify your mobile number again to sign in.'**
  String get signOutConfirmBody;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network is too slow right now. Please try again.'**
  String get errorNetwork;

  /// No description provided for @loadingAccount.
  ///
  /// In en, this message translates to:
  /// **'Loading your seller account'**
  String get loadingAccount;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
