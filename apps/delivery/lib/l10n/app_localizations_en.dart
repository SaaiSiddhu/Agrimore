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
  String get navHome => 'Home';

  @override
  String get navDeliveries => 'Deliveries';

  @override
  String get navEarnings => 'Earnings';

  @override
  String get navInbox => 'Inbox';

  @override
  String get navProfile => 'Profile';

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

  @override
  String get profileTitle => 'Your profile';

  @override
  String get profileOpen => 'Open your profile';

  @override
  String get profileDetails => 'Your details';

  @override
  String get profileContact => 'Contact and address';

  @override
  String get profileDocuments => 'Documents';

  @override
  String get profilePayout => 'Payout details';

  @override
  String get profileSupport => 'Help and support';

  @override
  String get profileGetHelp => 'Get help';

  @override
  String get helpSupportSubtitle =>
      'Get help for delivery, earnings, account and documents. Call support, or submit a request and we\'ll get back to you.';

  @override
  String get helpSupportQuestion => 'What do you need help with?';

  @override
  String get helpTopicDeliveryIssue => 'Delivery issue';

  @override
  String get helpTopicDeliveryIssueSub => 'Report a problem with an order';

  @override
  String get helpTopicEarningsPayouts => 'Earnings & payouts';

  @override
  String get helpTopicEarningsPayoutsSub =>
      'Questions about a payout or statement';

  @override
  String get helpTopicAccountDocuments => 'Account & documents';

  @override
  String get helpTopicAccountDocumentsSub => 'Request support';

  @override
  String get helpImmediateDanger => 'Immediate danger?';

  @override
  String get supportSubmitTitle => 'Submit a request';

  @override
  String get supportCategoryLabel => 'Category';

  @override
  String get supportMessageLabel => 'Message';

  @override
  String get supportMessageHint => 'Describe what you need help with';

  @override
  String get supportAttachmentLabel => 'Attachment (optional)';

  @override
  String get supportAddAttachment => 'Add a photo';

  @override
  String get supportRemoveAttachment => 'Remove';

  @override
  String get supportAttachmentFailed =>
      'Could not attach that file. You can still submit without it.';

  @override
  String get supportSubmitButton => 'Submit request';

  @override
  String get errSupportMessage => 'Write at least 3 characters (up to 500).';

  @override
  String get supportStatusTitle => 'Request status';

  @override
  String get supportStatusSubmitted => 'Submitted';

  @override
  String get supportStatusSeen => 'Seen';

  @override
  String get supportStatusClosed => 'Closed';

  @override
  String get supportStatusSubmittedBody => 'Your request has been recorded.';

  @override
  String get supportStatusSeenBody => 'Your request has been viewed.';

  @override
  String get supportStatusClosedBody =>
      'Request closed. View the outcome below.';

  @override
  String get mySupportRequestsEntry => 'My support requests';

  @override
  String get mySupportRequestsTitle => 'My support requests';

  @override
  String get mySupportRequestsEmpty =>
      'You haven\'t filed any support requests yet.';

  @override
  String get mySupportRequestsNetworkError =>
      'Couldn\'t load your support requests. Check your connection and try again.';

  @override
  String get supportOutcomeLabel => 'Outcome';

  @override
  String get supportNewRequest => 'New request';

  @override
  String get profileAccount => 'Account';

  @override
  String get profileVehicle => 'Vehicle';

  @override
  String get profileVehicleNumber => 'Registration number';

  @override
  String get profileLicence => 'Driving licence';

  @override
  String get profileAadhaar => 'Aadhaar';

  @override
  String get profilePhone => 'Mobile';

  @override
  String get profileAltPhone => 'Alternate mobile';

  @override
  String get profileAddress => 'Address';

  @override
  String get profileNotSet => 'Not added';

  @override
  String get profileEditContact => 'Edit contact and address';

  @override
  String get profileLockedNote =>
      'To change your mobile number, licence or Aadhaar, contact Agrimore support — an admin reviews those changes.';

  @override
  String get profileRequestNameChange => 'Request name change';

  @override
  String get profileRequestVehicleChange => 'Request vehicle update';

  @override
  String get identityChangeTitle => 'Request identity change';

  @override
  String get identityChangeCurrentName => 'Current name';

  @override
  String get identityChangeProposedName => 'New name';

  @override
  String get identityChangeCurrentVehicle => 'Current vehicle';

  @override
  String get identityChangeProposedVehicleType => 'New vehicle type';

  @override
  String get identityChangeProposedVehicleNumber => 'New registration number';

  @override
  String get identityChangeReasonLabel => 'Reason for change';

  @override
  String get identityChangeSubmit => 'Submit request';

  @override
  String get identityChangeSubmitted => 'Your request has been submitted.';

  @override
  String get identityChangePendingTitle => 'Request pending review';

  @override
  String get identityChangePendingBody =>
      'Your current details remain unchanged while this is reviewed.';

  @override
  String get identityChangeRejectedTitle => 'Request not approved';

  @override
  String get identityChangeCorrect => 'Correct and resend';

  @override
  String get identityChangeAlreadyPending =>
      'You already have a request waiting for review.';

  @override
  String get identityChangeNetworkError =>
      'Could not submit your request. Try again.';

  @override
  String get identityChangeInvalid => 'Check your details and try again.';

  @override
  String get errIdentityName =>
      'Enter your full legal name (2–100 characters).';

  @override
  String get errIdentityVehicleType => 'Choose a vehicle type.';

  @override
  String get errIdentityReason => 'Enter a reason (3–250 characters).';

  @override
  String get docSubmitted => 'Submitted';

  @override
  String get docNotSubmitted => 'Not submitted';

  @override
  String payoutBank(String masked) {
    return 'Bank account $masked';
  }

  @override
  String payoutUpi(String upi) {
    return 'UPI $upi';
  }

  @override
  String get payoutNone => 'No payout details yet';

  @override
  String get payoutChange => 'Change payout details';

  @override
  String get supportCall => 'Call Agrimore support';

  @override
  String get supportEmail => 'Email Agrimore support';

  @override
  String supportOpenFailed(String contact) {
    return 'Couldn\'t open that. Support: $contact';
  }

  @override
  String get signOutConfirmTitle => 'Sign out of this device?';

  @override
  String get signOutConfirmBody =>
      'You\'ll be signed out from this device only. Your account and data remain safe, and you can sign in again anytime.';

  @override
  String get deleteAccount => 'Delete my account';

  @override
  String get deleteBlockedTitle => 'Account deletion isn\'t available yet';

  @override
  String get deleteBlockedViewDelivery => 'View delivery';

  @override
  String get deleteBlockedViewEarnings => 'View earnings';

  @override
  String get deleteConfirmTitle => 'Delete your account?';

  @override
  String get deleteConfirmBody =>
      'Your profile, documents and payout details are removed and you are signed out. Records of your deliveries and payments are kept. This cannot be undone.';

  @override
  String get deleteConfirm => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get deleteDone => 'Your account was deleted.';

  @override
  String get failActiveOrder =>
      'You still have an order assigned. Deliver it or ask Agrimore to reassign it first.';

  @override
  String get failCashHeld =>
      'You still hold customers\' cash. Deposit it with Agrimore first.';

  @override
  String get failPayOwed =>
      'Agrimore still owes you delivery pay. Wait until your statement is paid.';

  @override
  String get failOtherBalance =>
      'This account still has an open balance or order. Contact Agrimore support.';

  @override
  String get failInvalid => 'Some details need fixing — they\'re marked.';

  @override
  String get failNetwork => 'No connection. Try again.';

  @override
  String get failUnknown => 'That didn\'t go through. Try again.';

  @override
  String get save => 'Save';

  @override
  String get contactSaved => 'Contact details saved.';

  @override
  String get statusPendingTitle => 'Application under review';

  @override
  String get statusPendingBody =>
      'An Agrimore admin is checking your details and documents. You\'ll be able to go online once approved.';

  @override
  String get statusRejectedTitle => 'Application not approved';

  @override
  String get statusRejectedBody =>
      'Your application was not approved. You can correct it and submit again.';

  @override
  String get statusSuspendedTitle => 'Account suspended';

  @override
  String get statusSuspendedBody =>
      'You can\'t go online or accept orders until an admin reinstates your account.';

  @override
  String get statusDeactivatedTitle => 'Account deactivated';

  @override
  String get statusDeactivatedBody =>
      'This delivery partner account is no longer active.';

  @override
  String get statusReason => 'Reason';

  @override
  String get statusUpdateApplication => 'Update and resubmit';

  @override
  String get statusEditApplication => 'Edit application';

  @override
  String get regResubmitNote =>
      'Correct your details and submit your application again.';

  @override
  String get problemReport => 'Report a problem';

  @override
  String get problemSheetTitle => 'What went wrong?';

  @override
  String get problemNoteLabel => 'Details (optional)';

  @override
  String get problemSend => 'Send to Agrimore';

  @override
  String get problemReported => 'Problem reported';

  @override
  String get problemReportedBody =>
      'Agrimore has your report but may not have seen it yet. Keep the goods with you and stay reachable.';

  @override
  String get problemSeen => 'Seen by Agrimore';

  @override
  String get problemSeenBody =>
      'A person at Agrimore is looking at this. Keep the goods with you until they tell you what to do.';

  @override
  String get problemReattempt => 'Try the delivery again';

  @override
  String get problemReturned => 'Goods recorded as returned to the seller';

  @override
  String problemResolutionNote(String note) {
    return 'Agrimore wrote: $note';
  }

  @override
  String get problemFailNotAfterPickup =>
      'You can report a problem once you have picked the order up.';

  @override
  String get problemFailOpen => 'A problem is already open for this order.';

  @override
  String get problemFailNetwork =>
      'No connection — the report didn\'t go through. Try again.';

  @override
  String get problemFailUnknown =>
      'The report didn\'t go through. Try again or call Agrimore support.';

  @override
  String get reasonCustomerUnreachable => 'Customer not reachable';

  @override
  String get reasonCustomerRefused => 'Customer refused the order';

  @override
  String get reasonWrongAddress => 'Wrong address';

  @override
  String get reasonAddressNotFound => 'Can\'t find the address';

  @override
  String get reasonPaymentIssue => 'Cash payment problem';

  @override
  String get reasonDamagedGoods => 'Goods damaged or missing';

  @override
  String get reasonVehicleIssue => 'Vehicle problem';

  @override
  String get reasonSafety => 'Safety concern';

  @override
  String get reasonOther => 'Something else';

  @override
  String get proofNotSaved =>
      'Delivered. The proof photo couldn\'t be saved — the delivery still counts.';

  @override
  String get moneyTitle => 'Earnings';

  @override
  String get moneyThisWeek => 'This week';

  @override
  String get moneyToday => 'Today';

  @override
  String moneyDeliveries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count deliveries',
      one: '1 delivery',
    );
    return '$_temp0';
  }

  @override
  String get moneyPaidMondays => 'Paid every Monday';

  @override
  String get moneyLoadError =>
      'Could not load your earnings. Check your connection.';

  @override
  String get moneyNoDeliveriesYet =>
      'No deliveries yet this week. Pay for each delivery shows here as soon as it is delivered.';

  @override
  String get moneyCashNone => 'No cash with you';

  @override
  String get moneyCashNoneHint => 'Cash you collect on COD orders shows here.';

  @override
  String moneyCashHeld(String amount) {
    return 'Cash with you: $amount';
  }

  @override
  String get moneyCashHint =>
      'Cash from COD orders is taken off your Monday payout. Hand larger amounts to the Agrimore team.';

  @override
  String moneyCashUnderLimit(String limit) {
    return 'You get cash-on-delivery orders while you hold less than $limit.';
  }

  @override
  String moneyCashOverLimit(String limit) {
    return 'You hold $limit or more, so you won\'t get cash-on-delivery orders until you hand cash to the Agrimore team.';
  }

  @override
  String moneyEarningTitle(String number) {
    return 'Order #$number';
  }

  @override
  String moneyLineBase(String amount) {
    return 'Base $amount';
  }

  @override
  String moneyLineDistance(String km, String amount) {
    return '$km km $amount';
  }

  @override
  String moneyLineWaiting(int minutes, String amount) {
    return 'Waiting $minutes min $amount';
  }

  @override
  String moneyLineCash(String amount) {
    return 'Collected $amount cash';
  }

  @override
  String get moneyStatementsTitle => 'Weekly statements';

  @override
  String get moneyStatementsError => 'Could not load statements.';

  @override
  String get moneyStatementsEmpty =>
      'Your first statement is made on Monday for the week before. Pay is sent to your bank or UPI.';

  @override
  String moneyWeekEnding(String date) {
    return 'Week ending $date';
  }

  @override
  String moneyWeekEndingPart(String date, int part) {
    return 'Week ending $date · part $part';
  }

  @override
  String moneyStatementEarned(String amount) {
    return 'earned $amount';
  }

  @override
  String moneyStatementCashOff(String amount) {
    return 'cash taken off $amount';
  }

  @override
  String stagePaid(String reference) {
    return 'Money sent · Ref $reference';
  }

  @override
  String get stagePaidNoRef => 'Money sent';

  @override
  String get stageAwaiting =>
      'Statement ready — the Agrimore team will send the money';

  @override
  String get stageHeldReview =>
      'On hold — your new payout details are being checked';

  @override
  String get stageHeldNoDetails => 'On hold — add your bank or UPI details';

  @override
  String get stageNothing => 'Nothing to pay';

  @override
  String stageNothingCash(String amount) {
    return 'Nothing to pay — cash you hold covered it ($amount still with you)';
  }

  @override
  String stageUnknown(String status) {
    return 'Status: $status';
  }

  @override
  String get payoutDetailsTitle => 'Payout details';

  @override
  String get payoutDetailsNone =>
      'No bank or UPI details yet — your pay will wait until you add them.';

  @override
  String payoutDetailsBank(String account) {
    return 'Bank $account';
  }

  @override
  String payoutDetailsBankIfsc(String account, String ifsc) {
    return 'Bank $account · $ifsc';
  }

  @override
  String payoutDetailsUpi(String upi) {
    return 'UPI $upi';
  }

  @override
  String get bankChangeReviewing =>
      'Your change is being checked by the Agrimore team.';

  @override
  String bankChangeRejected(String reason) {
    return 'Your last change was not approved: $reason';
  }

  @override
  String get bankChangeRejectedNoReason => 'Your last change was not approved.';

  @override
  String get bankChangeButton => 'Change payout details';

  @override
  String get bankChangeWaiting => 'Change waiting for review';

  @override
  String get bankChangeSent =>
      'Sent. The Agrimore team will check it; your pay waits until then.';

  @override
  String get bankFormTitle => 'Change payout details';

  @override
  String get bankFormIntro =>
      'The Agrimore team checks every change before any money is sent to it.';

  @override
  String get bankFormHolder => 'Account holder name';

  @override
  String get bankFormAccount => 'Bank account number';

  @override
  String get bankFormIfsc => 'IFSC';

  @override
  String get bankFormOr => 'and / or';

  @override
  String get bankFormUpi => 'UPI ID (e.g. name@okaxis)';

  @override
  String get bankFormSend => 'Send for review';

  @override
  String get bankProblemEmpty => 'Enter bank details or a UPI ID';

  @override
  String get bankProblemHolder => 'Enter the account holder name';

  @override
  String get bankProblemAccount => 'Account number should be 9–18 digits';

  @override
  String get bankProblemIfsc => 'IFSC looks wrong (e.g. SBIN0001234)';

  @override
  String get bankProblemUpi => 'UPI ID looks wrong (e.g. name@okaxis)';

  @override
  String get bankFailAlreadyPending =>
      'A change is already waiting for review.';

  @override
  String get bankFailInvalid => 'Please check the details and try again.';

  @override
  String get bankFailOther => 'Could not send the change. Please try again.';

  @override
  String get statementTitle => 'Statement';

  @override
  String get statementEarned => 'Earned';

  @override
  String get statementCashOff => 'Cash you held, taken off';

  @override
  String get statementToPay => 'To be sent to you';

  @override
  String get statementSent => 'Sent to you';

  @override
  String get statementCashAfter => 'Cash still with you';

  @override
  String statementSentToBank(String last4) {
    return 'Sent to bank account ending $last4';
  }

  @override
  String statementSentToUpi(String upi) {
    return 'Sent to UPI $upi';
  }

  @override
  String statementSentOn(String date) {
    return 'Sent on $date';
  }

  @override
  String statementMadeOn(String date) {
    return 'Statement made on $date';
  }

  @override
  String get statementDeliveries => 'Deliveries in this statement';

  @override
  String get statementLinesEmpty => 'No deliveries in this statement.';

  @override
  String get statementLinesError =>
      'Could not load the deliveries. Check your connection.';

  @override
  String get statementLoadMore => 'Load more';

  @override
  String get moneyAmountLoading => '…';

  @override
  String get inboxTitle => 'Inbox';

  @override
  String get inboxOpen => 'Inbox';

  @override
  String inboxOpenUnread(int count) {
    return 'Inbox, $count unread';
  }

  @override
  String get inboxEmpty =>
      'Nothing here yet. Orders, statements and payments you should know about show here.';

  @override
  String get inboxLoadError =>
      'Could not load your inbox. Check your connection.';

  @override
  String get inboxMarkAllRead => 'Mark all read';

  @override
  String get inboxMarkingAllRead => 'Marking all read…';

  @override
  String get inboxMarkAllReadSuccess => 'All notifications marked as read.';

  @override
  String inboxLimitNote(int count) {
    return 'Showing your latest $count notices.';
  }

  @override
  String get inboxMarkReadFailed => 'Could not update your inbox. Try again.';

  @override
  String get inboxDeliveryUnavailable =>
      'This delivery is no longer available to you.';

  @override
  String get inboxDeliveryNetworkError =>
      'Could not open this delivery. Try again.';

  @override
  String get historyFilterAll => 'All';

  @override
  String get historyFilterDelivered => 'Delivered';

  @override
  String get historyFilterCancelled => 'Cancelled';

  @override
  String get historyFilterReturned => 'Returned';

  @override
  String get historyRangeAllTime => 'All time';

  @override
  String get historyRangeLast7Days => 'Last 7 days';

  @override
  String get historyRangeLast30Days => 'Last 30 days';

  @override
  String get historyClearFilters => 'Clear filters';

  @override
  String get historyEmptyFiltered => 'No orders here';

  @override
  String get historyDetailPay => 'Your pay for this order';

  @override
  String get historyDetailPayPending =>
      'Pay shows here once the order is delivered.';

  @override
  String get historyDetailCash => 'Cash collected';

  @override
  String get historyDetailInStatement => 'In a weekly statement';

  @override
  String get historyDetailNotInStatement =>
      'Goes into next Monday\'s statement';

  @override
  String get historyDetailStatementUnavailable =>
      'This statement is no longer available.';

  @override
  String get historyDetailStatementNetworkError =>
      'Could not open this statement. Try again.';

  @override
  String get historyDetailOrderTotal => 'Order amount';

  @override
  String get historyDetailPayError => 'Could not load your pay for this order.';

  @override
  String get historyDetailNoEarningsCancelled =>
      'No earnings — this order was cancelled.';

  @override
  String get historyDetailNoEarningsReturned =>
      'No earnings recorded for this returned order.';

  @override
  String get historyDetailTimelineTitle => 'Delivery timeline';

  @override
  String get historyDetailTimelineEmpty =>
      'No recorded timeline for this order.';

  @override
  String get historyDetailTimelineError =>
      'Could not load this order\'s timeline.';

  @override
  String get historyDetailCustomerTitle => 'Customer';

  @override
  String get historyDetailGetHelpTitle => 'Need help with this order?';

  @override
  String get actionNotNow => 'Not now';

  @override
  String get actionContinue => 'Continue';

  @override
  String get actionLater => 'Later';

  @override
  String get actionOpenSettings => 'Open settings';

  @override
  String get actionAllow => 'Allow';

  @override
  String get goOnlineServicesOff => 'Turn on location (GPS) to go online.';

  @override
  String get goOnlinePermissionDenied =>
      'Allow location access to go online. Orders are offered by distance.';

  @override
  String get goOnlinePermissionForever =>
      'Location access is turned off for this app. Turn it on in Settings to go online.';

  @override
  String get goOnlineFailed =>
      'Could not get your location. Move to an open area and try again.';

  @override
  String get serverOfflineNoLocation =>
      'You\'re offline — your location stopped for 15 minutes. Go online again when you\'re ready.';

  @override
  String get locationDisclosureTitle => 'Your location while you are online';

  @override
  String get locationDisclosureBody =>
      'While you are online, Agrimore Delivery collects your location — also when the app is closed or not in use — to offer you nearby orders and to show customers where their delivery is. A notification shows while this is on. It stops as soon as you go offline.';

  @override
  String get backgroundLocationTitle =>
      'Keep deliveries working when the app closes';

  @override
  String get backgroundLocationBody =>
      'Your phone sometimes closes apps to save memory. To keep sharing your location while you are online even then, choose \"Allow all the time\" on the next screen. It still stops as soon as you go offline.';

  @override
  String get backgroundLocationReminder =>
      'You are online. If your phone closes the app, location sharing stops and you go offline — allow location \"all the time\" in Settings to avoid this.';

  @override
  String get batteryGuideTitle => 'Stop your phone closing the app';

  @override
  String get batteryGuideBody =>
      'Some phones close apps in the background to save battery, which takes you offline. In the app settings that open next, set Battery to \"Unrestricted\" (or \"No restrictions\"). On Xiaomi, Oppo, Vivo and Realme phones also turn on \"Autostart\".';

  @override
  String get onlineNoticeTitle => 'You\'re online';

  @override
  String get onlineNoticeText =>
      'Sharing your location for nearby orders and live tracking. Go offline in the app to stop.';

  @override
  String get onlineNoticeChannel => 'Online status';

  @override
  String get offerChannelName => 'Delivery offers';

  @override
  String get offerChannelDescription =>
      'Rings when a new delivery order is offered to you';

  @override
  String get offerNotificationTitle => 'New delivery request';

  @override
  String get offerNotificationBody => 'Tap to see the order';

  @override
  String get offerRingPromptTitle => 'Ring for new orders?';

  @override
  String get offerRingPromptBody =>
      'Allow full-screen alerts so a new delivery order rings and shows even when your phone is locked. You can change this later in Settings.';

  @override
  String offerSummaryPay(String amount) {
    return 'Earn ~$amount';
  }

  @override
  String get offerSummaryNearby => 'Pickup nearby';

  @override
  String offerSummaryDistance(String km) {
    return 'Pickup $km km away';
  }

  @override
  String offerSummaryItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String offerSummaryCollect(String amount) {
    return 'Collect $amount';
  }

  @override
  String get offerRefusalTaken => 'Another delivery partner took this order.';

  @override
  String get offerRefusalExpired => 'This offer has expired.';

  @override
  String get offerRefusalBusy =>
      'Finish your current delivery before taking another.';

  @override
  String get offerRefusalNotEligible =>
      'Your account cannot take orders right now.';

  @override
  String get offerRefusalNoOffer => 'This order is no longer offered to you.';

  @override
  String get offerRefusalOffline => 'Go online to accept orders.';

  @override
  String get offerRefusalCashLimit =>
      'Deposit the cash you hold with Agrimore before taking cash orders.';

  @override
  String get offerRefusalSignIn => 'Please sign in again.';

  @override
  String get offerRefusalFailed =>
      'Could not update this offer. Please try again.';

  @override
  String distanceMeters(int meters) {
    return '$meters m';
  }

  @override
  String distanceKm(String km) {
    return '$km km';
  }

  @override
  String stepFarStore(String distance, String action) {
    return 'You\'re $distance from the store. $action anyway? The delivery team will be told.';
  }

  @override
  String stepFarCustomer(String distance, String action) {
    return 'You\'re $distance from the customer\'s address. $action anyway? The delivery team will be told.';
  }

  @override
  String get stepActionArrived => 'Mark arrived';

  @override
  String get stepActionPickedUp => 'Mark picked up';

  @override
  String get stepActionComplete => 'Complete the delivery';

  @override
  String get stepErrBadTransition =>
      'This step is not possible right now — the order may have changed. Go back and open it again.';

  @override
  String get stepErrNotAssigned => 'This order is no longer assigned to you.';

  @override
  String get stepErrAfterPickup =>
      'The order is already picked up, so it can no longer be released. Contact support if there is a problem.';

  @override
  String get stepErrNotFound => 'This order could not be found.';

  @override
  String get stepErrNetwork =>
      'No internet connection. Check your network and try again.';

  @override
  String get stepErrSession =>
      'Your session has expired. Please sign in again.';

  @override
  String get stepErrUpdate => 'Could not update the order. Please try again.';

  @override
  String get stepErrRelease => 'Could not release the order. Please try again.';

  @override
  String get incidentErrTooMany =>
      'Too many reports in a few minutes. Call 112 or Agrimore support.';

  @override
  String get incidentErrNotRider =>
      'This account cannot report here. Call 112 or Agrimore support.';

  @override
  String get incidentErrNetwork =>
      'No connection — the report didn\'t go through. Try again, or call 112.';

  @override
  String get incidentErrSignedOut =>
      'You are signed out. Call 112 or Agrimore support.';

  @override
  String get incidentErrFailed =>
      'The report didn\'t go through. Try again, or call 112.';

  @override
  String get incidentStatusClosed => 'Closed by the Agrimore team';

  @override
  String get incidentStatusNoNote => 'No note was added.';

  @override
  String get incidentStatusSeen => 'Seen by the Agrimore team';

  @override
  String get incidentStatusSeenDetail =>
      'A person on the team has opened your report. If you are in danger, call 112.';

  @override
  String get incidentStatusRecorded => 'Report recorded';

  @override
  String get incidentStatusRecordedDetail =>
      'Nobody on the Agrimore team may have seen it yet. If you are in danger, call 112 now.';

  @override
  String get emergencyTitle => 'Emergency help';

  @override
  String get activeHelpTooltip => 'Help';

  @override
  String get activeHelpSheetTitle => 'Help with this delivery';

  @override
  String get activeHelpSheetSubtitle =>
      'Your current delivery will remain active.';

  @override
  String get activeHelpBackToDelivery => 'Back to delivery';

  @override
  String emergencyIntro(String number) {
    return 'If you or someone else is in danger, call $number now. This app does not alert the police or Agrimore by itself.';
  }

  @override
  String emergencyCall(String number) {
    return 'Call $number (emergency)';
  }

  @override
  String get emergencyCallSupport => 'Call Agrimore support';

  @override
  String emergencyDialFailed(String number) {
    return 'Couldn\'t open the phone app. Dial $number directly.';
  }

  @override
  String get incidentReportAction => 'Tell the Agrimore team';

  @override
  String get incidentReportSending => 'Recording your report…';

  @override
  String get incidentReportHint =>
      'Records a report for the Agrimore team with your current order and, if the phone has it, your position. It does not call anyone.';

  @override
  String offerOrderNumber(String number) {
    return 'Order #$number';
  }

  @override
  String get offerSeconds => 'seconds';

  @override
  String get offerEarnLabel => 'You earn';

  @override
  String offerEarnValue(String amount) {
    return '~$amount (final pay adds waiting time)';
  }

  @override
  String get offerPaymentLabel => 'Payment';

  @override
  String offerPaymentCod(String amount) {
    return 'Collect $amount in cash';
  }

  @override
  String get offerPaymentPrepaid => 'Prepaid — nothing to collect';

  @override
  String get offerPickupLabel => 'Pickup';

  @override
  String get offerPickupNearby => 'Nearby';

  @override
  String offerPickupKm(String km) {
    return '$km km away';
  }

  @override
  String get offerDropLabel => 'Drop';

  @override
  String offerDropKm(String km) {
    return '$km km from pickup';
  }

  @override
  String offerDropPin(String pincode) {
    return 'PIN $pincode';
  }

  @override
  String get offerDropHidden => 'Shown after you accept';

  @override
  String get offerItemsLabel => 'Items';

  @override
  String get offerAccept => 'Accept order';

  @override
  String get offerDecline => 'Decline';

  @override
  String get offerExpired => 'The offer expired.';

  @override
  String get offerGone => 'This order is no longer available.';

  @override
  String get offerAcceptedOpenDashboard =>
      'Order accepted. Open it from your dashboard.';

  @override
  String get activeCallCustomer => 'Call customer';

  @override
  String get activeCall => 'Call';

  @override
  String get activeNavigate => 'Navigate';

  @override
  String get activeSectionCustomer => 'Customer';

  @override
  String get activeSectionAddress => 'Delivery address';

  @override
  String activeSectionItems(int count) {
    return 'Items ($count)';
  }

  @override
  String activeItemQuantity(int quantity) {
    return 'x$quantity';
  }

  @override
  String get activeSectionPayment => 'Payment';

  @override
  String get activePaymentCod => 'Cash on delivery';

  @override
  String get activePaymentPrepaid => 'Prepaid';

  @override
  String get activeSectionProgress => 'Delivery progress';

  @override
  String get activeStepAccepted => 'Accepted';

  @override
  String get activeStepArrived => 'Arrived at the store';

  @override
  String get activeStepPickedUp => 'Picked up';

  @override
  String get activeStepOutForDelivery => 'Out for delivery';

  @override
  String get activeStepDelivered => 'Delivered';

  @override
  String get activeActionArrived => 'Arrived at store';

  @override
  String get activeActionPickedUp => 'Picked up';

  @override
  String get activeActionStart => 'Start delivery';

  @override
  String get activeActionComplete => 'Complete delivery';

  @override
  String activeStepDone(String step) {
    return 'Done: $step';
  }

  @override
  String get activeProofTitle => 'Proof of delivery (optional)';

  @override
  String get activeProofTake => 'Tap to take a delivery photo';

  @override
  String get activeProofRetake => 'Retake';

  @override
  String get activeProofRemove => 'Remove';

  @override
  String get activeSellerNotReady => 'Seller not ready';

  @override
  String get activeSellerNotReadyTitle => 'Seller not ready?';

  @override
  String get activeSellerNotReadyBody =>
      'This releases the order back to the pickup queue and tells the team.';

  @override
  String get activeSellerNotReadyConfirm => 'Release order';

  @override
  String get activeSellerNotReadyWait => 'Wait';

  @override
  String get activeReleased => 'Order released for reassignment';

  @override
  String get assignmentChangedTitle => 'Delivery details changed';

  @override
  String get assignmentChangedBody =>
      'Review the latest information before continuing.';

  @override
  String get assignmentReviewChanges => 'Review changes';

  @override
  String get assignmentRemovedTitle =>
      'This delivery is no longer assigned to you';

  @override
  String get assignmentRemovedBody =>
      'The assignment has been changed. You can\'t view the delivery details for privacy.';

  @override
  String get assignmentBackToDashboard => 'Back to dashboard';

  @override
  String get assignmentContactSupport => 'Contact support';

  @override
  String get assignmentSafetyReminderTitle => 'Already carrying the order?';

  @override
  String get assignmentSafetyReminderBody =>
      'Contact support for handover instructions. Do not deliver to the customer. We\'ll help you with the next steps.';

  @override
  String get assignmentConnectionLostTitle =>
      'Couldn\'t confirm your assignment';

  @override
  String get assignmentConnectionLostBody =>
      'Reconnect to check the latest status.';

  @override
  String get assignmentLastKnownTitle => 'Last known status';

  @override
  String get assignmentActionsUnavailable =>
      'Delivery actions unavailable while we reconnect.';

  @override
  String get activeFarTitle => 'Are you there?';

  @override
  String get activeFarNotYet => 'Not yet';

  @override
  String get verifyTitle => 'Verify delivery';

  @override
  String get verifyHint => 'Ask the customer for their 6-digit delivery code.';

  @override
  String verifyDigit(int index) {
    return 'Digit $index of 6';
  }

  @override
  String get verifyIncomplete => 'Enter the full 6-digit code';

  @override
  String get verifySubmit => 'Verify & complete';

  @override
  String get verifySubmitting => 'Verifying…';

  @override
  String get deliverWrongCode => 'Incorrect code. Please try again.';

  @override
  String get deliverNotActive =>
      'This order is no longer active and cannot be marked delivered.';

  @override
  String get deliverNoVerification =>
      'Verification is not available for this order. Please contact support.';

  @override
  String deliverLocked(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other:
          'Too many incorrect codes. Check the code with the customer and try again in $minutes min.',
      one:
          'Too many incorrect codes. Check the code with the customer and try again in 1 min.',
    );
    return '$_temp0';
  }

  @override
  String get deliverFailed => 'Could not confirm delivery. Please try again.';

  @override
  String get deliverNotCompletedFar =>
      'Delivery not completed. Enter the code when you are with the customer.';

  @override
  String get deliveredTitle => 'Delivery complete';

  @override
  String deliveredBody(String number) {
    return 'Order #$number has been delivered.';
  }

  @override
  String get deliveredBack => 'Back to dashboard';

  @override
  String legMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get routeStore => 'Store';

  @override
  String get routeCustomer => 'Customer';

  @override
  String get routeYou => 'You';

  @override
  String get routeAtStore => 'You are at the store';

  @override
  String get routeToStore => 'Head to the store';

  @override
  String routeToCustomer(String name) {
    return 'Deliver to $name';
  }

  @override
  String get routeToCustomerNoName => 'Deliver to the customer';

  @override
  String get routeAtStoreHint => 'Collect the order, then tap Picked up';

  @override
  String get routeStoreUnknown => 'Store location not available';

  @override
  String get routeCustomerUnknown => 'Customer location not available';

  @override
  String get routePending => 'Road route on its way — Navigate gives it now';

  @override
  String get routeWaiting => 'Waiting for the route…';

  @override
  String get routeNavigateStore => 'Navigate to store';

  @override
  String get routeNavigateCustomer => 'Navigate to customer';

  @override
  String get navFailedTitle => 'Could not open navigation';

  @override
  String get navFailedBody =>
      'We couldn\'t find a compatible navigation app on this device.';

  @override
  String dashGreeting(String name) {
    return 'Hello, $name';
  }

  @override
  String get dashGreetingNoName => 'Hello';

  @override
  String get dashReady => 'Ready to deliver';

  @override
  String get dashOfflineShort => 'Offline';

  @override
  String get dashOnline => 'You are online';

  @override
  String get dashOffline => 'You are offline';

  @override
  String get dashSignOutTooltip => 'Sign out';

  @override
  String get dashSignOutTitle => 'Sign out?';

  @override
  String get dashSignOutBody => 'You will go offline and stop getting orders.';

  @override
  String get dashEarnedWeek => 'Earned this week';

  @override
  String dashEarnedTodayLine(String amount) {
    return 'Today $amount · paid every Monday';
  }

  @override
  String get dashStatToday => 'Today';

  @override
  String get dashStatWeek => 'This week';

  @override
  String get dashStatEarnedToday => 'Earned today';

  @override
  String get dashStatCash => 'Cash with you';

  @override
  String get dashMoneyTitle => 'Earnings & payouts';

  @override
  String get dashMoneySubtitle =>
      'Pay per delivery, cash with you, Monday statements';

  @override
  String get dashQuickActions => 'Quick actions';

  @override
  String get dashOfferTitle => 'Order offered to you';

  @override
  String get dashOfferSubtitle => 'Tap to see it before it expires';

  @override
  String get dashWaitingTitle => 'Waiting for orders';

  @override
  String get dashWaitingSubtitle =>
      'New orders near you will ring on this phone';

  @override
  String get dashGoOnlineTitle => 'Go online to get orders';

  @override
  String get dashGoOnlineSubtitle =>
      'Orders are only offered while you are online';

  @override
  String get dashActiveTitle => 'Active delivery';

  @override
  String get dashViewDetails => 'View details';

  @override
  String get goOnlineBlockedTitle => 'Can\'t go online yet';

  @override
  String get dsBrandName => 'AgriMore';

  @override
  String get dsBrandRole => 'DELIVERY PARTNER';

  @override
  String get dsRequired => 'required';

  @override
  String get dsOptional => '(optional)';

  @override
  String get dsLoading => 'Loading…';

  @override
  String get dsTryAgain => 'Try again';

  @override
  String get dsClose => 'Close';

  @override
  String get dsBack => 'Back';

  @override
  String get dsCancel => 'Cancel';

  @override
  String get dsSearchClear => 'Clear search';

  @override
  String get dsShowPassword => 'Show password';

  @override
  String get dsHidePassword => 'Hide password';

  @override
  String get dsStepCompleted => 'Completed';

  @override
  String get dsStepCurrent => 'Current';

  @override
  String get dsStepUpcoming => 'Upcoming';

  @override
  String get dsStepFailed => 'Needs attention';

  @override
  String dsStepOf(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String dsOtpFieldLabel(int length) {
    return 'Verification code, $length digits';
  }

  @override
  String dsFieldsNeedAttention(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Check $count fields',
      one: 'Check 1 field',
    );
    return '$_temp0';
  }

  @override
  String get dsDiscardTitle => 'Discard changes?';

  @override
  String get dsDiscardBody => 'Your unsaved changes will be lost.';

  @override
  String get dsDiscard => 'Discard';

  @override
  String get dsKeepEditing => 'Keep editing';

  @override
  String get dsExpandHint => 'Tap to expand';

  @override
  String get dsCollapseHint => 'Tap to collapse';

  @override
  String get dsNoImage => 'No photo';

  @override
  String get dsImageFailed => 'Photo unavailable';

  @override
  String dsTabPosition(int index, int count) {
    return 'Tab $index of $count';
  }

  @override
  String get dsTestDataRibbon => 'TEST DATA · Local emulator';

  @override
  String get dsUnreadDot => 'Unread';

  @override
  String get dsSaved => 'Saved';

  @override
  String get dsSubmitting => 'Submitting…';

  @override
  String get appearanceTitle => 'Appearance';

  @override
  String get appearanceSystem => 'System';

  @override
  String get appearanceLight => 'Light';

  @override
  String get appearanceDark => 'Dark';

  @override
  String get appearanceSubtitle =>
      'Match your phone or choose a theme for day and night riding';

  @override
  String get authCheckingSession => 'Checking your session…';

  @override
  String get authSigningOut => 'Signing out…';

  @override
  String get authTagline => 'Deliver farm-fresh orders in your city';

  @override
  String get authNewPartnerHeading => 'New to AgriMore Delivery?';

  @override
  String get authNewPartnerBody =>
      'Register with your vehicle and documents to start delivering.';

  @override
  String regStepProgress(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get regSaveExit => 'Cancel';

  @override
  String get regDiscardTitle => 'Leave registration?';

  @override
  String get regDiscardBody =>
      'Your progress on this screen will be discarded.';

  @override
  String get regDiscardConfirm => 'Leave';

  @override
  String get regPhotoTake => 'Take photo';

  @override
  String get regPhotoGallery => 'Choose from gallery';

  @override
  String get regPhotoRetake => 'Retake';

  @override
  String get regPhotoReplace => 'Replace';

  @override
  String get regPhotoUploaded => 'Uploaded';

  @override
  String get regPhotoUploading => 'Uploading…';

  @override
  String get regPhotoFailed => 'Upload failed';

  @override
  String get regPayoutOptionalBadge => 'Optional';

  @override
  String get regPayoutWhyTitle => 'Why add payout details?';

  @override
  String get regPayoutWhyBody =>
      'Your weekly earnings are sent every Monday to your bank account or UPI ID. You can also add or change this later.';

  @override
  String get regPayoutMethodBank => 'Bank account';

  @override
  String get regPayoutMethodUpi => 'UPI ID';

  @override
  String get regPayoutMethodSkip => 'Add later';

  @override
  String get regReviewSummaryTitle => 'Application summary';

  @override
  String get kycTimelineSubmitted => 'Application submitted';

  @override
  String get kycTimelineReview => 'Document & vehicle review';

  @override
  String get kycTimelineDecision => 'Approval decision';

  @override
  String get kycRefreshStatus => 'Refresh status';

  @override
  String get kycRefreshing => 'Checking status…';

  @override
  String get kycWhatToFix => 'What to fix';

  @override
  String get kycSuspensionDetails => 'Suspension details';

  @override
  String get kycSupportNote =>
      'Contact Agrimore support if you have questions about your account status.';

  @override
  String get dashNavHome => 'Home';

  @override
  String get dashNavDeliveries => 'Deliveries';

  @override
  String get dashNavEarnings => 'Earnings';

  @override
  String get dashNavInbox => 'Inbox';

  @override
  String get dashNavProfile => 'Profile';

  @override
  String get dashAvailabilityLabel => 'Work availability';

  @override
  String get dashGoingOnline => 'Going online…';

  @override
  String get dashGoingOffline => 'Going offline…';

  @override
  String get dashOfflineBannerTitle => 'You have no internet connection';

  @override
  String get dashOfflineBannerBody =>
      'Showing last saved data. Live offers require a connection.';

  @override
  String get dashCachedDataNote => 'Cached data · pull to refresh';

  @override
  String dashMultipleActiveWarning(int count) {
    return '$count active deliveries assigned';
  }

  @override
  String get dashMultipleActiveHint => 'Select an order below to continue';

  @override
  String get dashOpenOrder => 'Open order';

  @override
  String get dashCodLimitWarningTitle => 'COD cash limit reached';

  @override
  String dashCodLimitWarningBody(String amount) {
    return 'Settle $amount cash with the Agrimore team to receive new cash-on-delivery offers. Prepaid orders continue.';
  }

  @override
  String get locStep1Badge => 'Step 1 of 2 · Foreground & background location';

  @override
  String get locStep2Badge => 'Step 2 of 2 · Background reliability';

  @override
  String get locPurposeNearby => 'Match you with nearby pickup orders';

  @override
  String get locPurposeTracking =>
      'Share live delivery progress with the store and customer';

  @override
  String get locPurposeStop =>
      'Location sharing stops immediately when you go offline';

  @override
  String get locBatteryOemHint =>
      'On Xiaomi, Oppo, Vivo, Realme and Samsung phones, set Battery to Unrestricted and allow Autostart so your phone does not stop location while you are on a delivery.';

  @override
  String get locReducedBannerTitle => 'Background location not set to Always';

  @override
  String get locReducedBannerBody =>
      'If the app closes, location sharing may stop and take you offline.';

  @override
  String get locFixInSettings => 'Fix in Settings';

  @override
  String offerUrgentSeconds(int seconds) {
    return 'Hurry · ${seconds}s left';
  }

  @override
  String get offerAccepting => 'Accepting…';

  @override
  String get offerDeclining => 'Declining…';

  @override
  String get offerDeclineTitle => 'Decline this offer?';

  @override
  String get offerDeclineBody =>
      'This order will be offered to another delivery partner.';

  @override
  String get offerDeclineConfirm => 'Decline offer';

  @override
  String get offerKeepOrder => 'Keep viewing';

  @override
  String get offerPrepaidBadge => 'PREPAID';

  @override
  String offerCodBadge(String amount) {
    return 'COD · $amount';
  }

  @override
  String get offerPrivacyNote =>
      'Customer name, phone and full address are shown after you accept.';

  @override
  String activeOrderHeader(String number) {
    return 'Order #$number';
  }

  @override
  String get activePickupSection => 'Pickup store';

  @override
  String get activeDropSection => 'Customer drop-off';

  @override
  String get activeCallStore => 'Call store';

  @override
  String get activeCopyAddress => 'Copy address';

  @override
  String get activeAddressCopied => 'Address copied';

  @override
  String get activeInstructionsLabel => 'Delivery instructions';

  @override
  String activeCollectCashTitle(String amount) {
    return 'Collect $amount cash from customer';
  }

  @override
  String get activeCollectCashBody =>
      'Count the cash before entering the 6-digit delivery verification code.';

  @override
  String get activePrepaidTitle => 'Prepaid — do not collect cash';

  @override
  String get activePrepaidBody => 'The customer has already paid online.';

  @override
  String get activeStepUpdating => 'Updating…';

  @override
  String get activeVerifyOtpAction => 'Enter delivery OTP';

  @override
  String get routeViewMap => 'Map';

  @override
  String get routeViewList => 'Route details';

  @override
  String get routeRefresh => 'Refresh route';

  @override
  String get routeRefreshing => 'Refreshing route…';

  @override
  String get routeLastUpdated => 'Updated just now';

  @override
  String routeUpdatedMinAgo(int minutes) {
    return 'Updated $minutes min ago';
  }

  @override
  String get routeStaleTitle => 'Your location is out of date';

  @override
  String get routeStaleBodyRefreshable =>
      'Refresh your location to update the route.';

  @override
  String get routeStaleBodyNative =>
      'Location updates automatically in the background. If this continues, check your settings.';

  @override
  String get routeRefreshLocation => 'Refresh location';

  @override
  String get routeCheckSettings => 'Check settings';

  @override
  String get routeRefreshFailed =>
      'Could not refresh your location. Try again.';

  @override
  String get routeLiveGps => 'Live GPS';

  @override
  String get routeCachedBanner => 'Offline · showing last known route';

  @override
  String get routeCopyCoords => 'Copy coordinates';

  @override
  String get routeCoordsCopied => 'Coordinates copied';

  @override
  String get routeStepPickup => '1. Pickup';

  @override
  String get routeStepDrop => '2. Drop-off';

  @override
  String get waitTimerLabel => 'Waiting at store';

  @override
  String get waitTimerNote => 'Waiting time pay applies after the grace period';

  @override
  String get releaseReasonStoreClosed => 'Store is closed';

  @override
  String get releaseReasonLongWait => 'Order taking too long to prepare';

  @override
  String get releaseReasonVehicleProblem => 'Vehicle issue before pickup';

  @override
  String get releaseReasonOther => 'Other reason';

  @override
  String get releaseWarningNote =>
      'Only available before you mark Picked up. Releasing returns the order to the dispatch queue.';

  @override
  String verifyCodReminder(String amount) {
    return 'Confirm you collected $amount in cash before verifying';
  }

  @override
  String verifyAttemptsRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attempts remaining',
      one: '1 attempt remaining before temporary lock',
    );
    return '$_temp0';
  }

  @override
  String get verifyLockedTitle => 'Verification temporarily locked';

  @override
  String get verifyContactSupport => 'Contact support';

  @override
  String get deliveredEarnedLabel => 'Estimated earnings';

  @override
  String get deliveredCodRecordedLabel => 'COD cash recorded';

  @override
  String get deliveredProofSaved => 'Delivery proof photo saved';

  @override
  String get proofUploadTitle => 'Proof of delivery photo';

  @override
  String get proofUploadHint =>
      'Optional photo of the delivered package at the drop-off';

  @override
  String get proofUploading => 'Saving photo…';

  @override
  String get proofSavedBadge => 'Saved';

  @override
  String get problemNoteHint =>
      'Describe what happened so the Agrimore team can help';

  @override
  String get problemReturnToStoreHint =>
      'Return the items to the pickup store as instructed by Agrimore.';

  @override
  String get emergencyBannerNote =>
      'Calls open your phone dialer. Safety reports record an entry for the Agrimore team.';

  @override
  String get incidentNoteLabel => 'What happened? (optional)';

  @override
  String get incidentNoteHint => 'Add brief details if it is safe to do so';

  @override
  String get incidentLocationIncluded =>
      'Includes your current order and GPS fix if available';

  @override
  String get incidentLocationUnavailable =>
      'GPS fix unavailable — report will still be recorded';

  @override
  String get moneyNetRuleNote =>
      'Weekly payout = Gross delivery earnings − COD cash held';

  @override
  String get moneySettlementHistoryTitle => 'How COD cash is settled';

  @override
  String get moneySettlementHistoryBody =>
      'COD cash you collect is deducted from your Monday statement, or you can hand over cash directly to the Agrimore team.';

  @override
  String moneyOrderWaitingLine(int minutes, String amount) {
    return 'Waiting (${minutes}m): $amount';
  }

  @override
  String moneyOrderDistanceLine(String km, String amount) {
    return 'Distance ($km km): $amount';
  }

  @override
  String get statementFormulaNote =>
      'Net payout = Gross earned − COD cash offset';

  @override
  String statementCarryoverNote(String amount) {
    return 'Remaining cash ($amount) stays in your cash-in-hand balance for next week.';
  }

  @override
  String get statementHoldFixAction => 'Review payout details';

  @override
  String get payoutSingleActiveNote =>
      'Only one payout destination (bank account or UPI ID) is active per payout.';

  @override
  String get payoutMethodLabel => 'Destination type';

  @override
  String get payoutBankMethod => 'Bank account';

  @override
  String get payoutUpiMethod => 'UPI ID';

  @override
  String get payoutConfirmAccount => 'Confirm account number';

  @override
  String get payoutProblemAccountMismatch => 'Account numbers do not match';

  @override
  String get payoutReviewTitle => 'Review payout changes';

  @override
  String get payoutReviewSubtitle =>
      'Submission is not bank verification. Your current destination remains active until the Agrimore team approves this request.';

  @override
  String get payoutCurrentDestination => 'Current active destination';

  @override
  String get payoutProposedDestination =>
      'Proposed new destination (pending review)';

  @override
  String get payoutEditDetails => 'Edit details';

  @override
  String get payoutTimelineSubmitted => 'Request submitted';

  @override
  String get payoutTimelineReview => 'Agrimore team review';

  @override
  String get payoutTimelineApplied => 'Applied to future payouts';

  @override
  String get historySearchHint => 'Search by order number (e.g. ORD-104)';

  @override
  String get historyDetailTitle => 'Order details';

  @override
  String get historyTimelineTitle => 'Delivery timeline';

  @override
  String get inboxFilterAll => 'All';

  @override
  String get inboxFilterUnread => 'Unread';

  @override
  String get inboxGroupToday => 'Today';

  @override
  String get inboxGroupEarlier => 'Earlier';

  @override
  String get inboxDestinationUnavailable => 'This item is no longer available.';

  @override
  String get profileIdentitySection => 'Identity & KYC (read-only)';

  @override
  String get profileIdentityNote =>
      'Name, phone, Aadhaar and driving licence are verified by Agrimore. Contact support to request a correction.';

  @override
  String get profileContactSection => 'Contact & address';

  @override
  String get profileVehicleSection => 'Vehicle & documents';

  @override
  String get profileSupportSection => 'Help & support';

  @override
  String get profileAccountSection => 'Account actions';

  @override
  String get profileDeleteWarningTitle => 'Before you request deletion';

  @override
  String get profileDeleteWarningBody =>
      'You must have no active delivery, ₹0 COD cash in hand, and no unsettled earnings.';

  @override
  String get profileDeleteConfirmCheck =>
      'I understand that deleting my account permanently removes my rider access.';

  @override
  String get a11yRouteToggleLabel => 'Route view mode';

  @override
  String get a11yOnlineSwitchHint => 'Double-tap to toggle work availability';

  @override
  String get locDisclosureBullet1 =>
      'Match you with nearby pickup orders while you are online';

  @override
  String get locDisclosureBullet2 =>
      'Share live delivery progress with the pickup store and customer';

  @override
  String get locDisclosureBullet3 =>
      'Location sharing stops immediately when you go offline';

  @override
  String get locBackgroundStep1 =>
      'Select Permissions → Location → Allow all the time so tracking continues when your screen locks during a delivery.';

  @override
  String get locBackgroundStep2 =>
      'On Xiaomi, Oppo, Vivo, Realme and Samsung phones, set Battery to Unrestricted so your phone does not pause active deliveries.';

  @override
  String get kycBadgeActionRequired => 'Action required';

  @override
  String get kycBadgeSuspended => 'Suspended';

  @override
  String get kycBadgeUnderReview => 'Under review';

  @override
  String get vehicleBicycleSub => 'Short trips · no licence required';

  @override
  String get vehicleMotorcycleSub => 'Standard city deliveries';

  @override
  String get vehicleScooterSub => 'Gearless two-wheeler';

  @override
  String get vehicleEvSub => 'Electric two-wheeler';

  @override
  String get vehicleAutoSub => 'Three-wheeler cargo / auto';

  @override
  String get vehicleMiniTruckSub => 'Bulk & crate orders';

  @override
  String get profileAppearanceHeading => 'Appearance';

  @override
  String get profileThemeSystem => 'System';

  @override
  String get profileThemeLight => 'Light';

  @override
  String get profileThemeDark => 'Dark';
}
