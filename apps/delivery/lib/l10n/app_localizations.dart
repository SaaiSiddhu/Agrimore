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

  /// users doc is a rider but delivery_partners doc is missing
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find your delivery partner details. Contact Agrimore support.'**
  String get authNoPartnerRecord;

  /// users doc missing on the server
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find your account profile. Contact Agrimore support.'**
  String get authNoProfile;

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
  /// **'Newest first. Totals on this screen cover only the orders loaded.'**
  String get historyHint;

  /// Splash screen tagline
  ///
  /// In en, this message translates to:
  /// **'Delivery Partner'**
  String get splashTagline;
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
