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
