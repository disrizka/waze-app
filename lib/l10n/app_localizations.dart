import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_id.dart';

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
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('id')
  ];

  /// No description provided for @refresh_success.
  ///
  /// In en, this message translates to:
  /// **'Data updated'**
  String get refresh_success;

  /// No description provided for @refresh_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to refresh'**
  String get refresh_failed;

  /// No description provided for @previewReport_title.
  ///
  /// In en, this message translates to:
  /// **'Preview Report'**
  String get previewReport_title;

  /// No description provided for @income_day.
  ///
  /// In en, this message translates to:
  /// **'Income this day'**
  String get income_day;

  /// No description provided for @income_month.
  ///
  /// In en, this message translates to:
  /// **'Income this month'**
  String get income_month;

  /// No description provided for @income_year.
  ///
  /// In en, this message translates to:
  /// **'Income this year'**
  String get income_year;

  /// No description provided for @header_account_caption.
  ///
  /// In en, this message translates to:
  /// **'Account User'**
  String get header_account_caption;

  /// No description provided for @header_business_caption.
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get header_business_caption;

  /// No description provided for @snackbar_business_switch_success.
  ///
  /// In en, this message translates to:
  /// **'Active business updated successfully'**
  String get snackbar_business_switch_success;

  /// No description provided for @grid_hr.
  ///
  /// In en, this message translates to:
  /// **'HR'**
  String get grid_hr;

  /// No description provided for @grid_product.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get grid_product;

  /// No description provided for @grid_sales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get grid_sales;

  /// No description provided for @grid_purchase.
  ///
  /// In en, this message translates to:
  /// **'Purchase'**
  String get grid_purchase;

  /// No description provided for @grid_report.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get grid_report;

  /// No description provided for @grid_setting.
  ///
  /// In en, this message translates to:
  /// **'Setting'**
  String get grid_setting;

  /// No description provided for @sheet_switch_business_title.
  ///
  /// In en, this message translates to:
  /// **'Switch Business'**
  String get sheet_switch_business_title;

  /// No description provided for @sheet_no_business.
  ///
  /// In en, this message translates to:
  /// **'No business found'**
  String get sheet_no_business;

  /// Subtitle displaying business username/code in the switcher list.
  ///
  /// In en, this message translates to:
  /// **'id: {username}'**
  String sheet_business_id_label(String username);

  /// Label for username field
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get login_username;

  /// Placeholder hint in username TextField
  ///
  /// In en, this message translates to:
  /// **'E.g user0001@gmail.com'**
  String get login_username_hint;

  /// Label for password field
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get login_password;

  /// Placeholder hint in password TextField
  ///
  /// In en, this message translates to:
  /// **'Fill your password here'**
  String get login_password_hint;

  /// Text link to forgot password flow
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get login_forgot_password;

  /// Button text for login
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login_button;

  /// Text shown on shimmer loading button
  ///
  /// In en, this message translates to:
  /// **'Logging in…'**
  String get login_button_loading;

  /// Text before Register Now link
  ///
  /// In en, this message translates to:
  /// **'Don’t have account? '**
  String get login_no_account;

  /// Text for register link
  ///
  /// In en, this message translates to:
  /// **'Register Now'**
  String get login_register_now;

  /// Snackbar message when fields are empty
  ///
  /// In en, this message translates to:
  /// **'Username and password cannot be empty'**
  String get login_empty_fields;

  /// Default error message when login failed
  ///
  /// In en, this message translates to:
  /// **'Login failed'**
  String get login_failed;

  /// No description provided for @profile_appbar_title.
  ///
  /// In en, this message translates to:
  /// **'Other Menu'**
  String get profile_appbar_title;

  /// No description provided for @profile_action_switch_account.
  ///
  /// In en, this message translates to:
  /// **'Switch Account'**
  String get profile_action_switch_account;

  /// No description provided for @profile_section_setting.
  ///
  /// In en, this message translates to:
  /// **'Setting'**
  String get profile_section_setting;

  /// No description provided for @profile_section_others.
  ///
  /// In en, this message translates to:
  /// **'Others'**
  String get profile_section_others;

  /// No description provided for @profile_menu_account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get profile_menu_account;

  /// No description provided for @profile_menu_help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get profile_menu_help;

  /// No description provided for @profile_menu_terms.
  ///
  /// In en, this message translates to:
  /// **'Terms & Conditions'**
  String get profile_menu_terms;

  /// No description provided for @profile_menu_privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get profile_menu_privacy;

  /// No description provided for @profile_button_logout.
  ///
  /// In en, this message translates to:
  /// **'Logout Account'**
  String get profile_button_logout;

  /// No description provided for @dialog_add_account_title.
  ///
  /// In en, this message translates to:
  /// **'Add another account?'**
  String get dialog_add_account_title;

  /// No description provided for @dialog_add_account_message.
  ///
  /// In en, this message translates to:
  /// **'Do you want to add another account? You can log in and switch accounts anytime.'**
  String get dialog_add_account_message;

  /// No description provided for @dialog_add_account_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get dialog_add_account_cancel;

  /// No description provided for @dialog_add_account_confirm.
  ///
  /// In en, this message translates to:
  /// **'Yes, add'**
  String get dialog_add_account_confirm;

  /// No description provided for @sheet_switch_account_title.
  ///
  /// In en, this message translates to:
  /// **'Switch Account'**
  String get sheet_switch_account_title;

  /// No description provided for @sheet_add_another_account.
  ///
  /// In en, this message translates to:
  /// **'Add another account'**
  String get sheet_add_another_account;

  /// No description provided for @sheet_active_badge.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get sheet_active_badge;

  /// No description provided for @sheet_name_not_found.
  ///
  /// In en, this message translates to:
  /// **'Name not found'**
  String get sheet_name_not_found;

  /// No description provided for @sheet_switch_account_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to switch account'**
  String get sheet_switch_account_failed;

  /// No description provided for @profile_menu_language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get profile_menu_language;

  /// No description provided for @language_sheet_title.
  ///
  /// In en, this message translates to:
  /// **'Change Language'**
  String get language_sheet_title;

  /// No description provided for @language_use_system.
  ///
  /// In en, this message translates to:
  /// **'Use system language'**
  String get language_use_system;

  /// No description provided for @language_english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get language_english;

  /// No description provided for @language_indonesian.
  ///
  /// In en, this message translates to:
  /// **'Indonesian'**
  String get language_indonesian;

  /// No description provided for @language_switched.
  ///
  /// In en, this message translates to:
  /// **'Language updated'**
  String get language_switched;

  /// No description provided for @language_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get language_cancel;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'id'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'id': return AppLocalizationsId();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
