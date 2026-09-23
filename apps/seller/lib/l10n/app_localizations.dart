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

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @notificationsUnread.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Notifications, 1 unread} other{Notifications, {count} unread}}'**
  String notificationsUnread(int count);

  /// No description provided for @notificationsAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get notificationsAll;

  /// No description provided for @notificationsOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get notificationsOrders;

  /// No description provided for @notificationsQuotes.
  ///
  /// In en, this message translates to:
  /// **'Quotes'**
  String get notificationsQuotes;

  /// No description provided for @notificationsPayments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get notificationsPayments;

  /// No description provided for @notificationsAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get notificationsAccount;

  /// No description provided for @notificationsToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get notificationsToday;

  /// No description provided for @notificationsEarlier.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get notificationsEarlier;

  /// No description provided for @notificationsMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get notificationsMarkAllRead;

  /// No description provided for @notificationsMarkRead.
  ///
  /// In en, this message translates to:
  /// **'Mark read'**
  String get notificationsMarkRead;

  /// No description provided for @notificationsUnreadLabel.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get notificationsUnreadLabel;

  /// No description provided for @notificationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet. New orders, quotes and payments appear here.'**
  String get notificationsEmpty;

  /// No description provided for @notificationsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load notifications. Check your connection and open this screen again.'**
  String get notificationsLoadFailed;

  /// No description provided for @notificationsActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update your notifications. Try again.'**
  String get notificationsActionFailed;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search orders, products, quotes'**
  String get searchHint;

  /// No description provided for @searchClear.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get searchClear;

  /// No description provided for @searchPrompt.
  ///
  /// In en, this message translates to:
  /// **'Type at least 2 characters — an order number, customer, product or buyer.'**
  String get searchPrompt;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches “{query}”.'**
  String searchNoResults(String query);

  /// No description provided for @searchGroup.
  ///
  /// In en, this message translates to:
  /// **'{title} · {count}'**
  String searchGroup(String title, int count);

  /// No description provided for @searchOpenOrder.
  ///
  /// In en, this message translates to:
  /// **'Open order {number}'**
  String searchOpenOrder(String number);

  /// No description provided for @searchProducts.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get searchProducts;

  /// No description provided for @searchStock.
  ///
  /// In en, this message translates to:
  /// **'{stock} in stock'**
  String searchStock(String stock);

  /// No description provided for @homeSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get homeSearch;

  /// No description provided for @searchOrderLine.
  ///
  /// In en, this message translates to:
  /// **'{customer} · {date}'**
  String searchOrderLine(String customer, String date);

  /// No description provided for @storefrontTitle.
  ///
  /// In en, this message translates to:
  /// **'Storefront'**
  String get storefrontTitle;

  /// No description provided for @storefrontMenu.
  ///
  /// In en, this message translates to:
  /// **'Storefront'**
  String get storefrontMenu;

  /// No description provided for @storefrontMenuSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Cover, logo, description and highlights'**
  String get storefrontMenuSubtitle;

  /// No description provided for @storefrontPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get storefrontPreview;

  /// No description provided for @storefrontPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'How buyers see your store'**
  String get storefrontPreviewTitle;

  /// No description provided for @storefrontLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your storefront. Check your connection and open this screen again.'**
  String get storefrontLoadFailed;

  /// No description provided for @storefrontSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save. Check your connection and try again.'**
  String get storefrontSaveFailed;

  /// No description provided for @storefrontCover.
  ///
  /// In en, this message translates to:
  /// **'Cover photo'**
  String get storefrontCover;

  /// No description provided for @storefrontAddCover.
  ///
  /// In en, this message translates to:
  /// **'Add a cover photo'**
  String get storefrontAddCover;

  /// No description provided for @storefrontChangeCover.
  ///
  /// In en, this message translates to:
  /// **'Change cover photo'**
  String get storefrontChangeCover;

  /// No description provided for @storefrontAddLogo.
  ///
  /// In en, this message translates to:
  /// **'Add a logo'**
  String get storefrontAddLogo;

  /// No description provided for @storefrontChangeLogo.
  ///
  /// In en, this message translates to:
  /// **'Change logo'**
  String get storefrontChangeLogo;

  /// No description provided for @storefrontLogoHint.
  ///
  /// In en, this message translates to:
  /// **'A square logo works best. It appears on your storefront and next to your products.'**
  String get storefrontLogoHint;

  /// No description provided for @storefrontName.
  ///
  /// In en, this message translates to:
  /// **'Shop name'**
  String get storefrontName;

  /// No description provided for @storefrontNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your shop name'**
  String get storefrontNameRequired;

  /// No description provided for @storefrontDescription.
  ///
  /// In en, this message translates to:
  /// **'About your shop'**
  String get storefrontDescription;

  /// No description provided for @storefrontHighlights.
  ///
  /// In en, this message translates to:
  /// **'Highlights (up to {max})'**
  String storefrontHighlights(int max);

  /// No description provided for @storefrontAddHighlight.
  ///
  /// In en, this message translates to:
  /// **'Add a highlight'**
  String get storefrontAddHighlight;

  /// No description provided for @storefrontHighlightHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Farm fresh, Same-day dispatch'**
  String get storefrontHighlightHint;

  /// No description provided for @storefrontRemoveHighlight.
  ///
  /// In en, this message translates to:
  /// **'Remove {highlight}'**
  String storefrontRemoveHighlight(String highlight);

  /// No description provided for @storefrontSave.
  ///
  /// In en, this message translates to:
  /// **'Save storefront'**
  String get storefrontSave;

  /// No description provided for @profileSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save your profile. Check your connection and try again.'**
  String get profileSaveFailed;

  /// No description provided for @reviewsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get reviewsTitle;

  /// No description provided for @reviewsMenu.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get reviewsMenu;

  /// No description provided for @reviewsMenuSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ratings and replies'**
  String get reviewsMenuSubtitle;

  /// No description provided for @reviewsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your reviews. Check your connection and open this screen again.'**
  String get reviewsLoadFailed;

  /// No description provided for @reviewsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No reviews yet} =1{1 review} other{{count} reviews}}'**
  String reviewsCount(int count);

  /// No description provided for @reviewsBarLabel.
  ///
  /// In en, this message translates to:
  /// **'{stars} stars: {count}'**
  String reviewsBarLabel(int stars, int count);

  /// No description provided for @reviewsRatingLabel.
  ///
  /// In en, this message translates to:
  /// **'Rated {stars} out of 5'**
  String reviewsRatingLabel(int stars);

  /// No description provided for @reviewsAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get reviewsAll;

  /// No description provided for @reviewsUnanswered.
  ///
  /// In en, this message translates to:
  /// **'Unanswered · {count}'**
  String reviewsUnanswered(int count);

  /// No description provided for @reviewsStars.
  ///
  /// In en, this message translates to:
  /// **'{stars}★'**
  String reviewsStars(int stars);

  /// No description provided for @reviewsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet. Buyers can review a product after it is delivered.'**
  String get reviewsEmpty;

  /// No description provided for @reviewsNoneMatch.
  ///
  /// In en, this message translates to:
  /// **'No reviews match this filter.'**
  String get reviewsNoneMatch;

  /// No description provided for @reviewsAnonymous.
  ///
  /// In en, this message translates to:
  /// **'A buyer'**
  String get reviewsAnonymous;

  /// No description provided for @reviewsByLine.
  ///
  /// In en, this message translates to:
  /// **'{name} · {date}'**
  String reviewsByLine(String name, String date);

  /// No description provided for @reviewsVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified purchase'**
  String get reviewsVerified;

  /// No description provided for @reviewsYourReply.
  ///
  /// In en, this message translates to:
  /// **'Your reply'**
  String get reviewsYourReply;

  /// No description provided for @reviewsReply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get reviewsReply;

  /// No description provided for @reviewsEditReply.
  ///
  /// In en, this message translates to:
  /// **'Edit reply'**
  String get reviewsEditReply;

  /// No description provided for @reviewsReplyTitle.
  ///
  /// In en, this message translates to:
  /// **'Reply publicly'**
  String get reviewsReplyTitle;

  /// No description provided for @reviewsReplyHint.
  ///
  /// In en, this message translates to:
  /// **'Buyers see your reply under the review. You can edit it for 24 hours.'**
  String get reviewsReplyHint;

  /// No description provided for @reviewsReplyLabel.
  ///
  /// In en, this message translates to:
  /// **'Your reply'**
  String get reviewsReplyLabel;

  /// No description provided for @reviewsReplySend.
  ///
  /// In en, this message translates to:
  /// **'Post reply'**
  String get reviewsReplySend;

  /// No description provided for @reviewReplySent.
  ///
  /// In en, this message translates to:
  /// **'Reply posted'**
  String get reviewReplySent;

  /// No description provided for @reviewReplyLocked.
  ///
  /// In en, this message translates to:
  /// **'This reply can no longer be edited — replies can be changed for 24 hours.'**
  String get reviewReplyLocked;

  /// No description provided for @reviewReplyFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t post your reply. Check your connection and try again.'**
  String get reviewReplyFailed;

  /// No description provided for @prefTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get prefTitle;

  /// No description provided for @prefIntro.
  ///
  /// In en, this message translates to:
  /// **'Choose which alerts reach your phone. Everything still appears in your in-app notifications.'**
  String get prefIntro;

  /// No description provided for @prefOrders.
  ///
  /// In en, this message translates to:
  /// **'New orders and order updates'**
  String get prefOrders;

  /// No description provided for @prefQuotes.
  ///
  /// In en, this message translates to:
  /// **'Quote requests and offers'**
  String get prefQuotes;

  /// No description provided for @prefPayments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get prefPayments;

  /// No description provided for @prefStock.
  ///
  /// In en, this message translates to:
  /// **'Stock alerts'**
  String get prefStock;

  /// No description provided for @prefReviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get prefReviews;

  /// No description provided for @prefAnnouncements.
  ///
  /// In en, this message translates to:
  /// **'AgriMore announcements'**
  String get prefAnnouncements;

  /// No description provided for @prefQuietHours.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours'**
  String get prefQuietHours;

  /// No description provided for @prefQuietHoursHint.
  ///
  /// In en, this message translates to:
  /// **'No alerts on your phone during these hours'**
  String get prefQuietHoursHint;

  /// No description provided for @prefQuietFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get prefQuietFrom;

  /// No description provided for @prefQuietUntil.
  ///
  /// In en, this message translates to:
  /// **'Until'**
  String get prefQuietUntil;

  /// No description provided for @prefSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save your choice. Check your connection and try again.'**
  String get prefSaveFailed;

  /// No description provided for @helpTitle.
  ///
  /// In en, this message translates to:
  /// **'Help & support'**
  String get helpTitle;

  /// No description provided for @helpSearch.
  ///
  /// In en, this message translates to:
  /// **'Search help'**
  String get helpSearch;

  /// No description provided for @helpFaqTitle.
  ///
  /// In en, this message translates to:
  /// **'Common questions'**
  String get helpFaqTitle;

  /// No description provided for @helpNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No answers match. Contact us below.'**
  String get helpNoMatch;

  /// No description provided for @helpContactTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact AgriMore'**
  String get helpContactTitle;

  /// No description provided for @faqPayoutQ.
  ///
  /// In en, this message translates to:
  /// **'When do I get paid?'**
  String get faqPayoutQ;

  /// No description provided for @faqPayoutA.
  ///
  /// In en, this message translates to:
  /// **'A settlement is created when an order is delivered. AgriMore pays it to your bank account or UPI and shows the payment reference under Payments.'**
  String get faqPayoutA;

  /// No description provided for @faqOrderQ.
  ///
  /// In en, this message translates to:
  /// **'How fast should I accept an order?'**
  String get faqOrderQ;

  /// No description provided for @faqOrderA.
  ///
  /// In en, this message translates to:
  /// **'Accept or reject new orders as soon as you can — buyers see the status change immediately. Rejecting needs a reason, and prepaid buyers are refunded.'**
  String get faqOrderA;

  /// No description provided for @faqQuoteQ.
  ///
  /// In en, this message translates to:
  /// **'How do quotes work?'**
  String get faqQuoteQ;

  /// No description provided for @faqQuoteA.
  ///
  /// In en, this message translates to:
  /// **'Business buyers request a price for a quantity. Counter with your price and how long it is valid, accept their offer, or decline with a reason. Once accepted, the buyer can place the order at that price.'**
  String get faqQuoteA;

  /// No description provided for @faqInvoiceQ.
  ///
  /// In en, this message translates to:
  /// **'Why is my invoice a bill of supply?'**
  String get faqInvoiceQ;

  /// No description provided for @faqInvoiceA.
  ///
  /// In en, this message translates to:
  /// **'A tax invoice needs your GSTIN and an HSN code and GST rate on every product. Add them in Business details and in each product\'s tax section.'**
  String get faqInvoiceA;

  /// No description provided for @faqReviewQ.
  ///
  /// In en, this message translates to:
  /// **'Can I reply to a review?'**
  String get faqReviewQ;

  /// No description provided for @faqReviewA.
  ///
  /// In en, this message translates to:
  /// **'Yes — one public reply per review, which you can edit for 24 hours. Ratings are calculated by AgriMore and cannot be changed.'**
  String get faqReviewA;

  /// No description provided for @faqStorefrontQ.
  ///
  /// In en, this message translates to:
  /// **'How do I change my storefront?'**
  String get faqStorefrontQ;

  /// No description provided for @faqStorefrontA.
  ///
  /// In en, this message translates to:
  /// **'Go to Account → Storefront to change your cover photo, logo, description and highlights, and preview how buyers see it.'**
  String get faqStorefrontA;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsMenuSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Theme, notifications, help'**
  String get settingsMenuSubtitle;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsLicences.
  ///
  /// In en, this message translates to:
  /// **'Open-source licences'**
  String get settingsLicences;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get navOrders;

  /// No description provided for @navCatalogue.
  ///
  /// In en, this message translates to:
  /// **'Catalogue'**
  String get navCatalogue;

  /// No description provided for @navAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get navAccount;

  /// No description provided for @navOrdersPending.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Orders, 1 waiting} other{Orders, {count} waiting}}'**
  String navOrdersPending(int count);

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTitle;

  /// No description provided for @accountLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your account details. Pull down to try again.'**
  String get accountLoadFailed;

  /// No description provided for @accountNoRatings.
  ///
  /// In en, this message translates to:
  /// **'No ratings yet'**
  String get accountNoRatings;

  /// No description provided for @accountRating.
  ///
  /// In en, this message translates to:
  /// **'{rating} · {count, plural, =1{1 review} other{{count} reviews}}'**
  String accountRating(String rating, int count);

  /// No description provided for @accountProducts.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get accountProducts;

  /// No description provided for @accountDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get accountDelivered;

  /// No description provided for @accountSectionBusiness.
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get accountSectionBusiness;

  /// No description provided for @accountSectionSelling.
  ///
  /// In en, this message translates to:
  /// **'Selling & money'**
  String get accountSectionSelling;

  /// No description provided for @accountSectionAi.
  ///
  /// In en, this message translates to:
  /// **'AI assistant'**
  String get accountSectionAi;

  /// No description provided for @accountSectionApp.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get accountSectionApp;

  /// No description provided for @accountBusinessDetails.
  ///
  /// In en, this message translates to:
  /// **'Business details'**
  String get accountBusinessDetails;

  /// No description provided for @accountBusinessDetailsHint.
  ///
  /// In en, this message translates to:
  /// **'Name, GSTIN, location, hours'**
  String get accountBusinessDetailsHint;

  /// No description provided for @accountDeliveryFee.
  ///
  /// In en, this message translates to:
  /// **'Delivery fee'**
  String get accountDeliveryFee;

  /// No description provided for @accountPayoutHint.
  ///
  /// In en, this message translates to:
  /// **'Where your settlements are paid'**
  String get accountPayoutHint;

  /// No description provided for @accountPayoutUnavailable.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load your payout account right now. Reopen this screen, or contact support if it keeps happening.'**
  String get accountPayoutUnavailable;

  /// No description provided for @accountPayoutChangeHint.
  ///
  /// In en, this message translates to:
  /// **'To change your payout account, contact AgriMore support.'**
  String get accountPayoutChangeHint;

  /// No description provided for @accountIfsc.
  ///
  /// In en, this message translates to:
  /// **'IFSC {ifsc}'**
  String accountIfsc(String ifsc);

  /// No description provided for @accountAiAssistant.
  ///
  /// In en, this message translates to:
  /// **'Ask AI about your business'**
  String get accountAiAssistant;

  /// No description provided for @accountAiAssistantHint.
  ///
  /// In en, this message translates to:
  /// **'Sales, products and orders'**
  String get accountAiAssistantHint;

  /// No description provided for @accountAiConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect AI'**
  String get accountAiConnect;

  /// No description provided for @accountAiConnectHint.
  ///
  /// In en, this message translates to:
  /// **'Use your own ChatGPT or Gemini key'**
  String get accountAiConnectHint;

  /// No description provided for @accountLegal.
  ///
  /// In en, this message translates to:
  /// **'Seller policies'**
  String get accountLegal;

  /// No description provided for @legalAccurate.
  ///
  /// In en, this message translates to:
  /// **'Keep product details, prices and stock accurate.'**
  String get legalAccurate;

  /// No description provided for @legalPackOnTime.
  ///
  /// In en, this message translates to:
  /// **'Accept and pack orders on time.'**
  String get legalPackOnTime;

  /// No description provided for @legalPayouts.
  ///
  /// In en, this message translates to:
  /// **'Settlements are paid for delivered orders, after AgriMore\'s commission.'**
  String get legalPayouts;

  /// No description provided for @accountSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get accountSignOut;

  /// No description provided for @accountSignOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get accountSignOutTitle;

  /// No description provided for @accountSignOutBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ll need your phone number to sign in again.'**
  String get accountSignOutBody;

  /// No description provided for @accountSaved.
  ///
  /// In en, this message translates to:
  /// **'Business details saved'**
  String get accountSaved;

  /// No description provided for @accountBusinessName.
  ///
  /// In en, this message translates to:
  /// **'Business name'**
  String get accountBusinessName;

  /// No description provided for @accountBusinessNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your business name'**
  String get accountBusinessNameRequired;

  /// No description provided for @accountPhone.
  ///
  /// In en, this message translates to:
  /// **'Business phone'**
  String get accountPhone;

  /// No description provided for @accountGstin.
  ///
  /// In en, this message translates to:
  /// **'GSTIN (optional)'**
  String get accountGstin;

  /// No description provided for @accountGstinHelp.
  ///
  /// In en, this message translates to:
  /// **'Needed for tax invoices'**
  String get accountGstinHelp;

  /// No description provided for @accountCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get accountCity;

  /// No description provided for @accountState.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get accountState;

  /// No description provided for @accountOpens.
  ///
  /// In en, this message translates to:
  /// **'Opens'**
  String get accountOpens;

  /// No description provided for @accountCloses.
  ///
  /// In en, this message translates to:
  /// **'Closes'**
  String get accountCloses;

  /// No description provided for @accountRadius.
  ///
  /// In en, this message translates to:
  /// **'Delivery radius (km)'**
  String get accountRadius;

  /// No description provided for @accountRadiusInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number from 1 to {max}'**
  String accountRadiusInvalid(int max);

  /// No description provided for @accountSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get accountSave;

  /// No description provided for @stageToAccept.
  ///
  /// In en, this message translates to:
  /// **'To accept'**
  String get stageToAccept;

  /// No description provided for @stagePacking.
  ///
  /// In en, this message translates to:
  /// **'Packing'**
  String get stagePacking;

  /// No description provided for @stageReady.
  ///
  /// In en, this message translates to:
  /// **'Ready for pickup'**
  String get stageReady;

  /// No description provided for @stageOutForDelivery.
  ///
  /// In en, this message translates to:
  /// **'Out for delivery'**
  String get stageOutForDelivery;

  /// No description provided for @stageDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get stageDelivered;

  /// No description provided for @stageCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get stageCancelled;

  /// No description provided for @stageOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get stageOther;

  /// No description provided for @ordersSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Order number, customer or product'**
  String get ordersSearchHint;

  /// No description provided for @ordersLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your orders. Check your connection and try again.'**
  String get ordersLoadFailed;

  /// No description provided for @ordersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No orders yet. New orders appear here the moment a buyer places them.'**
  String get ordersEmpty;

  /// No description provided for @ordersNoneMatch.
  ///
  /// In en, this message translates to:
  /// **'No orders match.'**
  String get ordersNoneMatch;

  /// No description provided for @ordersCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get ordersCustomer;

  /// No description provided for @ordersItems.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String ordersItems(int count);

  /// No description provided for @ordersPrepaid.
  ///
  /// In en, this message translates to:
  /// **'Prepaid'**
  String get ordersPrepaid;

  /// No description provided for @ordersCod.
  ///
  /// In en, this message translates to:
  /// **'Cash on delivery'**
  String get ordersCod;

  /// No description provided for @stageToPack.
  ///
  /// In en, this message translates to:
  /// **'To pack'**
  String get stageToPack;

  /// No description provided for @stepPlaced.
  ///
  /// In en, this message translates to:
  /// **'Placed'**
  String get stepPlaced;

  /// No description provided for @stepAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get stepAccepted;

  /// No description provided for @stepPacking.
  ///
  /// In en, this message translates to:
  /// **'Packing'**
  String get stepPacking;

  /// No description provided for @stepReady.
  ///
  /// In en, this message translates to:
  /// **'Ready for pickup'**
  String get stepReady;

  /// No description provided for @orderCall.
  ///
  /// In en, this message translates to:
  /// **'Call customer'**
  String get orderCall;

  /// No description provided for @orderChat.
  ///
  /// In en, this message translates to:
  /// **'Message customer'**
  String get orderChat;

  /// No description provided for @orderCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get orderCustomer;

  /// No description provided for @orderName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get orderName;

  /// No description provided for @orderAddress.
  ///
  /// In en, this message translates to:
  /// **'Deliver to'**
  String get orderAddress;

  /// No description provided for @orderNoAddress.
  ///
  /// In en, this message translates to:
  /// **'No address provided'**
  String get orderNoAddress;

  /// No description provided for @orderSlot.
  ///
  /// In en, this message translates to:
  /// **'Delivery slot'**
  String get orderSlot;

  /// No description provided for @orderNote.
  ///
  /// In en, this message translates to:
  /// **'Buyer\'s note'**
  String get orderNote;

  /// No description provided for @orderPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get orderPayment;

  /// No description provided for @orderTax.
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get orderTax;

  /// No description provided for @orderReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get orderReject;

  /// No description provided for @orderCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel order'**
  String get orderCancel;

  /// No description provided for @orderAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept order'**
  String get orderAccept;

  /// No description provided for @orderStartPacking.
  ///
  /// In en, this message translates to:
  /// **'Start packing'**
  String get orderStartPacking;

  /// No description provided for @orderMarkReady.
  ///
  /// In en, this message translates to:
  /// **'Mark ready for pickup'**
  String get orderMarkReady;

  /// No description provided for @homeOrdersToPack.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 accepted order to pack} other{{count} accepted orders to pack}}'**
  String homeOrdersToPack(int count);

  /// No description provided for @productNewPost.
  ///
  /// In en, this message translates to:
  /// **'New post'**
  String get productNewPost;

  /// No description provided for @productSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search your products'**
  String get productSearchHint;

  /// No description provided for @productsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your products. Check your connection and try again.'**
  String get productsLoadFailed;

  /// No description provided for @productsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No products yet. Add your first product to start selling.'**
  String get productsEmpty;

  /// No description provided for @productsNoneMatch.
  ///
  /// In en, this message translates to:
  /// **'No products match.'**
  String get productsNoneMatch;

  /// No description provided for @productOutOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get productOutOfStock;

  /// No description provided for @productLowStock.
  ///
  /// In en, this message translates to:
  /// **'Only {stock} left'**
  String productLowStock(String stock);

  /// No description provided for @productLive.
  ///
  /// In en, this message translates to:
  /// **'Visible to buyers'**
  String get productLive;

  /// No description provided for @productHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden from buyers'**
  String get productHidden;

  /// No description provided for @productStock.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get productStock;

  /// No description provided for @productEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get productEdit;

  /// No description provided for @productDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get productDelete;

  /// No description provided for @productDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this product?'**
  String get productDeleteTitle;

  /// No description provided for @productDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'“{name}” will be removed from your catalogue. This can\'t be undone.'**
  String productDeleteBody(String name);

  /// No description provided for @productDeleted.
  ///
  /// In en, this message translates to:
  /// **'Product deleted'**
  String get productDeleted;

  /// No description provided for @productStockTitle.
  ///
  /// In en, this message translates to:
  /// **'Update stock'**
  String get productStockTitle;

  /// No description provided for @productStockLabel.
  ///
  /// In en, this message translates to:
  /// **'Units in stock'**
  String get productStockLabel;

  /// No description provided for @productStockSaved.
  ///
  /// In en, this message translates to:
  /// **'Stock updated'**
  String get productStockSaved;

  /// No description provided for @productActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update this product. Check your connection and try again.'**
  String get productActionFailed;

  /// No description provided for @editorNewTitle.
  ///
  /// In en, this message translates to:
  /// **'Add product'**
  String get editorNewTitle;

  /// No description provided for @editorEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit product'**
  String get editorEditTitle;

  /// No description provided for @editorAddPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add a product photo'**
  String get editorAddPhoto;

  /// No description provided for @editorChangePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get editorChangePhoto;

  /// No description provided for @editorSeparator.
  ///
  /// In en, this message translates to:
  /// **' · '**
  String get editorSeparator;

  /// No description provided for @editorName.
  ///
  /// In en, this message translates to:
  /// **'Product name'**
  String get editorName;

  /// No description provided for @editorDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get editorDescription;

  /// No description provided for @editorDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'What it is, quantity, quality, how it\'s packed'**
  String get editorDescriptionHint;

  /// No description provided for @editorSalePrice.
  ///
  /// In en, this message translates to:
  /// **'Selling price (₹)'**
  String get editorSalePrice;

  /// No description provided for @editorMrp.
  ///
  /// In en, this message translates to:
  /// **'MRP (₹, optional)'**
  String get editorMrp;

  /// No description provided for @editorStock.
  ///
  /// In en, this message translates to:
  /// **'Units in stock'**
  String get editorStock;

  /// No description provided for @editorLowStock.
  ///
  /// In en, this message translates to:
  /// **'Low-stock alert at'**
  String get editorLowStock;

  /// No description provided for @editorLowStockHelp.
  ///
  /// In en, this message translates to:
  /// **'You\'ll be alerted below this many units'**
  String get editorLowStockHelp;

  /// No description provided for @editorCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get editorCategory;

  /// No description provided for @editorCategoryHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Vegetables'**
  String get editorCategoryHint;

  /// No description provided for @editorRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get editorRequired;

  /// No description provided for @editorCenterPricing.
  ///
  /// In en, this message translates to:
  /// **'Centre / area pricing'**
  String get editorCenterPricing;

  /// No description provided for @editorCenter.
  ///
  /// In en, this message translates to:
  /// **'Centre'**
  String get editorCenter;

  /// No description provided for @editorLoadingCenters.
  ///
  /// In en, this message translates to:
  /// **'Loading centres…'**
  String get editorLoadingCenters;

  /// No description provided for @editorPriceManual.
  ///
  /// In en, this message translates to:
  /// **'Manual price'**
  String get editorPriceManual;

  /// No description provided for @editorPriceArea.
  ///
  /// In en, this message translates to:
  /// **'Area price'**
  String get editorPriceArea;

  /// No description provided for @editorPriceDefault.
  ///
  /// In en, this message translates to:
  /// **'Default price'**
  String get editorPriceDefault;

  /// No description provided for @editorPriceCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get editorPriceCurrent;

  /// No description provided for @editorPriceChip.
  ///
  /// In en, this message translates to:
  /// **'{label}: {price}'**
  String editorPriceChip(String label, String price);

  /// No description provided for @editorNoValue.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get editorNoValue;

  /// No description provided for @editorResetPrice.
  ///
  /// In en, this message translates to:
  /// **'Use the mapped price'**
  String get editorResetPrice;

  /// No description provided for @editorCoverage.
  ///
  /// In en, this message translates to:
  /// **'Delivery coverage'**
  String get editorCoverage;

  /// No description provided for @editorCoverageHint.
  ///
  /// In en, this message translates to:
  /// **'The whole state by default. Use a radius for local delivery.'**
  String get editorCoverageHint;

  /// No description provided for @editorCoverageState.
  ///
  /// In en, this message translates to:
  /// **'Whole state'**
  String get editorCoverageState;

  /// No description provided for @editorCoverageDistrict.
  ///
  /// In en, this message translates to:
  /// **'District'**
  String get editorCoverageDistrict;

  /// No description provided for @editorCoverageRadius.
  ///
  /// In en, this message translates to:
  /// **'Radius'**
  String get editorCoverageRadius;

  /// No description provided for @editorLatitude.
  ///
  /// In en, this message translates to:
  /// **'Latitude'**
  String get editorLatitude;

  /// No description provided for @editorLongitude.
  ///
  /// In en, this message translates to:
  /// **'Longitude'**
  String get editorLongitude;

  /// No description provided for @editorUseLocation.
  ///
  /// In en, this message translates to:
  /// **'Use my current location'**
  String get editorUseLocation;

  /// No description provided for @editorDetecting.
  ///
  /// In en, this message translates to:
  /// **'Detecting…'**
  String get editorDetecting;

  /// No description provided for @editorRadiusValue.
  ///
  /// In en, this message translates to:
  /// **'Radius: {km} km'**
  String editorRadiusValue(int km);

  /// No description provided for @editorB2b.
  ///
  /// In en, this message translates to:
  /// **'Wholesale (B2B)'**
  String get editorB2b;

  /// No description provided for @editorB2bHint.
  ///
  /// In en, this message translates to:
  /// **'Offer a bulk price with a minimum order quantity.'**
  String get editorB2bHint;

  /// No description provided for @editorB2bPrice.
  ///
  /// In en, this message translates to:
  /// **'B2B price (₹)'**
  String get editorB2bPrice;

  /// No description provided for @editorB2bMoq.
  ///
  /// In en, this message translates to:
  /// **'Minimum order quantity'**
  String get editorB2bMoq;

  /// No description provided for @editorB2bRule.
  ///
  /// In en, this message translates to:
  /// **'Must be lower than your selling price.'**
  String get editorB2bRule;

  /// No description provided for @editorUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update product'**
  String get editorUpdate;

  /// No description provided for @editorSave.
  ///
  /// In en, this message translates to:
  /// **'Save product'**
  String get editorSave;

  /// No description provided for @editorSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get editorSaving;

  /// No description provided for @editorUpdated.
  ///
  /// In en, this message translates to:
  /// **'Product updated'**
  String get editorUpdated;

  /// No description provided for @editorAdded.
  ///
  /// In en, this message translates to:
  /// **'Product added. It goes live once AgriMore approves it.'**
  String get editorAdded;

  /// No description provided for @editorSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save this product. Check your connection and try again.'**
  String get editorSaveFailed;

  /// No description provided for @editorUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t upload the photo. Try again.'**
  String get editorUploadFailed;

  /// No description provided for @editorPhotoFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open that photo. Try another one.'**
  String get editorPhotoFailed;

  /// No description provided for @editorNeedDistrict.
  ///
  /// In en, this message translates to:
  /// **'Choose a delivery district.'**
  String get editorNeedDistrict;

  /// No description provided for @editorNeedCoordinates.
  ///
  /// In en, this message translates to:
  /// **'Enter a latitude and longitude for radius delivery.'**
  String get editorNeedCoordinates;

  /// No description provided for @editorNeedB2bPrice.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid B2B price.'**
  String get editorNeedB2bPrice;

  /// No description provided for @editorB2bTooHigh.
  ///
  /// In en, this message translates to:
  /// **'The B2B price ({b2b}) must be lower than the selling price ({sale}).'**
  String editorB2bTooHigh(String b2b, String sale);

  /// No description provided for @editorNeedMoq.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid minimum order quantity.'**
  String get editorNeedMoq;

  /// No description provided for @editorLocationOff.
  ///
  /// In en, this message translates to:
  /// **'Turn on location services to use your current location.'**
  String get editorLocationOff;

  /// No description provided for @editorLocationDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission was denied.'**
  String get editorLocationDenied;

  /// No description provided for @editorLocationFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t find your current location.'**
  String get editorLocationFailed;

  /// No description provided for @aiTitle.
  ///
  /// In en, this message translates to:
  /// **'AI assistant'**
  String get aiTitle;

  /// No description provided for @aiWebOnly.
  ///
  /// In en, this message translates to:
  /// **'AI assistant activation is available on the AgriMore seller website (agrimore.in). The app doesn\'t process this payment.'**
  String get aiWebOnly;

  /// No description provided for @aiActivateTitle.
  ///
  /// In en, this message translates to:
  /// **'Activate your AI assistant'**
  String get aiActivateTitle;

  /// No description provided for @aiActivateBody.
  ///
  /// In en, this message translates to:
  /// **'Connect your own ChatGPT or Gemini API key for sales analysis, pricing insights and business questions.'**
  String get aiActivateBody;

  /// No description provided for @aiActivateCta.
  ///
  /// In en, this message translates to:
  /// **'Activate — ₹50'**
  String get aiActivateCta;

  /// No description provided for @aiPaymentReceived.
  ///
  /// In en, this message translates to:
  /// **'Payment received'**
  String get aiPaymentReceived;

  /// No description provided for @aiConnectHint.
  ///
  /// In en, this message translates to:
  /// **'Now add your AI provider details to finish connecting.'**
  String get aiConnectHint;

  /// No description provided for @aiProvider.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get aiProvider;

  /// No description provided for @aiProviderGemini.
  ///
  /// In en, this message translates to:
  /// **'Google Gemini'**
  String get aiProviderGemini;

  /// No description provided for @aiProviderChatgpt.
  ///
  /// In en, this message translates to:
  /// **'ChatGPT (OpenAI)'**
  String get aiProviderChatgpt;

  /// No description provided for @aiApiKey.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get aiApiKey;

  /// No description provided for @aiApiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Paste your API key'**
  String get aiApiKeyHint;

  /// No description provided for @aiConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get aiConnect;

  /// No description provided for @aiConnected.
  ///
  /// In en, this message translates to:
  /// **'AI assistant connected'**
  String get aiConnected;

  /// No description provided for @aiDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get aiDisconnect;

  /// No description provided for @aiDisconnectTitle.
  ///
  /// In en, this message translates to:
  /// **'Disconnect the AI assistant?'**
  String get aiDisconnectTitle;

  /// No description provided for @aiDisconnectBody.
  ///
  /// In en, this message translates to:
  /// **'Your API key is removed. You can connect again later.'**
  String get aiDisconnectBody;

  /// No description provided for @aiMoneyTaken.
  ///
  /// In en, this message translates to:
  /// **'We received your payment but couldn\'t confirm it just now. Try connecting again — you won\'t be charged twice for the same payment.'**
  String get aiMoneyTaken;

  /// No description provided for @aiPaymentReference.
  ///
  /// In en, this message translates to:
  /// **'Payment reference: {id}'**
  String aiPaymentReference(String id);

  /// No description provided for @aiRetryConnect.
  ///
  /// In en, this message translates to:
  /// **'Try connecting again'**
  String get aiRetryConnect;

  /// No description provided for @aiPreparingPayment.
  ///
  /// In en, this message translates to:
  /// **'Preparing payment…'**
  String get aiPreparingPayment;

  /// No description provided for @aiOpeningPayment.
  ///
  /// In en, this message translates to:
  /// **'Opening payment…'**
  String get aiOpeningPayment;

  /// No description provided for @aiVerifyingPayment.
  ///
  /// In en, this message translates to:
  /// **'Verifying payment…'**
  String get aiVerifyingPayment;

  /// No description provided for @aiPleaseWait.
  ///
  /// In en, this message translates to:
  /// **'Please wait…'**
  String get aiPleaseWait;

  /// No description provided for @aiSignInAgain.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again and retry.'**
  String get aiSignInAgain;

  /// No description provided for @aiStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start the payment. Try again.'**
  String get aiStartFailed;

  /// No description provided for @aiConnectFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t connect. Check your API key and try again.'**
  String get aiConnectFailed;

  /// No description provided for @aiDisconnectFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t disconnect. Try again.'**
  String get aiDisconnectFailed;

  /// No description provided for @aiConnectTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect your AI assistant'**
  String get aiConnectTitle;

  /// No description provided for @aiConnectBody.
  ///
  /// In en, this message translates to:
  /// **'Connect your own ChatGPT or Gemini key to ask about your products and orders.'**
  String get aiConnectBody;

  /// No description provided for @aiConnectNow.
  ///
  /// In en, this message translates to:
  /// **'Connect now'**
  String get aiConnectNow;

  /// No description provided for @aiInputHint.
  ///
  /// In en, this message translates to:
  /// **'Ask about your sales, products or orders'**
  String get aiInputHint;

  /// No description provided for @aiSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get aiSend;

  /// No description provided for @aiThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking'**
  String get aiThinking;

  /// No description provided for @aiPromptRestock.
  ///
  /// In en, this message translates to:
  /// **'Which products should I restock?'**
  String get aiPromptRestock;

  /// No description provided for @aiPromptBestSellers.
  ///
  /// In en, this message translates to:
  /// **'What sold best this week?'**
  String get aiPromptBestSellers;

  /// No description provided for @aiPromptPricing.
  ///
  /// In en, this message translates to:
  /// **'Are any of my prices out of line?'**
  String get aiPromptPricing;

  /// No description provided for @feeIntro.
  ///
  /// In en, this message translates to:
  /// **'Choose how you charge customers for delivery.'**
  String get feeIntro;

  /// No description provided for @feeFlat.
  ///
  /// In en, this message translates to:
  /// **'Flat fee'**
  String get feeFlat;

  /// No description provided for @feeSlab.
  ///
  /// In en, this message translates to:
  /// **'By order value'**
  String get feeSlab;

  /// No description provided for @feeAmount.
  ///
  /// In en, this message translates to:
  /// **'Delivery fee (₹)'**
  String get feeAmount;

  /// No description provided for @feeFlatHelp.
  ///
  /// In en, this message translates to:
  /// **'Charged on every order, whatever its value'**
  String get feeFlatHelp;

  /// No description provided for @feeSlabRule.
  ///
  /// In en, this message translates to:
  /// **'One tier must start at a minimum order value of ₹0.'**
  String get feeSlabRule;

  /// No description provided for @feeMinOrder.
  ///
  /// In en, this message translates to:
  /// **'Min. order (₹)'**
  String get feeMinOrder;

  /// No description provided for @feeSlabFee.
  ///
  /// In en, this message translates to:
  /// **'Fee (₹)'**
  String get feeSlabFee;

  /// No description provided for @feeRemoveSlab.
  ///
  /// In en, this message translates to:
  /// **'Remove this tier'**
  String get feeRemoveSlab;

  /// No description provided for @feeAddSlab.
  ///
  /// In en, this message translates to:
  /// **'Add tier'**
  String get feeAddSlab;

  /// No description provided for @feeSaved.
  ///
  /// In en, this message translates to:
  /// **'Delivery fee updated'**
  String get feeSaved;

  /// No description provided for @feeSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save your delivery fee. Try again.'**
  String get feeSaveFailed;

  /// No description provided for @feeDefault.
  ///
  /// In en, this message translates to:
  /// **'Using default pricing'**
  String get feeDefault;

  /// No description provided for @feeSummaryFlat.
  ///
  /// In en, this message translates to:
  /// **'Flat {amount}'**
  String feeSummaryFlat(String amount);

  /// No description provided for @feeSummarySlab.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{By order value · 1 tier} other{By order value · {count} tiers}}'**
  String feeSummarySlab(int count);

  /// No description provided for @postHint.
  ///
  /// In en, this message translates to:
  /// **'What\'s new? Tell your followers about it'**
  String get postHint;

  /// No description provided for @postAddPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add a photo'**
  String get postAddPhoto;

  /// No description provided for @postRemovePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get postRemovePhoto;

  /// No description provided for @postTagProduct.
  ///
  /// In en, this message translates to:
  /// **'Tag a product (optional)'**
  String get postTagProduct;

  /// No description provided for @postNoTag.
  ///
  /// In en, this message translates to:
  /// **'No product'**
  String get postNoTag;

  /// No description provided for @postPublish.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get postPublish;

  /// No description provided for @postPosting.
  ///
  /// In en, this message translates to:
  /// **'Posting…'**
  String get postPosting;

  /// No description provided for @postEmpty.
  ///
  /// In en, this message translates to:
  /// **'Add some text, a photo or a product first.'**
  String get postEmpty;

  /// No description provided for @postPublished.
  ///
  /// In en, this message translates to:
  /// **'Posted to your followers'**
  String get postPublished;

  /// No description provided for @postFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t publish your post. Try again.'**
  String get postFailed;

  /// No description provided for @insightsTitle.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get insightsTitle;

  /// No description provided for @insightsHint.
  ///
  /// In en, this message translates to:
  /// **'Sales trends, orders and best sellers'**
  String get insightsHint;

  /// No description provided for @insightsDays.
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String insightsDays(int days);

  /// No description provided for @insightsVsPrevious.
  ///
  /// In en, this message translates to:
  /// **'{delta} vs {previous} in the previous period'**
  String insightsVsPrevious(String delta, String previous);

  /// No description provided for @insightsChartSummary.
  ///
  /// In en, this message translates to:
  /// **'Sales {current} in the last {days} days, against {previous} in the {days} days before.'**
  String insightsChartSummary(String current, String previous, int days);

  /// No description provided for @insightsThisPeriod.
  ///
  /// In en, this message translates to:
  /// **'This period'**
  String get insightsThisPeriod;

  /// No description provided for @insightsPreviousPeriod.
  ///
  /// In en, this message translates to:
  /// **'Previous period'**
  String get insightsPreviousPeriod;

  /// No description provided for @insightsB2bShare.
  ///
  /// In en, this message translates to:
  /// **'{share} of sales came from business (B2B) orders'**
  String insightsB2bShare(String share);

  /// No description provided for @insightsOrdersByStage.
  ///
  /// In en, this message translates to:
  /// **'Orders by stage'**
  String get insightsOrdersByStage;

  /// No description provided for @insightsTopProducts.
  ///
  /// In en, this message translates to:
  /// **'Best sellers'**
  String get insightsTopProducts;

  /// No description provided for @insightsNoOrders.
  ///
  /// In en, this message translates to:
  /// **'No orders in this period yet.'**
  String get insightsNoOrders;

  /// No description provided for @healthTitle.
  ///
  /// In en, this message translates to:
  /// **'Account health'**
  String get healthTitle;

  /// No description provided for @healthNotEnoughData.
  ///
  /// In en, this message translates to:
  /// **'Not enough activity yet to score your account. It appears after a few orders, reviews or quotes.'**
  String get healthNotEnoughData;

  /// No description provided for @healthNotEnoughDataShort.
  ///
  /// In en, this message translates to:
  /// **'Shown after a few orders'**
  String get healthNotEnoughDataShort;

  /// No description provided for @healthExplainer.
  ///
  /// In en, this message translates to:
  /// **'Calculated from the last 30 days. Only measures with enough data count.'**
  String get healthExplainer;

  /// No description provided for @healthScoreLabel.
  ///
  /// In en, this message translates to:
  /// **'Account health {score} out of 100'**
  String healthScoreLabel(int score);

  /// No description provided for @healthGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get healthGood;

  /// No description provided for @healthFair.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get healthFair;

  /// No description provided for @healthPoor.
  ///
  /// In en, this message translates to:
  /// **'At risk'**
  String get healthPoor;

  /// No description provided for @healthFulfilment.
  ///
  /// In en, this message translates to:
  /// **'Orders delivered'**
  String get healthFulfilment;

  /// No description provided for @healthCancellations.
  ///
  /// In en, this message translates to:
  /// **'Cancellations'**
  String get healthCancellations;

  /// No description provided for @healthRating.
  ///
  /// In en, this message translates to:
  /// **'Buyer rating'**
  String get healthRating;

  /// No description provided for @healthListings.
  ///
  /// In en, this message translates to:
  /// **'Complete listings'**
  String get healthListings;

  /// No description provided for @healthQuotes.
  ///
  /// In en, this message translates to:
  /// **'Quotes answered within a day'**
  String get healthQuotes;

  /// No description provided for @healthTargetAtLeast.
  ///
  /// In en, this message translates to:
  /// **'Target: at least {value}'**
  String healthTargetAtLeast(String value);

  /// No description provided for @healthTargetAtMost.
  ///
  /// In en, this message translates to:
  /// **'Target: at most {value}'**
  String healthTargetAtMost(String value);

  /// No description provided for @healthTipFulfilment.
  ///
  /// In en, this message translates to:
  /// **'Accept only what you can deliver, and mark orders ready on time.'**
  String get healthTipFulfilment;

  /// No description provided for @healthTipCancellations.
  ///
  /// In en, this message translates to:
  /// **'Keep stock accurate so you don\'t have to cancel accepted orders.'**
  String get healthTipCancellations;

  /// No description provided for @healthTipRating.
  ///
  /// In en, this message translates to:
  /// **'Reply to reviews and pack carefully — buyers rate the whole experience.'**
  String get healthTipRating;

  /// No description provided for @healthTipListings.
  ///
  /// In en, this message translates to:
  /// **'Add a photo, a description and the HSN code with GST rate to every live product.'**
  String get healthTipListings;

  /// No description provided for @healthTipQuotes.
  ///
  /// In en, this message translates to:
  /// **'Answer quote requests within a day — counter, accept or decline.'**
  String get healthTipQuotes;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersion;

  /// No description provided for @settingsVersionValue.
  ///
  /// In en, this message translates to:
  /// **'{version} ({build})'**
  String settingsVersionValue(String version, String build);

  /// No description provided for @filterLowStock.
  ///
  /// In en, this message translates to:
  /// **'Low stock'**
  String get filterLowStock;

  /// No description provided for @storeStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Store status'**
  String get storeStatusTitle;

  /// No description provided for @storeStatusOpen.
  ///
  /// In en, this message translates to:
  /// **'Taking orders'**
  String get storeStatusOpen;

  /// No description provided for @storeStatusPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused — not taking orders'**
  String get storeStatusPaused;

  /// No description provided for @storeAcceptingOrders.
  ///
  /// In en, this message translates to:
  /// **'Accepting orders'**
  String get storeAcceptingOrders;

  /// No description provided for @storeAcceptingHint.
  ///
  /// In en, this message translates to:
  /// **'Buyers can order from your store.'**
  String get storeAcceptingHint;

  /// No description provided for @storePausedHint.
  ///
  /// In en, this message translates to:
  /// **'Buyers see your store but can\'t place orders.'**
  String get storePausedHint;

  /// No description provided for @storePauseFor.
  ///
  /// In en, this message translates to:
  /// **'Pause for'**
  String get storePauseFor;

  /// No description provided for @storePauseDays.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day} other{{days} days}}'**
  String storePauseDays(int days);

  /// No description provided for @storePauseUntilResumed.
  ///
  /// In en, this message translates to:
  /// **'Until I resume'**
  String get storePauseUntilResumed;

  /// No description provided for @storePauseConsequence.
  ///
  /// In en, this message translates to:
  /// **'New orders and quotes can\'t be placed while paused. Orders you already have are not affected.'**
  String get storePauseConsequence;

  /// No description provided for @storePauseCta.
  ///
  /// In en, this message translates to:
  /// **'Pause my store'**
  String get storePauseCta;

  /// No description provided for @storePausedTitle.
  ///
  /// In en, this message translates to:
  /// **'Your store is paused'**
  String get storePausedTitle;

  /// No description provided for @storePausedBody.
  ///
  /// In en, this message translates to:
  /// **'Buyers can\'t place orders until you resume.'**
  String get storePausedBody;

  /// No description provided for @storePausedUntil.
  ///
  /// In en, this message translates to:
  /// **'Buyers can\'t place orders until {date}.'**
  String storePausedUntil(String date);

  /// No description provided for @storeResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get storeResume;

  /// No description provided for @storeResumed.
  ///
  /// In en, this message translates to:
  /// **'Your store is taking orders again'**
  String get storeResumed;

  /// No description provided for @storePausedToast.
  ///
  /// In en, this message translates to:
  /// **'Your store is paused'**
  String get storePausedToast;

  /// No description provided for @variantsTitle.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get variantsTitle;

  /// No description provided for @variantsHint.
  ///
  /// In en, this message translates to:
  /// **'Sizes or pack weights, each with its own price and stock. Leave empty for a single product.'**
  String get variantsHint;

  /// No description provided for @variantsLine.
  ///
  /// In en, this message translates to:
  /// **'{price} · {stock} in stock'**
  String variantsLine(String price, String stock);

  /// No description provided for @variantsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add option'**
  String get variantsAdd;

  /// No description provided for @variantsEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit option'**
  String get variantsEdit;

  /// No description provided for @variantsRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}'**
  String variantsRemove(String name);

  /// No description provided for @variantsName.
  ///
  /// In en, this message translates to:
  /// **'Option name'**
  String get variantsName;

  /// No description provided for @variantsNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 1 kg, 5 kg, Large'**
  String get variantsNameHint;

  /// No description provided for @variantsDuplicate.
  ///
  /// In en, this message translates to:
  /// **'You already have an option with this name'**
  String get variantsDuplicate;

  /// No description provided for @variantsOrderLine.
  ///
  /// In en, this message translates to:
  /// **'Option: {name}'**
  String variantsOrderLine(String name);
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
