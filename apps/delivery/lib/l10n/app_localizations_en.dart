// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Agrimore Delivery';

  @override
  String get loadingAccount => 'Loading your account';

  @override
  String get authWrongCredentials => 'Email or password is incorrect.';

  @override
  String get authInvalidEmail => 'Enter a valid email address.';

  @override
  String get authTooManyAttempts =>
      'Too many attempts. Wait a few minutes, then try again.';

  @override
  String get authNetwork => 'No connection. Check your internet and try again.';

  @override
  String get authAccountDisabled =>
      'This account is turned off. Contact Agrimore support.';

  @override
  String get authNotDeliveryPartner =>
      'This account is not a delivery partner account.';

  @override
  String get authProfileUnavailable =>
      'Couldn\'t load your account. Check your connection.';

  @override
  String get authUnknown => 'Sign-in didn\'t work. Try again.';

  @override
  String get actionRetry => 'Try again';

  @override
  String get actionSignOut => 'Sign out';

  @override
  String get sessionLoadFailedTitle => 'Account not loaded';

  @override
  String get activeWorkLoading => 'Loading your orders';

  @override
  String get activeWorkOffline => 'Showing saved data — reconnecting';

  @override
  String get activeWorkErrorPermission =>
      'Your account can\'t read orders right now. Sign out and in again, or contact support.';

  @override
  String get activeWorkErrorOffline =>
      'Couldn\'t reach Agrimore. Check your connection.';

  @override
  String get activeWorkErrorUnknown => 'Couldn\'t load your orders.';

  @override
  String activeWorkMultipleTitle(int count) {
    return '$count orders are assigned to you';
  }

  @override
  String get activeWorkMultipleBody =>
      'Finish them one at a time. If you did not accept all of them, call Agrimore support.';

  @override
  String activeWorkOpen(String number) {
    return 'Open order $number';
  }

  @override
  String get todayDeliveredUnknown => '—';

  @override
  String get historyTitle => 'Delivery history';

  @override
  String get historyEmpty => 'No orders yet';

  @override
  String get historyLoadMore => 'Load more';

  @override
  String get historyEnd => 'That\'s all your orders';

  @override
  String historyOrderNumber(String number) {
    return 'Order $number';
  }

  @override
  String get historyStatusDelivered => 'Delivered';

  @override
  String get historyStatusActive => 'In progress';

  @override
  String get historyStatusCancelled => 'Cancelled';

  @override
  String get historyStatusReturned => 'Returned';

  @override
  String get historyStatusOther => 'Other status';

  @override
  String get historyHint => 'Newest first, 20 at a time.';

  @override
  String get splashTagline => 'Delivery Partner';

  @override
  String get historyActionTitle => 'Delivery history';

  @override
  String get historyActionSubtitle => 'Every order you carried, newest first';

  @override
  String get regTitle => 'Become a delivery partner';

  @override
  String get regResumeNote =>
      'Your account is ready — finish your details to apply.';

  @override
  String get regStepAccount => 'Account';

  @override
  String get regStepAbout => 'About you';

  @override
  String get regStepVehicle => 'Vehicle and licence';

  @override
  String get regStepDocuments => 'Identity documents';

  @override
  String get regStepPayout => 'Payout (optional)';

  @override
  String get regNext => 'Next';

  @override
  String get regBack => 'Back';

  @override
  String get regSubmit => 'Submit application';

  @override
  String get regSubmitting => 'Submitting…';

  @override
  String get fieldEmail => 'Email';

  @override
  String get fieldPassword => 'Password';

  @override
  String get fieldName => 'Full name';

  @override
  String get fieldPhone => 'Mobile number';

  @override
  String get fieldAltPhone => 'Alternate mobile (optional)';

  @override
  String get fieldAddress => 'Address';

  @override
  String get fieldCity => 'City';

  @override
  String get fieldPincode => 'PIN code';

  @override
  String get fieldVehicleType => 'Vehicle';

  @override
  String get fieldVehicleNumber => 'Vehicle registration number';

  @override
  String get fieldLicenseNumber => 'Driving licence number';

  @override
  String get fieldAadhaarNumber => 'Aadhaar number';

  @override
  String get fieldAccountHolder => 'Account holder name';

  @override
  String get fieldAccountNumber => 'Bank account number';

  @override
  String get fieldIfsc => 'IFSC';

  @override
  String get fieldUpi => 'UPI ID';

  @override
  String get payoutHint =>
      'Add a bank account, a UPI ID, or both — or skip and add them later from Earnings (an admin reviews changes).';

  @override
  String get docAadhaarFront => 'Aadhaar — front';

  @override
  String get docAadhaarBack => 'Aadhaar — back';

  @override
  String get docSelfie => 'Selfie';

  @override
  String get docLicense => 'Driving licence';

  @override
  String get docAdd => 'Add photo';

  @override
  String get docChange => 'Change';

  @override
  String get docMissing => 'Add this photo';

  @override
  String get docsPrivacy =>
      'Photos are visible only to you and Agrimore admins, and are locked once your application is decided.';

  @override
  String get vehicleBicycle => 'Bicycle';

  @override
  String get vehicleBike => 'Motorbike';

  @override
  String get vehicleScooter => 'Scooter';

  @override
  String get vehicleEv => 'Electric two-wheeler';

  @override
  String get vehicleThreeWheeler => 'Three-wheeler';

  @override
  String get vehicleCar => 'Car';

  @override
  String get vehicleVan => 'Van';

  @override
  String get errEmail => 'Enter a valid email';

  @override
  String get errPassword => 'At least 6 characters';

  @override
  String get errName => 'Enter your full name';

  @override
  String get errPhone => 'Enter a 10-digit Indian mobile number';

  @override
  String get errAltPhone => 'Enter a different 10-digit mobile number';

  @override
  String get errAddress => 'Enter your address';

  @override
  String get errCity => 'Enter your city';

  @override
  String get errPincode => 'Enter a 6-digit PIN code';

  @override
  String get errVehicleNumber =>
      'Enter the registration number, e.g. TN58AB1234';

  @override
  String get errLicenseNumber => 'Enter your driving licence number';

  @override
  String get errAadhaarNumber => 'Enter the 12-digit Aadhaar number';

  @override
  String get errAccountHolder => 'Enter the account holder\'s name';

  @override
  String get errAccountNumber => '9–18 digits';

  @override
  String get errIfsc => '11 characters, e.g. SBIN0001234';

  @override
  String get errUpi => 'Enter a UPI ID like name@bank';

  @override
  String get regFailEmailInUse =>
      'An account with this email already exists. Sign in with it to continue your application.';

  @override
  String get regFailWeakPassword => 'Choose a stronger password.';

  @override
  String get regFailInvalidEmail => 'Enter a valid email address.';

  @override
  String get regFailNetwork =>
      'No connection. Your details are kept — try again.';

  @override
  String get regFailUpload =>
      'A photo didn\'t upload. Your details are kept — try again.';

  @override
  String get regFailInvalid =>
      'Some details need fixing — they\'re marked below.';

  @override
  String get regFailDocuments =>
      'Some photos didn\'t reach Agrimore. Add them again and resubmit.';

  @override
  String get regFailAlreadyRegistered =>
      'This account is already registered. Sign in to continue.';

  @override
  String get regFailOtherRole =>
      'This account is used for another Agrimore app. Register with a different email.';

  @override
  String get regFailUnknown =>
      'The application didn\'t go through. Your details are kept — try again.';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get resetTitle => 'Reset your password';

  @override
  String get resetBody =>
      'Enter your account email. If an account exists, we\'ll email a link to set a new password.';

  @override
  String get resetSend => 'Send link';

  @override
  String get resetCancel => 'Cancel';

  @override
  String get resetSent =>
      'If an account exists for that email, a reset link is on its way. Check your inbox and spam folder.';

  @override
  String get signInTitle => 'Sign in';

  @override
  String get signInSubtitle =>
      'Use the email and password you registered with.';

  @override
  String get signInAction => 'Sign in';

  @override
  String get signingIn => 'Signing in';

  @override
  String get registerAction => 'Register as a delivery partner';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get errPasswordEmpty => 'Enter your password';

  @override
  String get resetFailed =>
      'Couldn\'t send the reset link. Try again, or contact Agrimore support.';
}
