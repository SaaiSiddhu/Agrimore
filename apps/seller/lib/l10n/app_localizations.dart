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

  /// No description provided for @invoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get invoiceTitle;

  /// No description provided for @docTaxInvoice.
  ///
  /// In en, this message translates to:
  /// **'Tax Invoice'**
  String get docTaxInvoice;

  /// No description provided for @docBillOfSupply.
  ///
  /// In en, this message translates to:
  /// **'Bill of Supply'**
  String get docBillOfSupply;

  /// No description provided for @billOfSupplyNote.
  ///
  /// In en, this message translates to:
  /// **'Issued as a bill of supply: no GST is charged separately. Add your GSTIN and each product\'s HSN code and GST rate to issue tax invoices.'**
  String get billOfSupplyNote;

  /// No description provided for @invoiceLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this invoice. Please try again.'**
  String get invoiceLoadFailed;

  /// No description provided for @invoiceIssueFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create the invoice. Please try again.'**
  String get invoiceIssueFailed;

  /// No description provided for @copyInvoiceNumber.
  ///
  /// In en, this message translates to:
  /// **'Copy invoice number'**
  String get copyInvoiceNumber;

  /// No description provided for @invoiceIssued.
  ///
  /// In en, this message translates to:
  /// **'Issued {when}'**
  String invoiceIssued(String when);

  /// No description provided for @invoiceForOrder.
  ///
  /// In en, this message translates to:
  /// **'For order {number}'**
  String invoiceForOrder(String number);

  /// No description provided for @invoiceFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get invoiceFrom;

  /// No description provided for @invoiceTo.
  ///
  /// In en, this message translates to:
  /// **'Bill to'**
  String get invoiceTo;

  /// No description provided for @invoiceGstin.
  ///
  /// In en, this message translates to:
  /// **'GSTIN {gstin}'**
  String invoiceGstin(String gstin);

  /// No description provided for @invoiceLineQty.
  ///
  /// In en, this message translates to:
  /// **'{qty} × {price}'**
  String invoiceLineQty(String qty, String price);

  /// No description provided for @invoiceLineTax.
  ///
  /// In en, this message translates to:
  /// **'HSN {hsn} · GST {rate}%'**
  String invoiceLineTax(String hsn, String rate);

  /// No description provided for @invoiceSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get invoiceSubtotal;

  /// No description provided for @invoiceDiscount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get invoiceDiscount;

  /// No description provided for @invoiceDelivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get invoiceDelivery;

  /// No description provided for @invoiceCgst.
  ///
  /// In en, this message translates to:
  /// **'CGST (included)'**
  String get invoiceCgst;

  /// No description provided for @invoiceSgst.
  ///
  /// In en, this message translates to:
  /// **'SGST (included)'**
  String get invoiceSgst;

  /// No description provided for @invoiceIgst.
  ///
  /// In en, this message translates to:
  /// **'IGST (included)'**
  String get invoiceIgst;

  /// No description provided for @invoiceTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get invoiceTotal;

  /// No description provided for @invoiceTaxIncluded.
  ///
  /// In en, this message translates to:
  /// **'Prices include GST.'**
  String get invoiceTaxIncluded;

  /// No description provided for @generateInvoice.
  ///
  /// In en, this message translates to:
  /// **'Generate invoice'**
  String get generateInvoice;

  /// No description provided for @generatingInvoice.
  ///
  /// In en, this message translates to:
  /// **'Generating…'**
  String get generatingInvoice;

  /// No description provided for @viewInvoice.
  ///
  /// In en, this message translates to:
  /// **'View invoice'**
  String get viewInvoice;

  /// No description provided for @paymentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get paymentsTitle;

  /// No description provided for @paymentsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your payments. Check your connection and open this tab again.'**
  String get paymentsLoadFailed;

  /// No description provided for @paymentsPending.
  ///
  /// In en, this message translates to:
  /// **'To be paid'**
  String get paymentsPending;

  /// No description provided for @paymentsPaid30d.
  ///
  /// In en, this message translates to:
  /// **'Paid · last 30 days'**
  String get paymentsPaid30d;

  /// No description provided for @paymentsPaidAll.
  ///
  /// In en, this message translates to:
  /// **'Paid · all time'**
  String get paymentsPaidAll;

  /// No description provided for @paymentsHistory.
  ///
  /// In en, this message translates to:
  /// **'Settlements'**
  String get paymentsHistory;

  /// No description provided for @paymentsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No settlements yet. You\'ll see one here for every delivered order.'**
  String get paymentsEmpty;

  /// No description provided for @paymentsForOrder.
  ///
  /// In en, this message translates to:
  /// **'Order {number}'**
  String paymentsForOrder(String number);

  /// No description provided for @payoutPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get payoutPaid;

  /// No description provided for @payoutPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get payoutPending;

  /// No description provided for @payoutAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Payout account'**
  String get payoutAccountTitle;

  /// No description provided for @payoutAccountMissing.
  ///
  /// In en, this message translates to:
  /// **'No payout account on file'**
  String get payoutAccountMissing;

  /// No description provided for @payoutAccountMissingHelp.
  ///
  /// In en, this message translates to:
  /// **'Contact AgriMore to add your bank account or UPI ID before your first settlement.'**
  String get payoutAccountMissingHelp;

  /// No description provided for @payoutAccountUpi.
  ///
  /// In en, this message translates to:
  /// **'UPI · {upi}'**
  String payoutAccountUpi(String upi);

  /// No description provided for @payoutAccountBank.
  ///
  /// In en, this message translates to:
  /// **'{bank} · {account}'**
  String payoutAccountBank(String bank, String account);

  /// No description provided for @settlementCreated.
  ///
  /// In en, this message translates to:
  /// **'Order delivered — settlement created'**
  String get settlementCreated;

  /// No description provided for @settlementPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid to your account'**
  String get settlementPaid;

  /// No description provided for @settlementGross.
  ///
  /// In en, this message translates to:
  /// **'Order value'**
  String get settlementGross;

  /// No description provided for @settlementCommission.
  ///
  /// In en, this message translates to:
  /// **'AgriMore commission'**
  String get settlementCommission;

  /// No description provided for @settlementNet.
  ///
  /// In en, this message translates to:
  /// **'You receive'**
  String get settlementNet;

  /// No description provided for @settlementReference.
  ///
  /// In en, this message translates to:
  /// **'Payment reference'**
  String get settlementReference;

  /// No description provided for @quotesTitle.
  ///
  /// In en, this message translates to:
  /// **'Quotes'**
  String get quotesTitle;

  /// No description provided for @quotesTabNeedsResponse.
  ///
  /// In en, this message translates to:
  /// **'Needs response'**
  String get quotesTabNeedsResponse;

  /// No description provided for @quotesTabNegotiating.
  ///
  /// In en, this message translates to:
  /// **'Negotiating'**
  String get quotesTabNegotiating;

  /// No description provided for @quotesTabAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get quotesTabAccepted;

  /// No description provided for @quotesTabClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get quotesTabClosed;

  /// No description provided for @quotesTabWithCount.
  ///
  /// In en, this message translates to:
  /// **'{label} · {count}'**
  String quotesTabWithCount(String label, int count);

  /// No description provided for @quotesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your quotes. Check your connection and open this screen again.'**
  String get quotesLoadFailed;

  /// No description provided for @quotesEmptyNeedsResponse.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up. New quote requests from business buyers appear here.'**
  String get quotesEmptyNeedsResponse;

  /// No description provided for @quotesEmptyOther.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet.'**
  String get quotesEmptyOther;

  /// No description provided for @quoteUnknownProduct.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get quoteUnknownProduct;

  /// No description provided for @quoteUnknownBuyer.
  ///
  /// In en, this message translates to:
  /// **'Business buyer'**
  String get quoteUnknownBuyer;

  /// No description provided for @quoteQtyAtPrice.
  ///
  /// In en, this message translates to:
  /// **'{qty} × {price}'**
  String quoteQtyAtPrice(String qty, String price);

  /// No description provided for @quoteNoPriceYet.
  ///
  /// In en, this message translates to:
  /// **'No price proposed — send your offer'**
  String get quoteNoPriceYet;

  /// No description provided for @quoteExpiresIn.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{Expires in 1 day} other{Expires in {days} days}}'**
  String quoteExpiresIn(int days);

  /// No description provided for @quoteExpired.
  ///
  /// In en, this message translates to:
  /// **'Offer expired'**
  String get quoteExpired;

  /// No description provided for @quoteYourTurn.
  ///
  /// In en, this message translates to:
  /// **'Your turn'**
  String get quoteYourTurn;

  /// No description provided for @quoteWaitingBuyer.
  ///
  /// In en, this message translates to:
  /// **'Waiting for buyer'**
  String get quoteWaitingBuyer;

  /// No description provided for @quoteStatusAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get quoteStatusAccepted;

  /// No description provided for @quoteStatusOrdered.
  ///
  /// In en, this message translates to:
  /// **'Order placed'**
  String get quoteStatusOrdered;

  /// No description provided for @quoteStatusDeclined.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get quoteStatusDeclined;

  /// No description provided for @quoteDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Quote'**
  String get quoteDetailTitle;

  /// No description provided for @quoteNotFound.
  ///
  /// In en, this message translates to:
  /// **'This quote is no longer available.'**
  String get quoteNotFound;

  /// No description provided for @quoteRequested.
  ///
  /// In en, this message translates to:
  /// **'Requested {date}'**
  String quoteRequested(String date);

  /// No description provided for @quoteListedB2b.
  ///
  /// In en, this message translates to:
  /// **'Your B2B price {price}'**
  String quoteListedB2b(String price);

  /// No description provided for @quoteMoq.
  ///
  /// In en, this message translates to:
  /// **'Min. order {qty}'**
  String quoteMoq(String qty);

  /// No description provided for @quoteCurrentOffer.
  ///
  /// In en, this message translates to:
  /// **'Offer on the table'**
  String get quoteCurrentOffer;

  /// No description provided for @quoteAgreedTerms.
  ///
  /// In en, this message translates to:
  /// **'Last offer'**
  String get quoteAgreedTerms;

  /// No description provided for @quoteVsListedBelow.
  ///
  /// In en, this message translates to:
  /// **'{pct} below your B2B price'**
  String quoteVsListedBelow(String pct);

  /// No description provided for @quoteVsListedAbove.
  ///
  /// In en, this message translates to:
  /// **'{pct} above your B2B price'**
  String quoteVsListedAbove(String pct);

  /// No description provided for @quoteVsListedSame.
  ///
  /// In en, this message translates to:
  /// **'Same as your B2B price'**
  String get quoteVsListedSame;

  /// No description provided for @quoteHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Negotiation'**
  String get quoteHistoryTitle;

  /// No description provided for @quoteByBuyer.
  ///
  /// In en, this message translates to:
  /// **'Buyer'**
  String get quoteByBuyer;

  /// No description provided for @quoteByYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get quoteByYou;

  /// No description provided for @quoteActionCreate.
  ///
  /// In en, this message translates to:
  /// **'Requested a quote'**
  String get quoteActionCreate;

  /// No description provided for @quoteActionOffer.
  ///
  /// In en, this message translates to:
  /// **'Offered'**
  String get quoteActionOffer;

  /// No description provided for @quoteActionAccept.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get quoteActionAccept;

  /// No description provided for @quoteActionReject.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get quoteActionReject;

  /// No description provided for @quoteCounter.
  ///
  /// In en, this message translates to:
  /// **'Counter'**
  String get quoteCounter;

  /// No description provided for @quoteAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get quoteAccept;

  /// No description provided for @quoteDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get quoteDecline;

  /// No description provided for @quoteAcceptTitle.
  ///
  /// In en, this message translates to:
  /// **'Accept this offer?'**
  String get quoteAcceptTitle;

  /// No description provided for @quoteAcceptBody.
  ///
  /// In en, this message translates to:
  /// **'{qty} × {price} = {total}. The buyer can then place the order at this price. This can\'t be undone.'**
  String quoteAcceptBody(String qty, String price, String total);

  /// No description provided for @quoteAcceptExpiredHint.
  ///
  /// In en, this message translates to:
  /// **'This offer has expired, so it can\'t be accepted. Send a counter-offer with a new validity instead.'**
  String get quoteAcceptExpiredHint;

  /// No description provided for @quoteAcceptedBanner.
  ///
  /// In en, this message translates to:
  /// **'Accepted at {price} × {qty}. The buyer can now place the order.'**
  String quoteAcceptedBanner(String price, String qty);

  /// No description provided for @quoteOrderedBanner.
  ///
  /// In en, this message translates to:
  /// **'The buyer has placed an order for this quote.'**
  String get quoteOrderedBanner;

  /// No description provided for @quoteViewOrder.
  ///
  /// In en, this message translates to:
  /// **'View order'**
  String get quoteViewOrder;

  /// No description provided for @quoteDeclinedBanner.
  ///
  /// In en, this message translates to:
  /// **'This quote was declined.'**
  String get quoteDeclinedBanner;

  /// No description provided for @quoteWaitingBanner.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the buyer to respond to your offer.'**
  String get quoteWaitingBanner;

  /// No description provided for @quoteSent.
  ///
  /// In en, this message translates to:
  /// **'Offer sent'**
  String get quoteSent;

  /// No description provided for @quoteAcceptedToast.
  ///
  /// In en, this message translates to:
  /// **'Quote accepted'**
  String get quoteAcceptedToast;

  /// No description provided for @quoteDeclinedToast.
  ///
  /// In en, this message translates to:
  /// **'Quote declined'**
  String get quoteDeclinedToast;

  /// No description provided for @quoteErrorExpired.
  ///
  /// In en, this message translates to:
  /// **'This offer has expired — send a counter-offer instead.'**
  String get quoteErrorExpired;

  /// No description provided for @quoteErrorNotYourTurn.
  ///
  /// In en, this message translates to:
  /// **'The buyer has already responded. The latest offer is shown now.'**
  String get quoteErrorNotYourTurn;

  /// No description provided for @quoteErrorClosed.
  ///
  /// In en, this message translates to:
  /// **'This quote is already closed.'**
  String get quoteErrorClosed;

  /// No description provided for @quoteErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update this quote. Check your connection and try again.'**
  String get quoteErrorGeneric;

  /// No description provided for @counterTitle.
  ///
  /// In en, this message translates to:
  /// **'Counter-offer'**
  String get counterTitle;

  /// No description provided for @counterPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Price per unit (₹)'**
  String get counterPriceLabel;

  /// No description provided for @counterQtyLabel.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get counterQtyLabel;

  /// No description provided for @counterPriceInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a price above ₹0'**
  String get counterPriceInvalid;

  /// No description provided for @counterQtyInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number above 0'**
  String get counterQtyInvalid;

  /// No description provided for @counterBelowMoq.
  ///
  /// In en, this message translates to:
  /// **'Below your minimum order of {moq}'**
  String counterBelowMoq(String moq);

  /// No description provided for @counterValidityLabel.
  ///
  /// In en, this message translates to:
  /// **'Offer valid for'**
  String get counterValidityLabel;

  /// No description provided for @counterValidityDays.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day} other{{days} days}}'**
  String counterValidityDays(int days);

  /// No description provided for @counterNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note to the buyer (optional)'**
  String get counterNoteLabel;

  /// No description provided for @counterTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get counterTotal;

  /// No description provided for @counterSend.
  ///
  /// In en, this message translates to:
  /// **'Send offer'**
  String get counterSend;

  /// No description provided for @declineTitle.
  ///
  /// In en, this message translates to:
  /// **'Decline quote'**
  String get declineTitle;

  /// No description provided for @declinePrompt.
  ///
  /// In en, this message translates to:
  /// **'Tell the buyer why'**
  String get declinePrompt;

  /// No description provided for @declineReasonPriceTooLow.
  ///
  /// In en, this message translates to:
  /// **'Price is too low'**
  String get declineReasonPriceTooLow;

  /// No description provided for @declineReasonOutOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get declineReasonOutOfStock;

  /// No description provided for @declineReasonQuantity.
  ///
  /// In en, this message translates to:
  /// **'Can\'t supply this quantity'**
  String get declineReasonQuantity;

  /// No description provided for @declineReasonCannotDeliver.
  ///
  /// In en, this message translates to:
  /// **'Can\'t deliver to the buyer'**
  String get declineReasonCannotDeliver;

  /// No description provided for @declineReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get declineReasonOther;

  /// No description provided for @declineNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Add a note (optional)'**
  String get declineNoteLabel;

  /// No description provided for @declineConsequence.
  ///
  /// In en, this message translates to:
  /// **'The buyer sees your reason. They can send a new quote request later.'**
  String get declineConsequence;

  /// No description provided for @declineCta.
  ///
  /// In en, this message translates to:
  /// **'Decline quote'**
  String get declineCta;

  /// No description provided for @declineKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep negotiating'**
  String get declineKeep;

  /// No description provided for @quoteHistoryHeader.
  ///
  /// In en, this message translates to:
  /// **'{who} · {action}'**
  String quoteHistoryHeader(String who, String action);

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTitle;

  /// No description provided for @homeGreetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get homeGreetingMorning;

  /// No description provided for @homeGreetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get homeGreetingAfternoon;

  /// No description provided for @homeGreetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get homeGreetingEvening;

  /// No description provided for @homeNeedsYou.
  ///
  /// In en, this message translates to:
  /// **'Needs you now'**
  String get homeNeedsYou;

  /// No description provided for @homeAllCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up'**
  String get homeAllCaughtUp;

  /// No description provided for @homeAllCaughtUpBody.
  ///
  /// In en, this message translates to:
  /// **'New orders, quotes and stock alerts will show up here.'**
  String get homeAllCaughtUpBody;

  /// No description provided for @homeOrdersToAccept.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 order to accept} other{{count} orders to accept}}'**
  String homeOrdersToAccept(int count);

  /// No description provided for @homeOldestWaiting.
  ///
  /// In en, this message translates to:
  /// **'Oldest placed {time}'**
  String homeOldestWaiting(String time);

  /// No description provided for @homeQuotesToAnswer.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 quote to answer} other{{count} quotes to answer}}'**
  String homeQuotesToAnswer(int count);

  /// No description provided for @homeQuotesExpiringSoon.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 expires within a day} other{{count} expire within a day}}'**
  String homeQuotesExpiringSoon(int count);

  /// No description provided for @homeOutOfStock.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 product out of stock} other{{count} products out of stock}}'**
  String homeOutOfStock(int count);

  /// No description provided for @homeLowStock.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 product low on stock} other{{count} products low on stock}}'**
  String homeLowStock(int count);

  /// No description provided for @homePerformance.
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get homePerformance;

  /// No description provided for @periodToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get periodToday;

  /// No description provided for @period7d.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get period7d;

  /// No description provided for @period30d.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get period30d;

  /// No description provided for @homeStatsFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your numbers. Check your connection and reopen Home.'**
  String get homeStatsFailed;

  /// No description provided for @kpiSales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get kpiSales;

  /// No description provided for @kpiOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get kpiOrders;

  /// No description provided for @kpiAov.
  ///
  /// In en, this message translates to:
  /// **'Avg. order'**
  String get kpiAov;

  /// No description provided for @kpiUpVsPrevious.
  ///
  /// In en, this message translates to:
  /// **'{pct} up on the previous period'**
  String kpiUpVsPrevious(String pct);

  /// No description provided for @kpiDownVsPrevious.
  ///
  /// In en, this message translates to:
  /// **'{pct} down on the previous period'**
  String kpiDownVsPrevious(String pct);

  /// No description provided for @kpiNoComparison.
  ///
  /// In en, this message translates to:
  /// **'Nothing to compare with yet'**
  String get kpiNoComparison;

  /// No description provided for @homeNextSettlement.
  ///
  /// In en, this message translates to:
  /// **'To be paid to you'**
  String get homeNextSettlement;

  /// No description provided for @homeQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get homeQuickActions;

  /// No description provided for @homeAddProduct.
  ///
  /// In en, this message translates to:
  /// **'Add product'**
  String get homeAddProduct;

  /// No description provided for @kpiOrdersMore.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 more than before} other{{count} more than before}}'**
  String kpiOrdersMore(int count);

  /// No description provided for @kpiOrdersFewer.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 fewer than before} other{{count} fewer than before}}'**
  String kpiOrdersFewer(int count);

  /// No description provided for @kpiOrdersSame.
  ///
  /// In en, this message translates to:
  /// **'Same as before'**
  String get kpiOrdersSame;
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
