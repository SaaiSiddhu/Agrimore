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

  /// No description provided for @applyTitle.
  ///
  /// In en, this message translates to:
  /// **'Start selling on AgriMore'**
  String get applyTitle;

  /// No description provided for @applySubhead.
  ///
  /// In en, this message translates to:
  /// **'Tell us about your business. It takes about 5 minutes and you can stop and continue any time.'**
  String get applySubhead;

  /// No description provided for @applyNeedBusiness.
  ///
  /// In en, this message translates to:
  /// **'Business name and what you sell'**
  String get applyNeedBusiness;

  /// No description provided for @applyNeedAddress.
  ///
  /// In en, this message translates to:
  /// **'Shop address and delivery area'**
  String get applyNeedAddress;

  /// No description provided for @applyNeedDocuments.
  ///
  /// In en, this message translates to:
  /// **'A photo of your ID and of your shop'**
  String get applyNeedDocuments;

  /// No description provided for @applyNeedPayout.
  ///
  /// In en, this message translates to:
  /// **'Bank account or UPI ID for payments'**
  String get applyNeedPayout;

  /// No description provided for @applyStartCta.
  ///
  /// In en, this message translates to:
  /// **'Start application'**
  String get applyStartCta;

  /// No description provided for @applyResumeCta.
  ///
  /// In en, this message translates to:
  /// **'Continue application'**
  String get applyResumeCta;

  /// No description provided for @applyReopenCta.
  ///
  /// In en, this message translates to:
  /// **'Fix and resubmit'**
  String get applyReopenCta;

  /// No description provided for @stepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String stepOf(int current, int total);

  /// No description provided for @stepBusiness.
  ///
  /// In en, this message translates to:
  /// **'Business details'**
  String get stepBusiness;

  /// No description provided for @stepLocation.
  ///
  /// In en, this message translates to:
  /// **'Location and delivery'**
  String get stepLocation;

  /// No description provided for @stepDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get stepDocuments;

  /// No description provided for @stepPayout.
  ///
  /// In en, this message translates to:
  /// **'Payout account'**
  String get stepPayout;

  /// No description provided for @stepReview.
  ///
  /// In en, this message translates to:
  /// **'Review and submit'**
  String get stepReview;

  /// No description provided for @saveContinue.
  ///
  /// In en, this message translates to:
  /// **'Save and continue'**
  String get saveContinue;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get saving;

  /// No description provided for @savedDraft.
  ///
  /// In en, this message translates to:
  /// **'Saved. You can continue later.'**
  String get savedDraft;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save. Check your connection and try again.'**
  String get saveFailed;

  /// No description provided for @fieldOwnerName.
  ///
  /// In en, this message translates to:
  /// **'Your full name'**
  String get fieldOwnerName;

  /// No description provided for @fieldShopName.
  ///
  /// In en, this message translates to:
  /// **'Shop or business name'**
  String get fieldShopName;

  /// No description provided for @fieldCategory.
  ///
  /// In en, this message translates to:
  /// **'What do you mainly sell?'**
  String get fieldCategory;

  /// No description provided for @fieldGstin.
  ///
  /// In en, this message translates to:
  /// **'GSTIN (optional)'**
  String get fieldGstin;

  /// No description provided for @fieldGstinHelp.
  ///
  /// In en, this message translates to:
  /// **'15 characters, e.g. 33ABCDE1234F1Z5'**
  String get fieldGstinHelp;

  /// No description provided for @category_vegetables.
  ///
  /// In en, this message translates to:
  /// **'Vegetables'**
  String get category_vegetables;

  /// No description provided for @category_fruits.
  ///
  /// In en, this message translates to:
  /// **'Fruits'**
  String get category_fruits;

  /// No description provided for @category_grains.
  ///
  /// In en, this message translates to:
  /// **'Grains and pulses'**
  String get category_grains;

  /// No description provided for @category_dairy.
  ///
  /// In en, this message translates to:
  /// **'Dairy'**
  String get category_dairy;

  /// No description provided for @category_seeds.
  ///
  /// In en, this message translates to:
  /// **'Seeds'**
  String get category_seeds;

  /// No description provided for @category_fertilisers.
  ///
  /// In en, this message translates to:
  /// **'Fertilisers and inputs'**
  String get category_fertilisers;

  /// No description provided for @category_equipment.
  ///
  /// In en, this message translates to:
  /// **'Tools and equipment'**
  String get category_equipment;

  /// No description provided for @category_other.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get category_other;

  /// No description provided for @fieldAddress.
  ///
  /// In en, this message translates to:
  /// **'Shop address'**
  String get fieldAddress;

  /// No description provided for @fieldCity.
  ///
  /// In en, this message translates to:
  /// **'City or town'**
  String get fieldCity;

  /// No description provided for @fieldState.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get fieldState;

  /// No description provided for @fieldPincode.
  ///
  /// In en, this message translates to:
  /// **'PIN code'**
  String get fieldPincode;

  /// No description provided for @fieldRadius.
  ///
  /// In en, this message translates to:
  /// **'Delivery radius'**
  String get fieldRadius;

  /// No description provided for @radiusKm.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String radiusKm(int km);

  /// No description provided for @useCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Use my current location'**
  String get useCurrentLocation;

  /// No description provided for @locationCaptured.
  ///
  /// In en, this message translates to:
  /// **'Location pinned'**
  String get locationCaptured;

  /// No description provided for @locationFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get your location. You can continue without it.'**
  String get locationFailed;

  /// No description provided for @documentsHelp.
  ///
  /// In en, this message translates to:
  /// **'Clear photos help us approve you faster. Only AgriMore reviewers can see them.'**
  String get documentsHelp;

  /// No description provided for @doc_idProof.
  ///
  /// In en, this message translates to:
  /// **'ID proof (Aadhaar, PAN, voter ID or driving licence)'**
  String get doc_idProof;

  /// No description provided for @doc_shopPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo of your shop or farm'**
  String get doc_shopPhoto;

  /// No description provided for @doc_gstCertificate.
  ///
  /// In en, this message translates to:
  /// **'GST certificate (optional)'**
  String get doc_gstCertificate;

  /// No description provided for @docTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get docTakePhoto;

  /// No description provided for @docChoosePhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get docChoosePhoto;

  /// No description provided for @docUploaded.
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get docUploaded;

  /// No description provided for @docUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading…'**
  String get docUploading;

  /// No description provided for @docReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get docReplace;

  /// No description provided for @docUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed. Try again.'**
  String get docUploadFailed;

  /// No description provided for @payoutHelp.
  ///
  /// In en, this message translates to:
  /// **'Your settlements are paid here. We never show these details on your public profile.'**
  String get payoutHelp;

  /// No description provided for @payoutBank.
  ///
  /// In en, this message translates to:
  /// **'Bank account'**
  String get payoutBank;

  /// No description provided for @payoutUpi.
  ///
  /// In en, this message translates to:
  /// **'UPI ID'**
  String get payoutUpi;

  /// No description provided for @fieldAccountHolder.
  ///
  /// In en, this message translates to:
  /// **'Account holder name'**
  String get fieldAccountHolder;

  /// No description provided for @fieldBankName.
  ///
  /// In en, this message translates to:
  /// **'Bank name'**
  String get fieldBankName;

  /// No description provided for @fieldAccountNumber.
  ///
  /// In en, this message translates to:
  /// **'Account number'**
  String get fieldAccountNumber;

  /// No description provided for @fieldAccountNumberConfirm.
  ///
  /// In en, this message translates to:
  /// **'Re-enter account number'**
  String get fieldAccountNumberConfirm;

  /// No description provided for @fieldIfsc.
  ///
  /// In en, this message translates to:
  /// **'IFSC code'**
  String get fieldIfsc;

  /// No description provided for @fieldUpiId.
  ///
  /// In en, this message translates to:
  /// **'UPI ID'**
  String get fieldUpiId;

  /// No description provided for @accountMismatch.
  ///
  /// In en, this message translates to:
  /// **'Account numbers don\'t match'**
  String get accountMismatch;

  /// No description provided for @reviewHelp.
  ///
  /// In en, this message translates to:
  /// **'Check your details. You can\'t edit them while we review your application.'**
  String get reviewHelp;

  /// No description provided for @reviewEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get reviewEdit;

  /// No description provided for @reviewDocumentsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} of {total} photos uploaded'**
  String reviewDocumentsCount(int count, int total);

  /// No description provided for @acceptTerms.
  ///
  /// In en, this message translates to:
  /// **'I confirm these details are correct and agree to AgriMore\'s seller terms'**
  String get acceptTerms;

  /// No description provided for @submitCta.
  ///
  /// In en, this message translates to:
  /// **'Submit application'**
  String get submitCta;

  /// No description provided for @submitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting…'**
  String get submitting;

  /// No description provided for @submitInvalid.
  ///
  /// In en, this message translates to:
  /// **'Some details need attention. We\'ve taken you to the first one.'**
  String get submitInvalid;

  /// No description provided for @submitFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t submit. Check your connection and try again.'**
  String get submitFailed;

  /// No description provided for @errRequired.
  ///
  /// In en, this message translates to:
  /// **'This is required'**
  String get errRequired;

  /// No description provided for @errGstin.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 15-character GSTIN'**
  String get errGstin;

  /// No description provided for @errPincode.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 6-digit PIN code'**
  String get errPincode;

  /// No description provided for @errIfsc.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 11-character IFSC code'**
  String get errIfsc;

  /// No description provided for @errAccount.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid account number (9–18 digits)'**
  String get errAccount;

  /// No description provided for @errUpi.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid UPI ID, e.g. name@bank'**
  String get errUpi;

  /// No description provided for @errDocument.
  ///
  /// In en, this message translates to:
  /// **'Upload this photo to continue'**
  String get errDocument;

  /// No description provided for @rejectOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'Reject this order?'**
  String get rejectOrderTitle;

  /// No description provided for @cancelOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this order?'**
  String get cancelOrderTitle;

  /// No description provided for @reasonPrompt.
  ///
  /// In en, this message translates to:
  /// **'Tell the buyer why. This is required.'**
  String get reasonPrompt;

  /// No description provided for @reasonOutOfStock.
  ///
  /// In en, this message translates to:
  /// **'Item out of stock'**
  String get reasonOutOfStock;

  /// No description provided for @reasonCannotDeliver.
  ///
  /// In en, this message translates to:
  /// **'Can\'t deliver to this area'**
  String get reasonCannotDeliver;

  /// No description provided for @reasonPriceError.
  ///
  /// In en, this message translates to:
  /// **'Price was wrong'**
  String get reasonPriceError;

  /// No description provided for @reasonShopClosed.
  ///
  /// In en, this message translates to:
  /// **'Shop is closed'**
  String get reasonShopClosed;

  /// No description provided for @reasonOther.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get reasonOther;

  /// No description provided for @reasonNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note for the buyer (optional)'**
  String get reasonNoteLabel;

  /// No description provided for @rejectConsequence.
  ///
  /// In en, this message translates to:
  /// **'The buyer is notified and the stock goes back to your listings.'**
  String get rejectConsequence;

  /// No description provided for @rejectConsequencePrepaid.
  ///
  /// In en, this message translates to:
  /// **'The buyer is notified, the stock goes back to your listings, and the payment is marked for refund.'**
  String get rejectConsequencePrepaid;

  /// No description provided for @rejectOrderCta.
  ///
  /// In en, this message translates to:
  /// **'Reject order'**
  String get rejectOrderCta;

  /// No description provided for @cancelOrderCta.
  ///
  /// In en, this message translates to:
  /// **'Cancel order'**
  String get cancelOrderCta;

  /// No description provided for @keepOrder.
  ///
  /// In en, this message translates to:
  /// **'Keep order'**
  String get keepOrder;

  /// No description provided for @orderAccepted.
  ///
  /// In en, this message translates to:
  /// **'Order accepted'**
  String get orderAccepted;

  /// No description provided for @orderPacking.
  ///
  /// In en, this message translates to:
  /// **'Packing started'**
  String get orderPacking;

  /// No description provided for @orderReady.
  ///
  /// In en, this message translates to:
  /// **'Marked ready for pickup'**
  String get orderReady;

  /// No description provided for @orderRejected.
  ///
  /// In en, this message translates to:
  /// **'Order rejected'**
  String get orderRejected;

  /// No description provided for @orderCancelled.
  ///
  /// In en, this message translates to:
  /// **'Order cancelled'**
  String get orderCancelled;

  /// No description provided for @orderActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update the order. Please try again.'**
  String get orderActionFailed;

  /// No description provided for @orderAlreadyMoved.
  ///
  /// In en, this message translates to:
  /// **'This order was already updated. Pull to refresh.'**
  String get orderAlreadyMoved;

  /// No description provided for @orderUnpaid.
  ///
  /// In en, this message translates to:
  /// **'Payment for this order isn\'t complete yet.'**
  String get orderUnpaid;

  /// No description provided for @chatReady.
  ///
  /// In en, this message translates to:
  /// **'Chat with the buyer is ready'**
  String get chatReady;

  /// No description provided for @taxSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Tax details (for invoices)'**
  String get taxSectionTitle;

  /// No description provided for @taxSectionHelp.
  ///
  /// In en, this message translates to:
  /// **'Optional. Add them if you\'re GST-registered so your invoices show the right tax.'**
  String get taxSectionHelp;

  /// No description provided for @fieldHsn.
  ///
  /// In en, this message translates to:
  /// **'HSN code'**
  String get fieldHsn;

  /// No description provided for @fieldGstRate.
  ///
  /// In en, this message translates to:
  /// **'GST rate'**
  String get fieldGstRate;

  /// No description provided for @gstNotDeclared.
  ///
  /// In en, this message translates to:
  /// **'Not declared'**
  String get gstNotDeclared;

  /// No description provided for @gstRatePercent.
  ///
  /// In en, this message translates to:
  /// **'{rate}%'**
  String gstRatePercent(int rate);

  /// No description provided for @errHsn.
  ///
  /// In en, this message translates to:
  /// **'HSN codes are 4, 6 or 8 digits'**
  String get errHsn;

  /// No description provided for @saveDraftCta.
  ///
  /// In en, this message translates to:
  /// **'Save as draft'**
  String get saveDraftCta;

  /// No description provided for @draftSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved as a draft. Publish it when you\'re ready.'**
  String get draftSaved;

  /// No description provided for @draftNeedsName.
  ///
  /// In en, this message translates to:
  /// **'Add a product name to save a draft'**
  String get draftNeedsName;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get filterActive;

  /// No description provided for @filterDraft.
  ///
  /// In en, this message translates to:
  /// **'Drafts'**
  String get filterDraft;

  /// No description provided for @filterOutOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get filterOutOfStock;

  /// No description provided for @filterInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get filterInactive;

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedCount(int count);

  /// No description provided for @bulkActivate.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get bulkActivate;

  /// No description provided for @bulkDeactivate.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get bulkDeactivate;

  /// No description provided for @bulkClear.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get bulkClear;

  /// No description provided for @bulkDone.
  ///
  /// In en, this message translates to:
  /// **'{count} products updated'**
  String bulkDone(int count);

  /// No description provided for @bulkFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update the products. Please try again.'**
  String get bulkFailed;

  /// No description provided for @draftBadge.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get draftBadge;

  /// No description provided for @filterWithCount.
  ///
  /// In en, this message translates to:
  /// **'{label} · {count}'**
  String filterWithCount(String label, String count);
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
