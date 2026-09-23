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

  @override
  String get profileSaveFailed =>
      'Couldn\'t save your profile. Check your connection and try again.';

  @override
  String get reviewsTitle => 'Reviews';

  @override
  String get reviewsMenu => 'Reviews';

  @override
  String get reviewsMenuSubtitle => 'Ratings and replies';

  @override
  String get reviewsLoadFailed =>
      'Couldn\'t load your reviews. Check your connection and open this screen again.';

  @override
  String reviewsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reviews',
      one: '1 review',
      zero: 'No reviews yet',
    );
    return '$_temp0';
  }

  @override
  String reviewsBarLabel(int stars, int count) {
    return '$stars stars: $count';
  }

  @override
  String reviewsRatingLabel(int stars) {
    return 'Rated $stars out of 5';
  }

  @override
  String get reviewsAll => 'All';

  @override
  String reviewsUnanswered(int count) {
    return 'Unanswered · $count';
  }

  @override
  String reviewsStars(int stars) {
    return '$stars★';
  }

  @override
  String get reviewsEmpty =>
      'No reviews yet. Buyers can review a product after it is delivered.';

  @override
  String get reviewsNoneMatch => 'No reviews match this filter.';

  @override
  String get reviewsAnonymous => 'A buyer';

  @override
  String reviewsByLine(String name, String date) {
    return '$name · $date';
  }

  @override
  String get reviewsVerified => 'Verified purchase';

  @override
  String get reviewsYourReply => 'Your reply';

  @override
  String get reviewsReply => 'Reply';

  @override
  String get reviewsEditReply => 'Edit reply';

  @override
  String get reviewsReplyTitle => 'Reply publicly';

  @override
  String get reviewsReplyHint =>
      'Buyers see your reply under the review. You can edit it for 24 hours.';

  @override
  String get reviewsReplyLabel => 'Your reply';

  @override
  String get reviewsReplySend => 'Post reply';

  @override
  String get reviewReplySent => 'Reply posted';

  @override
  String get reviewReplyLocked =>
      'This reply can no longer be edited — replies can be changed for 24 hours.';

  @override
  String get reviewReplyFailed =>
      'Couldn\'t post your reply. Check your connection and try again.';

  @override
  String get prefTitle => 'Notifications';

  @override
  String get prefIntro =>
      'Choose which alerts reach your phone. Everything still appears in your in-app notifications.';

  @override
  String get prefOrders => 'New orders and order updates';

  @override
  String get prefQuotes => 'Quote requests and offers';

  @override
  String get prefPayments => 'Payments';

  @override
  String get prefStock => 'Stock alerts';

  @override
  String get prefReviews => 'Reviews';

  @override
  String get prefAnnouncements => 'AgriMore announcements';

  @override
  String get prefQuietHours => 'Quiet hours';

  @override
  String get prefQuietHoursHint => 'No alerts on your phone during these hours';

  @override
  String get prefQuietFrom => 'From';

  @override
  String get prefQuietUntil => 'Until';

  @override
  String get prefSaveFailed =>
      'Couldn\'t save your choice. Check your connection and try again.';

  @override
  String get helpTitle => 'Help & support';

  @override
  String get helpSearch => 'Search help';

  @override
  String get helpFaqTitle => 'Common questions';

  @override
  String get helpNoMatch => 'No answers match. Contact us below.';

  @override
  String get helpContactTitle => 'Contact AgriMore';

  @override
  String get faqPayoutQ => 'When do I get paid?';

  @override
  String get faqPayoutA =>
      'A settlement is created when an order is delivered. AgriMore pays it to your bank account or UPI and shows the payment reference under Payments.';

  @override
  String get faqOrderQ => 'How fast should I accept an order?';

  @override
  String get faqOrderA =>
      'Accept or reject new orders as soon as you can — buyers see the status change immediately. Rejecting needs a reason, and prepaid buyers are refunded.';

  @override
  String get faqQuoteQ => 'How do quotes work?';

  @override
  String get faqQuoteA =>
      'Business buyers request a price for a quantity. Counter with your price and how long it is valid, accept their offer, or decline with a reason. Once accepted, the buyer can place the order at that price.';

  @override
  String get faqInvoiceQ => 'Why is my invoice a bill of supply?';

  @override
  String get faqInvoiceA =>
      'A tax invoice needs your GSTIN and an HSN code and GST rate on every product. Add them in Business details and in each product\'s tax section.';

  @override
  String get faqReviewQ => 'Can I reply to a review?';

  @override
  String get faqReviewA =>
      'Yes — one public reply per review, which you can edit for 24 hours. Ratings are calculated by AgriMore and cannot be changed.';

  @override
  String get faqStorefrontQ => 'How do I change my storefront?';

  @override
  String get faqStorefrontA =>
      'Go to Account → Storefront to change your cover photo, logo, description and highlights, and preview how buyers see it.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsMenuSubtitle => 'Theme, notifications, help';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsLicences => 'Open-source licences';

  @override
  String get navHome => 'Home';

  @override
  String get navOrders => 'Orders';

  @override
  String get navCatalogue => 'Catalogue';

  @override
  String get navAccount => 'Account';

  @override
  String navOrdersPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Orders, $count waiting',
      one: 'Orders, 1 waiting',
    );
    return '$_temp0';
  }

  @override
  String get accountTitle => 'Account';

  @override
  String get accountLoadFailed =>
      'Couldn\'t load your account details. Pull down to try again.';

  @override
  String get accountNoRatings => 'No ratings yet';

  @override
  String accountRating(String rating, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reviews',
      one: '1 review',
    );
    return '$rating · $_temp0';
  }

  @override
  String get accountProducts => 'Products';

  @override
  String get accountDelivered => 'Delivered';

  @override
  String get accountSectionBusiness => 'Business';

  @override
  String get accountSectionSelling => 'Selling & money';

  @override
  String get accountSectionAi => 'AI assistant';

  @override
  String get accountSectionApp => 'App';

  @override
  String get accountBusinessDetails => 'Business details';

  @override
  String get accountBusinessDetailsHint => 'Name, GSTIN, location, hours';

  @override
  String get accountDeliveryFee => 'Delivery fee';

  @override
  String get accountPayoutHint => 'Where your settlements are paid';

  @override
  String get accountPayoutUnavailable =>
      'We couldn\'t load your payout account right now. Reopen this screen, or contact support if it keeps happening.';

  @override
  String get accountPayoutChangeHint =>
      'To change your payout account, contact AgriMore support.';

  @override
  String accountIfsc(String ifsc) {
    return 'IFSC $ifsc';
  }

  @override
  String get accountAiAssistant => 'Ask AI about your business';

  @override
  String get accountAiAssistantHint => 'Sales, products and orders';

  @override
  String get accountAiConnect => 'Connect AI';

  @override
  String get accountAiConnectHint => 'Use your own ChatGPT or Gemini key';

  @override
  String get accountLegal => 'Seller policies';

  @override
  String get legalAccurate =>
      'Keep product details, prices and stock accurate.';

  @override
  String get legalPackOnTime => 'Accept and pack orders on time.';

  @override
  String get legalPayouts =>
      'Settlements are paid for delivered orders, after AgriMore\'s commission.';

  @override
  String get accountSignOut => 'Sign out';

  @override
  String get accountSignOutTitle => 'Sign out?';

  @override
  String get accountSignOutBody =>
      'You\'ll need your phone number to sign in again.';

  @override
  String get accountSaved => 'Business details saved';

  @override
  String get accountBusinessName => 'Business name';

  @override
  String get accountBusinessNameRequired => 'Enter your business name';

  @override
  String get accountPhone => 'Business phone';

  @override
  String get accountGstin => 'GSTIN (optional)';

  @override
  String get accountGstinHelp => 'Needed for tax invoices';

  @override
  String get accountCity => 'City';

  @override
  String get accountState => 'State';

  @override
  String get accountOpens => 'Opens';

  @override
  String get accountCloses => 'Closes';

  @override
  String get accountRadius => 'Delivery radius (km)';

  @override
  String accountRadiusInvalid(int max) {
    return 'Enter a whole number from 1 to $max';
  }

  @override
  String get accountSave => 'Save';

  @override
  String get stageToAccept => 'To accept';

  @override
  String get stagePacking => 'Packing';

  @override
  String get stageReady => 'Ready for pickup';

  @override
  String get stageOutForDelivery => 'Out for delivery';

  @override
  String get stageDelivered => 'Delivered';

  @override
  String get stageCancelled => 'Cancelled';

  @override
  String get stageOther => 'Other';

  @override
  String get ordersSearchHint => 'Order number, customer or product';

  @override
  String get ordersLoadFailed =>
      'Couldn\'t load your orders. Check your connection and try again.';

  @override
  String get ordersEmpty =>
      'No orders yet. New orders appear here the moment a buyer places them.';

  @override
  String get ordersNoneMatch => 'No orders match.';

  @override
  String get ordersCustomer => 'Customer';

  @override
  String ordersItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get ordersPrepaid => 'Prepaid';

  @override
  String get ordersCod => 'Cash on delivery';

  @override
  String get stageToPack => 'To pack';

  @override
  String get stepPlaced => 'Placed';

  @override
  String get stepAccepted => 'Accepted';

  @override
  String get stepPacking => 'Packing';

  @override
  String get stepReady => 'Ready for pickup';

  @override
  String get orderCall => 'Call customer';

  @override
  String get orderChat => 'Message customer';

  @override
  String get orderCustomer => 'Customer';

  @override
  String get orderName => 'Name';

  @override
  String get orderAddress => 'Deliver to';

  @override
  String get orderNoAddress => 'No address provided';

  @override
  String get orderSlot => 'Delivery slot';

  @override
  String get orderNote => 'Buyer\'s note';

  @override
  String get orderPayment => 'Payment';

  @override
  String get orderTax => 'Tax';

  @override
  String get orderReject => 'Reject';

  @override
  String get orderCancel => 'Cancel order';

  @override
  String get orderAccept => 'Accept order';

  @override
  String get orderStartPacking => 'Start packing';

  @override
  String get orderMarkReady => 'Mark ready for pickup';

  @override
  String homeOrdersToPack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count accepted orders to pack',
      one: '1 accepted order to pack',
    );
    return '$_temp0';
  }

  @override
  String get productNewPost => 'New post';

  @override
  String get productSearchHint => 'Search your products';

  @override
  String get productsLoadFailed =>
      'Couldn\'t load your products. Check your connection and try again.';

  @override
  String get productsEmpty =>
      'No products yet. Add your first product to start selling.';

  @override
  String get productsNoneMatch => 'No products match.';

  @override
  String get productOutOfStock => 'Out of stock';

  @override
  String productLowStock(String stock) {
    return 'Only $stock left';
  }

  @override
  String get productLive => 'Visible to buyers';

  @override
  String get productHidden => 'Hidden from buyers';

  @override
  String get productStock => 'Stock';

  @override
  String get productEdit => 'Edit';

  @override
  String get productDelete => 'Delete';

  @override
  String get productDeleteTitle => 'Delete this product?';

  @override
  String productDeleteBody(String name) {
    return '“$name” will be removed from your catalogue. This can\'t be undone.';
  }

  @override
  String get productDeleted => 'Product deleted';

  @override
  String get productStockTitle => 'Update stock';

  @override
  String get productStockLabel => 'Units in stock';

  @override
  String get productStockSaved => 'Stock updated';

  @override
  String get productActionFailed =>
      'Couldn\'t update this product. Check your connection and try again.';

  @override
  String get editorNewTitle => 'Add product';

  @override
  String get editorEditTitle => 'Edit product';

  @override
  String get editorAddPhoto => 'Add a product photo';

  @override
  String get editorChangePhoto => 'Change photo';

  @override
  String get editorSeparator => ' · ';

  @override
  String get editorName => 'Product name';

  @override
  String get editorDescription => 'Description';

  @override
  String get editorDescriptionHint =>
      'What it is, quantity, quality, how it\'s packed';

  @override
  String get editorSalePrice => 'Selling price (₹)';

  @override
  String get editorMrp => 'MRP (₹, optional)';

  @override
  String get editorStock => 'Units in stock';

  @override
  String get editorLowStock => 'Low-stock alert at';

  @override
  String get editorLowStockHelp => 'You\'ll be alerted below this many units';

  @override
  String get editorCategory => 'Category';

  @override
  String get editorCategoryHint => 'e.g. Vegetables';

  @override
  String get editorRequired => 'Required';

  @override
  String get editorCenterPricing => 'Centre / area pricing';

  @override
  String get editorCenter => 'Centre';

  @override
  String get editorLoadingCenters => 'Loading centres…';

  @override
  String get editorPriceManual => 'Manual price';

  @override
  String get editorPriceArea => 'Area price';

  @override
  String get editorPriceDefault => 'Default price';

  @override
  String get editorPriceCurrent => 'Current';

  @override
  String editorPriceChip(String label, String price) {
    return '$label: $price';
  }

  @override
  String get editorNoValue => '—';

  @override
  String get editorResetPrice => 'Use the mapped price';

  @override
  String get editorCoverage => 'Delivery coverage';

  @override
  String get editorCoverageHint =>
      'The whole state by default. Use a radius for local delivery.';

  @override
  String get editorCoverageState => 'Whole state';

  @override
  String get editorCoverageDistrict => 'District';

  @override
  String get editorCoverageRadius => 'Radius';

  @override
  String get editorLatitude => 'Latitude';

  @override
  String get editorLongitude => 'Longitude';

  @override
  String get editorUseLocation => 'Use my current location';

  @override
  String get editorDetecting => 'Detecting…';

  @override
  String editorRadiusValue(int km) {
    return 'Radius: $km km';
  }

  @override
  String get editorB2b => 'Wholesale (B2B)';

  @override
  String get editorB2bHint =>
      'Offer a bulk price with a minimum order quantity.';

  @override
  String get editorB2bPrice => 'B2B price (₹)';

  @override
  String get editorB2bMoq => 'Minimum order quantity';

  @override
  String get editorB2bRule => 'Must be lower than your selling price.';

  @override
  String get editorUpdate => 'Update product';

  @override
  String get editorSave => 'Save product';

  @override
  String get editorSaving => 'Saving…';

  @override
  String get editorUpdated => 'Product updated';

  @override
  String get editorAdded =>
      'Product added. It goes live once AgriMore approves it.';

  @override
  String get editorSaveFailed =>
      'Couldn\'t save this product. Check your connection and try again.';

  @override
  String get editorUploadFailed => 'Couldn\'t upload the photo. Try again.';

  @override
  String get editorPhotoFailed => 'Couldn\'t open that photo. Try another one.';

  @override
  String get editorNeedDistrict => 'Choose a delivery district.';

  @override
  String get editorNeedCoordinates =>
      'Enter a latitude and longitude for radius delivery.';

  @override
  String get editorNeedB2bPrice => 'Enter a valid B2B price.';

  @override
  String editorB2bTooHigh(String b2b, String sale) {
    return 'The B2B price ($b2b) must be lower than the selling price ($sale).';
  }

  @override
  String get editorNeedMoq => 'Enter a valid minimum order quantity.';

  @override
  String get editorLocationOff =>
      'Turn on location services to use your current location.';

  @override
  String get editorLocationDenied => 'Location permission was denied.';

  @override
  String get editorLocationFailed => 'Couldn\'t find your current location.';

  @override
  String get aiTitle => 'AI assistant';

  @override
  String get aiWebOnly =>
      'AI assistant activation is available on the AgriMore seller website (agrimore.in). The app doesn\'t process this payment.';

  @override
  String get aiActivateTitle => 'Activate your AI assistant';

  @override
  String get aiActivateBody =>
      'Connect your own ChatGPT or Gemini API key for sales analysis, pricing insights and business questions.';

  @override
  String get aiActivateCta => 'Activate — ₹50';

  @override
  String get aiPaymentReceived => 'Payment received';

  @override
  String get aiConnectHint =>
      'Now add your AI provider details to finish connecting.';

  @override
  String get aiProvider => 'Provider';

  @override
  String get aiProviderGemini => 'Google Gemini';

  @override
  String get aiProviderChatgpt => 'ChatGPT (OpenAI)';

  @override
  String get aiApiKey => 'API key';

  @override
  String get aiApiKeyHint => 'Paste your API key';

  @override
  String get aiConnect => 'Connect';

  @override
  String get aiConnected => 'AI assistant connected';

  @override
  String get aiDisconnect => 'Disconnect';

  @override
  String get aiDisconnectTitle => 'Disconnect the AI assistant?';

  @override
  String get aiDisconnectBody =>
      'Your API key is removed. You can connect again later.';

  @override
  String get aiMoneyTaken =>
      'We received your payment but couldn\'t confirm it just now. Try connecting again — you won\'t be charged twice for the same payment.';

  @override
  String aiPaymentReference(String id) {
    return 'Payment reference: $id';
  }

  @override
  String get aiRetryConnect => 'Try connecting again';

  @override
  String get aiPreparingPayment => 'Preparing payment…';

  @override
  String get aiOpeningPayment => 'Opening payment…';

  @override
  String get aiVerifyingPayment => 'Verifying payment…';

  @override
  String get aiPleaseWait => 'Please wait…';

  @override
  String get aiSignInAgain => 'Please sign in again and retry.';

  @override
  String get aiStartFailed => 'Couldn\'t start the payment. Try again.';

  @override
  String get aiConnectFailed =>
      'Couldn\'t connect. Check your API key and try again.';

  @override
  String get aiDisconnectFailed => 'Couldn\'t disconnect. Try again.';

  @override
  String get aiConnectTitle => 'Connect your AI assistant';

  @override
  String get aiConnectBody =>
      'Connect your own ChatGPT or Gemini key to ask about your products and orders.';

  @override
  String get aiConnectNow => 'Connect now';

  @override
  String get aiInputHint => 'Ask about your sales, products or orders';

  @override
  String get aiSend => 'Send';

  @override
  String get aiThinking => 'Thinking';

  @override
  String get aiPromptRestock => 'Which products should I restock?';

  @override
  String get aiPromptBestSellers => 'What sold best this week?';

  @override
  String get aiPromptPricing => 'Are any of my prices out of line?';

  @override
  String get feeIntro => 'Choose how you charge customers for delivery.';

  @override
  String get feeFlat => 'Flat fee';

  @override
  String get feeSlab => 'By order value';

  @override
  String get feeAmount => 'Delivery fee (₹)';

  @override
  String get feeFlatHelp => 'Charged on every order, whatever its value';

  @override
  String get feeSlabRule =>
      'One tier must start at a minimum order value of ₹0.';

  @override
  String get feeMinOrder => 'Min. order (₹)';

  @override
  String get feeSlabFee => 'Fee (₹)';

  @override
  String get feeRemoveSlab => 'Remove this tier';

  @override
  String get feeAddSlab => 'Add tier';

  @override
  String get feeSaved => 'Delivery fee updated';

  @override
  String get feeSaveFailed => 'Couldn\'t save your delivery fee. Try again.';

  @override
  String get feeDefault => 'Using default pricing';

  @override
  String feeSummaryFlat(String amount) {
    return 'Flat $amount';
  }

  @override
  String feeSummarySlab(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'By order value · $count tiers',
      one: 'By order value · 1 tier',
    );
    return '$_temp0';
  }

  @override
  String get postHint => 'What\'s new? Tell your followers about it';

  @override
  String get postAddPhoto => 'Add a photo';

  @override
  String get postRemovePhoto => 'Remove photo';

  @override
  String get postTagProduct => 'Tag a product (optional)';

  @override
  String get postNoTag => 'No product';

  @override
  String get postPublish => 'Post';

  @override
  String get postPosting => 'Posting…';

  @override
  String get postEmpty => 'Add some text, a photo or a product first.';

  @override
  String get postPublished => 'Posted to your followers';

  @override
  String get postFailed => 'Couldn\'t publish your post. Try again.';

  @override
  String get insightsTitle => 'Insights';

  @override
  String get insightsHint => 'Sales trends, orders and best sellers';

  @override
  String insightsDays(int days) {
    return '$days days';
  }

  @override
  String insightsVsPrevious(String delta, String previous) {
    return '$delta vs $previous in the previous period';
  }

  @override
  String insightsChartSummary(String current, String previous, int days) {
    return 'Sales $current in the last $days days, against $previous in the $days days before.';
  }

  @override
  String get insightsThisPeriod => 'This period';

  @override
  String get insightsPreviousPeriod => 'Previous period';

  @override
  String insightsB2bShare(String share) {
    return '$share of sales came from business (B2B) orders';
  }

  @override
  String get insightsOrdersByStage => 'Orders by stage';

  @override
  String get insightsTopProducts => 'Best sellers';

  @override
  String get insightsNoOrders => 'No orders in this period yet.';

  @override
  String get healthTitle => 'Account health';

  @override
  String get healthNotEnoughData =>
      'Not enough activity yet to score your account. It appears after a few orders, reviews or quotes.';

  @override
  String get healthNotEnoughDataShort => 'Shown after a few orders';

  @override
  String get healthExplainer =>
      'Calculated from the last 30 days. Only measures with enough data count.';

  @override
  String healthScoreLabel(int score) {
    return 'Account health $score out of 100';
  }

  @override
  String get healthGood => 'Good';

  @override
  String get healthFair => 'Needs attention';

  @override
  String get healthPoor => 'At risk';

  @override
  String get healthFulfilment => 'Orders delivered';

  @override
  String get healthCancellations => 'Cancellations';

  @override
  String get healthRating => 'Buyer rating';

  @override
  String get healthListings => 'Complete listings';

  @override
  String get healthQuotes => 'Quotes answered within a day';

  @override
  String healthTargetAtLeast(String value) {
    return 'Target: at least $value';
  }

  @override
  String healthTargetAtMost(String value) {
    return 'Target: at most $value';
  }

  @override
  String get healthTipFulfilment =>
      'Accept only what you can deliver, and mark orders ready on time.';

  @override
  String get healthTipCancellations =>
      'Keep stock accurate so you don\'t have to cancel accepted orders.';

  @override
  String get healthTipRating =>
      'Reply to reviews and pack carefully — buyers rate the whole experience.';

  @override
  String get healthTipListings =>
      'Add a photo, a description and the HSN code with GST rate to every live product.';

  @override
  String get healthTipQuotes =>
      'Answer quote requests within a day — counter, accept or decline.';

  @override
  String get settingsVersion => 'Version';

  @override
  String settingsVersionValue(String version, String build) {
    return '$version ($build)';
  }

  @override
  String get filterLowStock => 'Low stock';

  @override
  String get storeStatusTitle => 'Store status';

  @override
  String get storeStatusOpen => 'Taking orders';

  @override
  String get storeStatusPaused => 'Paused — not taking orders';

  @override
  String get storeAcceptingOrders => 'Accepting orders';

  @override
  String get storeAcceptingHint => 'Buyers can order from your store.';

  @override
  String get storePausedHint =>
      'Buyers see your store but can\'t place orders.';

  @override
  String get storePauseFor => 'Pause for';

  @override
  String storePauseDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get storePauseUntilResumed => 'Until I resume';

  @override
  String get storePauseConsequence =>
      'New orders and quotes can\'t be placed while paused. Orders you already have are not affected.';

  @override
  String get storePauseCta => 'Pause my store';

  @override
  String get storePausedTitle => 'Your store is paused';

  @override
  String get storePausedBody => 'Buyers can\'t place orders until you resume.';

  @override
  String storePausedUntil(String date) {
    return 'Buyers can\'t place orders until $date.';
  }

  @override
  String get storeResume => 'Resume';

  @override
  String get storeResumed => 'Your store is taking orders again';

  @override
  String get storePausedToast => 'Your store is paused';

  @override
  String get followersTitle => 'Followers & posts';

  @override
  String get followersMenuSubtitle => 'Who follows your store, and your posts';

  @override
  String get followersCount => 'Followers';

  @override
  String followersNew(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count in the last 30 days',
      one: '+1 in the last 30 days',
    );
    return '$_temp0';
  }

  @override
  String get followersLoadFailed =>
      'Couldn\'t load this. Check your connection and open the screen again.';

  @override
  String get postsTitle => 'Your posts';

  @override
  String get postsEmpty =>
      'No posts yet. Posts reach everyone who follows your store.';

  @override
  String get postsNoText => 'Photo post';

  @override
  String get postsDeleteTitle => 'Delete this post?';

  @override
  String get postsDeleteBody => 'Followers will no longer see it.';

  @override
  String get postsDeleted => 'Post deleted';

  @override
  String get periodAll => 'All time';

  @override
  String get ordersB2bOnly => 'Business (B2B)';

  @override
  String get productStatsTitle => 'Last 30 days';

  @override
  String get productStatsUnits => 'Units sold';

  @override
  String get productStatsNeverSold => 'Not sold yet';

  @override
  String productStatsLastSold(String date) {
    return 'Last sold $date';
  }

  @override
  String get statementsTitle => 'Monthly statements';

  @override
  String statementHeading(String month) {
    return 'Statement — $month';
  }

  @override
  String statementTotals(String gross, String commission, String net) {
    return 'Order value $gross · commission $commission · you receive $net';
  }

  @override
  String statementLine(String date, String order, String net, String status) {
    return '$date  Order $order  $net  $status';
  }

  @override
  String get statementCopy => 'Copy statement';

  @override
  String get statementCopied => 'Statement copied';

  @override
  String get variantsTitle => 'Options';

  @override
  String get variantsHint =>
      'Sizes or pack weights, each with its own price and stock. Leave empty for a single product.';

  @override
  String variantsLine(String price, String stock) {
    return '$price · $stock in stock';
  }

  @override
  String get variantsAdd => 'Add option';

  @override
  String get variantsEdit => 'Edit option';

  @override
  String variantsRemove(String name) {
    return 'Remove $name';
  }

  @override
  String get variantsName => 'Option name';

  @override
  String get variantsNameHint => 'e.g. 1 kg, 5 kg, Large';

  @override
  String get variantsDuplicate => 'You already have an option with this name';

  @override
  String variantsOrderLine(String name) {
    return 'Option: $name';
  }
}
