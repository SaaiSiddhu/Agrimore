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
  /// **'Your profile, documents and payout details are removed and you are signed out. Records of deliveries and payments are kept, as the law requires. This cannot be undone.'**
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
