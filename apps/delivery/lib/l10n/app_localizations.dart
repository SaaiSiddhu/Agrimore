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
  /// **'To change your name, mobile number, vehicle, licence or Aadhaar, contact Agrimore support — an admin reviews those changes.'**
  String get profileLockedNote;

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

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get deleteAccount;

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

  /// Mark every shown notice read
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get inboxMarkAllRead;

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

  /// History filter: orders not delivered
  ///
  /// In en, this message translates to:
  /// **'Cancelled or returned'**
  String get historyFilterNotDelivered;

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
