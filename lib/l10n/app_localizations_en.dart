// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get refresh_success => 'Data updated';

  @override
  String get refresh_failed => 'Failed to refresh';

  @override
  String get previewReport_title => 'Preview Report';

  @override
  String get income_day => 'Income this day';

  @override
  String get income_month => 'Income this month';

  @override
  String get income_year => 'Income this year';

  @override
  String get header_account_caption => 'Account User';

  @override
  String get header_business_caption => 'Business';

  @override
  String get snackbar_business_switch_success => 'Active business updated successfully';

  @override
  String get grid_hr => 'HR';

  @override
  String get grid_product => 'Product';

  @override
  String get grid_sales => 'Sales';

  @override
  String get grid_purchase => 'Purchase';

  @override
  String get grid_report => 'Report';

  @override
  String get grid_setting => 'Setting';

  @override
  String get sheet_switch_business_title => 'Switch Business';

  @override
  String get sheet_no_business => 'No business found';

  @override
  String sheet_business_id_label(String username) {
    return 'id: $username';
  }

  @override
  String get login_username => 'Username';

  @override
  String get login_username_hint => 'E.g user0001@gmail.com';

  @override
  String get login_password => 'Password';

  @override
  String get login_password_hint => 'Fill your password here';

  @override
  String get login_forgot_password => 'Forgot password?';

  @override
  String get login_button => 'Login';

  @override
  String get login_button_loading => 'Logging in…';

  @override
  String get login_no_account => 'Don’t have account? ';

  @override
  String get login_register_now => 'Register Now';

  @override
  String get login_empty_fields => 'Username and password cannot be empty';

  @override
  String get login_failed => 'Login failed';

  @override
  String get profile_appbar_title => 'Other Menu';

  @override
  String get profile_action_switch_account => 'Switch Account';

  @override
  String get profile_section_setting => 'Setting';

  @override
  String get profile_section_others => 'Others';

  @override
  String get profile_menu_account => 'Account';

  @override
  String get profile_menu_help => 'Help';

  @override
  String get profile_menu_terms => 'Terms & Conditions';

  @override
  String get profile_menu_privacy => 'Privacy Policy';

  @override
  String get profile_button_logout => 'Logout Account';

  @override
  String get dialog_add_account_title => 'Add another account?';

  @override
  String get dialog_add_account_message => 'Do you want to add another account? You can log in and switch accounts anytime.';

  @override
  String get dialog_add_account_cancel => 'Cancel';

  @override
  String get dialog_add_account_confirm => 'Yes, add';

  @override
  String get sheet_switch_account_title => 'Switch Account';

  @override
  String get sheet_add_another_account => 'Add another account';

  @override
  String get sheet_active_badge => 'Active';

  @override
  String get sheet_name_not_found => 'Name not found';

  @override
  String get sheet_switch_account_failed => 'Failed to switch account';

  @override
  String get profile_menu_language => 'Language';

  @override
  String get language_sheet_title => 'Change Language';

  @override
  String get language_use_system => 'Use system language';

  @override
  String get language_english => 'English';

  @override
  String get language_indonesian => 'Indonesian';

  @override
  String get language_switched => 'Language updated';

  @override
  String get language_cancel => 'Cancel';
}
