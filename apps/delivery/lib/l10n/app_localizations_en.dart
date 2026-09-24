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
  String get authNoPartnerRecord =>
      'We couldn\'t find your delivery partner details. Contact Agrimore support.';

  @override
  String get authNoProfile =>
      'We couldn\'t find your account profile. Contact Agrimore support.';

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
}
