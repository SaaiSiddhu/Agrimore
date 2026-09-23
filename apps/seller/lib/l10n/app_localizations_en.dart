// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'AgriMore Seller';

  @override
  String get appTagline => 'Seller workspace';

  @override
  String get authHeadline => 'Sell to farms and families across your district';

  @override
  String get authSubhead => 'Manage orders, stock and payments in one place.';

  @override
  String get authValueOrders => 'Accept orders before they\'re due';

  @override
  String get authValueStock => 'Keep stock and prices up to date';

  @override
  String get authValuePayments => 'Track every settlement to your bank';

  @override
  String get phoneLabel => 'Mobile number';

  @override
  String get phonePrefix => '+91';

  @override
  String get phoneHint => '10-digit mobile number';

  @override
  String get phoneErrorEmpty => 'Enter your mobile number';

  @override
  String get phoneErrorInvalid => 'Enter a valid 10-digit Indian mobile number';

  @override
  String get getOtpCta => 'Get OTP';

  @override
  String get sendingOtp => 'Sending OTP…';

  @override
  String get orDivider => 'or';

  @override
  String get googleCta => 'Continue with Google';

  @override
  String get googleLinkingTitle => 'Verify your mobile once';

  @override
  String googleLinkingBody(String email) {
    return '$email isn\'t linked to a seller account yet. Verify your mobile number and we\'ll link Google to it.';
  }

  @override
  String get googleLinkingCancel => 'Cancel';

  @override
  String get googleLinkedConflict =>
      'Signed in. Your Google account is already linked to another AgriMore account, so it wasn\'t added.';

  @override
  String get emailSignInLink => 'Sign in with email instead';

  @override
  String get legalPrefix => 'By continuing you agree to our';

  @override
  String get legalTerms => 'Terms';

  @override
  String get legalAnd => 'and';

  @override
  String get legalPrivacy => 'Privacy Policy';

  @override
  String get otpTitle => 'Enter the 6-digit code';

  @override
  String otpSentSms(String phone) {
    return 'Sent by SMS to $phone';
  }

  @override
  String otpSentVoice(String phone) {
    return 'You\'ll get a call on $phone with your code';
  }

  @override
  String get otpChangeNumber => 'Change';

  @override
  String otpDigitLabel(int index) {
    return 'Digit $index of 6';
  }

  @override
  String get otpVerifyCta => 'Verify and continue';

  @override
  String get otpVerifying => 'Verifying…';

  @override
  String otpResendIn(int seconds) {
    return 'Resend code in ${seconds}s';
  }

  @override
  String get otpResend => 'Resend code';

  @override
  String get otpCallInstead => 'Get a call instead';

  @override
  String get otpErrorIncomplete => 'Enter all 6 digits';

  @override
  String get testModeRibbon => 'Test mode — code filled in automatically';

  @override
  String get emailTitle => 'Sign in with email';

  @override
  String get emailSubhead =>
      'For seller accounts created by AgriMore with an email and password.';

  @override
  String get emailLabel => 'Email address';

  @override
  String get emailErrorInvalid => 'Enter a valid email address';

  @override
  String get passwordLabel => 'Password';

  @override
  String get passwordErrorEmpty => 'Enter your password';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get emailSignInCta => 'Sign in';

  @override
  String get signingIn => 'Signing in…';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get resetSheetTitle => 'Reset your password';

  @override
  String resetSheetBody(String email) {
    return 'We\'ll email a reset link to $email.';
  }

  @override
  String get resetSendCta => 'Send reset link';

  @override
  String get resetSent => 'Reset link sent. Check your inbox.';

  @override
  String get resetNeedsEmail => 'Enter your email address first';

  @override
  String get addPhoneNudge =>
      'Tip: after signing in, add your mobile number so you can sign in with OTP next time.';

  @override
  String get back => 'Back';

  @override
  String get statusTitle => 'Application under review';

  @override
  String get statusSubhead =>
      'We\'re checking your details. You\'ll get a notification when there\'s a decision.';

  @override
  String get statusStepSubmitted => 'Application submitted';

  @override
  String get statusStepReview => 'Documents and details reviewed';

  @override
  String get statusStepApproved => 'Approved — start selling';

  @override
  String get statusRefresh => 'Check status';

  @override
  String get statusRefreshing => 'Checking…';

  @override
  String get statusStillPending =>
      'Still under review. We\'ll notify you as soon as it changes.';

  @override
  String get restrictedRejectedTitle => 'Application not approved';

  @override
  String get restrictedRejectedBody =>
      'Your seller application wasn\'t approved. Contact us to find out what to change before applying again.';

  @override
  String get restrictedSuspendedTitle => 'Seller account suspended';

  @override
  String get restrictedSuspendedBody =>
      'Your listings are hidden and new orders are paused. Contact us to resolve this.';

  @override
  String get supportTitle => 'Contact AgriMore';

  @override
  String supportCall(String phone) {
    return 'Call $phone';
  }

  @override
  String supportEmail(String email) {
    return 'Email $email';
  }

  @override
  String get signOut => 'Sign out';

  @override
  String get signOutConfirmTitle => 'Sign out?';

  @override
  String get signOutConfirmBody =>
      'You\'ll need to verify your mobile number again to sign in.';

  @override
  String get cancel => 'Cancel';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get errorNetwork => 'Network is too slow right now. Please try again.';

  @override
  String get loadingAccount => 'Loading your seller account';

  @override
  String get applyTitle => 'Start selling on AgriMore';

  @override
  String get applySubhead =>
      'Tell us about your business. It takes about 5 minutes and you can stop and continue any time.';

  @override
  String get applyNeedBusiness => 'Business name and what you sell';

  @override
  String get applyNeedAddress => 'Shop address and delivery area';

  @override
  String get applyNeedDocuments => 'A photo of your ID and of your shop';

  @override
  String get applyNeedPayout => 'Bank account or UPI ID for payments';

  @override
  String get applyStartCta => 'Start application';

  @override
  String get applyResumeCta => 'Continue application';

  @override
  String get applyReopenCta => 'Fix and resubmit';

  @override
  String stepOf(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get stepBusiness => 'Business details';

  @override
  String get stepLocation => 'Location and delivery';

  @override
  String get stepDocuments => 'Documents';

  @override
  String get stepPayout => 'Payout account';

  @override
  String get stepReview => 'Review and submit';

  @override
  String get saveContinue => 'Save and continue';

  @override
  String get saving => 'Saving…';

  @override
  String get savedDraft => 'Saved. You can continue later.';

  @override
  String get saveFailed =>
      'Couldn\'t save. Check your connection and try again.';

  @override
  String get fieldOwnerName => 'Your full name';

  @override
  String get fieldShopName => 'Shop or business name';

  @override
  String get fieldCategory => 'What do you mainly sell?';

  @override
  String get fieldGstin => 'GSTIN (optional)';

  @override
  String get fieldGstinHelp => '15 characters, e.g. 33ABCDE1234F1Z5';

  @override
  String get category_vegetables => 'Vegetables';

  @override
  String get category_fruits => 'Fruits';

  @override
  String get category_grains => 'Grains and pulses';

  @override
  String get category_dairy => 'Dairy';

  @override
  String get category_seeds => 'Seeds';

  @override
  String get category_fertilisers => 'Fertilisers and inputs';

  @override
  String get category_equipment => 'Tools and equipment';

  @override
  String get category_other => 'Something else';

  @override
  String get fieldAddress => 'Shop address';

  @override
  String get fieldCity => 'City or town';

  @override
  String get fieldState => 'State';

  @override
  String get fieldPincode => 'PIN code';

  @override
  String get fieldRadius => 'Delivery radius';

  @override
  String radiusKm(int km) {
    return '$km km';
  }

  @override
  String get useCurrentLocation => 'Use my current location';

  @override
  String get locationCaptured => 'Location pinned';

  @override
  String get locationFailed =>
      'Couldn\'t get your location. You can continue without it.';

  @override
  String get documentsHelp =>
      'Clear photos help us approve you faster. Only AgriMore reviewers can see them.';

  @override
  String get doc_idProof =>
      'ID proof (Aadhaar, PAN, voter ID or driving licence)';

  @override
  String get doc_shopPhoto => 'Photo of your shop or farm';

  @override
  String get doc_gstCertificate => 'GST certificate (optional)';

  @override
  String get docTakePhoto => 'Take photo';

  @override
  String get docChoosePhoto => 'Choose from gallery';

  @override
  String get docUploaded => 'Uploaded';

  @override
  String get docUploading => 'Uploading…';

  @override
  String get docReplace => 'Replace';

  @override
  String get docUploadFailed => 'Upload failed. Try again.';

  @override
  String get payoutHelp =>
      'Your settlements are paid here. We never show these details on your public profile.';

  @override
  String get payoutBank => 'Bank account';

  @override
  String get payoutUpi => 'UPI ID';

  @override
  String get fieldAccountHolder => 'Account holder name';

  @override
  String get fieldBankName => 'Bank name';

  @override
  String get fieldAccountNumber => 'Account number';

  @override
  String get fieldAccountNumberConfirm => 'Re-enter account number';

  @override
  String get fieldIfsc => 'IFSC code';

  @override
  String get fieldUpiId => 'UPI ID';

  @override
  String get accountMismatch => 'Account numbers don\'t match';

  @override
  String get reviewHelp =>
      'Check your details. You can\'t edit them while we review your application.';

  @override
  String get reviewEdit => 'Edit';

  @override
  String reviewDocumentsCount(int count, int total) {
    return '$count of $total photos uploaded';
  }

  @override
  String get acceptTerms =>
      'I confirm these details are correct and agree to AgriMore\'s seller terms';

  @override
  String get submitCta => 'Submit application';

  @override
  String get submitting => 'Submitting…';

  @override
  String get submitInvalid =>
      'Some details need attention. We\'ve taken you to the first one.';

  @override
  String get submitFailed =>
      'Couldn\'t submit. Check your connection and try again.';

  @override
  String get errRequired => 'This is required';

  @override
  String get errGstin => 'Enter a valid 15-character GSTIN';

  @override
  String get errPincode => 'Enter a valid 6-digit PIN code';

  @override
  String get errIfsc => 'Enter a valid 11-character IFSC code';

  @override
  String get errAccount => 'Enter a valid account number (9–18 digits)';

  @override
  String get errUpi => 'Enter a valid UPI ID, e.g. name@bank';

  @override
  String get errDocument => 'Upload this photo to continue';

  @override
  String get rejectOrderTitle => 'Reject this order?';

  @override
  String get cancelOrderTitle => 'Cancel this order?';

  @override
  String get reasonPrompt => 'Tell the buyer why. This is required.';

  @override
  String get reasonOutOfStock => 'Item out of stock';

  @override
  String get reasonCannotDeliver => 'Can\'t deliver to this area';

  @override
  String get reasonPriceError => 'Price was wrong';

  @override
  String get reasonShopClosed => 'Shop is closed';

  @override
  String get reasonOther => 'Something else';

  @override
  String get reasonNoteLabel => 'Note for the buyer (optional)';

  @override
  String get rejectConsequence =>
      'The buyer is notified and the stock goes back to your listings.';

  @override
  String get rejectConsequencePrepaid =>
      'The buyer is notified, the stock goes back to your listings, and the payment is marked for refund.';

  @override
  String get rejectOrderCta => 'Reject order';

  @override
  String get cancelOrderCta => 'Cancel order';

  @override
  String get keepOrder => 'Keep order';

  @override
  String get orderAccepted => 'Order accepted';

  @override
  String get orderPacking => 'Packing started';

  @override
  String get orderReady => 'Marked ready for pickup';

  @override
  String get orderRejected => 'Order rejected';

  @override
  String get orderCancelled => 'Order cancelled';

  @override
  String get orderActionFailed =>
      'Couldn\'t update the order. Please try again.';

  @override
  String get orderAlreadyMoved =>
      'This order was already updated. Pull to refresh.';

  @override
  String get orderUnpaid => 'Payment for this order isn\'t complete yet.';

  @override
  String get chatReady => 'Chat with the buyer is ready';

  @override
  String get taxSectionTitle => 'Tax details (for invoices)';

  @override
  String get taxSectionHelp =>
      'Optional. Add them if you\'re GST-registered so your invoices show the right tax.';

  @override
  String get fieldHsn => 'HSN code';

  @override
  String get fieldGstRate => 'GST rate';

  @override
  String get gstNotDeclared => 'Not declared';

  @override
  String gstRatePercent(int rate) {
    return '$rate%';
  }

  @override
  String get errHsn => 'HSN codes are 4, 6 or 8 digits';

  @override
  String get saveDraftCta => 'Save as draft';

  @override
  String get draftSaved => 'Saved as a draft. Publish it when you\'re ready.';

  @override
  String get draftNeedsName => 'Add a product name to save a draft';

  @override
  String get filterAll => 'All';

  @override
  String get filterActive => 'Active';

  @override
  String get filterDraft => 'Drafts';

  @override
  String get filterOutOfStock => 'Out of stock';

  @override
  String get filterInactive => 'Inactive';

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String get bulkActivate => 'Publish';

  @override
  String get bulkDeactivate => 'Hide';

  @override
  String get bulkClear => 'Clear selection';

  @override
  String bulkDone(int count) {
    return '$count products updated';
  }

  @override
  String get bulkFailed => 'Couldn\'t update the products. Please try again.';

  @override
  String get draftBadge => 'Draft';

  @override
  String filterWithCount(String label, String count) {
    return '$label · $count';
  }

  @override
  String get invoiceTitle => 'Invoice';

  @override
  String get docTaxInvoice => 'Tax Invoice';

  @override
  String get docBillOfSupply => 'Bill of Supply';

  @override
  String get billOfSupplyNote =>
      'Issued as a bill of supply: no GST is charged separately. Add your GSTIN and each product\'s HSN code and GST rate to issue tax invoices.';

  @override
  String get invoiceLoadFailed =>
      'Couldn\'t load this invoice. Please try again.';

  @override
  String get invoiceIssueFailed =>
      'Couldn\'t create the invoice. Please try again.';

  @override
  String get copyInvoiceNumber => 'Copy invoice number';

  @override
  String invoiceIssued(String when) {
    return 'Issued $when';
  }

  @override
  String invoiceForOrder(String number) {
    return 'For order $number';
  }

  @override
  String get invoiceFrom => 'From';

  @override
  String get invoiceTo => 'Bill to';

  @override
  String invoiceGstin(String gstin) {
    return 'GSTIN $gstin';
  }

  @override
  String invoiceLineQty(String qty, String price) {
    return '$qty × $price';
  }

  @override
  String invoiceLineTax(String hsn, String rate) {
    return 'HSN $hsn · GST $rate%';
  }

  @override
  String get invoiceSubtotal => 'Subtotal';

  @override
  String get invoiceDiscount => 'Discount';

  @override
  String get invoiceDelivery => 'Delivery';

  @override
  String get invoiceCgst => 'CGST (included)';

  @override
  String get invoiceSgst => 'SGST (included)';

  @override
  String get invoiceIgst => 'IGST (included)';

  @override
  String get invoiceTotal => 'Total';

  @override
  String get invoiceTaxIncluded => 'Prices include GST.';

  @override
  String get generateInvoice => 'Generate invoice';

  @override
  String get generatingInvoice => 'Generating…';

  @override
  String get viewInvoice => 'View invoice';

  @override
  String get paymentsTitle => 'Payments';

  @override
  String get paymentsLoadFailed =>
      'Couldn\'t load your payments. Check your connection and open this tab again.';

  @override
  String get paymentsPending => 'To be paid';

  @override
  String get paymentsPaid30d => 'Paid · last 30 days';

  @override
  String get paymentsPaidAll => 'Paid · all time';

  @override
  String get paymentsHistory => 'Settlements';

  @override
  String get paymentsEmpty =>
      'No settlements yet. You\'ll see one here for every delivered order.';

  @override
  String paymentsForOrder(String number) {
    return 'Order $number';
  }

  @override
  String get payoutPaid => 'Paid';

  @override
  String get payoutPending => 'Pending';

  @override
  String get payoutAccountTitle => 'Payout account';

  @override
  String get payoutAccountMissing => 'No payout account on file';

  @override
  String get payoutAccountMissingHelp =>
      'Contact AgriMore to add your bank account or UPI ID before your first settlement.';

  @override
  String payoutAccountUpi(String upi) {
    return 'UPI · $upi';
  }

  @override
  String payoutAccountBank(String bank, String account) {
    return '$bank · $account';
  }

  @override
  String get settlementCreated => 'Order delivered — settlement created';

  @override
  String get settlementPaid => 'Paid to your account';

  @override
  String get settlementGross => 'Order value';

  @override
  String get settlementCommission => 'AgriMore commission';

  @override
  String get settlementNet => 'You receive';

  @override
  String get settlementReference => 'Payment reference';

  @override
  String get quotesTitle => 'Quotes';

  @override
  String get quotesTabNeedsResponse => 'Needs response';

  @override
  String get quotesTabNegotiating => 'Negotiating';

  @override
  String get quotesTabAccepted => 'Accepted';

  @override
  String get quotesTabClosed => 'Closed';

  @override
  String quotesTabWithCount(String label, int count) {
    return '$label · $count';
  }

  @override
  String get quotesLoadFailed =>
      'Couldn\'t load your quotes. Check your connection and open this screen again.';

  @override
  String get quotesEmptyNeedsResponse =>
      'You\'re all caught up. New quote requests from business buyers appear here.';

  @override
  String get quotesEmptyOther => 'Nothing here yet.';

  @override
  String get quoteUnknownProduct => 'Product';

  @override
  String get quoteUnknownBuyer => 'Business buyer';

  @override
  String quoteQtyAtPrice(String qty, String price) {
    return '$qty × $price';
  }

  @override
  String get quoteNoPriceYet => 'No price proposed — send your offer';

  @override
  String quoteExpiresIn(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Expires in $days days',
      one: 'Expires in 1 day',
    );
    return '$_temp0';
  }

  @override
  String get quoteExpired => 'Offer expired';

  @override
  String get quoteYourTurn => 'Your turn';

  @override
  String get quoteWaitingBuyer => 'Waiting for buyer';

  @override
  String get quoteStatusAccepted => 'Accepted';

  @override
  String get quoteStatusOrdered => 'Order placed';

  @override
  String get quoteStatusDeclined => 'Declined';

  @override
  String get quoteDetailTitle => 'Quote';

  @override
  String get quoteNotFound => 'This quote is no longer available.';

  @override
  String quoteRequested(String date) {
    return 'Requested $date';
  }

  @override
  String quoteListedB2b(String price) {
    return 'Your B2B price $price';
  }

  @override
  String quoteMoq(String qty) {
    return 'Min. order $qty';
  }

  @override
  String get quoteCurrentOffer => 'Offer on the table';

  @override
  String get quoteAgreedTerms => 'Last offer';

  @override
  String quoteVsListedBelow(String pct) {
    return '$pct below your B2B price';
  }

  @override
  String quoteVsListedAbove(String pct) {
    return '$pct above your B2B price';
  }

  @override
  String get quoteVsListedSame => 'Same as your B2B price';

  @override
  String get quoteHistoryTitle => 'Negotiation';

  @override
  String get quoteByBuyer => 'Buyer';

  @override
  String get quoteByYou => 'You';

  @override
  String get quoteActionCreate => 'Requested a quote';

  @override
  String get quoteActionOffer => 'Offered';

  @override
  String get quoteActionAccept => 'Accepted';

  @override
  String get quoteActionReject => 'Declined';

  @override
  String get quoteCounter => 'Counter';

  @override
  String get quoteAccept => 'Accept';

  @override
  String get quoteDecline => 'Decline';

  @override
  String get quoteAcceptTitle => 'Accept this offer?';

  @override
  String quoteAcceptBody(String qty, String price, String total) {
    return '$qty × $price = $total. The buyer can then place the order at this price. This can\'t be undone.';
  }

  @override
  String get quoteAcceptExpiredHint =>
      'This offer has expired, so it can\'t be accepted. Send a counter-offer with a new validity instead.';

  @override
  String quoteAcceptedBanner(String price, String qty) {
    return 'Accepted at $price × $qty. The buyer can now place the order.';
  }

  @override
  String get quoteOrderedBanner =>
      'The buyer has placed an order for this quote.';

  @override
  String get quoteViewOrder => 'View order';

  @override
  String get quoteDeclinedBanner => 'This quote was declined.';

  @override
  String get quoteWaitingBanner =>
      'Waiting for the buyer to respond to your offer.';

  @override
  String get quoteSent => 'Offer sent';

  @override
  String get quoteAcceptedToast => 'Quote accepted';

  @override
  String get quoteDeclinedToast => 'Quote declined';

  @override
  String get quoteErrorExpired =>
      'This offer has expired — send a counter-offer instead.';

  @override
  String get quoteErrorNotYourTurn =>
      'The buyer has already responded. The latest offer is shown now.';

  @override
  String get quoteErrorClosed => 'This quote is already closed.';

  @override
  String get quoteErrorGeneric =>
      'Couldn\'t update this quote. Check your connection and try again.';

  @override
  String get counterTitle => 'Counter-offer';

  @override
  String get counterPriceLabel => 'Price per unit (₹)';

  @override
  String get counterQtyLabel => 'Quantity';

  @override
  String get counterPriceInvalid => 'Enter a price above ₹0';

  @override
  String get counterQtyInvalid => 'Enter a whole number above 0';

  @override
  String counterBelowMoq(String moq) {
    return 'Below your minimum order of $moq';
  }

  @override
  String get counterValidityLabel => 'Offer valid for';

  @override
  String counterValidityDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get counterNoteLabel => 'Note to the buyer (optional)';

  @override
  String get counterTotal => 'Total';

  @override
  String get counterSend => 'Send offer';

  @override
  String get declineTitle => 'Decline quote';

  @override
  String get declinePrompt => 'Tell the buyer why';

  @override
  String get declineReasonPriceTooLow => 'Price is too low';

  @override
  String get declineReasonOutOfStock => 'Out of stock';

  @override
  String get declineReasonQuantity => 'Can\'t supply this quantity';

  @override
  String get declineReasonCannotDeliver => 'Can\'t deliver to the buyer';

  @override
  String get declineReasonOther => 'Other';

  @override
  String get declineNoteLabel => 'Add a note (optional)';

  @override
  String get declineConsequence =>
      'The buyer sees your reason. They can send a new quote request later.';

  @override
  String get declineCta => 'Decline quote';

  @override
  String get declineKeep => 'Keep negotiating';

  @override
  String quoteHistoryHeader(String who, String action) {
    return '$who · $action';
  }

  @override
  String get homeTitle => 'Home';

  @override
  String get homeGreetingMorning => 'Good morning';

  @override
  String get homeGreetingAfternoon => 'Good afternoon';

  @override
  String get homeGreetingEvening => 'Good evening';

  @override
  String get homeNeedsYou => 'Needs you now';

  @override
  String get homeAllCaughtUp => 'You\'re all caught up';

  @override
  String get homeAllCaughtUpBody =>
      'New orders, quotes and stock alerts will show up here.';

  @override
  String homeOrdersToAccept(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count orders to accept',
      one: '1 order to accept',
    );
    return '$_temp0';
  }

  @override
  String homeOldestWaiting(String time) {
    return 'Oldest placed $time';
  }

  @override
  String homeQuotesToAnswer(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count quotes to answer',
      one: '1 quote to answer',
    );
    return '$_temp0';
  }

  @override
  String homeQuotesExpiringSoon(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count expire within a day',
      one: '1 expires within a day',
    );
    return '$_temp0';
  }

  @override
  String homeOutOfStock(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count products out of stock',
      one: '1 product out of stock',
    );
    return '$_temp0';
  }

  @override
  String homeLowStock(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count products low on stock',
      one: '1 product low on stock',
    );
    return '$_temp0';
  }

  @override
  String get homePerformance => 'Performance';

  @override
  String get periodToday => 'Today';

  @override
  String get period7d => '7 days';

  @override
  String get period30d => '30 days';

  @override
  String get homeStatsFailed =>
      'Couldn\'t load your numbers. Check your connection and reopen Home.';

  @override
  String get kpiSales => 'Sales';

  @override
  String get kpiOrders => 'Orders';

  @override
  String get kpiAov => 'Avg. order';

  @override
  String kpiUpVsPrevious(String pct) {
    return '$pct up on the previous period';
  }

  @override
  String kpiDownVsPrevious(String pct) {
    return '$pct down on the previous period';
  }

  @override
  String get kpiNoComparison => 'Nothing to compare with yet';

  @override
  String get homeNextSettlement => 'To be paid to you';

  @override
  String get homeQuickActions => 'Quick actions';

  @override
  String get homeAddProduct => 'Add product';

  @override
  String kpiOrdersMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more than before',
      one: '1 more than before',
    );
    return '$_temp0';
  }

  @override
  String kpiOrdersFewer(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fewer than before',
      one: '1 fewer than before',
    );
    return '$_temp0';
  }

  @override
  String get kpiOrdersSame => 'Same as before';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String notificationsUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Notifications, $count unread',
      one: 'Notifications, 1 unread',
    );
    return '$_temp0';
  }

  @override
  String get notificationsAll => 'All';

  @override
  String get notificationsOrders => 'Orders';

  @override
  String get notificationsQuotes => 'Quotes';

  @override
  String get notificationsPayments => 'Payments';

  @override
  String get notificationsAccount => 'Account';

  @override
  String get notificationsToday => 'Today';

  @override
  String get notificationsEarlier => 'Earlier';

  @override
  String get notificationsMarkAllRead => 'Mark all read';

  @override
  String get notificationsMarkRead => 'Mark read';

  @override
  String get notificationsUnreadLabel => 'Unread';

  @override
  String get notificationsEmpty =>
      'No notifications yet. New orders, quotes and payments appear here.';

  @override
  String get notificationsLoadFailed =>
      'Couldn\'t load notifications. Check your connection and open this screen again.';

  @override
  String get notificationsActionFailed =>
      'Couldn\'t update your notifications. Try again.';

  @override
  String get searchHint => 'Search orders, products, quotes';

  @override
  String get searchClear => 'Clear search';

  @override
  String get searchPrompt =>
      'Type at least 2 characters — an order number, customer, product or buyer.';

  @override
  String searchNoResults(String query) {
    return 'Nothing matches “$query”.';
  }

  @override
  String searchGroup(String title, int count) {
    return '$title · $count';
  }

  @override
  String searchOpenOrder(String number) {
    return 'Open order $number';
  }

  @override
  String get searchProducts => 'Products';

  @override
  String searchStock(String stock) {
    return '$stock in stock';
  }

  @override
  String get homeSearch => 'Search';

  @override
  String searchOrderLine(String customer, String date) {
    return '$customer · $date';
  }

  @override
  String get storefrontTitle => 'Storefront';

  @override
  String get storefrontMenu => 'Storefront';

  @override
  String get storefrontMenuSubtitle =>
      'Cover, logo, description and highlights';

  @override
  String get storefrontPreview => 'Preview';

  @override
  String get storefrontPreviewTitle => 'How buyers see your store';

  @override
  String get storefrontLoadFailed =>
      'Couldn\'t load your storefront. Check your connection and open this screen again.';

  @override
  String get storefrontSaveFailed =>
      'Couldn\'t save. Check your connection and try again.';

  @override
  String get storefrontCover => 'Cover photo';

  @override
  String get storefrontAddCover => 'Add a cover photo';

  @override
  String get storefrontChangeCover => 'Change cover photo';

  @override
  String get storefrontAddLogo => 'Add a logo';

  @override
  String get storefrontChangeLogo => 'Change logo';

  @override
  String get storefrontLogoHint =>
      'A square logo works best. It appears on your storefront and next to your products.';

  @override
  String get storefrontName => 'Shop name';

  @override
  String get storefrontNameRequired => 'Enter your shop name';

  @override
  String get storefrontDescription => 'About your shop';

  @override
  String storefrontHighlights(int max) {
    return 'Highlights (up to $max)';
  }

  @override
  String get storefrontAddHighlight => 'Add a highlight';

  @override
  String get storefrontHighlightHint => 'e.g. Farm fresh, Same-day dispatch';

  @override
  String storefrontRemoveHighlight(String highlight) {
    return 'Remove $highlight';
  }

  @override
  String get storefrontSave => 'Save storefront';
}
