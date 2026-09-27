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

  /// App title in the task switcher
  ///
  /// In en, this message translates to:
  /// **'Agrimore Delivery'**
  String get appName;

  /// Screen-reader label while the account loads
  ///
  /// In en, this message translates to:
  /// **'Loading your account'**
  String get loadingAccount;

  /// Bottom navigation label: the dashboard tab
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// Bottom navigation label: active work and delivery history
  ///
  /// In en, this message translates to:
  /// **'Deliveries'**
  String get navDeliveries;

  /// Bottom navigation label: pay, cash and statements
  ///
  /// In en, this message translates to:
  /// **'Earnings'**
  String get navEarnings;

  /// Bottom navigation label: notifications
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get navInbox;

  /// Bottom navigation label: the rider's own account
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// Sign-in refused: wrong email/password
  ///
  /// In en, this message translates to:
  /// **'Email or password is incorrect.'**
  String get authWrongCredentials;

  /// Sign-in refused: malformed email
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get authInvalidEmail;

  /// Sign-in throttled
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a few minutes, then try again.'**
  String get authTooManyAttempts;

  /// Sign-in failed offline
  ///
  /// In en, this message translates to:
  /// **'No connection. Check your internet and try again.'**
  String get authNetwork;

  /// Firebase account disabled
  ///
  /// In en, this message translates to:
  /// **'This account is turned off. Contact Agrimore support.'**
  String get authAccountDisabled;

  /// Signed in with a non-rider account
  ///
  /// In en, this message translates to:
  /// **'This account is not a delivery partner account.'**
  String get authNotDeliveryPartner;

  /// Profile read only reached the device cache / failed
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your account. Check your connection.'**
  String get authProfileUnavailable;

  /// Any other sign-in failure
  ///
  /// In en, this message translates to:
  /// **'Sign-in didn\'t work. Try again.'**
  String get authUnknown;

  /// Retry button
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get actionRetry;

  /// Sign-out button
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get actionSignOut;

  /// Title when the profile can't be read
  ///
  /// In en, this message translates to:
  /// **'Account not loaded'**
  String get sessionLoadFailedTitle;

  /// Screen-reader label while active orders load
  ///
  /// In en, this message translates to:
  /// **'Loading your orders'**
  String get activeWorkLoading;

  /// Active orders came from the device cache
  ///
  /// In en, this message translates to:
  /// **'Showing saved data — reconnecting'**
  String get activeWorkOffline;

  /// Active-work read refused by rules
  ///
  /// In en, this message translates to:
  /// **'Your account can\'t read orders right now. Sign out and in again, or contact support.'**
  String get activeWorkErrorPermission;

  /// Active-work read failed offline
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach Agrimore. Check your connection.'**
  String get activeWorkErrorOffline;

  /// Active-work read failed otherwise
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your orders.'**
  String get activeWorkErrorUnknown;

  /// Rider holds more than one active order
  ///
  /// In en, this message translates to:
  /// **'{count} orders are assigned to you'**
  String activeWorkMultipleTitle(int count);

  /// Explains multiple active orders
  ///
  /// In en, this message translates to:
  /// **'Finish them one at a time. If you did not accept all of them, call Agrimore support.'**
  String get activeWorkMultipleBody;

  /// Button opening one of several active orders
  ///
  /// In en, this message translates to:
  /// **'Open order {number}'**
  String activeWorkOpen(String number);

  /// Today's count before it is known
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get todayDeliveredUnknown;

  /// History screen title
  ///
  /// In en, this message translates to:
  /// **'Delivery history'**
  String get historyTitle;

  /// History with no orders
  ///
  /// In en, this message translates to:
  /// **'No orders yet'**
  String get historyEmpty;

  /// Load the next history page
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get historyLoadMore;

  /// End of history
  ///
  /// In en, this message translates to:
  /// **'That\'s all your orders'**
  String get historyEnd;

  /// History row title
  ///
  /// In en, this message translates to:
  /// **'Order {number}'**
  String historyOrderNumber(String number);

  /// History status label
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get historyStatusDelivered;

  /// History status label
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get historyStatusActive;

  /// History status label
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get historyStatusCancelled;

  /// History status label
  ///
  /// In en, this message translates to:
  /// **'Returned'**
  String get historyStatusReturned;

  /// History status: no longer this rider's / unknown state
  ///
  /// In en, this message translates to:
  /// **'Other status'**
  String get historyStatusOther;

  /// Explains that the list is paged
  ///
  /// In en, this message translates to:
  /// **'Newest first, 20 at a time.'**
  String get historyHint;

  /// Splash screen tagline
  ///
  /// In en, this message translates to:
  /// **'Delivery Partner'**
  String get splashTagline;

  /// Dashboard quick action title
  ///
  /// In en, this message translates to:
  /// **'Delivery history'**
  String get historyActionTitle;

  /// Dashboard quick action subtitle
  ///
  /// In en, this message translates to:
  /// **'Every order you carried, newest first'**
  String get historyActionSubtitle;

  /// Registration screen title
  ///
  /// In en, this message translates to:
  /// **'Become a delivery partner'**
  String get regTitle;

  /// Shown when registration resumes for a signed-in account
  ///
  /// In en, this message translates to:
  /// **'Your account is ready — finish your details to apply.'**
  String get regResumeNote;

  /// Dialog title offering to resume an interrupted registration
  ///
  /// In en, this message translates to:
  /// **'Resume registration?'**
  String get regDraftFoundTitle;

  /// Dialog body offering to resume an interrupted registration
  ///
  /// In en, this message translates to:
  /// **'You have an unfinished registration. Continue where you left off, or start over and re-enter your details.'**
  String get regDraftFoundBody;

  /// Dialog action: continue an interrupted registration
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get regDraftResume;

  /// Dialog action: discard an interrupted registration and begin again
  ///
  /// In en, this message translates to:
  /// **'Start over'**
  String get regDraftStartOver;

  /// AppBar action to discard the current registration draft
  ///
  /// In en, this message translates to:
  /// **'Start over'**
  String get regStartOverAction;

  /// Confirmation dialog title before discarding a registration draft
  ///
  /// In en, this message translates to:
  /// **'Start over?'**
  String get regDraftDiscardTitle;

  /// Confirmation dialog body before discarding a registration draft
  ///
  /// In en, this message translates to:
  /// **'This clears everything you\'ve entered so far, including any photos you\'ve picked. This can\'t be undone.'**
  String get regDraftDiscardBody;

  /// Stepper step
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get regStepAccount;

  /// Stepper step
  ///
  /// In en, this message translates to:
  /// **'About you'**
  String get regStepAbout;

  /// Stepper step
  ///
  /// In en, this message translates to:
  /// **'Vehicle and licence'**
  String get regStepVehicle;

  /// Stepper step
  ///
  /// In en, this message translates to:
  /// **'Identity documents'**
  String get regStepDocuments;

  /// Stepper step
  ///
  /// In en, this message translates to:
  /// **'Payout (optional)'**
  String get regStepPayout;

  /// Stepper continue
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get regNext;

  /// Stepper back
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get regBack;

  /// Final submit button
  ///
  /// In en, this message translates to:
  /// **'Submit application'**
  String get regSubmit;

  /// Submit in progress
  ///
  /// In en, this message translates to:
  /// **'Submitting…'**
  String get regSubmitting;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get fieldEmail;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get fieldPassword;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fieldName;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get fieldPhone;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Alternate mobile (optional)'**
  String get fieldAltPhone;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get fieldAddress;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get fieldCity;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'PIN code'**
  String get fieldPincode;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get fieldVehicleType;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Vehicle registration number'**
  String get fieldVehicleNumber;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Driving licence number'**
  String get fieldLicenseNumber;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Aadhaar number'**
  String get fieldAadhaarNumber;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Account holder name'**
  String get fieldAccountHolder;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Bank account number'**
  String get fieldAccountNumber;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'IFSC'**
  String get fieldIfsc;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'UPI ID'**
  String get fieldUpi;

  /// Payout step explanation
  ///
  /// In en, this message translates to:
  /// **'Add a bank account, a UPI ID, or both — or skip and add them later from Earnings (an admin reviews changes).'**
  String get payoutHint;

  /// Photo tile
  ///
  /// In en, this message translates to:
  /// **'Aadhaar — front'**
  String get docAadhaarFront;

  /// Photo tile
  ///
  /// In en, this message translates to:
  /// **'Aadhaar — back'**
  String get docAadhaarBack;

  /// Photo tile
  ///
  /// In en, this message translates to:
  /// **'Selfie'**
  String get docSelfie;

  /// Photo tile
  ///
  /// In en, this message translates to:
  /// **'Driving licence'**
  String get docLicense;

  /// Photo tile action
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get docAdd;

  /// Photo tile action
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get docChange;

  /// Photo tile error
  ///
  /// In en, this message translates to:
  /// **'Add this photo'**
  String get docMissing;

  /// Photo tile note when a resumed draft's stored file no longer exists on disk
  ///
  /// In en, this message translates to:
  /// **'Please re-select this photo'**
  String get regDraftPhotoMissing;

  /// KYC privacy note
  ///
  /// In en, this message translates to:
  /// **'Photos are visible only to you and Agrimore admins, and are locked once your application is decided.'**
  String get docsPrivacy;

  /// Vehicle type
  ///
  /// In en, this message translates to:
  /// **'Bicycle'**
  String get vehicleBicycle;

  /// Vehicle type
  ///
  /// In en, this message translates to:
  /// **'Motorbike'**
  String get vehicleBike;

  /// Vehicle type
  ///
  /// In en, this message translates to:
  /// **'Scooter'**
  String get vehicleScooter;

  /// Vehicle type
  ///
  /// In en, this message translates to:
  /// **'Electric two-wheeler'**
  String get vehicleEv;

  /// Vehicle type
  ///
  /// In en, this message translates to:
  /// **'Three-wheeler'**
  String get vehicleThreeWheeler;

  /// Vehicle type
  ///
  /// In en, this message translates to:
  /// **'Car'**
  String get vehicleCar;

  /// Vehicle type
  ///
  /// In en, this message translates to:
  /// **'Van'**
  String get vehicleVan;

  /// Field error
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get errEmail;

  /// Field error
  ///
  /// In en, this message translates to:
  /// **'At least 6 characters'**
  String get errPassword;

  /// Field error
  ///
  /// In en, this message translates to:
  /// **'Enter your full name'**
  String get errName;

  /// Field error
  ///
  /// In en, this message translates to:
  /// **'Enter a 10-digit Indian mobile number'**
  String get errPhone;

  /// Field error
  ///
  /// In en, this message translates to:
  /// **'Enter a different 10-digit mobile number'**
  String get errAltPhone;

  /// Field error
  ///
  /// In en, this message translates to:
  /// **'Enter your address'**
  String get errAddress;

  /// Field error
  ///
  /// In en, this message translates to:
  /// **'Enter your city'**
  String get errCity;

  /// Field error
  ///
  /// In en, this message translates to:
  /// **'Enter a 6-digit PIN code'**
  String get errPincode;

  /// Field error
  ///
  /// In en, this message translates to:
  /// **'Enter the registration number, e.g. TN58AB1234'**
  String get errVehicleNumber;

  /// Field error
  ///
  /// In en, this message translates to:
  /// **'Enter your driving licence number'**
  String get errLicenseNumber;

  /// Field error
  ///
  /// In en, this message translates to:
  /// **'Enter the 12-digit Aadhaar number'**
  String get errAadhaarNumber;

  /// Field error
  ///
  /// In en, this message translates to:
  /// **'Enter the account holder\'s name'**
  String get errAccountHolder;

  /// Field error
  ///
  /// In en, this message translates to:
  /// **'9–18 digits'**
  String get errAccountNumber;

  /// Field error
  ///
  /// In en, this message translates to:
  /// **'11 characters, e.g. SBIN0001234'**
  String get errIfsc;

  /// Field error
  ///
  /// In en, this message translates to:
  /// **'Enter a UPI ID like name@bank'**
  String get errUpi;

  /// Registration failure
  ///
  /// In en, this message translates to:
  /// **'An account with this email already exists. Sign in with it to continue your application.'**
  String get regFailEmailInUse;

  /// Registration failure
  ///
  /// In en, this message translates to:
  /// **'Choose a stronger password.'**
  String get regFailWeakPassword;

  /// Registration failure
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get regFailInvalidEmail;

  /// Registration failure
  ///
  /// In en, this message translates to:
  /// **'No connection. Your details are kept — try again.'**
  String get regFailNetwork;

  /// Registration failure
  ///
  /// In en, this message translates to:
  /// **'A photo didn\'t upload. Your details are kept — try again.'**
  String get regFailUpload;

  /// Registration failure
  ///
  /// In en, this message translates to:
  /// **'Some details need fixing — they\'re marked below.'**
  String get regFailInvalid;

  /// Registration failure
  ///
  /// In en, this message translates to:
  /// **'Some photos didn\'t reach Agrimore. Add them again and resubmit.'**
  String get regFailDocuments;

  /// Registration failure
  ///
  /// In en, this message translates to:
  /// **'This account is already registered. Sign in to continue.'**
  String get regFailAlreadyRegistered;

  /// Registration failure
  ///
  /// In en, this message translates to:
  /// **'This account is used for another Agrimore app. Register with a different email.'**
  String get regFailOtherRole;

  /// Registration failure
  ///
  /// In en, this message translates to:
  /// **'The application didn\'t go through. Your details are kept — try again.'**
  String get regFailUnknown;

  /// Login link
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// Dialog title
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get resetTitle;

  /// Dialog body
  ///
  /// In en, this message translates to:
  /// **'Enter your account email. If an account exists, we\'ll email a link to set a new password.'**
  String get resetBody;

  /// Dialog action
  ///
  /// In en, this message translates to:
  /// **'Send link'**
  String get resetSend;

  /// Dialog action
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get resetCancel;

  /// Account-safe confirmation (same for known and unknown emails)
  ///
  /// In en, this message translates to:
  /// **'If an account exists for that email, a reset link is on its way. Check your inbox and spam folder.'**
  String get resetSent;

  /// Card title
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInTitle;

  /// Card subtitle
  ///
  /// In en, this message translates to:
  /// **'Use the email and password you registered with.'**
  String get signInSubtitle;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInAction;

  /// Screen-reader label while signing in
  ///
  /// In en, this message translates to:
  /// **'Signing in'**
  String get signingIn;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Register as a delivery partner'**
  String get registerAction;

  /// Tooltip
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// Tooltip
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// Field error
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get errPasswordEmpty;

  /// Password reset request failed (not an unknown-account case)
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send the reset link. Try again, or contact Agrimore support.'**
  String get resetFailed;

  /// Profile screen title
  ///
  /// In en, this message translates to:
  /// **'Your profile'**
  String get profileTitle;

  /// Tooltip / label for the avatar button
  ///
  /// In en, this message translates to:
  /// **'Open your profile'**
  String get profileOpen;

  /// Section
  ///
  /// In en, this message translates to:
  /// **'Your details'**
  String get profileDetails;

  /// Section
  ///
  /// In en, this message translates to:
  /// **'Contact and address'**
  String get profileContact;

  /// Section
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get profileDocuments;

  /// Section
  ///
  /// In en, this message translates to:
  /// **'Payout details'**
  String get profilePayout;

  /// Section
  ///
  /// In en, this message translates to:
  /// **'Help and support'**
  String get profileSupport;

  /// Button opening the Help & support screen
  ///
  /// In en, this message translates to:
  /// **'Get help'**
  String get profileGetHelp;

  /// Help & support screen subtitle
  ///
  /// In en, this message translates to:
  /// **'Get help for delivery, earnings, account and documents. Call support, or submit a request and we\'ll get back to you.'**
  String get helpSupportSubtitle;

  /// Help & support screen heading
  ///
  /// In en, this message translates to:
  /// **'What do you need help with?'**
  String get helpSupportQuestion;

  /// Support category
  ///
  /// In en, this message translates to:
  /// **'Delivery issue'**
  String get helpTopicDeliveryIssue;

  /// Support category subtitle
  ///
  /// In en, this message translates to:
  /// **'Report a problem with an order'**
  String get helpTopicDeliveryIssueSub;

  /// Support category
  ///
  /// In en, this message translates to:
  /// **'Earnings & payouts'**
  String get helpTopicEarningsPayouts;

  /// Support category subtitle
  ///
  /// In en, this message translates to:
  /// **'Questions about a payout or statement'**
  String get helpTopicEarningsPayoutsSub;

  /// Support category
  ///
  /// In en, this message translates to:
  /// **'Account & documents'**
  String get helpTopicAccountDocuments;

  /// Support category subtitle
  ///
  /// In en, this message translates to:
  /// **'Request support'**
  String get helpTopicAccountDocumentsSub;

  /// Emergency row title on the Help & support screen
  ///
  /// In en, this message translates to:
  /// **'Immediate danger?'**
  String get helpImmediateDanger;

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Submit a request'**
  String get supportSubmitTitle;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get supportCategoryLabel;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get supportMessageLabel;

  /// Field hint
  ///
  /// In en, this message translates to:
  /// **'Describe what you need help with'**
  String get supportMessageHint;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Attachment (optional)'**
  String get supportAttachmentLabel;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Add a photo'**
  String get supportAddAttachment;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get supportRemoveAttachment;

  /// Toast when the attachment upload fails
  ///
  /// In en, this message translates to:
  /// **'Could not attach that file. You can still submit without it.'**
  String get supportAttachmentFailed;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Submit request'**
  String get supportSubmitButton;

  /// Field validation error
  ///
  /// In en, this message translates to:
  /// **'Write at least 3 characters (up to 500).'**
  String get errSupportMessage;

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Request status'**
  String get supportStatusTitle;

  /// Status timeline label
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get supportStatusSubmitted;

  /// Status timeline label
  ///
  /// In en, this message translates to:
  /// **'Seen'**
  String get supportStatusSeen;

  /// Status timeline label
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get supportStatusClosed;

  /// Status timeline body
  ///
  /// In en, this message translates to:
  /// **'Your request has been recorded.'**
  String get supportStatusSubmittedBody;

  /// Status timeline body
  ///
  /// In en, this message translates to:
  /// **'Your request has been viewed.'**
  String get supportStatusSeenBody;

  /// Status timeline body
  ///
  /// In en, this message translates to:
  /// **'Request closed. View the outcome below.'**
  String get supportStatusClosedBody;

  /// DLVSUP2: entry point on the help screen to the ticket list
  ///
  /// In en, this message translates to:
  /// **'My support requests'**
  String get mySupportRequestsEntry;

  /// DLVSUP2: ticket list screen's own AppBar title
  ///
  /// In en, this message translates to:
  /// **'My support requests'**
  String get mySupportRequestsTitle;

  /// DLVSUP2: empty state for the ticket list
  ///
  /// In en, this message translates to:
  /// **'You haven\'t filed any support requests yet.'**
  String get mySupportRequestsEmpty;

  /// DLVSUP2: error state for the ticket list
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your support requests. Check your connection and try again.'**
  String get mySupportRequestsNetworkError;

  /// Field label, shown once a request is closed
  ///
  /// In en, this message translates to:
  /// **'Outcome'**
  String get supportOutcomeLabel;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'New request'**
  String get supportNewRequest;

  /// Section
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get profileAccount;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get profileVehicle;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Registration number'**
  String get profileVehicleNumber;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Driving licence'**
  String get profileLicence;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Aadhaar'**
  String get profileAadhaar;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Mobile'**
  String get profilePhone;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Alternate mobile'**
  String get profileAltPhone;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get profileAddress;

  /// Value missing
  ///
  /// In en, this message translates to:
  /// **'Not added'**
  String get profileNotSet;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Edit contact and address'**
  String get profileEditContact;

  /// Explains which fields are reviewed
  ///
  /// In en, this message translates to:
  /// **'To change your mobile number, licence or Aadhaar, contact Agrimore support — an admin reviews those changes.'**
  String get profileLockedNote;

  /// Button opening the identity change screen
  ///
  /// In en, this message translates to:
  /// **'Request name change'**
  String get profileRequestNameChange;

  /// Button opening the identity change screen for the vehicle type/number
  ///
  /// In en, this message translates to:
  /// **'Request vehicle update'**
  String get profileRequestVehicleChange;

  /// Screen title and form heading
  ///
  /// In en, this message translates to:
  /// **'Request identity change'**
  String get identityChangeTitle;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Current name'**
  String get identityChangeCurrentName;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'New name'**
  String get identityChangeProposedName;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Current vehicle'**
  String get identityChangeCurrentVehicle;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'New vehicle type'**
  String get identityChangeProposedVehicleType;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'New registration number'**
  String get identityChangeProposedVehicleNumber;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Reason for change'**
  String get identityChangeReasonLabel;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Submit request'**
  String get identityChangeSubmit;

  /// Success toast
  ///
  /// In en, this message translates to:
  /// **'Your request has been submitted.'**
  String get identityChangeSubmitted;

  /// Status card heading while status == pending
  ///
  /// In en, this message translates to:
  /// **'Request pending review'**
  String get identityChangePendingTitle;

  /// Status card body while status == pending
  ///
  /// In en, this message translates to:
  /// **'Your current details remain unchanged while this is reviewed.'**
  String get identityChangePendingBody;

  /// Status card heading when status == rejected
  ///
  /// In en, this message translates to:
  /// **'Request not approved'**
  String get identityChangeRejectedTitle;

  /// DLVID3: status card heading, a name-change notification's referenced request, approved
  ///
  /// In en, this message translates to:
  /// **'Your name was updated'**
  String get identityChangeNameApprovedTitle;

  /// DLVID3: status card heading, a vehicle-change notification's referenced request, approved
  ///
  /// In en, this message translates to:
  /// **'Your vehicle details were updated'**
  String get identityChangeVehicleApprovedTitle;

  /// DLVID3: status card body for the approved-request view
  ///
  /// In en, this message translates to:
  /// **'This change has already been applied to your profile.'**
  String get identityChangeApprovedBody;

  /// Button on a rejected request, opens the form again prefilled
  ///
  /// In en, this message translates to:
  /// **'Correct and resend'**
  String get identityChangeCorrect;

  /// Submission refused: already_pending
  ///
  /// In en, this message translates to:
  /// **'You already have a request waiting for review.'**
  String get identityChangeAlreadyPending;

  /// Submission refused: network
  ///
  /// In en, this message translates to:
  /// **'Could not submit your request. Try again.'**
  String get identityChangeNetworkError;

  /// Submission refused: generic invalid, no specific field named
  ///
  /// In en, this message translates to:
  /// **'Check your details and try again.'**
  String get identityChangeInvalid;

  /// Field validation error
  ///
  /// In en, this message translates to:
  /// **'Enter your full legal name (2–100 characters).'**
  String get errIdentityName;

  /// Field validation error
  ///
  /// In en, this message translates to:
  /// **'Choose a vehicle type.'**
  String get errIdentityVehicleType;

  /// Field validation error
  ///
  /// In en, this message translates to:
  /// **'Enter a reason (3–250 characters).'**
  String get errIdentityReason;

  /// Document state
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get docSubmitted;

  /// Document state
  ///
  /// In en, this message translates to:
  /// **'Not submitted'**
  String get docNotSubmitted;

  /// Button to preview an already-uploaded document
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get docPreviewAction;

  /// Shown when a document preview fails to load
  ///
  /// In en, this message translates to:
  /// **'This document couldn\'t be loaded right now.'**
  String get docPreviewUnavailable;

  /// A replacement document is awaiting admin review
  ///
  /// In en, this message translates to:
  /// **'Pending review'**
  String get docReviewPending;

  /// A replacement document was rejected
  ///
  /// In en, this message translates to:
  /// **'Not approved'**
  String get docReviewRejected;

  /// Button to submit a replacement for an on-file document
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get docReplaceAction;

  /// Shown while a document replacement is being submitted
  ///
  /// In en, this message translates to:
  /// **'Submitting…'**
  String get docReplaceSubmitting;

  /// Confirmation after a document replacement is submitted
  ///
  /// In en, this message translates to:
  /// **'Submitted for review'**
  String get docReplaceSubmitted;

  /// Shown when a rider tries to replace a document that already has a pending submission
  ///
  /// In en, this message translates to:
  /// **'A replacement for this document is already being reviewed.'**
  String get docReplaceAlreadyPending;

  /// Shown when a document replacement fails to upload
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t submit — check your connection and try again.'**
  String get docReplaceNetworkError;

  /// Generic failure submitting a document replacement
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t submit this replacement right now.'**
  String get docReplaceFailed;

  /// Payout destination
  ///
  /// In en, this message translates to:
  /// **'Bank account {masked}'**
  String payoutBank(String masked);

  /// Payout destination
  ///
  /// In en, this message translates to:
  /// **'UPI {upi}'**
  String payoutUpi(String upi);

  /// No destination
  ///
  /// In en, this message translates to:
  /// **'No payout details yet'**
  String get payoutNone;

  /// Button (reviewed flow)
  ///
  /// In en, this message translates to:
  /// **'Change payout details'**
  String get payoutChange;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Call Agrimore support'**
  String get supportCall;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Email Agrimore support'**
  String get supportEmail;

  /// Launcher failed
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open that. Support: {contact}'**
  String supportOpenFailed(String contact);

  /// Sign-out confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'Sign out of this device?'**
  String get signOutConfirmTitle;

  /// Sign-out confirmation dialog body
  ///
  /// In en, this message translates to:
  /// **'You\'ll be signed out from this device only. Your account and data remain safe, and you can sign in again anytime.'**
  String get signOutConfirmBody;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get deleteAccount;

  /// Shared title for every proactive account-deletion blocker dialog
  ///
  /// In en, this message translates to:
  /// **'Account deletion isn\'t available yet'**
  String get deleteBlockedTitle;

  /// Blocker dialog action: open the active order that is blocking deletion
  ///
  /// In en, this message translates to:
  /// **'View delivery'**
  String get deleteBlockedViewDelivery;

  /// Blocker dialog action: open Earnings for held cash or unpaid earnings blocking deletion
  ///
  /// In en, this message translates to:
  /// **'View earnings'**
  String get deleteBlockedViewEarnings;

  /// Dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get deleteConfirmTitle;

  /// Dialog body
  ///
  /// In en, this message translates to:
  /// **'Your profile, documents and payout details are removed and you are signed out. Records of your deliveries and payments are kept. This cannot be undone.'**
  String get deleteConfirmBody;

  /// Dialog destructive action
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteConfirm;

  /// Dialog cancel
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Toast after deletion
  ///
  /// In en, this message translates to:
  /// **'Your account was deleted.'**
  String get deleteDone;

  /// Account action refused
  ///
  /// In en, this message translates to:
  /// **'You still have an order assigned. Deliver it or ask Agrimore to reassign it first.'**
  String get failActiveOrder;

  /// Account action refused
  ///
  /// In en, this message translates to:
  /// **'You still hold customers\' cash. Deposit it with Agrimore first.'**
  String get failCashHeld;

  /// Account action refused
  ///
  /// In en, this message translates to:
  /// **'Agrimore still owes you delivery pay. Wait until your statement is paid.'**
  String get failPayOwed;

  /// Account action refused
  ///
  /// In en, this message translates to:
  /// **'This account still has an open balance or order. Contact Agrimore support.'**
  String get failOtherBalance;

  /// Account action refused
  ///
  /// In en, this message translates to:
  /// **'Some details need fixing — they\'re marked.'**
  String get failInvalid;

  /// Account action failed
  ///
  /// In en, this message translates to:
  /// **'No connection. Try again.'**
  String get failNetwork;

  /// Account action failed
  ///
  /// In en, this message translates to:
  /// **'That didn\'t go through. Try again.'**
  String get failUnknown;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Toast
  ///
  /// In en, this message translates to:
  /// **'Contact details saved.'**
  String get contactSaved;

  /// Account status title
  ///
  /// In en, this message translates to:
  /// **'Application under review'**
  String get statusPendingTitle;

  /// Account status body
  ///
  /// In en, this message translates to:
  /// **'An Agrimore admin is checking your details and documents. You\'ll be able to go online once approved.'**
  String get statusPendingBody;

  /// Account status title
  ///
  /// In en, this message translates to:
  /// **'Application not approved'**
  String get statusRejectedTitle;

  /// Account status body
  ///
  /// In en, this message translates to:
  /// **'Your application was not approved. You can correct it and submit again.'**
  String get statusRejectedBody;

  /// Account status title
  ///
  /// In en, this message translates to:
  /// **'Account suspended'**
  String get statusSuspendedTitle;

  /// Account status body
  ///
  /// In en, this message translates to:
  /// **'You can\'t go online or accept orders until an admin reinstates your account.'**
  String get statusSuspendedBody;

  /// Account status title
  ///
  /// In en, this message translates to:
  /// **'Account deactivated'**
  String get statusDeactivatedTitle;

  /// Account status body
  ///
  /// In en, this message translates to:
  /// **'This delivery partner account is no longer active.'**
  String get statusDeactivatedBody;

  /// Label for the admin's reason
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get statusReason;

  /// Button (pending/rejected)
  ///
  /// In en, this message translates to:
  /// **'Update and resubmit'**
  String get statusUpdateApplication;

  /// Button (pending)
  ///
  /// In en, this message translates to:
  /// **'Edit application'**
  String get statusEditApplication;

  /// Banner when a pending/rejected rider edits the application
  ///
  /// In en, this message translates to:
  /// **'Correct your details and submit your application again.'**
  String get regResubmitNote;

  /// Button on the active order after pickup
  ///
  /// In en, this message translates to:
  /// **'Report a problem'**
  String get problemReport;

  /// Sheet title
  ///
  /// In en, this message translates to:
  /// **'What went wrong?'**
  String get problemSheetTitle;

  /// Note field
  ///
  /// In en, this message translates to:
  /// **'Details (optional)'**
  String get problemNoteLabel;

  /// Sheet submit
  ///
  /// In en, this message translates to:
  /// **'Send to Agrimore'**
  String get problemSend;

  /// State title
  ///
  /// In en, this message translates to:
  /// **'Problem reported'**
  String get problemReported;

  /// State body
  ///
  /// In en, this message translates to:
  /// **'Agrimore has your report but may not have seen it yet. Keep the goods with you and stay reachable.'**
  String get problemReportedBody;

  /// State title
  ///
  /// In en, this message translates to:
  /// **'Seen by Agrimore'**
  String get problemSeen;

  /// State body
  ///
  /// In en, this message translates to:
  /// **'A person at Agrimore is looking at this. Keep the goods with you until they tell you what to do.'**
  String get problemSeenBody;

  /// State title (resolved: reattempt)
  ///
  /// In en, this message translates to:
  /// **'Try the delivery again'**
  String get problemReattempt;

  /// State title (resolved: returned)
  ///
  /// In en, this message translates to:
  /// **'Goods recorded as returned to the seller'**
  String get problemReturned;

  /// Resolution text shown verbatim
  ///
  /// In en, this message translates to:
  /// **'Agrimore wrote: {note}'**
  String problemResolutionNote(String note);

  /// Refusal
  ///
  /// In en, this message translates to:
  /// **'You can report a problem once you have picked the order up.'**
  String get problemFailNotAfterPickup;

  /// Refusal
  ///
  /// In en, this message translates to:
  /// **'A problem is already open for this order.'**
  String get problemFailOpen;

  /// Failure
  ///
  /// In en, this message translates to:
  /// **'No connection — the report didn\'t go through. Try again.'**
  String get problemFailNetwork;

  /// Failure
  ///
  /// In en, this message translates to:
  /// **'The report didn\'t go through. Try again or call Agrimore support.'**
  String get problemFailUnknown;

  /// Reason
  ///
  /// In en, this message translates to:
  /// **'Customer not reachable'**
  String get reasonCustomerUnreachable;

  /// Reason
  ///
  /// In en, this message translates to:
  /// **'Customer refused the order'**
  String get reasonCustomerRefused;

  /// Reason
  ///
  /// In en, this message translates to:
  /// **'Wrong address'**
  String get reasonWrongAddress;

  /// Reason
  ///
  /// In en, this message translates to:
  /// **'Can\'t find the address'**
  String get reasonAddressNotFound;

  /// Reason
  ///
  /// In en, this message translates to:
  /// **'Cash payment problem'**
  String get reasonPaymentIssue;

  /// Reason
  ///
  /// In en, this message translates to:
  /// **'Goods damaged or missing'**
  String get reasonDamagedGoods;

  /// Reason
  ///
  /// In en, this message translates to:
  /// **'Vehicle problem'**
  String get reasonVehicleIssue;

  /// Reason
  ///
  /// In en, this message translates to:
  /// **'Safety concern'**
  String get reasonSafety;

  /// Reason
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get reasonOther;

  /// After delivery when the photo fails
  ///
  /// In en, this message translates to:
  /// **'Delivered. The proof photo couldn\'t be saved — the delivery still counts.'**
  String get proofNotSaved;

  /// Dashboard banner title for a delivery whose proof photo never attached
  ///
  /// In en, this message translates to:
  /// **'Proof photo not saved'**
  String get proofRetryTitle;

  /// Dashboard banner body for a delivery whose proof photo never attached
  ///
  /// In en, this message translates to:
  /// **'A delivery you completed is missing its proof photo. The delivery still counts — retry to add the photo.'**
  String get proofRetryBody;

  /// Dashboard banner action to retry attaching a proof photo
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get proofRetryAction;

  /// Dashboard banner action label while a proof-photo retry is in progress
  ///
  /// In en, this message translates to:
  /// **'Retrying…'**
  String get proofRetrying;

  /// Toast after a proof-photo retry succeeds
  ///
  /// In en, this message translates to:
  /// **'Proof photo saved.'**
  String get proofRetrySucceeded;

  /// Toast when a pending proof photo's local file is gone
  ///
  /// In en, this message translates to:
  /// **'That photo is no longer on this device and can\'t be recovered.'**
  String get proofRetryMissingFile;

  /// Dashboard banner title once a pending proof photo can no longer be attached
  ///
  /// In en, this message translates to:
  /// **'Proof photo window closed'**
  String get proofRetryExpiredTitle;

  /// Dashboard banner body once a pending proof photo can no longer be attached
  ///
  /// In en, this message translates to:
  /// **'It\'s been too long to add this delivery\'s proof photo. The delivery still counts.'**
  String get proofRetryExpiredBody;

  /// Dashboard banner action to dismiss an expired pending proof photo
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get proofRetryDismiss;

  /// Earnings screen title
  ///
  /// In en, this message translates to:
  /// **'Earnings'**
  String get moneyTitle;

  /// Heading: pay not yet in a statement
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get moneyThisWeek;

  /// Label: pay earned today
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get moneyToday;

  /// A number of deliveries
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 delivery} other{{count} deliveries}}'**
  String moneyDeliveries(int count);

  /// Summary caption: when pay is sent
  ///
  /// In en, this message translates to:
  /// **'Paid every Monday'**
  String get moneyPaidMondays;

  /// Earnings stream failed
  ///
  /// In en, this message translates to:
  /// **'Could not load your earnings. Check your connection.'**
  String get moneyLoadError;

  /// Empty week
  ///
  /// In en, this message translates to:
  /// **'No deliveries yet this week. Pay for each delivery shows here as soon as it is delivered.'**
  String get moneyNoDeliveriesYet;

  /// Cash card: nothing held
  ///
  /// In en, this message translates to:
  /// **'No cash with you'**
  String get moneyCashNone;

  /// Cash card hint when nothing is held
  ///
  /// In en, this message translates to:
  /// **'Cash you collect on COD orders shows here.'**
  String get moneyCashNoneHint;

  /// Cash card: amount held
  ///
  /// In en, this message translates to:
  /// **'Cash with you: {amount}'**
  String moneyCashHeld(String amount);

  /// Cash card hint while holding cash
  ///
  /// In en, this message translates to:
  /// **'Cash from COD orders is taken off your Monday payout. Hand larger amounts to the Agrimore team.'**
  String get moneyCashHint;

  /// Cash card: the COD cash limit, under it
  ///
  /// In en, this message translates to:
  /// **'You get cash-on-delivery orders while you hold less than {limit}.'**
  String moneyCashUnderLimit(String limit);

  /// Cash card: at or over the COD cash limit
  ///
  /// In en, this message translates to:
  /// **'You hold {limit} or more, so you won\'t get cash-on-delivery orders until you hand cash to the Agrimore team.'**
  String moneyCashOverLimit(String limit);

  /// Earning row title
  ///
  /// In en, this message translates to:
  /// **'Order #{number}'**
  String moneyEarningTitle(String number);

  /// Earning line: base pay
  ///
  /// In en, this message translates to:
  /// **'Base {amount}'**
  String moneyLineBase(String amount);

  /// Earning line: distance pay
  ///
  /// In en, this message translates to:
  /// **'{km} km {amount}'**
  String moneyLineDistance(String km, String amount);

  /// Earning line: waiting pay
  ///
  /// In en, this message translates to:
  /// **'Waiting {minutes} min {amount}'**
  String moneyLineWaiting(int minutes, String amount);

  /// Earning line: COD cash collected
  ///
  /// In en, this message translates to:
  /// **'Collected {amount} cash'**
  String moneyLineCash(String amount);

  /// Heading: statements
  ///
  /// In en, this message translates to:
  /// **'Weekly statements'**
  String get moneyStatementsTitle;

  /// Statements stream failed
  ///
  /// In en, this message translates to:
  /// **'Could not load statements.'**
  String get moneyStatementsError;

  /// No statements yet
  ///
  /// In en, this message translates to:
  /// **'Your first statement is made on Monday for the week before. Pay is sent to your bank or UPI.'**
  String get moneyStatementsEmpty;

  /// Statement title
  ///
  /// In en, this message translates to:
  /// **'Week ending {date}'**
  String moneyWeekEnding(String date);

  /// Statement title for a split week
  ///
  /// In en, this message translates to:
  /// **'Week ending {date} · part {part}'**
  String moneyWeekEndingPart(String date, int part);

  /// Statement row: gross earned
  ///
  /// In en, this message translates to:
  /// **'earned {amount}'**
  String moneyStatementEarned(String amount);

  /// Statement row: COD cash offset
  ///
  /// In en, this message translates to:
  /// **'cash taken off {amount}'**
  String moneyStatementCashOff(String amount);

  /// Statement: transferred, with the reference
  ///
  /// In en, this message translates to:
  /// **'Money sent · Ref {reference}'**
  String stagePaid(String reference);

  /// Statement: transferred, no reference
  ///
  /// In en, this message translates to:
  /// **'Money sent'**
  String get stagePaidNoRef;

  /// Statement made, not yet transferred
  ///
  /// In en, this message translates to:
  /// **'Statement ready — the Agrimore team will send the money'**
  String get stageAwaiting;

  /// Statement held for a bank change
  ///
  /// In en, this message translates to:
  /// **'On hold — your new payout details are being checked'**
  String get stageHeldReview;

  /// Statement held: no payout details
  ///
  /// In en, this message translates to:
  /// **'On hold — add your bank or UPI details'**
  String get stageHeldNoDetails;

  /// Statement with nothing to pay
  ///
  /// In en, this message translates to:
  /// **'Nothing to pay'**
  String get stageNothing;

  /// Nothing to pay; cash remains
  ///
  /// In en, this message translates to:
  /// **'Nothing to pay — cash you hold covered it ({amount} still with you)'**
  String stageNothingCash(String amount);

  /// Unrecognised statement status
  ///
  /// In en, this message translates to:
  /// **'Status: {status}'**
  String stageUnknown(String status);

  /// Heading: bank/UPI details
  ///
  /// In en, this message translates to:
  /// **'Payout details'**
  String get payoutDetailsTitle;

  /// No payout details on file
  ///
  /// In en, this message translates to:
  /// **'No bank or UPI details yet — your pay will wait until you add them.'**
  String get payoutDetailsNone;

  /// Bank on file
  ///
  /// In en, this message translates to:
  /// **'Bank {account}'**
  String payoutDetailsBank(String account);

  /// Bank on file with IFSC
  ///
  /// In en, this message translates to:
  /// **'Bank {account} · {ifsc}'**
  String payoutDetailsBankIfsc(String account, String ifsc);

  /// UPI on file
  ///
  /// In en, this message translates to:
  /// **'UPI {upi}'**
  String payoutDetailsUpi(String upi);

  /// Bank change pending
  ///
  /// In en, this message translates to:
  /// **'Your change is being checked by the Agrimore team.'**
  String get bankChangeReviewing;

  /// Bank change rejected
  ///
  /// In en, this message translates to:
  /// **'Your last change was not approved: {reason}'**
  String bankChangeRejected(String reason);

  /// Bank change rejected without a reason
  ///
  /// In en, this message translates to:
  /// **'Your last change was not approved.'**
  String get bankChangeRejectedNoReason;

  /// Open the bank change form
  ///
  /// In en, this message translates to:
  /// **'Change payout details'**
  String get bankChangeButton;

  /// Disabled button while a change is pending
  ///
  /// In en, this message translates to:
  /// **'Change waiting for review'**
  String get bankChangeWaiting;

  /// Bank change sent
  ///
  /// In en, this message translates to:
  /// **'Sent. The Agrimore team will check it; your pay waits until then.'**
  String get bankChangeSent;

  /// Bank change sheet title
  ///
  /// In en, this message translates to:
  /// **'Change payout details'**
  String get bankFormTitle;

  /// Bank change sheet intro
  ///
  /// In en, this message translates to:
  /// **'The Agrimore team checks every change before any money is sent to it.'**
  String get bankFormIntro;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Account holder name'**
  String get bankFormHolder;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Bank account number'**
  String get bankFormAccount;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'IFSC'**
  String get bankFormIfsc;

  /// Between bank and UPI fields
  ///
  /// In en, this message translates to:
  /// **'and / or'**
  String get bankFormOr;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'UPI ID (e.g. name@okaxis)'**
  String get bankFormUpi;

  /// Submit the bank change
  ///
  /// In en, this message translates to:
  /// **'Send for review'**
  String get bankFormSend;

  /// Form: nothing entered
  ///
  /// In en, this message translates to:
  /// **'Enter bank details or a UPI ID'**
  String get bankProblemEmpty;

  /// Form: holder missing
  ///
  /// In en, this message translates to:
  /// **'Enter the account holder name'**
  String get bankProblemHolder;

  /// Form: bad account number
  ///
  /// In en, this message translates to:
  /// **'Account number should be 9–18 digits'**
  String get bankProblemAccount;

  /// Form: bad IFSC
  ///
  /// In en, this message translates to:
  /// **'IFSC looks wrong (e.g. SBIN0001234)'**
  String get bankProblemIfsc;

  /// Form: bad UPI
  ///
  /// In en, this message translates to:
  /// **'UPI ID looks wrong (e.g. name@okaxis)'**
  String get bankProblemUpi;

  /// Server: change already pending
  ///
  /// In en, this message translates to:
  /// **'A change is already waiting for review.'**
  String get bankFailAlreadyPending;

  /// Server: details refused
  ///
  /// In en, this message translates to:
  /// **'Please check the details and try again.'**
  String get bankFailInvalid;

  /// Server: other failure
  ///
  /// In en, this message translates to:
  /// **'Could not send the change. Please try again.'**
  String get bankFailOther;

  /// Statement screen title
  ///
  /// In en, this message translates to:
  /// **'Statement'**
  String get statementTitle;

  /// Statement: gross
  ///
  /// In en, this message translates to:
  /// **'Earned'**
  String get statementEarned;

  /// Statement: COD offset
  ///
  /// In en, this message translates to:
  /// **'Cash you held, taken off'**
  String get statementCashOff;

  /// Statement: net, not yet transferred
  ///
  /// In en, this message translates to:
  /// **'To be sent to you'**
  String get statementToPay;

  /// Statement: net, transferred
  ///
  /// In en, this message translates to:
  /// **'Sent to you'**
  String get statementSent;

  /// Statement: cash remaining after offset
  ///
  /// In en, this message translates to:
  /// **'Cash still with you'**
  String get statementCashAfter;

  /// Statement: bank destination
  ///
  /// In en, this message translates to:
  /// **'Sent to bank account ending {last4}'**
  String statementSentToBank(String last4);

  /// Statement: UPI destination
  ///
  /// In en, this message translates to:
  /// **'Sent to UPI {upi}'**
  String statementSentToUpi(String upi);

  /// Statement: transfer date
  ///
  /// In en, this message translates to:
  /// **'Sent on {date}'**
  String statementSentOn(String date);

  /// Statement: creation date
  ///
  /// In en, this message translates to:
  /// **'Statement made on {date}'**
  String statementMadeOn(String date);

  /// Heading: statement lines
  ///
  /// In en, this message translates to:
  /// **'Deliveries in this statement'**
  String get statementDeliveries;

  /// Statement without lines
  ///
  /// In en, this message translates to:
  /// **'No deliveries in this statement.'**
  String get statementLinesEmpty;

  /// Statement lines failed
  ///
  /// In en, this message translates to:
  /// **'Could not load the deliveries. Check your connection.'**
  String get statementLinesError;

  /// Load the next page of statement lines
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get statementLoadMore;

  /// Stands in for an amount while it loads
  ///
  /// In en, this message translates to:
  /// **'…'**
  String get moneyAmountLoading;

  /// Inbox screen title
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get inboxTitle;

  /// Tooltip: open the inbox
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get inboxOpen;

  /// Tooltip: open the inbox with unread notices
  ///
  /// In en, this message translates to:
  /// **'Inbox, {count} unread'**
  String inboxOpenUnread(int count);

  /// Empty inbox
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet. Orders, statements and payments you should know about show here.'**
  String get inboxEmpty;

  /// Inbox stream failed
  ///
  /// In en, this message translates to:
  /// **'Could not load your inbox. Check your connection.'**
  String get inboxLoadError;

  /// Inbox section header for notices from today
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get inboxSectionToday;

  /// Inbox section header for notices from before today
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get inboxSectionEarlier;

  /// Mark every unread notice read, not only the ones currently shown
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get inboxMarkAllRead;

  /// Mark-all-read button label while the request is in flight
  ///
  /// In en, this message translates to:
  /// **'Marking all read…'**
  String get inboxMarkingAllRead;

  /// Mark-all-read succeeded, shown only after server confirmation
  ///
  /// In en, this message translates to:
  /// **'All notifications marked as read.'**
  String get inboxMarkAllReadSuccess;

  /// Inbox shows only the newest N
  ///
  /// In en, this message translates to:
  /// **'Showing your latest {count} notices.'**
  String inboxLimitNote(int count);

  /// Mark read failed
  ///
  /// In en, this message translates to:
  /// **'Could not update your inbox. Try again.'**
  String get inboxMarkReadFailed;

  /// Inbox: the order a notice points to is deleted or no longer this rider's own
  ///
  /// In en, this message translates to:
  /// **'This delivery is no longer available to you.'**
  String get inboxDeliveryUnavailable;

  /// Inbox: the order lookup for a notice failed (network)
  ///
  /// In en, this message translates to:
  /// **'Could not open this delivery. Try again.'**
  String get inboxDeliveryNetworkError;

  /// History filter: every order
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get historyFilterAll;

  /// History filter: delivered orders
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get historyFilterDelivered;

  /// History filter: cancelled orders
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get historyFilterCancelled;

  /// History filter: returned orders
  ///
  /// In en, this message translates to:
  /// **'Returned'**
  String get historyFilterReturned;

  /// History date-range filter: no cutoff
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get historyRangeAllTime;

  /// History date-range filter: the last week
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get historyRangeLast7Days;

  /// History date-range filter: the last month
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get historyRangeLast30Days;

  /// Resets the status and date-range filters to their defaults
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get historyClearFilters;

  /// History with a filter and no match
  ///
  /// In en, this message translates to:
  /// **'No orders here'**
  String get historyEmptyFiltered;

  /// History detail: rider's earning
  ///
  /// In en, this message translates to:
  /// **'Your pay for this order'**
  String get historyDetailPay;

  /// History detail: no earning yet
  ///
  /// In en, this message translates to:
  /// **'Pay shows here once the order is delivered.'**
  String get historyDetailPayPending;

  /// History detail: COD cash collected
  ///
  /// In en, this message translates to:
  /// **'Cash collected'**
  String get historyDetailCash;

  /// History detail: earning already in a statement
  ///
  /// In en, this message translates to:
  /// **'In a weekly statement'**
  String get historyDetailInStatement;

  /// History detail: earning not yet in a statement
  ///
  /// In en, this message translates to:
  /// **'Goes into next Monday\'s statement'**
  String get historyDetailNotInStatement;

  /// History detail: the linked statement is missing, deleted, or not this rider's own
  ///
  /// In en, this message translates to:
  /// **'This statement is no longer available.'**
  String get historyDetailStatementUnavailable;

  /// History detail: the statement lookup failed (network)
  ///
  /// In en, this message translates to:
  /// **'Could not open this statement. Try again.'**
  String get historyDetailStatementNetworkError;

  /// History detail: order total
  ///
  /// In en, this message translates to:
  /// **'Order amount'**
  String get historyDetailOrderTotal;

  /// History detail: earning read failed
  ///
  /// In en, this message translates to:
  /// **'Could not load your pay for this order.'**
  String get historyDetailPayError;

  /// History detail: a cancelled order never has a recorded earning
  ///
  /// In en, this message translates to:
  /// **'No earnings — this order was cancelled.'**
  String get historyDetailNoEarningsCancelled;

  /// History detail: a returned order has no recorded earning today
  ///
  /// In en, this message translates to:
  /// **'No earnings recorded for this returned order.'**
  String get historyDetailNoEarningsReturned;

  /// History detail: section heading for the recorded status timeline
  ///
  /// In en, this message translates to:
  /// **'Delivery timeline'**
  String get historyDetailTimelineTitle;

  /// History detail: the timeline subcollection had no entries
  ///
  /// In en, this message translates to:
  /// **'No recorded timeline for this order.'**
  String get historyDetailTimelineEmpty;

  /// History detail: timeline read failed
  ///
  /// In en, this message translates to:
  /// **'Could not load this order\'s timeline.'**
  String get historyDetailTimelineError;

  /// History detail: section heading for the customer's contact details
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get historyDetailCustomerTitle;

  /// History detail: section heading above the support contact buttons
  ///
  /// In en, this message translates to:
  /// **'Need help with this order?'**
  String get historyDetailGetHelpTitle;

  /// Decline for now
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get actionNotNow;

  /// Go on to the next step
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get actionContinue;

  /// Put off
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get actionLater;

  /// Open the phone's settings for this app
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get actionOpenSettings;

  /// Grant a permission
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get actionAllow;

  /// Going online: location services off
  ///
  /// In en, this message translates to:
  /// **'Turn on location (GPS) to go online.'**
  String get goOnlineServicesOff;

  /// Going online: permission denied
  ///
  /// In en, this message translates to:
  /// **'Allow location access to go online. Orders are offered by distance.'**
  String get goOnlinePermissionDenied;

  /// Going online: permission denied forever
  ///
  /// In en, this message translates to:
  /// **'Location access is turned off for this app. Turn it on in Settings to go online.'**
  String get goOnlinePermissionForever;

  /// Going online: no fix
  ///
  /// In en, this message translates to:
  /// **'Could not get your location. Move to an open area and try again.'**
  String get goOnlineFailed;

  /// The server took the rider offline for no location
  ///
  /// In en, this message translates to:
  /// **'You\'re offline — your location stopped for 15 minutes. Go online again when you\'re ready.'**
  String get serverOfflineNoLocation;

  /// Play prominent disclosure title
  ///
  /// In en, this message translates to:
  /// **'Your location while you are online'**
  String get locationDisclosureTitle;

  /// Play prominent disclosure body
  ///
  /// In en, this message translates to:
  /// **'While you are online, Agrimore Delivery collects your location — also when the app is closed or not in use — to offer you nearby orders and to show customers where their delivery is. A notification shows while this is on. It stops as soon as you go offline.'**
  String get locationDisclosureBody;

  /// Allow-all-the-time step title
  ///
  /// In en, this message translates to:
  /// **'Keep deliveries working when the app closes'**
  String get backgroundLocationTitle;

  /// Allow-all-the-time step body
  ///
  /// In en, this message translates to:
  /// **'Your phone sometimes closes apps to save memory. To keep sharing your location while you are online even then, choose \"Allow all the time\" on the next screen. It still stops as soon as you go offline.'**
  String get backgroundLocationBody;

  /// Shown after going online without background location
  ///
  /// In en, this message translates to:
  /// **'You are online. If your phone closes the app, location sharing stops and you go offline — allow location \"all the time\" in Settings to avoid this.'**
  String get backgroundLocationReminder;

  /// Battery guide title
  ///
  /// In en, this message translates to:
  /// **'Stop your phone closing the app'**
  String get batteryGuideTitle;

  /// Battery guide body
  ///
  /// In en, this message translates to:
  /// **'Some phones close apps in the background to save battery, which takes you offline. In the app settings that open next, set Battery to \"Unrestricted\" (or \"No restrictions\"). On Xiaomi, Oppo, Vivo and Realme phones also turn on \"Autostart\".'**
  String get batteryGuideBody;

  /// Ongoing notification while sharing location
  ///
  /// In en, this message translates to:
  /// **'You\'re online'**
  String get onlineNoticeTitle;

  /// Ongoing notification text
  ///
  /// In en, this message translates to:
  /// **'Sharing your location for nearby orders and live tracking. Go offline in the app to stop.'**
  String get onlineNoticeText;

  /// Android notification channel name for the ongoing notice
  ///
  /// In en, this message translates to:
  /// **'Online status'**
  String get onlineNoticeChannel;

  /// Android notification channel name for offers
  ///
  /// In en, this message translates to:
  /// **'Delivery offers'**
  String get offerChannelName;

  /// Android notification channel description
  ///
  /// In en, this message translates to:
  /// **'Rings when a new delivery order is offered to you'**
  String get offerChannelDescription;

  /// Offer notification title
  ///
  /// In en, this message translates to:
  /// **'New delivery request'**
  String get offerNotificationTitle;

  /// Offer notification body when no details are known
  ///
  /// In en, this message translates to:
  /// **'Tap to see the order'**
  String get offerNotificationBody;

  /// Ask for full-screen alerts
  ///
  /// In en, this message translates to:
  /// **'Ring for new orders?'**
  String get offerRingPromptTitle;

  /// Full-screen alert permission explanation
  ///
  /// In en, this message translates to:
  /// **'Allow full-screen alerts so a new delivery order rings and shows even when your phone is locked. You can change this later in Settings.'**
  String get offerRingPromptBody;

  /// Offer line: estimated pay
  ///
  /// In en, this message translates to:
  /// **'Earn ~{amount}'**
  String offerSummaryPay(String amount);

  /// Offer line: pickup distance unknown
  ///
  /// In en, this message translates to:
  /// **'Pickup nearby'**
  String get offerSummaryNearby;

  /// Offer line: pickup distance
  ///
  /// In en, this message translates to:
  /// **'Pickup {km} km away'**
  String offerSummaryDistance(String km);

  /// Offer line: item count
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String offerSummaryItems(int count);

  /// Offer line: cash to collect
  ///
  /// In en, this message translates to:
  /// **'Collect {amount}'**
  String offerSummaryCollect(String amount);

  /// Accept refused: taken
  ///
  /// In en, this message translates to:
  /// **'Another delivery partner took this order.'**
  String get offerRefusalTaken;

  /// Accept refused: expired
  ///
  /// In en, this message translates to:
  /// **'This offer has expired.'**
  String get offerRefusalExpired;

  /// Accept refused: busy
  ///
  /// In en, this message translates to:
  /// **'Finish your current delivery before taking another.'**
  String get offerRefusalBusy;

  /// Accept refused: not eligible
  ///
  /// In en, this message translates to:
  /// **'Your account cannot take orders right now.'**
  String get offerRefusalNotEligible;

  /// Accept refused: no offer
  ///
  /// In en, this message translates to:
  /// **'This order is no longer offered to you.'**
  String get offerRefusalNoOffer;

  /// Accept refused: rider offline
  ///
  /// In en, this message translates to:
  /// **'Go online to accept orders.'**
  String get offerRefusalOffline;

  /// Accept refused: COD cash limit
  ///
  /// In en, this message translates to:
  /// **'Deposit the cash you hold with Agrimore before taking cash orders.'**
  String get offerRefusalCashLimit;

  /// Offer call: signed out
  ///
  /// In en, this message translates to:
  /// **'Please sign in again.'**
  String get offerRefusalSignIn;

  /// Offer call: other failure
  ///
  /// In en, this message translates to:
  /// **'Could not update this offer. Please try again.'**
  String get offerRefusalFailed;

  /// A distance under 1 km
  ///
  /// In en, this message translates to:
  /// **'{meters} m'**
  String distanceMeters(int meters);

  /// A distance in km
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String distanceKm(String km);

  /// Far-tap question at the store
  ///
  /// In en, this message translates to:
  /// **'You\'re {distance} from the store. {action} anyway? The delivery team will be told.'**
  String stepFarStore(String distance, String action);

  /// Far-tap question at the customer
  ///
  /// In en, this message translates to:
  /// **'You\'re {distance} from the customer\'s address. {action} anyway? The delivery team will be told.'**
  String stepFarCustomer(String distance, String action);

  /// Far-tap question: the arrived step
  ///
  /// In en, this message translates to:
  /// **'Mark arrived'**
  String get stepActionArrived;

  /// Far-tap question: the picked-up step
  ///
  /// In en, this message translates to:
  /// **'Mark picked up'**
  String get stepActionPickedUp;

  /// Far-tap question: completing the delivery
  ///
  /// In en, this message translates to:
  /// **'Complete the delivery'**
  String get stepActionComplete;

  /// Step refused: bad transition
  ///
  /// In en, this message translates to:
  /// **'This step is not possible right now — the order may have changed. Go back and open it again.'**
  String get stepErrBadTransition;

  /// Step refused: not assigned
  ///
  /// In en, this message translates to:
  /// **'This order is no longer assigned to you.'**
  String get stepErrNotAssigned;

  /// Release refused after pickup
  ///
  /// In en, this message translates to:
  /// **'The order is already picked up, so it can no longer be released. Contact support if there is a problem.'**
  String get stepErrAfterPickup;

  /// Step refused: order missing
  ///
  /// In en, this message translates to:
  /// **'This order could not be found.'**
  String get stepErrNotFound;

  /// Step call offline
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Check your network and try again.'**
  String get stepErrNetwork;

  /// Step call signed out
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please sign in again.'**
  String get stepErrSession;

  /// Step call other failure
  ///
  /// In en, this message translates to:
  /// **'Could not update the order. Please try again.'**
  String get stepErrUpdate;

  /// Release call other failure
  ///
  /// In en, this message translates to:
  /// **'Could not release the order. Please try again.'**
  String get stepErrRelease;

  /// Safety report refused: rate limit
  ///
  /// In en, this message translates to:
  /// **'Too many reports in a few minutes. Call 112 or Agrimore support.'**
  String get incidentErrTooMany;

  /// Safety report refused: not a rider
  ///
  /// In en, this message translates to:
  /// **'This account cannot report here. Call 112 or Agrimore support.'**
  String get incidentErrNotRider;

  /// Safety report offline
  ///
  /// In en, this message translates to:
  /// **'No connection — the report didn\'t go through. Try again, or call 112.'**
  String get incidentErrNetwork;

  /// Safety report signed out
  ///
  /// In en, this message translates to:
  /// **'You are signed out. Call 112 or Agrimore support.'**
  String get incidentErrSignedOut;

  /// Safety report other failure
  ///
  /// In en, this message translates to:
  /// **'The report didn\'t go through. Try again, or call 112.'**
  String get incidentErrFailed;

  /// Safety report state: resolved
  ///
  /// In en, this message translates to:
  /// **'Closed by the Agrimore team'**
  String get incidentStatusClosed;

  /// Safety report resolved without a note
  ///
  /// In en, this message translates to:
  /// **'No note was added.'**
  String get incidentStatusNoNote;

  /// Safety report state: acknowledged
  ///
  /// In en, this message translates to:
  /// **'Seen by the Agrimore team'**
  String get incidentStatusSeen;

  /// Safety report acknowledged detail
  ///
  /// In en, this message translates to:
  /// **'A person on the team has opened your report. If you are in danger, call 112.'**
  String get incidentStatusSeenDetail;

  /// Safety report state: reported
  ///
  /// In en, this message translates to:
  /// **'Report recorded'**
  String get incidentStatusRecorded;

  /// Safety report reported detail
  ///
  /// In en, this message translates to:
  /// **'Nobody on the Agrimore team may have seen it yet. If you are in danger, call 112 now.'**
  String get incidentStatusRecordedDetail;

  /// Emergency sheet title
  ///
  /// In en, this message translates to:
  /// **'Emergency help'**
  String get emergencyTitle;

  /// Active-delivery AppBar action opening the help sheet
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get activeHelpTooltip;

  /// Help sheet title, opened from the active-delivery screen
  ///
  /// In en, this message translates to:
  /// **'Help with this delivery'**
  String get activeHelpSheetTitle;

  /// Reassures the rider that opening the help sheet does not affect the delivery in progress
  ///
  /// In en, this message translates to:
  /// **'Your current delivery will remain active.'**
  String get activeHelpSheetSubtitle;

  /// Dismisses the help sheet, returning to the active-delivery screen
  ///
  /// In en, this message translates to:
  /// **'Back to delivery'**
  String get activeHelpBackToDelivery;

  /// Emergency sheet intro — makes no claim that anyone was alerted
  ///
  /// In en, this message translates to:
  /// **'If you or someone else is in danger, call {number} now. This app does not alert the police or Agrimore by itself.'**
  String emergencyIntro(String number);

  /// Hands the emergency number to the dialer
  ///
  /// In en, this message translates to:
  /// **'Call {number} (emergency)'**
  String emergencyCall(String number);

  /// Hands the support number to the dialer
  ///
  /// In en, this message translates to:
  /// **'Call Agrimore support'**
  String get emergencyCallSupport;

  /// The dialer did not open
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the phone app. Dial {number} directly.'**
  String emergencyDialFailed(String number);

  /// Records a safety report
  ///
  /// In en, this message translates to:
  /// **'Tell the Agrimore team'**
  String get incidentReportAction;

  /// While the safety report is being sent
  ///
  /// In en, this message translates to:
  /// **'Recording your report…'**
  String get incidentReportSending;

  /// What the safety report does and does not do
  ///
  /// In en, this message translates to:
  /// **'Records a report for the Agrimore team with your current order and, if the phone has it, your position. It does not call anyone.'**
  String get incidentReportHint;

  /// Offer screen: which order
  ///
  /// In en, this message translates to:
  /// **'Order #{number}'**
  String offerOrderNumber(String number);

  /// Under the countdown number
  ///
  /// In en, this message translates to:
  /// **'seconds'**
  String get offerSeconds;

  /// Offer row label: pay
  ///
  /// In en, this message translates to:
  /// **'You earn'**
  String get offerEarnLabel;

  /// Offer row value: estimated pay
  ///
  /// In en, this message translates to:
  /// **'~{amount} (final pay adds waiting time)'**
  String offerEarnValue(String amount);

  /// Offer row label: payment
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get offerPaymentLabel;

  /// Offer row value: COD
  ///
  /// In en, this message translates to:
  /// **'Collect {amount} in cash'**
  String offerPaymentCod(String amount);

  /// Offer row value: prepaid
  ///
  /// In en, this message translates to:
  /// **'Prepaid — nothing to collect'**
  String get offerPaymentPrepaid;

  /// Offer row label: pickup
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get offerPickupLabel;

  /// Offer row: pickup distance unknown
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get offerPickupNearby;

  /// Offer row: pickup distance
  ///
  /// In en, this message translates to:
  /// **'{km} km away'**
  String offerPickupKm(String km);

  /// Offer row label: drop
  ///
  /// In en, this message translates to:
  /// **'Drop'**
  String get offerDropLabel;

  /// Offer row: drop distance
  ///
  /// In en, this message translates to:
  /// **'{km} km from pickup'**
  String offerDropKm(String km);

  /// Offer row: drop pincode
  ///
  /// In en, this message translates to:
  /// **'PIN {pincode}'**
  String offerDropPin(String pincode);

  /// Offer row: drop not disclosed before acceptance
  ///
  /// In en, this message translates to:
  /// **'Shown after you accept'**
  String get offerDropHidden;

  /// Offer row label: item count
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get offerItemsLabel;

  /// Accept the offer
  ///
  /// In en, this message translates to:
  /// **'Accept order'**
  String get offerAccept;

  /// Decline the offer
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get offerDecline;

  /// The offer screen closed at expiry
  ///
  /// In en, this message translates to:
  /// **'The offer expired.'**
  String get offerExpired;

  /// The offer was withdrawn or taken
  ///
  /// In en, this message translates to:
  /// **'This order is no longer available.'**
  String get offerGone;

  /// Accepted but the order could not be opened
  ///
  /// In en, this message translates to:
  /// **'Order accepted. Open it from your dashboard.'**
  String get offerAcceptedOpenDashboard;

  /// Tooltip: call the customer
  ///
  /// In en, this message translates to:
  /// **'Call customer'**
  String get activeCallCustomer;

  /// Call the customer
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get activeCall;

  /// Open turn-by-turn directions
  ///
  /// In en, this message translates to:
  /// **'Navigate'**
  String get activeNavigate;

  /// Section: the customer
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get activeSectionCustomer;

  /// Section: where to deliver
  ///
  /// In en, this message translates to:
  /// **'Delivery address'**
  String get activeSectionAddress;

  /// Section: order items
  ///
  /// In en, this message translates to:
  /// **'Items ({count})'**
  String activeSectionItems(int count);

  /// Quantity of an item
  ///
  /// In en, this message translates to:
  /// **'x{quantity}'**
  String activeItemQuantity(int quantity);

  /// Section: payment
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get activeSectionPayment;

  /// Payment method: COD
  ///
  /// In en, this message translates to:
  /// **'Cash on delivery'**
  String get activePaymentCod;

  /// Payment method: paid online
  ///
  /// In en, this message translates to:
  /// **'Prepaid'**
  String get activePaymentPrepaid;

  /// Section: step timeline
  ///
  /// In en, this message translates to:
  /// **'Delivery progress'**
  String get activeSectionProgress;

  /// Timeline step
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get activeStepAccepted;

  /// Timeline step
  ///
  /// In en, this message translates to:
  /// **'Arrived at the store'**
  String get activeStepArrived;

  /// Timeline step
  ///
  /// In en, this message translates to:
  /// **'Picked up'**
  String get activeStepPickedUp;

  /// Timeline step
  ///
  /// In en, this message translates to:
  /// **'Out for delivery'**
  String get activeStepOutForDelivery;

  /// Timeline step
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get activeStepDelivered;

  /// Next-step button
  ///
  /// In en, this message translates to:
  /// **'Arrived at store'**
  String get activeActionArrived;

  /// Next-step button
  ///
  /// In en, this message translates to:
  /// **'Picked up'**
  String get activeActionPickedUp;

  /// Next-step button
  ///
  /// In en, this message translates to:
  /// **'Start delivery'**
  String get activeActionStart;

  /// Next-step button
  ///
  /// In en, this message translates to:
  /// **'Complete delivery'**
  String get activeActionComplete;

  /// Toast after a step is recorded
  ///
  /// In en, this message translates to:
  /// **'Done: {step}'**
  String activeStepDone(String step);

  /// Section: delivery photo
  ///
  /// In en, this message translates to:
  /// **'Proof of delivery (optional)'**
  String get activeProofTitle;

  /// Empty photo tile
  ///
  /// In en, this message translates to:
  /// **'Tap to take a delivery photo'**
  String get activeProofTake;

  /// Retake the photo
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get activeProofRetake;

  /// Remove the photo
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get activeProofRemove;

  /// Release the order before pickup
  ///
  /// In en, this message translates to:
  /// **'Seller not ready'**
  String get activeSellerNotReady;

  /// Confirm releasing the order
  ///
  /// In en, this message translates to:
  /// **'Seller not ready?'**
  String get activeSellerNotReadyTitle;

  /// What releasing does
  ///
  /// In en, this message translates to:
  /// **'This releases the order back to the pickup queue and tells the team.'**
  String get activeSellerNotReadyBody;

  /// Confirm release
  ///
  /// In en, this message translates to:
  /// **'Release order'**
  String get activeSellerNotReadyConfirm;

  /// Keep the order
  ///
  /// In en, this message translates to:
  /// **'Wait'**
  String get activeSellerNotReadyWait;

  /// Toast after release
  ///
  /// In en, this message translates to:
  /// **'Order released for reassignment'**
  String get activeReleased;

  /// DLVMAP3: banner title when the live order differs from what is shown
  ///
  /// In en, this message translates to:
  /// **'Delivery details changed'**
  String get assignmentChangedTitle;

  /// DLVMAP3: banner body for the changed-details banner
  ///
  /// In en, this message translates to:
  /// **'Review the latest information before continuing.'**
  String get assignmentChangedBody;

  /// DLVMAP3: dismisses the changed-details banner
  ///
  /// In en, this message translates to:
  /// **'Review changes'**
  String get assignmentReviewChanges;

  /// DLVMAP3: title when the order has been reassigned away or otherwise lost
  ///
  /// In en, this message translates to:
  /// **'This delivery is no longer assigned to you'**
  String get assignmentRemovedTitle;

  /// DLVMAP3: body text explaining why details are now hidden
  ///
  /// In en, this message translates to:
  /// **'The assignment has been changed. You can\'t view the delivery details for privacy.'**
  String get assignmentRemovedBody;

  /// DLVMAP3: primary action on the removed-assignment screen
  ///
  /// In en, this message translates to:
  /// **'Back to dashboard'**
  String get assignmentBackToDashboard;

  /// DLVMAP3: secondary action on the removed-assignment screen
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get assignmentContactSupport;

  /// DLVMAP3: safety reminder card title, mockup 20.8
  ///
  /// In en, this message translates to:
  /// **'Already carrying the order?'**
  String get assignmentSafetyReminderTitle;

  /// DLVMAP3: safety reminder card body, mockup 20.8
  ///
  /// In en, this message translates to:
  /// **'Contact support for handover instructions. Do not deliver to the customer. We\'ll help you with the next steps.'**
  String get assignmentSafetyReminderBody;

  /// DLVMAP3: title when the live listener has failed (offline/permission)
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t confirm your assignment'**
  String get assignmentConnectionLostTitle;

  /// DLVMAP3: body text for the connection-lost state
  ///
  /// In en, this message translates to:
  /// **'Reconnect to check the latest status.'**
  String get assignmentConnectionLostBody;

  /// DLVMAP3: section title for the masked last-known summary
  ///
  /// In en, this message translates to:
  /// **'Last known status'**
  String get assignmentLastKnownTitle;

  /// DLVMAP3: disabled-actions notice during connection loss
  ///
  /// In en, this message translates to:
  /// **'Delivery actions unavailable while we reconnect.'**
  String get assignmentActionsUnavailable;

  /// Far-tap confirmation title
  ///
  /// In en, this message translates to:
  /// **'Are you there?'**
  String get activeFarTitle;

  /// Far-tap: do not go ahead
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get activeFarNotYet;

  /// Code sheet title
  ///
  /// In en, this message translates to:
  /// **'Verify delivery'**
  String get verifyTitle;

  /// Code sheet instruction
  ///
  /// In en, this message translates to:
  /// **'Ask the customer for their 6-digit delivery code.'**
  String get verifyHint;

  /// Screen-reader label for a code cell
  ///
  /// In en, this message translates to:
  /// **'Digit {index} of 6'**
  String verifyDigit(int index);

  /// Code shorter than 6 digits
  ///
  /// In en, this message translates to:
  /// **'Enter the full 6-digit code'**
  String get verifyIncomplete;

  /// Submit the code
  ///
  /// In en, this message translates to:
  /// **'Verify & complete'**
  String get verifySubmit;

  /// While the code is checked
  ///
  /// In en, this message translates to:
  /// **'Verifying…'**
  String get verifySubmitting;

  /// confirmDelivery: wrong code
  ///
  /// In en, this message translates to:
  /// **'Incorrect code. Please try again.'**
  String get deliverWrongCode;

  /// confirmDelivery: not deliverable
  ///
  /// In en, this message translates to:
  /// **'This order is no longer active and cannot be marked delivered.'**
  String get deliverNotActive;

  /// confirmDelivery: other precondition
  ///
  /// In en, this message translates to:
  /// **'Verification is not available for this order. Please contact support.'**
  String get deliverNoVerification;

  /// confirmDelivery: locked out
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1{Too many incorrect codes. Check the code with the customer and try again in 1 min.} other{Too many incorrect codes. Check the code with the customer and try again in {minutes} min.}}'**
  String deliverLocked(int minutes);

  /// confirmDelivery: other failure
  ///
  /// In en, this message translates to:
  /// **'Could not confirm delivery. Please try again.'**
  String get deliverFailed;

  /// The rider declined a far code entry
  ///
  /// In en, this message translates to:
  /// **'Delivery not completed. Enter the code when you are with the customer.'**
  String get deliverNotCompletedFar;

  /// After a confirmed delivery
  ///
  /// In en, this message translates to:
  /// **'Delivery complete'**
  String get deliveredTitle;

  /// After a confirmed delivery
  ///
  /// In en, this message translates to:
  /// **'Order #{number} has been delivered.'**
  String deliveredBody(String number);

  /// Leave the finished order
  ///
  /// In en, this message translates to:
  /// **'Back to dashboard'**
  String get deliveredBack;

  /// Riding time left
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String legMinutes(int minutes);

  /// Map pin: the store
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get routeStore;

  /// Map pin: the customer when no name
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get routeCustomer;

  /// Map pin: the rider (web)
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get routeYou;

  /// Route headline at the store
  ///
  /// In en, this message translates to:
  /// **'You are at the store'**
  String get routeAtStore;

  /// Route headline before pickup
  ///
  /// In en, this message translates to:
  /// **'Head to the store'**
  String get routeToStore;

  /// Route headline after pickup
  ///
  /// In en, this message translates to:
  /// **'Deliver to {name}'**
  String routeToCustomer(String name);

  /// Route headline after pickup, no name
  ///
  /// In en, this message translates to:
  /// **'Deliver to the customer'**
  String get routeToCustomerNoName;

  /// Route line at the store
  ///
  /// In en, this message translates to:
  /// **'Collect the order, then tap Picked up'**
  String get routeAtStoreHint;

  /// No store coordinates
  ///
  /// In en, this message translates to:
  /// **'Store location not available'**
  String get routeStoreUnknown;

  /// No customer coordinates
  ///
  /// In en, this message translates to:
  /// **'Customer location not available'**
  String get routeCustomerUnknown;

  /// Route not computed yet
  ///
  /// In en, this message translates to:
  /// **'Road route on its way — Navigate gives it now'**
  String get routePending;

  /// Map placeholder
  ///
  /// In en, this message translates to:
  /// **'Waiting for the route…'**
  String get routeWaiting;

  /// Open Maps to the store
  ///
  /// In en, this message translates to:
  /// **'Navigate to store'**
  String get routeNavigateStore;

  /// Open Maps to the customer
  ///
  /// In en, this message translates to:
  /// **'Navigate to customer'**
  String get routeNavigateCustomer;

  /// Fallback sheet title when external navigation could not be launched at all
  ///
  /// In en, this message translates to:
  /// **'Could not open navigation'**
  String get navFailedTitle;

  /// Fallback sheet body
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find a compatible navigation app on this device.'**
  String get navFailedBody;

  /// Dashboard greeting
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}'**
  String dashGreeting(String name);

  /// Dashboard greeting without a name
  ///
  /// In en, this message translates to:
  /// **'Hello'**
  String get dashGreetingNoName;

  /// Under the greeting while online
  ///
  /// In en, this message translates to:
  /// **'Ready to deliver'**
  String get dashReady;

  /// Under the greeting while offline
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get dashOfflineShort;

  /// Online toggle while online
  ///
  /// In en, this message translates to:
  /// **'You are online'**
  String get dashOnline;

  /// Online toggle while offline
  ///
  /// In en, this message translates to:
  /// **'You are offline'**
  String get dashOffline;

  /// Online toggle card explanatory subtitle while online (distinct from the header's own status text)
  ///
  /// In en, this message translates to:
  /// **'We\'ll show new offers here.'**
  String get dashOnlineHint;

  /// Online toggle card explanatory subtitle while offline (distinct from the header's own status text)
  ///
  /// In en, this message translates to:
  /// **'Orders are only offered while you are online.'**
  String get dashOfflineHint;

  /// Tooltip: sign out
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get dashSignOutTooltip;

  /// Confirm sign-out title
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get dashSignOutTitle;

  /// Confirm sign-out body
  ///
  /// In en, this message translates to:
  /// **'You will go offline and stop getting orders.'**
  String get dashSignOutBody;

  /// Earnings card label
  ///
  /// In en, this message translates to:
  /// **'Earned this week'**
  String get dashEarnedWeek;

  /// Earnings card line
  ///
  /// In en, this message translates to:
  /// **'Today {amount} · paid every Monday'**
  String dashEarnedTodayLine(String amount);

  /// Stat: deliveries today
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dashStatToday;

  /// Stat: pay this week
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get dashStatWeek;

  /// Stat: pay today
  ///
  /// In en, this message translates to:
  /// **'Earned today'**
  String get dashStatEarnedToday;

  /// Stat: COD cash held
  ///
  /// In en, this message translates to:
  /// **'Cash with you'**
  String get dashStatCash;

  /// Action card: money
  ///
  /// In en, this message translates to:
  /// **'Earnings & payouts'**
  String get dashMoneyTitle;

  /// Action card: money subtitle
  ///
  /// In en, this message translates to:
  /// **'Pay per delivery, cash with you, Monday statements'**
  String get dashMoneySubtitle;

  /// Heading
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get dashQuickActions;

  /// Action card: an offer is waiting
  ///
  /// In en, this message translates to:
  /// **'Order offered to you'**
  String get dashOfferTitle;

  /// Action card: open the offer
  ///
  /// In en, this message translates to:
  /// **'Tap to see it before it expires'**
  String get dashOfferSubtitle;

  /// Action card: online, no offer
  ///
  /// In en, this message translates to:
  /// **'Waiting for orders'**
  String get dashWaitingTitle;

  /// Action card: online, no offer
  ///
  /// In en, this message translates to:
  /// **'New orders near you will ring on this phone'**
  String get dashWaitingSubtitle;

  /// Action card: offline
  ///
  /// In en, this message translates to:
  /// **'Go online to get orders'**
  String get dashGoOnlineTitle;

  /// Action card: offline
  ///
  /// In en, this message translates to:
  /// **'Orders are only offered while you are online'**
  String get dashGoOnlineSubtitle;

  /// Active order card title
  ///
  /// In en, this message translates to:
  /// **'Active delivery'**
  String get dashActiveTitle;

  /// Open the active order
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get dashViewDetails;

  /// Going online needs a phone setting
  ///
  /// In en, this message translates to:
  /// **'Can\'t go online yet'**
  String get goOnlineBlockedTitle;

  /// No description provided for @dsBrandName.
  ///
  /// In en, this message translates to:
  /// **'AgriMore'**
  String get dsBrandName;

  /// No description provided for @dsBrandRole.
  ///
  /// In en, this message translates to:
  /// **'DELIVERY PARTNER'**
  String get dsBrandRole;

  /// No description provided for @dsRequired.
  ///
  /// In en, this message translates to:
  /// **'required'**
  String get dsRequired;

  /// No description provided for @dsOptional.
  ///
  /// In en, this message translates to:
  /// **'(optional)'**
  String get dsOptional;

  /// No description provided for @dsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get dsLoading;

  /// No description provided for @dsTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get dsTryAgain;

  /// No description provided for @dsClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get dsClose;

  /// No description provided for @dsBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get dsBack;

  /// No description provided for @dsCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get dsCancel;

  /// No description provided for @dsSearchClear.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get dsSearchClear;

  /// No description provided for @dsShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get dsShowPassword;

  /// No description provided for @dsHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get dsHidePassword;

  /// No description provided for @dsStepCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get dsStepCompleted;

  /// No description provided for @dsStepCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get dsStepCurrent;

  /// No description provided for @dsStepUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get dsStepUpcoming;

  /// No description provided for @dsStepFailed.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get dsStepFailed;

  /// No description provided for @dsStepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String dsStepOf(int current, int total);

  /// No description provided for @dsOtpFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Verification code, {length} digits'**
  String dsOtpFieldLabel(int length);

  /// No description provided for @dsFieldsNeedAttention.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Check 1 field} other{Check {count} fields}}'**
  String dsFieldsNeedAttention(int count);

  /// No description provided for @dsDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get dsDiscardTitle;

  /// No description provided for @dsDiscardBody.
  ///
  /// In en, this message translates to:
  /// **'Your unsaved changes will be lost.'**
  String get dsDiscardBody;

  /// No description provided for @dsDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get dsDiscard;

  /// No description provided for @dsKeepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get dsKeepEditing;

  /// No description provided for @dsExpandHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to expand'**
  String get dsExpandHint;

  /// No description provided for @dsCollapseHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to collapse'**
  String get dsCollapseHint;

  /// No description provided for @dsNoImage.
  ///
  /// In en, this message translates to:
  /// **'No photo'**
  String get dsNoImage;

  /// No description provided for @dsImageFailed.
  ///
  /// In en, this message translates to:
  /// **'Photo unavailable'**
  String get dsImageFailed;

  /// No description provided for @dsTabPosition.
  ///
  /// In en, this message translates to:
  /// **'Tab {index} of {count}'**
  String dsTabPosition(int index, int count);

  /// No description provided for @dsTestDataRibbon.
  ///
  /// In en, this message translates to:
  /// **'TEST DATA · Local emulator'**
  String get dsTestDataRibbon;

  /// No description provided for @dsUnreadDot.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get dsUnreadDot;

  /// No description provided for @dsSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get dsSaved;

  /// No description provided for @dsSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting…'**
  String get dsSubmitting;

  /// No description provided for @appearanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceTitle;

  /// No description provided for @appearanceSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get appearanceSystem;

  /// No description provided for @appearanceLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get appearanceLight;

  /// No description provided for @appearanceDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get appearanceDark;

  /// No description provided for @appearanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Match your phone or choose a theme for day and night riding'**
  String get appearanceSubtitle;

  /// No description provided for @authCheckingSession.
  ///
  /// In en, this message translates to:
  /// **'Checking your session…'**
  String get authCheckingSession;

  /// No description provided for @authSigningOut.
  ///
  /// In en, this message translates to:
  /// **'Signing out…'**
  String get authSigningOut;

  /// No description provided for @authTagline.
  ///
  /// In en, this message translates to:
  /// **'Deliver farm-fresh orders in your city'**
  String get authTagline;

  /// No description provided for @authNewPartnerHeading.
  ///
  /// In en, this message translates to:
  /// **'New to AgriMore Delivery?'**
  String get authNewPartnerHeading;

  /// No description provided for @authNewPartnerBody.
  ///
  /// In en, this message translates to:
  /// **'Register with your vehicle and documents to start delivering.'**
  String get authNewPartnerBody;

  /// No description provided for @regStepProgress.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String regStepProgress(int current, int total);

  /// No description provided for @regSaveExit.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get regSaveExit;

  /// No description provided for @regDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave registration?'**
  String get regDiscardTitle;

  /// No description provided for @regDiscardBody.
  ///
  /// In en, this message translates to:
  /// **'Your progress on this screen will be discarded.'**
  String get regDiscardBody;

  /// No description provided for @regDiscardConfirm.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get regDiscardConfirm;

  /// No description provided for @regPhotoTake.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get regPhotoTake;

  /// No description provided for @regPhotoGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get regPhotoGallery;

  /// No description provided for @regPhotoRetake.
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get regPhotoRetake;

  /// No description provided for @regPhotoReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get regPhotoReplace;

  /// No description provided for @regPhotoUploaded.
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get regPhotoUploaded;

  /// No description provided for @regPhotoUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading…'**
  String get regPhotoUploading;

  /// No description provided for @regPhotoFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed'**
  String get regPhotoFailed;

  /// No description provided for @regPayoutOptionalBadge.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get regPayoutOptionalBadge;

  /// No description provided for @regPayoutWhyTitle.
  ///
  /// In en, this message translates to:
  /// **'Why add payout details?'**
  String get regPayoutWhyTitle;

  /// No description provided for @regPayoutWhyBody.
  ///
  /// In en, this message translates to:
  /// **'Your weekly earnings are sent every Monday to your bank account or UPI ID. You can also add or change this later.'**
  String get regPayoutWhyBody;

  /// No description provided for @regPayoutMethodBank.
  ///
  /// In en, this message translates to:
  /// **'Bank account'**
  String get regPayoutMethodBank;

  /// No description provided for @regPayoutMethodUpi.
  ///
  /// In en, this message translates to:
  /// **'UPI ID'**
  String get regPayoutMethodUpi;

  /// No description provided for @regPayoutMethodSkip.
  ///
  /// In en, this message translates to:
  /// **'Add later'**
  String get regPayoutMethodSkip;

  /// No description provided for @regReviewSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Application summary'**
  String get regReviewSummaryTitle;

  /// No description provided for @kycTimelineSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Application submitted'**
  String get kycTimelineSubmitted;

  /// No description provided for @kycTimelineReview.
  ///
  /// In en, this message translates to:
  /// **'Document & vehicle review'**
  String get kycTimelineReview;

  /// No description provided for @kycTimelineDecision.
  ///
  /// In en, this message translates to:
  /// **'Approval decision'**
  String get kycTimelineDecision;

  /// No description provided for @kycRefreshStatus.
  ///
  /// In en, this message translates to:
  /// **'Refresh status'**
  String get kycRefreshStatus;

  /// No description provided for @kycRefreshing.
  ///
  /// In en, this message translates to:
  /// **'Checking status…'**
  String get kycRefreshing;

  /// No description provided for @kycWhatToFix.
  ///
  /// In en, this message translates to:
  /// **'What to fix'**
  String get kycWhatToFix;

  /// No description provided for @kycSuspensionDetails.
  ///
  /// In en, this message translates to:
  /// **'Suspension details'**
  String get kycSuspensionDetails;

  /// No description provided for @kycSupportNote.
  ///
  /// In en, this message translates to:
  /// **'Contact Agrimore support if you have questions about your account status.'**
  String get kycSupportNote;

  /// No description provided for @dashNavHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get dashNavHome;

  /// No description provided for @dashNavDeliveries.
  ///
  /// In en, this message translates to:
  /// **'Deliveries'**
  String get dashNavDeliveries;

  /// No description provided for @dashNavEarnings.
  ///
  /// In en, this message translates to:
  /// **'Earnings'**
  String get dashNavEarnings;

  /// No description provided for @dashNavInbox.
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get dashNavInbox;

  /// No description provided for @dashNavProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get dashNavProfile;

  /// No description provided for @dashAvailabilityLabel.
  ///
  /// In en, this message translates to:
  /// **'Work availability'**
  String get dashAvailabilityLabel;

  /// No description provided for @dashGoingOnline.
  ///
  /// In en, this message translates to:
  /// **'Going online…'**
  String get dashGoingOnline;

  /// No description provided for @dashGoingOffline.
  ///
  /// In en, this message translates to:
  /// **'Going offline…'**
  String get dashGoingOffline;

  /// No description provided for @dashOfflineBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'You have no internet connection'**
  String get dashOfflineBannerTitle;

  /// No description provided for @dashOfflineBannerBody.
  ///
  /// In en, this message translates to:
  /// **'Showing last saved data. Live offers require a connection.'**
  String get dashOfflineBannerBody;

  /// No description provided for @dashCachedDataNote.
  ///
  /// In en, this message translates to:
  /// **'Cached data · pull to refresh'**
  String get dashCachedDataNote;

  /// No description provided for @dashMultipleActiveWarning.
  ///
  /// In en, this message translates to:
  /// **'{count} active deliveries assigned'**
  String dashMultipleActiveWarning(int count);

  /// No description provided for @dashMultipleActiveHint.
  ///
  /// In en, this message translates to:
  /// **'Select an order below to continue'**
  String get dashMultipleActiveHint;

  /// No description provided for @dashOpenOrder.
  ///
  /// In en, this message translates to:
  /// **'Open order'**
  String get dashOpenOrder;

  /// No description provided for @dashCodLimitWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'COD cash limit reached'**
  String get dashCodLimitWarningTitle;

  /// No description provided for @dashCodLimitWarningBody.
  ///
  /// In en, this message translates to:
  /// **'Settle {amount} cash with the Agrimore team to receive new cash-on-delivery offers. Prepaid orders continue.'**
  String dashCodLimitWarningBody(String amount);

  /// No description provided for @locStep1Badge.
  ///
  /// In en, this message translates to:
  /// **'Step 1 of 2 · Foreground & background location'**
  String get locStep1Badge;

  /// No description provided for @locStep2Badge.
  ///
  /// In en, this message translates to:
  /// **'Step 2 of 2 · Background reliability'**
  String get locStep2Badge;

  /// No description provided for @locPurposeNearby.
  ///
  /// In en, this message translates to:
  /// **'Match you with nearby pickup orders'**
  String get locPurposeNearby;

  /// No description provided for @locPurposeTracking.
  ///
  /// In en, this message translates to:
  /// **'Share live delivery progress with the store and customer'**
  String get locPurposeTracking;

  /// No description provided for @locPurposeStop.
  ///
  /// In en, this message translates to:
  /// **'Location sharing stops immediately when you go offline'**
  String get locPurposeStop;

  /// No description provided for @locBatteryOemHint.
  ///
  /// In en, this message translates to:
  /// **'On Xiaomi, Oppo, Vivo, Realme and Samsung phones, set Battery to Unrestricted and allow Autostart so your phone does not stop location while you are on a delivery.'**
  String get locBatteryOemHint;

  /// No description provided for @locReducedBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Background location not set to Always'**
  String get locReducedBannerTitle;

  /// No description provided for @locReducedBannerBody.
  ///
  /// In en, this message translates to:
  /// **'If the app closes, location sharing may stop and take you offline.'**
  String get locReducedBannerBody;

  /// No description provided for @locFixInSettings.
  ///
  /// In en, this message translates to:
  /// **'Fix in Settings'**
  String get locFixInSettings;

  /// No description provided for @offerUrgentSeconds.
  ///
  /// In en, this message translates to:
  /// **'Hurry · {seconds}s left'**
  String offerUrgentSeconds(int seconds);

  /// No description provided for @offerAccepting.
  ///
  /// In en, this message translates to:
  /// **'Accepting…'**
  String get offerAccepting;

  /// No description provided for @offerDeclining.
  ///
  /// In en, this message translates to:
  /// **'Declining…'**
  String get offerDeclining;

  /// No description provided for @offerDeclineTitle.
  ///
  /// In en, this message translates to:
  /// **'Decline this offer?'**
  String get offerDeclineTitle;

  /// No description provided for @offerDeclineBody.
  ///
  /// In en, this message translates to:
  /// **'This order will be offered to another delivery partner.'**
  String get offerDeclineBody;

  /// No description provided for @offerDeclineConfirm.
  ///
  /// In en, this message translates to:
  /// **'Decline offer'**
  String get offerDeclineConfirm;

  /// No description provided for @offerKeepOrder.
  ///
  /// In en, this message translates to:
  /// **'Keep viewing'**
  String get offerKeepOrder;

  /// No description provided for @offerPrepaidBadge.
  ///
  /// In en, this message translates to:
  /// **'PREPAID'**
  String get offerPrepaidBadge;

  /// No description provided for @offerCodBadge.
  ///
  /// In en, this message translates to:
  /// **'COD · {amount}'**
  String offerCodBadge(String amount);

  /// No description provided for @offerPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'Customer name, phone and full address are shown after you accept.'**
  String get offerPrivacyNote;

  /// No description provided for @activeOrderHeader.
  ///
  /// In en, this message translates to:
  /// **'Order #{number}'**
  String activeOrderHeader(String number);

  /// No description provided for @activePickupSection.
  ///
  /// In en, this message translates to:
  /// **'Pickup store'**
  String get activePickupSection;

  /// No description provided for @activeDropSection.
  ///
  /// In en, this message translates to:
  /// **'Customer drop-off'**
  String get activeDropSection;

  /// No description provided for @activeCallStore.
  ///
  /// In en, this message translates to:
  /// **'Call store'**
  String get activeCallStore;

  /// No description provided for @activeCopyAddress.
  ///
  /// In en, this message translates to:
  /// **'Copy address'**
  String get activeCopyAddress;

  /// No description provided for @activeAddressCopied.
  ///
  /// In en, this message translates to:
  /// **'Address copied'**
  String get activeAddressCopied;

  /// No description provided for @activeInstructionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Delivery instructions'**
  String get activeInstructionsLabel;

  /// No description provided for @activeCollectCashTitle.
  ///
  /// In en, this message translates to:
  /// **'Collect {amount} cash from customer'**
  String activeCollectCashTitle(String amount);

  /// No description provided for @activeCollectCashBody.
  ///
  /// In en, this message translates to:
  /// **'Count the cash before entering the 6-digit delivery verification code.'**
  String get activeCollectCashBody;

  /// No description provided for @activePrepaidTitle.
  ///
  /// In en, this message translates to:
  /// **'Prepaid — do not collect cash'**
  String get activePrepaidTitle;

  /// No description provided for @activePrepaidBody.
  ///
  /// In en, this message translates to:
  /// **'The customer has already paid online.'**
  String get activePrepaidBody;

  /// No description provided for @activeStepUpdating.
  ///
  /// In en, this message translates to:
  /// **'Updating…'**
  String get activeStepUpdating;

  /// No description provided for @activeVerifyOtpAction.
  ///
  /// In en, this message translates to:
  /// **'Enter delivery OTP'**
  String get activeVerifyOtpAction;

  /// Toggle: show the map view of the route
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get routeViewMap;

  /// No description provided for @routeViewList.
  ///
  /// In en, this message translates to:
  /// **'Route details'**
  String get routeViewList;

  /// No description provided for @routeRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh route'**
  String get routeRefresh;

  /// No description provided for @routeRefreshing.
  ///
  /// In en, this message translates to:
  /// **'Refreshing route…'**
  String get routeRefreshing;

  /// No description provided for @routeLastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated just now'**
  String get routeLastUpdated;

  /// Position freshness caption near the map
  ///
  /// In en, this message translates to:
  /// **'Updated {minutes} min ago'**
  String routeUpdatedMinAgo(int minutes);

  /// Stale-location banner title
  ///
  /// In en, this message translates to:
  /// **'Your location is out of date'**
  String get routeStaleTitle;

  /// Stale-location banner body when Refresh location is offered
  ///
  /// In en, this message translates to:
  /// **'Refresh your location to update the route.'**
  String get routeStaleBodyRefreshable;

  /// Stale-location banner body when the native service owns sending and no manual refresh is offered
  ///
  /// In en, this message translates to:
  /// **'Location updates automatically in the background. If this continues, check your settings.'**
  String get routeStaleBodyNative;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Refresh location'**
  String get routeRefreshLocation;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Check settings'**
  String get routeCheckSettings;

  /// Toast when refreshNow() fails
  ///
  /// In en, this message translates to:
  /// **'Could not refresh your location. Try again.'**
  String get routeRefreshFailed;

  /// No description provided for @routeLiveGps.
  ///
  /// In en, this message translates to:
  /// **'Live GPS'**
  String get routeLiveGps;

  /// No description provided for @routeCachedBanner.
  ///
  /// In en, this message translates to:
  /// **'Offline · showing last known route'**
  String get routeCachedBanner;

  /// No description provided for @routeCopyCoords.
  ///
  /// In en, this message translates to:
  /// **'Copy coordinates'**
  String get routeCopyCoords;

  /// No description provided for @routeCoordsCopied.
  ///
  /// In en, this message translates to:
  /// **'Coordinates copied'**
  String get routeCoordsCopied;

  /// No description provided for @routeStepPickup.
  ///
  /// In en, this message translates to:
  /// **'1. Pickup'**
  String get routeStepPickup;

  /// No description provided for @routeStepDrop.
  ///
  /// In en, this message translates to:
  /// **'2. Drop-off'**
  String get routeStepDrop;

  /// Toggle: show the accessible text view of the route
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get routeViewDetails;

  /// Banner title when the delivery-task stream fails
  ///
  /// In en, this message translates to:
  /// **'Route information unavailable'**
  String get routeErrorTaskTitle;

  /// Banner body when the delivery-task stream fails
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load this delivery\'s route details.'**
  String get routeErrorTaskBody;

  /// Banner title when the rider-position stream fails
  ///
  /// In en, this message translates to:
  /// **'Live position unavailable'**
  String get routeErrorPositionTitle;

  /// Banner body when the rider-position stream fails
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load your current position.'**
  String get routeErrorPositionBody;

  /// Banner body when a route stream fails with permission-denied specifically
  ///
  /// In en, this message translates to:
  /// **'You may no longer have access to this delivery\'s route.'**
  String get routeErrorPermissionBody;

  /// Accessible route details section label
  ///
  /// In en, this message translates to:
  /// **'Current stage'**
  String get routeDetailsStageLabel;

  /// Accessible route details section label
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get routeDetailsPickupLabel;

  /// Accessible route details section label
  ///
  /// In en, this message translates to:
  /// **'Drop-off'**
  String get routeDetailsDropLabel;

  /// Accessible route details section label
  ///
  /// In en, this message translates to:
  /// **'Estimated distance and time'**
  String get routeDetailsDistanceLabel;

  /// Accessible route details: no route computed, but the connection is healthy
  ///
  /// In en, this message translates to:
  /// **'Route details aren\'t available for this delivery yet.'**
  String get routeDetailsRouteUnavailable;

  /// Accessible route details: still waiting for the first delivery-task update
  ///
  /// In en, this message translates to:
  /// **'Loading route details…'**
  String get routeDetailsLoadingRoute;

  /// Accessible route details: no pickup coordinates, but the connection is healthy
  ///
  /// In en, this message translates to:
  /// **'Pickup location isn\'t available for this delivery.'**
  String get routeDetailsPickupUnavailable;

  /// Accessible route details: no drop-off coordinates, but the connection is healthy
  ///
  /// In en, this message translates to:
  /// **'Drop-off location isn\'t available for this delivery.'**
  String get routeDetailsDropUnavailable;

  /// Accessible route details: still waiting for the first delivery-task update
  ///
  /// In en, this message translates to:
  /// **'Loading pickup location…'**
  String get routeDetailsLoadingPickup;

  /// Accessible route details: still waiting for the first delivery-task update
  ///
  /// In en, this message translates to:
  /// **'Loading drop-off location…'**
  String get routeDetailsLoadingDrop;

  /// No description provided for @waitTimerLabel.
  ///
  /// In en, this message translates to:
  /// **'Waiting at store'**
  String get waitTimerLabel;

  /// No description provided for @waitTimerNote.
  ///
  /// In en, this message translates to:
  /// **'Waiting time pay applies after the grace period'**
  String get waitTimerNote;

  /// No description provided for @releaseReasonStoreClosed.
  ///
  /// In en, this message translates to:
  /// **'Store is closed'**
  String get releaseReasonStoreClosed;

  /// No description provided for @releaseReasonLongWait.
  ///
  /// In en, this message translates to:
  /// **'Order taking too long to prepare'**
  String get releaseReasonLongWait;

  /// No description provided for @releaseReasonVehicleProblem.
  ///
  /// In en, this message translates to:
  /// **'Vehicle issue before pickup'**
  String get releaseReasonVehicleProblem;

  /// No description provided for @releaseReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other reason'**
  String get releaseReasonOther;

  /// No description provided for @releaseWarningNote.
  ///
  /// In en, this message translates to:
  /// **'Only available before you mark Picked up. Releasing returns the order to the dispatch queue.'**
  String get releaseWarningNote;

  /// No description provided for @verifyCodReminder.
  ///
  /// In en, this message translates to:
  /// **'Confirm you collected {amount} in cash before verifying'**
  String verifyCodReminder(String amount);

  /// No description provided for @verifyAttemptsRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 attempt remaining before temporary lock} other{{count} attempts remaining}}'**
  String verifyAttemptsRemaining(int count);

  /// No description provided for @verifyLockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Verification temporarily locked'**
  String get verifyLockedTitle;

  /// No description provided for @verifyContactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get verifyContactSupport;

  /// No description provided for @deliveredEarnedLabel.
  ///
  /// In en, this message translates to:
  /// **'Estimated earnings'**
  String get deliveredEarnedLabel;

  /// No description provided for @deliveredCodRecordedLabel.
  ///
  /// In en, this message translates to:
  /// **'COD cash recorded'**
  String get deliveredCodRecordedLabel;

  /// No description provided for @deliveredProofSaved.
  ///
  /// In en, this message translates to:
  /// **'Delivery proof photo saved'**
  String get deliveredProofSaved;

  /// No description provided for @proofUploadTitle.
  ///
  /// In en, this message translates to:
  /// **'Proof of delivery photo'**
  String get proofUploadTitle;

  /// No description provided for @proofUploadHint.
  ///
  /// In en, this message translates to:
  /// **'Optional photo of the delivered package at the drop-off'**
  String get proofUploadHint;

  /// No description provided for @proofUploading.
  ///
  /// In en, this message translates to:
  /// **'Saving photo…'**
  String get proofUploading;

  /// No description provided for @proofSavedBadge.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get proofSavedBadge;

  /// No description provided for @problemNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Describe what happened so the Agrimore team can help'**
  String get problemNoteHint;

  /// No description provided for @problemReturnToStoreHint.
  ///
  /// In en, this message translates to:
  /// **'Return the items to the pickup store as instructed by Agrimore.'**
  String get problemReturnToStoreHint;

  /// No description provided for @emergencyBannerNote.
  ///
  /// In en, this message translates to:
  /// **'Calls open your phone dialer. Safety reports record an entry for the Agrimore team.'**
  String get emergencyBannerNote;

  /// No description provided for @incidentNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'What happened? (optional)'**
  String get incidentNoteLabel;

  /// No description provided for @incidentNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Add brief details if it is safe to do so'**
  String get incidentNoteHint;

  /// No description provided for @incidentLocationIncluded.
  ///
  /// In en, this message translates to:
  /// **'Includes your current order and GPS fix if available'**
  String get incidentLocationIncluded;

  /// No description provided for @incidentLocationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'GPS fix unavailable — report will still be recorded'**
  String get incidentLocationUnavailable;

  /// No description provided for @moneyNetRuleNote.
  ///
  /// In en, this message translates to:
  /// **'Weekly payout = Gross delivery earnings − COD cash held'**
  String get moneyNetRuleNote;

  /// No description provided for @moneySettlementHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'How COD cash is settled'**
  String get moneySettlementHistoryTitle;

  /// No description provided for @moneySettlementHistoryBody.
  ///
  /// In en, this message translates to:
  /// **'COD cash you collect is deducted from your Monday statement, or you can hand over cash directly to the Agrimore team.'**
  String get moneySettlementHistoryBody;

  /// No description provided for @moneyOrderWaitingLine.
  ///
  /// In en, this message translates to:
  /// **'Waiting ({minutes}m): {amount}'**
  String moneyOrderWaitingLine(int minutes, String amount);

  /// No description provided for @moneyOrderDistanceLine.
  ///
  /// In en, this message translates to:
  /// **'Distance ({km} km): {amount}'**
  String moneyOrderDistanceLine(String km, String amount);

  /// No description provided for @statementFormulaNote.
  ///
  /// In en, this message translates to:
  /// **'Net payout = Gross earned − COD cash offset'**
  String get statementFormulaNote;

  /// No description provided for @statementCarryoverNote.
  ///
  /// In en, this message translates to:
  /// **'Remaining cash ({amount}) stays in your cash-in-hand balance for next week.'**
  String statementCarryoverNote(String amount);

  /// No description provided for @statementHoldFixAction.
  ///
  /// In en, this message translates to:
  /// **'Review payout details'**
  String get statementHoldFixAction;

  /// No description provided for @payoutSingleActiveNote.
  ///
  /// In en, this message translates to:
  /// **'Only one payout destination (bank account or UPI ID) is active per payout.'**
  String get payoutSingleActiveNote;

  /// No description provided for @payoutMethodLabel.
  ///
  /// In en, this message translates to:
  /// **'Destination type'**
  String get payoutMethodLabel;

  /// No description provided for @payoutBankMethod.
  ///
  /// In en, this message translates to:
  /// **'Bank account'**
  String get payoutBankMethod;

  /// No description provided for @payoutUpiMethod.
  ///
  /// In en, this message translates to:
  /// **'UPI ID'**
  String get payoutUpiMethod;

  /// No description provided for @payoutConfirmAccount.
  ///
  /// In en, this message translates to:
  /// **'Confirm account number'**
  String get payoutConfirmAccount;

  /// No description provided for @payoutProblemAccountMismatch.
  ///
  /// In en, this message translates to:
  /// **'Account numbers do not match'**
  String get payoutProblemAccountMismatch;

  /// No description provided for @payoutReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review payout changes'**
  String get payoutReviewTitle;

  /// No description provided for @payoutReviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Submission is not bank verification. Your current destination remains active until the Agrimore team approves this request.'**
  String get payoutReviewSubtitle;

  /// No description provided for @payoutCurrentDestination.
  ///
  /// In en, this message translates to:
  /// **'Current active destination'**
  String get payoutCurrentDestination;

  /// No description provided for @payoutProposedDestination.
  ///
  /// In en, this message translates to:
  /// **'Proposed new destination (pending review)'**
  String get payoutProposedDestination;

  /// No description provided for @payoutEditDetails.
  ///
  /// In en, this message translates to:
  /// **'Edit details'**
  String get payoutEditDetails;

  /// No description provided for @payoutTimelineSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Request submitted'**
  String get payoutTimelineSubmitted;

  /// No description provided for @payoutTimelineReview.
  ///
  /// In en, this message translates to:
  /// **'Agrimore team review'**
  String get payoutTimelineReview;

  /// No description provided for @payoutTimelineApplied.
  ///
  /// In en, this message translates to:
  /// **'Applied to future payouts'**
  String get payoutTimelineApplied;

  /// No description provided for @historySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by order number (e.g. ORD-104)'**
  String get historySearchHint;

  /// No description provided for @historyDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Order details'**
  String get historyDetailTitle;

  /// No description provided for @historyTimelineTitle.
  ///
  /// In en, this message translates to:
  /// **'Delivery timeline'**
  String get historyTimelineTitle;

  /// No description provided for @inboxFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get inboxFilterAll;

  /// No description provided for @inboxFilterUnread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get inboxFilterUnread;

  /// No description provided for @inboxGroupToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get inboxGroupToday;

  /// No description provided for @inboxGroupEarlier.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get inboxGroupEarlier;

  /// No description provided for @inboxDestinationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This item is no longer available.'**
  String get inboxDestinationUnavailable;

  /// No description provided for @profileIdentitySection.
  ///
  /// In en, this message translates to:
  /// **'Identity & KYC (read-only)'**
  String get profileIdentitySection;

  /// No description provided for @profileIdentityNote.
  ///
  /// In en, this message translates to:
  /// **'Name, phone, Aadhaar and driving licence are verified by Agrimore. Contact support to request a correction.'**
  String get profileIdentityNote;

  /// No description provided for @profileContactSection.
  ///
  /// In en, this message translates to:
  /// **'Contact & address'**
  String get profileContactSection;

  /// No description provided for @profileVehicleSection.
  ///
  /// In en, this message translates to:
  /// **'Vehicle & documents'**
  String get profileVehicleSection;

  /// No description provided for @profileSupportSection.
  ///
  /// In en, this message translates to:
  /// **'Help & support'**
  String get profileSupportSection;

  /// No description provided for @profileAccountSection.
  ///
  /// In en, this message translates to:
  /// **'Account actions'**
  String get profileAccountSection;

  /// No description provided for @profileDeleteWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Before you request deletion'**
  String get profileDeleteWarningTitle;

  /// No description provided for @profileDeleteWarningBody.
  ///
  /// In en, this message translates to:
  /// **'You must have no active delivery, ₹0 COD cash in hand, and no unsettled earnings.'**
  String get profileDeleteWarningBody;

  /// No description provided for @profileDeleteConfirmCheck.
  ///
  /// In en, this message translates to:
  /// **'I understand that deleting my account permanently removes my rider access.'**
  String get profileDeleteConfirmCheck;

  /// No description provided for @a11yRouteToggleLabel.
  ///
  /// In en, this message translates to:
  /// **'Route view mode'**
  String get a11yRouteToggleLabel;

  /// No description provided for @a11yOnlineSwitchHint.
  ///
  /// In en, this message translates to:
  /// **'Double-tap to toggle work availability'**
  String get a11yOnlineSwitchHint;

  /// No description provided for @locDisclosureBullet1.
  ///
  /// In en, this message translates to:
  /// **'Match you with nearby pickup orders while you are online'**
  String get locDisclosureBullet1;

  /// No description provided for @locDisclosureBullet2.
  ///
  /// In en, this message translates to:
  /// **'Share live delivery progress with the pickup store and customer'**
  String get locDisclosureBullet2;

  /// No description provided for @locDisclosureBullet3.
  ///
  /// In en, this message translates to:
  /// **'Location sharing stops immediately when you go offline'**
  String get locDisclosureBullet3;

  /// No description provided for @locBackgroundStep1.
  ///
  /// In en, this message translates to:
  /// **'Select Permissions → Location → Allow all the time so tracking continues when your screen locks during a delivery.'**
  String get locBackgroundStep1;

  /// No description provided for @locBackgroundStep2.
  ///
  /// In en, this message translates to:
  /// **'On Xiaomi, Oppo, Vivo, Realme and Samsung phones, set Battery to Unrestricted so your phone does not pause active deliveries.'**
  String get locBackgroundStep2;

  /// No description provided for @kycBadgeActionRequired.
  ///
  /// In en, this message translates to:
  /// **'Action required'**
  String get kycBadgeActionRequired;

  /// No description provided for @kycBadgeSuspended.
  ///
  /// In en, this message translates to:
  /// **'Suspended'**
  String get kycBadgeSuspended;

  /// No description provided for @kycBadgeUnderReview.
  ///
  /// In en, this message translates to:
  /// **'Under review'**
  String get kycBadgeUnderReview;

  /// No description provided for @vehicleBicycleSub.
  ///
  /// In en, this message translates to:
  /// **'Short trips · no licence required'**
  String get vehicleBicycleSub;

  /// No description provided for @vehicleMotorcycleSub.
  ///
  /// In en, this message translates to:
  /// **'Standard city deliveries'**
  String get vehicleMotorcycleSub;

  /// No description provided for @vehicleScooterSub.
  ///
  /// In en, this message translates to:
  /// **'Gearless two-wheeler'**
  String get vehicleScooterSub;

  /// No description provided for @vehicleEvSub.
  ///
  /// In en, this message translates to:
  /// **'Electric two-wheeler'**
  String get vehicleEvSub;

  /// No description provided for @vehicleAutoSub.
  ///
  /// In en, this message translates to:
  /// **'Three-wheeler cargo / auto'**
  String get vehicleAutoSub;

  /// No description provided for @vehicleMiniTruckSub.
  ///
  /// In en, this message translates to:
  /// **'Bulk & crate orders'**
  String get vehicleMiniTruckSub;

  /// No description provided for @profileAppearanceHeading.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get profileAppearanceHeading;

  /// No description provided for @profileThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get profileThemeSystem;

  /// No description provided for @profileThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get profileThemeLight;

  /// No description provided for @profileThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get profileThemeDark;

  /// No description provided for @profileReadinessHeading.
  ///
  /// In en, this message translates to:
  /// **'Delivery readiness'**
  String get profileReadinessHeading;

  /// No description provided for @readinessOpen.
  ///
  /// In en, this message translates to:
  /// **'Check delivery readiness'**
  String get readinessOpen;

  /// No description provided for @readinessScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Delivery readiness'**
  String get readinessScreenTitle;

  /// No description provided for @readinessScreenIntro.
  ///
  /// In en, this message translates to:
  /// **'These affect whether you actually see and can accept new delivery offers. Going online still works even if some are off.'**
  String get readinessScreenIntro;

  /// No description provided for @readinessReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get readinessReady;

  /// No description provided for @readinessActionNeeded.
  ///
  /// In en, this message translates to:
  /// **'Action needed'**
  String get readinessActionNeeded;

  /// No description provided for @readinessFix.
  ///
  /// In en, this message translates to:
  /// **'Fix'**
  String get readinessFix;

  /// No description provided for @readinessNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get readinessNotificationsTitle;

  /// No description provided for @readinessNotificationsBody.
  ///
  /// In en, this message translates to:
  /// **'Lets the app alert you when a new order arrives.'**
  String get readinessNotificationsBody;

  /// No description provided for @readinessFullScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Full-screen ring alert'**
  String get readinessFullScreenTitle;

  /// No description provided for @readinessFullScreenBody.
  ///
  /// In en, this message translates to:
  /// **'Lets an incoming order ring and show even while your phone is locked.'**
  String get readinessFullScreenBody;

  /// No description provided for @readinessLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get readinessLocationTitle;

  /// No description provided for @readinessLocationBody.
  ///
  /// In en, this message translates to:
  /// **'Needed so nearby orders can be offered to you at all.'**
  String get readinessLocationBody;

  /// No description provided for @readinessBackgroundLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Background location'**
  String get readinessBackgroundLocationTitle;

  /// No description provided for @readinessBackgroundLocationBody.
  ///
  /// In en, this message translates to:
  /// **'Keeps sharing your location while online even if the app closes.'**
  String get readinessBackgroundLocationBody;

  /// No description provided for @readinessBatteryTitle.
  ///
  /// In en, this message translates to:
  /// **'Battery settings'**
  String get readinessBatteryTitle;

  /// No description provided for @readinessBatteryBody.
  ///
  /// In en, this message translates to:
  /// **'Stops your phone closing the app in the background, which would take you offline.'**
  String get readinessBatteryBody;
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
    'that was used.',
  );
}
