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
  /// **'App Settings'**
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

  /// No description provided for @profile_button_password.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get profile_button_password;

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

  /// No description provided for @profile_thermal_pinter.
  ///
  /// In en, this message translates to:
  /// **'Thermal Printer'**
  String get profile_thermal_pinter;

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

  /// Headline text on the register welcome screen.
  ///
  /// In en, this message translates to:
  /// **'Let’s sign up a new account!'**
  String get register_welcome_title;

  /// Short description under the headline on the register welcome screen.
  ///
  /// In en, this message translates to:
  /// **'Create your account in just a few easy steps. We’ll guide you through a friendly, simple setup.'**
  String get register_welcome_description;

  /// Title of the hint card explaining benefits of creating a WaveUp account.
  ///
  /// In en, this message translates to:
  /// **'Why create a WaveUp account?'**
  String get register_welcome_hint_title;

  /// First bullet point in the hint card.
  ///
  /// In en, this message translates to:
  /// **'Access your business data anywhere'**
  String get register_welcome_hint_point1;

  /// Second bullet point in the hint card.
  ///
  /// In en, this message translates to:
  /// **'Track your report accurately'**
  String get register_welcome_hint_point2;

  /// Third bullet point in the hint card.
  ///
  /// In en, this message translates to:
  /// **'Faster checkout and insights'**
  String get register_welcome_hint_point3;

  /// Tooltip text for the back button on the register welcome screen.
  ///
  /// In en, this message translates to:
  /// **'Back to login'**
  String get register_welcome_back_tooltip;

  /// No description provided for @register_step1_device_not_ready.
  ///
  /// In en, this message translates to:
  /// **'We are still preparing your device. Please try again in a moment.'**
  String get register_step1_device_not_ready;

  /// No description provided for @register_step1_registration_failed_default.
  ///
  /// In en, this message translates to:
  /// **'Registration failed. Please try again.'**
  String get register_step1_registration_failed_default;

  /// No description provided for @register_step1_primary_continue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get register_step1_primary_continue;

  /// No description provided for @register_step1_primary_create_account.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get register_step1_primary_create_account;

  /// No description provided for @register_step1_step1_title.
  ///
  /// In en, this message translates to:
  /// **'What is your email?'**
  String get register_step1_step1_title;

  /// No description provided for @register_step1_step2_title.
  ///
  /// In en, this message translates to:
  /// **'Tell us about you'**
  String get register_step1_step2_title;

  /// No description provided for @register_step1_step3_title.
  ///
  /// In en, this message translates to:
  /// **'Create a secure password'**
  String get register_step1_step3_title;

  /// No description provided for @register_step1_step4_title.
  ///
  /// In en, this message translates to:
  /// **'Review and confirm'**
  String get register_step1_step4_title;

  /// No description provided for @register_step1_step1_desc.
  ///
  /// In en, this message translates to:
  /// **'We will use this email to create your WaveUp account and send important notifications.'**
  String get register_step1_step1_desc;

  /// No description provided for @register_step1_step2_desc.
  ///
  /// In en, this message translates to:
  /// **'We only need your name to personalize your experience and help your team recognize you.'**
  String get register_step1_step2_desc;

  /// No description provided for @register_step1_step3_desc.
  ///
  /// In en, this message translates to:
  /// **'Choose a strong password to keep your account and business data safe.'**
  String get register_step1_step3_desc;

  /// No description provided for @register_step1_step4_desc.
  ///
  /// In en, this message translates to:
  /// **'Please review your details below before we create your account.'**
  String get register_step1_step4_desc;

  /// No description provided for @register_step1_email_label.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get register_step1_email_label;

  /// No description provided for @register_step1_email_hint.
  ///
  /// In en, this message translates to:
  /// **'e.g. yourmail@mail.com'**
  String get register_step1_email_hint;

  /// No description provided for @register_step1_email_required.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get register_step1_email_required;

  /// No description provided for @register_step1_email_invalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get register_step1_email_invalid;

  /// No description provided for @register_step1_first_name_label.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get register_step1_first_name_label;

  /// No description provided for @register_step1_first_name_hint.
  ///
  /// In en, this message translates to:
  /// **'e.g. John'**
  String get register_step1_first_name_hint;

  /// No description provided for @register_step1_first_name_required.
  ///
  /// In en, this message translates to:
  /// **'First name is required'**
  String get register_step1_first_name_required;

  /// No description provided for @register_step1_first_name_min_length.
  ///
  /// In en, this message translates to:
  /// **'Please enter at least 2 characters'**
  String get register_step1_first_name_min_length;

  /// No description provided for @register_step1_last_name_label.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get register_step1_last_name_label;

  /// No description provided for @register_step1_last_name_hint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Doe'**
  String get register_step1_last_name_hint;

  /// No description provided for @register_step1_last_name_required.
  ///
  /// In en, this message translates to:
  /// **'Last name is required'**
  String get register_step1_last_name_required;

  /// No description provided for @register_step1_last_name_min_length.
  ///
  /// In en, this message translates to:
  /// **'Please enter at least 2 characters'**
  String get register_step1_last_name_min_length;

  /// No description provided for @register_step1_password_label.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get register_step1_password_label;

  /// No description provided for @register_step1_password_hint.
  ///
  /// In en, this message translates to:
  /// **'Create a strong password'**
  String get register_step1_password_hint;

  /// No description provided for @register_step1_password_required.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get register_step1_password_required;

  /// No description provided for @register_step1_password_min_length.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters long'**
  String get register_step1_password_min_length;

  /// No description provided for @register_step1_password_rule_not_satisfied.
  ///
  /// In en, this message translates to:
  /// **'Password must contain uppercase, lowercase, number, and special character'**
  String get register_step1_password_rule_not_satisfied;

  /// No description provided for @register_step1_confirm_password_label.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get register_step1_confirm_password_label;

  /// No description provided for @register_step1_confirm_password_hint.
  ///
  /// In en, this message translates to:
  /// **'Confirm your password'**
  String get register_step1_confirm_password_hint;

  /// No description provided for @register_step1_confirm_password_required.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password'**
  String get register_step1_confirm_password_required;

  /// No description provided for @register_step1_confirm_password_not_match.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get register_step1_confirm_password_not_match;

  /// No description provided for @register_step1_password_info_title.
  ///
  /// In en, this message translates to:
  /// **'Your password must contain:'**
  String get register_step1_password_info_title;

  /// No description provided for @register_step1_password_rule_8_chars.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get register_step1_password_rule_8_chars;

  /// No description provided for @register_step1_password_rule_uppercase.
  ///
  /// In en, this message translates to:
  /// **'At least 1 uppercase letter (A–Z)'**
  String get register_step1_password_rule_uppercase;

  /// No description provided for @register_step1_password_rule_lowercase.
  ///
  /// In en, this message translates to:
  /// **'At least 1 lowercase letter (a–z)'**
  String get register_step1_password_rule_lowercase;

  /// No description provided for @register_step1_password_rule_number.
  ///
  /// In en, this message translates to:
  /// **'At least 1 number (0–9)'**
  String get register_step1_password_rule_number;

  /// No description provided for @register_step1_password_rule_special.
  ///
  /// In en, this message translates to:
  /// **'At least 1 special character (e.g. !, @, #, ?)'**
  String get register_step1_password_rule_special;

  /// No description provided for @register_step1_privacy_checkbox_text_prefix.
  ///
  /// In en, this message translates to:
  /// **'By creating an account, you confirm that your details are correct and you agree to our '**
  String get register_step1_privacy_checkbox_text_prefix;

  /// No description provided for @register_step1_privacy_checkbox_link.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get register_step1_privacy_checkbox_link;

  /// No description provided for @register_step1_privacy_policy_title.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get register_step1_privacy_policy_title;

  /// No description provided for @register_step1_privacy_not_agreed_snackbar.
  ///
  /// In en, this message translates to:
  /// **'Please agree to the Privacy Policy to continue.'**
  String get register_step1_privacy_not_agreed_snackbar;

  /// No description provided for @register_step1_back_button.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get register_step1_back_button;

  /// No description provided for @register_step1_footer_have_account.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get register_step1_footer_have_account;

  /// No description provided for @register_step1_footer_login.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get register_step1_footer_login;

  /// No description provided for @register_step2_camera_perm_permanently_denied.
  ///
  /// In en, this message translates to:
  /// **'Camera permission is permanently denied. Please enable it from Settings.'**
  String get register_step2_camera_perm_permanently_denied;

  /// No description provided for @register_step2_image_too_large_prefix.
  ///
  /// In en, this message translates to:
  /// **'Image size is too large'**
  String get register_step2_image_too_large_prefix;

  /// No description provided for @register_step2_image_too_large_suffix.
  ///
  /// In en, this message translates to:
  /// **'Maximum allowed is'**
  String get register_step2_image_too_large_suffix;

  /// No description provided for @register_step2_pick_image_failed_prefix.
  ///
  /// In en, this message translates to:
  /// **'Failed to pick image: '**
  String get register_step2_pick_image_failed_prefix;

  /// No description provided for @register_step2_logo_from_gallery_title.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get register_step2_logo_from_gallery_title;

  /// No description provided for @register_step2_logo_from_gallery_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Recommended for existing photos'**
  String get register_step2_logo_from_gallery_subtitle;

  /// No description provided for @register_step2_logo_take_photo_title.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get register_step2_logo_take_photo_title;

  /// No description provided for @register_step2_logo_take_photo_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Use your camera to capture a logo'**
  String get register_step2_logo_take_photo_subtitle;

  /// No description provided for @register_step2_failed_default.
  ///
  /// In en, this message translates to:
  /// **'Step 2 registration failed'**
  String get register_step2_failed_default;

  /// No description provided for @register_step2_title.
  ///
  /// In en, this message translates to:
  /// **'Set up your business'**
  String get register_step2_title;

  /// No description provided for @register_step2_desc.
  ///
  /// In en, this message translates to:
  /// **'Tell us more about your business. This helps us personalise reports and how your brand appears to your customers.'**
  String get register_step2_desc;

  /// No description provided for @register_step2_business_name_label.
  ///
  /// In en, this message translates to:
  /// **'Business name'**
  String get register_step2_business_name_label;

  /// No description provided for @register_step2_business_name_hint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Berjaya Selalu Grocery'**
  String get register_step2_business_name_hint;

  /// No description provided for @register_step2_business_name_required.
  ///
  /// In en, this message translates to:
  /// **'Business name is required'**
  String get register_step2_business_name_required;

  /// No description provided for @register_step2_business_name_min_length.
  ///
  /// In en, this message translates to:
  /// **'Please enter at least 2 characters'**
  String get register_step2_business_name_min_length;

  /// No description provided for @register_step2_about_label.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get register_step2_about_label;

  /// No description provided for @register_step2_about_hint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Modern mini market focused on fresh groceries and daily needs.'**
  String get register_step2_about_hint;

  /// No description provided for @register_step2_logo_label.
  ///
  /// In en, this message translates to:
  /// **'Business logo'**
  String get register_step2_logo_label;

  /// No description provided for @register_step2_logo_add.
  ///
  /// In en, this message translates to:
  /// **'Add your business logo'**
  String get register_step2_logo_add;

  /// No description provided for @register_step2_logo_selected_prefix.
  ///
  /// In en, this message translates to:
  /// **'Selected: '**
  String get register_step2_logo_selected_prefix;

  /// No description provided for @register_step2_logo_hint.
  ///
  /// In en, this message translates to:
  /// **'JPG or PNG, up to 10MB. A clear square logo works best.'**
  String get register_step2_logo_hint;

  /// No description provided for @register_step2_logo_remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get register_step2_logo_remove;

  /// No description provided for @register_step2_logo_upload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get register_step2_logo_upload;

  /// No description provided for @register_step2_finish_button.
  ///
  /// In en, this message translates to:
  /// **'Finish setup'**
  String get register_step2_finish_button;

  /// No description provided for @manage_report_load_error_prefix.
  ///
  /// In en, this message translates to:
  /// **'Failed to load report summary: '**
  String get manage_report_load_error_prefix;

  /// No description provided for @manage_report_appbar_title.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get manage_report_appbar_title;

  /// No description provided for @manage_report_section_menu_title.
  ///
  /// In en, this message translates to:
  /// **'List Menu'**
  String get manage_report_section_menu_title;

  /// No description provided for @manage_report_menu_sales.
  ///
  /// In en, this message translates to:
  /// **'Report Sales'**
  String get manage_report_menu_sales;

  /// No description provided for @manage_report_menu_purchase.
  ///
  /// In en, this message translates to:
  /// **'Report Purchase'**
  String get manage_report_menu_purchase;

  /// No description provided for @manage_report_dashboard_title.
  ///
  /// In en, this message translates to:
  /// **'Report Summary'**
  String get manage_report_dashboard_title;

  /// No description provided for @manage_report_sales_revenue_title.
  ///
  /// In en, this message translates to:
  /// **'Sales Revenue'**
  String get manage_report_sales_revenue_title;

  /// No description provided for @manage_report_purchase_revenue_title.
  ///
  /// In en, this message translates to:
  /// **'Purchase'**
  String get manage_report_purchase_revenue_title;

  /// No description provided for @manage_report_submetric_transactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get manage_report_submetric_transactions;

  /// No description provided for @manage_report_submetric_qty.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get manage_report_submetric_qty;

  /// No description provided for @make_order_store_location_title.
  ///
  /// In en, this message translates to:
  /// **'Store Location'**
  String get make_order_store_location_title;

  /// No description provided for @make_order_required_badge.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get make_order_required_badge;

  /// No description provided for @make_order_store_picker_label.
  ///
  /// In en, this message translates to:
  /// **'Choose a store'**
  String get make_order_store_picker_label;

  /// No description provided for @make_order_store_picker_empty.
  ///
  /// In en, this message translates to:
  /// **'Select store…'**
  String get make_order_store_picker_empty;

  /// No description provided for @make_order_customer_section_title.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get make_order_customer_section_title;

  /// No description provided for @make_order_customer_clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get make_order_customer_clear;

  /// No description provided for @make_order_customer_picker_label.
  ///
  /// In en, this message translates to:
  /// **'Choose customer'**
  String get make_order_customer_picker_label;

  /// No description provided for @make_order_customer_picker_empty.
  ///
  /// In en, this message translates to:
  /// **'Select customer...'**
  String get make_order_customer_picker_empty;

  /// No description provided for @make_order_notes_section_title.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get make_order_notes_section_title;

  /// No description provided for @make_order_notes_hint.
  ///
  /// In en, this message translates to:
  /// **'Optional notes for this order...'**
  String get make_order_notes_hint;

  /// No description provided for @make_order_cta_check_order.
  ///
  /// In en, this message translates to:
  /// **'Check Order'**
  String get make_order_cta_check_order;

  /// No description provided for @make_order_empty_cart_message.
  ///
  /// In en, this message translates to:
  /// **'No items yet. Add products from catalog.'**
  String get make_order_empty_cart_message;

  /// No description provided for @make_order_table_col_product.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get make_order_table_col_product;

  /// No description provided for @make_order_table_col_sku.
  ///
  /// In en, this message translates to:
  /// **'SKU'**
  String get make_order_table_col_sku;

  /// No description provided for @make_order_table_col_qty.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get make_order_table_col_qty;

  /// No description provided for @make_order_table_col_disc_per_item.
  ///
  /// In en, this message translates to:
  /// **'Disc/Item'**
  String get make_order_table_col_disc_per_item;

  /// No description provided for @make_order_table_col_unit_base.
  ///
  /// In en, this message translates to:
  /// **'Unit (Base)'**
  String get make_order_table_col_unit_base;

  /// No description provided for @make_order_table_col_unit_effective.
  ///
  /// In en, this message translates to:
  /// **'Unit (Effective)'**
  String get make_order_table_col_unit_effective;

  /// No description provided for @make_order_table_col_line_total.
  ///
  /// In en, this message translates to:
  /// **'Line Total'**
  String get make_order_table_col_line_total;

  /// No description provided for @make_order_table_action_remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get make_order_table_action_remove;

  /// No description provided for @make_order_totals_discount_label.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get make_order_totals_discount_label;

  /// No description provided for @make_order_totals_total_label.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get make_order_totals_total_label;

  /// No description provided for @make_order_edit_ref_title.
  ///
  /// In en, this message translates to:
  /// **'Edit Reference Number'**
  String get make_order_edit_ref_title;

  /// No description provided for @make_order_edit_ref_hint.
  ///
  /// In en, this message translates to:
  /// **'REF-123456'**
  String get make_order_edit_ref_hint;

  /// No description provided for @make_order_edit_ref_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get make_order_edit_ref_cancel;

  /// No description provided for @make_order_edit_ref_save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get make_order_edit_ref_save;

  /// No description provided for @add_product_retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get add_product_retry;

  /// No description provided for @add_product_select_products_title.
  ///
  /// In en, this message translates to:
  /// **'Select Products'**
  String get add_product_select_products_title;

  /// No description provided for @add_product_search_hint.
  ///
  /// In en, this message translates to:
  /// **'Search product / SKU'**
  String get add_product_search_hint;

  /// No description provided for @add_product_no_products.
  ///
  /// In en, this message translates to:
  /// **'No products found'**
  String get add_product_no_products;

  /// No description provided for @add_product_footer_hint_empty.
  ///
  /// In en, this message translates to:
  /// **'Select products then set their variants'**
  String get add_product_footer_hint_empty;

  /// No description provided for @add_product_footer_hint_selected.
  ///
  /// In en, this message translates to:
  /// **'{skuCount} SKU • {qtyCount} qty'**
  String add_product_footer_hint_selected(int skuCount, int qtyCount);

  /// No description provided for @add_product_use_selected_button.
  ///
  /// In en, this message translates to:
  /// **'Use selected'**
  String get add_product_use_selected_button;

  /// No description provided for @common_close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get common_close;

  /// No description provided for @add_product_selected_semantics.
  ///
  /// In en, this message translates to:
  /// **'Selected {count}'**
  String add_product_selected_semantics(int count);

  /// No description provided for @add_product_empty_stock_label.
  ///
  /// In en, this message translates to:
  /// **'Empty Stock'**
  String get add_product_empty_stock_label;

  /// No description provided for @add_product_price_from_label.
  ///
  /// In en, this message translates to:
  /// **'from Rp {price}'**
  String add_product_price_from_label(String price);

  /// No description provided for @add_product_unavailable_button.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get add_product_unavailable_button;

  /// No description provided for @add_product_choose_button.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get add_product_choose_button;

  /// No description provided for @variant_sheet_title.
  ///
  /// In en, this message translates to:
  /// **'Choose Variants'**
  String get variant_sheet_title;

  /// No description provided for @variant_stock_label.
  ///
  /// In en, this message translates to:
  /// **'Stock: {stock}'**
  String variant_stock_label(int stock);

  /// No description provided for @variant_in_cart_label.
  ///
  /// In en, this message translates to:
  /// **'In cart: {qty}'**
  String variant_in_cart_label(int qty);

  /// No description provided for @variant_quantity_label.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get variant_quantity_label;

  /// No description provided for @variant_cta_select_all_variants.
  ///
  /// In en, this message translates to:
  /// **'Select all variants'**
  String get variant_cta_select_all_variants;

  /// No description provided for @variant_cta_stock_empty.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get variant_cta_stock_empty;

  /// No description provided for @variant_cta_add_to_cart.
  ///
  /// In en, this message translates to:
  /// **'Add to cart — Rp {price}'**
  String variant_cta_add_to_cart(String price);

  /// Title of manage product screen app bar
  ///
  /// In en, this message translates to:
  /// **'Manage Product'**
  String get manageProductTitle;

  /// Section label above the menu list on manage product screen
  ///
  /// In en, this message translates to:
  /// **'List Menu'**
  String get manageProductListMenuLabel;

  /// Menu item label for navigating to product list screen
  ///
  /// In en, this message translates to:
  /// **'Product List'**
  String get manageProductProductList;

  /// Menu item label for navigating to brand list screen
  ///
  /// In en, this message translates to:
  /// **'Brand List'**
  String get manageProductBrandList;

  /// Menu item label for navigating to category list screen
  ///
  /// In en, this message translates to:
  /// **'Category List'**
  String get manageProductCategoryList;

  /// Title for the product detail screen app bar
  ///
  /// In en, this message translates to:
  /// **'Product Detail'**
  String get productDetailTitle;

  /// Tooltip for back button on product detail screen
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get productDetailBackTooltip;

  /// Section title for product description
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get productDetailDescriptionSectionTitle;

  /// Section title for wholesale prices
  ///
  /// In en, this message translates to:
  /// **'Prices (Wholesale tiers)'**
  String get productDetailPricesWholesaleTitle;

  /// Label for minimum quantity row in wholesale price list
  ///
  /// In en, this message translates to:
  /// **'Min. {minQty} pcs'**
  String productDetailPriceRowMin(int minQty);

  /// Section title for SKU list
  ///
  /// In en, this message translates to:
  /// **'SKU'**
  String get productDetailSkuSectionTitle;

  /// Snackbar message when product delete succeeds
  ///
  /// In en, this message translates to:
  /// **'Product deleted'**
  String get productDetailDeleteSuccess;

  /// Snackbar message when product delete fails
  ///
  /// In en, this message translates to:
  /// **'Failed to delete'**
  String get productDetailDeleteFailed;

  /// Label for delete button on product detail screen
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get productDetailDeleteButton;

  /// Label for edit product button on product detail screen
  ///
  /// In en, this message translates to:
  /// **'Edit Product'**
  String get productDetailEditButton;

  /// Badge label when product is hidden
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get productDetailHiddenLabel;

  /// Button label and tooltip for opening stock page of SKU
  ///
  /// In en, this message translates to:
  /// **'Open stock'**
  String get productDetailOpenStock;

  /// Tooltip for close button in full screen image viewer
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get productDetailImageViewerCloseTooltip;

  /// No description provided for @salesTitle.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get salesTitle;

  /// No description provided for @salesHistorySuffix.
  ///
  /// In en, this message translates to:
  /// **'/history'**
  String get salesHistorySuffix;

  /// No description provided for @salesSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search code / reference / status'**
  String get salesSearchHint;

  /// No description provided for @salesDateApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get salesDateApply;

  /// No description provided for @salesFilterAnyTime.
  ///
  /// In en, this message translates to:
  /// **'Any time'**
  String get salesFilterAnyTime;

  /// No description provided for @salesStoreAll.
  ///
  /// In en, this message translates to:
  /// **'All stores'**
  String get salesStoreAll;

  /// Label showing selected store name in sales report header
  ///
  /// In en, this message translates to:
  /// **'Store: {storeName}'**
  String salesStoreLabelWithName(String storeName);

  /// No description provided for @salesStoreLabelAll.
  ///
  /// In en, this message translates to:
  /// **'Store: All'**
  String get salesStoreLabelAll;

  /// No description provided for @salesTotalAmount.
  ///
  /// In en, this message translates to:
  /// **'Total amount'**
  String get salesTotalAmount;

  /// No description provided for @salesQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get salesQuantity;

  /// No description provided for @salesErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Failed to load sales'**
  String get salesErrorTitle;

  /// No description provided for @salesErrorRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get salesErrorRetry;

  /// No description provided for @salesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No sales yet'**
  String get salesEmptyTitle;

  /// No description provided for @salesEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pull down to refresh.'**
  String get salesEmptySubtitle;

  /// No description provided for @salesAddButton.
  ///
  /// In en, this message translates to:
  /// **'Add sales'**
  String get salesAddButton;

  /// No description provided for @reportSalesTitle.
  ///
  /// In en, this message translates to:
  /// **'Sales report'**
  String get reportSalesTitle;

  /// No description provided for @reportSalesCustomerLabel.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get reportSalesCustomerLabel;

  /// No description provided for @reportCommonRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get reportCommonRefresh;

  /// No description provided for @reportDateRangeHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose date range'**
  String get reportDateRangeHelp;

  /// No description provided for @reportDateRangeApply.
  ///
  /// In en, this message translates to:
  /// **'Apply range'**
  String get reportDateRangeApply;

  /// No description provided for @reportFilterTarget.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get reportFilterTarget;

  /// No description provided for @reportFilterGranularity.
  ///
  /// In en, this message translates to:
  /// **'Granularity'**
  String get reportFilterGranularity;

  /// No description provided for @reportFilterCustomRange.
  ///
  /// In en, this message translates to:
  /// **'Custom date range'**
  String get reportFilterCustomRange;

  /// No description provided for @reportFilterToggleOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get reportFilterToggleOn;

  /// No description provided for @reportFilterToggleOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get reportFilterToggleOff;

  /// No description provided for @reportFilterPickDateRange.
  ///
  /// In en, this message translates to:
  /// **'Pick date range'**
  String get reportFilterPickDateRange;

  /// No description provided for @reportSummaryTotalRevenue.
  ///
  /// In en, this message translates to:
  /// **'Total revenue'**
  String get reportSummaryTotalRevenue;

  /// No description provided for @reportSummaryTotalQty.
  ///
  /// In en, this message translates to:
  /// **'Total qty'**
  String get reportSummaryTotalQty;

  /// No description provided for @reportSummaryTotalTransactions.
  ///
  /// In en, this message translates to:
  /// **'Total transactions'**
  String get reportSummaryTotalTransactions;

  /// No description provided for @reportSortLabel.
  ///
  /// In en, this message translates to:
  /// **'Sort:'**
  String get reportSortLabel;

  /// No description provided for @reportSortPeriod.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get reportSortPeriod;

  /// No description provided for @reportSortTransactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get reportSortTransactions;

  /// No description provided for @reportSortQty.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get reportSortQty;

  /// No description provided for @reportSortRevenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get reportSortRevenue;

  /// No description provided for @reportSortName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get reportSortName;

  /// No description provided for @reportSortDescendingTooltip.
  ///
  /// In en, this message translates to:
  /// **'Descending'**
  String get reportSortDescendingTooltip;

  /// No description provided for @reportSortAscendingTooltip.
  ///
  /// In en, this message translates to:
  /// **'Ascending'**
  String get reportSortAscendingTooltip;

  /// No description provided for @reportDistributionTitle.
  ///
  /// In en, this message translates to:
  /// **'Revenue distribution'**
  String get reportDistributionTitle;

  /// No description provided for @reportDistributionNoData.
  ///
  /// In en, this message translates to:
  /// **'No data to visualize'**
  String get reportDistributionNoData;

  /// No description provided for @reportDistributionOthers.
  ///
  /// In en, this message translates to:
  /// **'Others'**
  String get reportDistributionOthers;

  /// Title for top 5 section when grouped by customer-like entity
  ///
  /// In en, this message translates to:
  /// **'Top 5 {customerLabel}'**
  String reportTop5CustomerTitle(String customerLabel);

  /// No description provided for @reportTop5ProductsTitle.
  ///
  /// In en, this message translates to:
  /// **'Top 5 products'**
  String get reportTop5ProductsTitle;

  /// No description provided for @reportTop5CategoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Top 5 categories'**
  String get reportTop5CategoriesTitle;

  /// No description provided for @reportTop5BrandsTitle.
  ///
  /// In en, this message translates to:
  /// **'Top 5 brands'**
  String get reportTop5BrandsTitle;

  /// No description provided for @reportTop5PeriodsTitle.
  ///
  /// In en, this message translates to:
  /// **'Top 5 periods'**
  String get reportTop5PeriodsTitle;

  /// No description provided for @reportTop5Empty.
  ///
  /// In en, this message translates to:
  /// **'No data yet'**
  String get reportTop5Empty;

  /// No description provided for @reportTopRowUnnamed.
  ///
  /// In en, this message translates to:
  /// **'Unnamed'**
  String get reportTopRowUnnamed;

  /// Shows how much percent of revenue this row contributes
  ///
  /// In en, this message translates to:
  /// **'{percentage}% of revenue'**
  String reportTopRowPercentageOfRevenue(String percentage);

  /// Section title for details table grouped by a customer-like entity
  ///
  /// In en, this message translates to:
  /// **'Details by {customerLabel}'**
  String reportDetailsByCustomerLabel(String customerLabel);

  /// No description provided for @reportDetailsByProduct.
  ///
  /// In en, this message translates to:
  /// **'Details by product'**
  String get reportDetailsByProduct;

  /// No description provided for @reportDetailsByCategory.
  ///
  /// In en, this message translates to:
  /// **'Details by category'**
  String get reportDetailsByCategory;

  /// No description provided for @reportDetailsByBrand.
  ///
  /// In en, this message translates to:
  /// **'Details by brand'**
  String get reportDetailsByBrand;

  /// No description provided for @reportDetailsByPeriod.
  ///
  /// In en, this message translates to:
  /// **'Details by period'**
  String get reportDetailsByPeriod;

  /// No description provided for @reportTableColumnQty.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get reportTableColumnQty;

  /// No description provided for @reportTableColumnRevenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get reportTableColumnRevenue;

  /// No description provided for @reportTableColumnAvgTx.
  ///
  /// In en, this message translates to:
  /// **'Avg/Tx'**
  String get reportTableColumnAvgTx;

  /// No description provided for @reportTableColumnPeriod.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get reportTableColumnPeriod;

  /// No description provided for @reportTableColumnTransactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get reportTableColumnTransactions;

  /// No description provided for @reportTableSkuPrefix.
  ///
  /// In en, this message translates to:
  /// **'SKU: {sku}'**
  String reportTableSkuPrefix(String sku);

  /// No description provided for @reportTablePhonePrefix.
  ///
  /// In en, this message translates to:
  /// **'Phone: {phone}'**
  String reportTablePhonePrefix(String phone);

  /// No description provided for @reportRangeChipLabel.
  ///
  /// In en, this message translates to:
  /// **'Range: {start} — {end}'**
  String reportRangeChipLabel(String start, String end);

  /// No description provided for @reportDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get reportDetailsTitle;

  /// No description provided for @reportPurchaseTitle.
  ///
  /// In en, this message translates to:
  /// **'Purchase report'**
  String get reportPurchaseTitle;

  /// No description provided for @reportPurchaseSupplierLabel.
  ///
  /// In en, this message translates to:
  /// **'Supplier'**
  String get reportPurchaseSupplierLabel;

  /// No description provided for @reportPurchaseSummaryTotalPurchase.
  ///
  /// In en, this message translates to:
  /// **'Total purchase'**
  String get reportPurchaseSummaryTotalPurchase;

  /// No description provided for @reportPurchaseDistributionTitle.
  ///
  /// In en, this message translates to:
  /// **'Purchase distribution'**
  String get reportPurchaseDistributionTitle;

  /// No description provided for @reportPurchaseDistributionNoData.
  ///
  /// In en, this message translates to:
  /// **'No data to visualize'**
  String get reportPurchaseDistributionNoData;

  /// No description provided for @reportPurchaseDistributionOthers.
  ///
  /// In en, this message translates to:
  /// **'Others'**
  String get reportPurchaseDistributionOthers;

  /// Shows how much percent of purchase this row contributes
  ///
  /// In en, this message translates to:
  /// **'{percentage}% of purchase'**
  String reportPurchaseTopRowPercentageOfPurchase(String percentage);

  /// No description provided for @businessSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Business settings'**
  String get businessSettingsTitle;

  /// No description provided for @businessSettingsSectionManagement.
  ///
  /// In en, this message translates to:
  /// **'Management'**
  String get businessSettingsSectionManagement;

  /// No description provided for @businessSettingsBusinessEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Business edit'**
  String get businessSettingsBusinessEditTitle;

  /// No description provided for @businessSettingsBusinessEditSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your business information'**
  String get businessSettingsBusinessEditSubtitle;

  /// No description provided for @businessSettingsStoreListTitle.
  ///
  /// In en, this message translates to:
  /// **'Store list'**
  String get businessSettingsStoreListTitle;

  /// No description provided for @businessSettingsStoreListSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your stores and locations'**
  String get businessSettingsStoreListSubtitle;

  /// No description provided for @trackingReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Tracking report'**
  String get trackingReportTitle;

  /// No description provided for @trackingReportSalesToday.
  ///
  /// In en, this message translates to:
  /// **'Sales today'**
  String get trackingReportSalesToday;

  /// No description provided for @trackingReportProductsSoldToday.
  ///
  /// In en, this message translates to:
  /// **'Products sold today'**
  String get trackingReportProductsSoldToday;

  /// Bottom navigation label for the Home tab in MainWrapper
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get mainNavHomeLabel;

  /// Bottom navigation label for the Chats tab in MainWrapper
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get mainNavChatsLabel;

  /// Bottom navigation label for the Settings tab in MainWrapper
  ///
  /// In en, this message translates to:
  /// **'Setting'**
  String get mainNavSettingsLabel;

  /// Unit for 1 million in compact currency format
  ///
  /// In en, this message translates to:
  /// **'million'**
  String get currencyUnitMillion;

  /// Unit for 1 billion in compact currency format
  ///
  /// In en, this message translates to:
  /// **'billion'**
  String get currencyUnitBillion;

  /// Unit for 1 trillion in compact currency format
  ///
  /// In en, this message translates to:
  /// **'trillion'**
  String get currencyUnitTrillion;
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
