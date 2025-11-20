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
  String get profile_section_setting => 'App Settings';

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
  String get profile_button_password => 'Change Password';

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
  String get profile_thermal_pinter => 'Thermal Printer';

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

  @override
  String get register_welcome_title => 'Let’s sign up a new account!';

  @override
  String get register_welcome_description => 'Create your account in just a few easy steps. We’ll guide you through a friendly, simple setup.';

  @override
  String get register_welcome_hint_title => 'Why create a WaveUp account?';

  @override
  String get register_welcome_hint_point1 => 'Access your business data anywhere';

  @override
  String get register_welcome_hint_point2 => 'Track your report accurately';

  @override
  String get register_welcome_hint_point3 => 'Faster checkout and insights';

  @override
  String get register_welcome_back_tooltip => 'Back to login';

  @override
  String get register_step1_device_not_ready => 'We are still preparing your device. Please try again in a moment.';

  @override
  String get register_step1_registration_failed_default => 'Registration failed. Please try again.';

  @override
  String get register_step1_primary_continue => 'Continue';

  @override
  String get register_step1_primary_create_account => 'Create account';

  @override
  String get register_step1_step1_title => 'What is your email?';

  @override
  String get register_step1_step2_title => 'Tell us about you';

  @override
  String get register_step1_step3_title => 'Create a secure password';

  @override
  String get register_step1_step4_title => 'Review and confirm';

  @override
  String get register_step1_step1_desc => 'We will use this email to create your WaveUp account and send important notifications.';

  @override
  String get register_step1_step2_desc => 'We only need your name to personalize your experience and help your team recognize you.';

  @override
  String get register_step1_step3_desc => 'Choose a strong password to keep your account and business data safe.';

  @override
  String get register_step1_step4_desc => 'Please review your details below before we create your account.';

  @override
  String get register_step1_email_label => 'Email';

  @override
  String get register_step1_email_hint => 'e.g. yourmail@mail.com';

  @override
  String get register_step1_email_required => 'Email is required';

  @override
  String get register_step1_email_invalid => 'Please enter a valid email address';

  @override
  String get register_step1_first_name_label => 'First name';

  @override
  String get register_step1_first_name_hint => 'e.g. John';

  @override
  String get register_step1_first_name_required => 'First name is required';

  @override
  String get register_step1_first_name_min_length => 'Please enter at least 2 characters';

  @override
  String get register_step1_last_name_label => 'Last name';

  @override
  String get register_step1_last_name_hint => 'e.g. Doe';

  @override
  String get register_step1_last_name_required => 'Last name is required';

  @override
  String get register_step1_last_name_min_length => 'Please enter at least 2 characters';

  @override
  String get register_step1_password_label => 'Password';

  @override
  String get register_step1_password_hint => 'Create a strong password';

  @override
  String get register_step1_password_required => 'Password is required';

  @override
  String get register_step1_password_min_length => 'Password must be at least 8 characters long';

  @override
  String get register_step1_password_rule_not_satisfied => 'Password must contain uppercase, lowercase, number, and special character';

  @override
  String get register_step1_confirm_password_label => 'Confirm password';

  @override
  String get register_step1_confirm_password_hint => 'Confirm your password';

  @override
  String get register_step1_confirm_password_required => 'Please confirm your password';

  @override
  String get register_step1_confirm_password_not_match => 'Passwords do not match';

  @override
  String get register_step1_password_info_title => 'Your password must contain:';

  @override
  String get register_step1_password_rule_8_chars => 'At least 8 characters';

  @override
  String get register_step1_password_rule_uppercase => 'At least 1 uppercase letter (A–Z)';

  @override
  String get register_step1_password_rule_lowercase => 'At least 1 lowercase letter (a–z)';

  @override
  String get register_step1_password_rule_number => 'At least 1 number (0–9)';

  @override
  String get register_step1_password_rule_special => 'At least 1 special character (e.g. !, @, #, ?)';

  @override
  String get register_step1_privacy_checkbox_text_prefix => 'By creating an account, you confirm that your details are correct and you agree to our ';

  @override
  String get register_step1_privacy_checkbox_link => 'Privacy Policy';

  @override
  String get register_step1_privacy_policy_title => 'Privacy Policy';

  @override
  String get register_step1_privacy_not_agreed_snackbar => 'Please agree to the Privacy Policy to continue.';

  @override
  String get register_step1_back_button => 'Back';

  @override
  String get register_step1_footer_have_account => 'Already have an account? ';

  @override
  String get register_step1_footer_login => 'Log in';

  @override
  String get register_step2_camera_perm_permanently_denied => 'Camera permission is permanently denied. Please enable it from Settings.';

  @override
  String get register_step2_image_too_large_prefix => 'Image size is too large';

  @override
  String get register_step2_image_too_large_suffix => 'Maximum allowed is';

  @override
  String get register_step2_pick_image_failed_prefix => 'Failed to pick image: ';

  @override
  String get register_step2_logo_from_gallery_title => 'Choose from gallery';

  @override
  String get register_step2_logo_from_gallery_subtitle => 'Recommended for existing photos';

  @override
  String get register_step2_logo_take_photo_title => 'Take a photo';

  @override
  String get register_step2_logo_take_photo_subtitle => 'Use your camera to capture a logo';

  @override
  String get register_step2_failed_default => 'Step 2 registration failed';

  @override
  String get register_step2_title => 'Set up your business';

  @override
  String get register_step2_desc => 'Tell us more about your business. This helps us personalise reports and how your brand appears to your customers.';

  @override
  String get register_step2_business_name_label => 'Business name';

  @override
  String get register_step2_business_name_hint => 'e.g. Berjaya Selalu Grocery';

  @override
  String get register_step2_business_name_required => 'Business name is required';

  @override
  String get register_step2_business_name_min_length => 'Please enter at least 2 characters';

  @override
  String get register_step2_about_label => 'About';

  @override
  String get register_step2_about_hint => 'e.g. Modern mini market focused on fresh groceries and daily needs.';

  @override
  String get register_step2_logo_label => 'Business logo';

  @override
  String get register_step2_logo_add => 'Add your business logo';

  @override
  String get register_step2_logo_selected_prefix => 'Selected: ';

  @override
  String get register_step2_logo_hint => 'JPG or PNG, up to 10MB. A clear square logo works best.';

  @override
  String get register_step2_logo_remove => 'Remove';

  @override
  String get register_step2_logo_upload => 'Upload';

  @override
  String get register_step2_finish_button => 'Finish setup';

  @override
  String get manage_report_load_error_prefix => 'Failed to load report summary: ';

  @override
  String get manage_report_appbar_title => 'Report';

  @override
  String get manage_report_section_menu_title => 'List Menu';

  @override
  String get manage_report_menu_sales => 'Report Sales';

  @override
  String get manage_report_menu_purchase => 'Report Purchase';

  @override
  String get manage_report_dashboard_title => 'Report Summary';

  @override
  String get manage_report_sales_revenue_title => 'Sales Revenue';

  @override
  String get manage_report_purchase_revenue_title => 'Purchase';

  @override
  String get manage_report_submetric_transactions => 'Transactions';

  @override
  String get manage_report_submetric_qty => 'Qty';

  @override
  String get make_order_store_location_title => 'Store Location';

  @override
  String get make_order_required_badge => 'Required';

  @override
  String get make_order_store_picker_label => 'Choose a store';

  @override
  String get make_order_store_picker_empty => 'Select store…';

  @override
  String get make_order_customer_section_title => 'Customer';

  @override
  String get make_order_customer_clear => 'Clear';

  @override
  String get make_order_customer_picker_label => 'Choose customer';

  @override
  String get make_order_customer_picker_empty => 'Select customer...';

  @override
  String get make_order_notes_section_title => 'Notes';

  @override
  String get make_order_notes_hint => 'Optional notes for this order...';

  @override
  String get make_order_cta_check_order => 'Check Order';

  @override
  String get make_order_empty_cart_message => 'No items yet. Add products from catalog.';

  @override
  String get make_order_table_col_product => 'Product';

  @override
  String get make_order_table_col_sku => 'SKU';

  @override
  String get make_order_table_col_qty => 'Qty';

  @override
  String get make_order_table_col_disc_per_item => 'Disc/Item';

  @override
  String get make_order_table_col_unit_base => 'Unit (Base)';

  @override
  String get make_order_table_col_unit_effective => 'Unit (Effective)';

  @override
  String get make_order_table_col_line_total => 'Line Total';

  @override
  String get make_order_table_action_remove => 'Remove';

  @override
  String get make_order_totals_discount_label => 'Discount';

  @override
  String get make_order_totals_total_label => 'Total';

  @override
  String get make_order_edit_ref_title => 'Edit Reference Number';

  @override
  String get make_order_edit_ref_hint => 'REF-123456';

  @override
  String get make_order_edit_ref_cancel => 'Cancel';

  @override
  String get make_order_edit_ref_save => 'Save';

  @override
  String get add_product_retry => 'Retry';

  @override
  String get add_product_select_products_title => 'Select Products';

  @override
  String get add_product_search_hint => 'Search product / SKU';

  @override
  String get add_product_no_products => 'No products found';

  @override
  String get add_product_footer_hint_empty => 'Select products then set their variants';

  @override
  String add_product_footer_hint_selected(int skuCount, int qtyCount) {
    return '$skuCount SKU • $qtyCount qty';
  }

  @override
  String get add_product_use_selected_button => 'Use selected';

  @override
  String get common_close => 'Close';

  @override
  String add_product_selected_semantics(int count) {
    return 'Selected $count';
  }

  @override
  String get add_product_empty_stock_label => 'Empty Stock';

  @override
  String add_product_price_from_label(String price) {
    return 'from Rp $price';
  }

  @override
  String get add_product_unavailable_button => 'Unavailable';

  @override
  String get add_product_choose_button => 'Choose';

  @override
  String get variant_sheet_title => 'Choose Variants';

  @override
  String variant_stock_label(int stock) {
    return 'Stock: $stock';
  }

  @override
  String variant_in_cart_label(int qty) {
    return 'In cart: $qty';
  }

  @override
  String get variant_quantity_label => 'Quantity';

  @override
  String get variant_cta_select_all_variants => 'Select all variants';

  @override
  String get variant_cta_stock_empty => 'Out of stock';

  @override
  String variant_cta_add_to_cart(String price) {
    return 'Add to cart — Rp $price';
  }

  @override
  String get manageProductTitle => 'Manage Product';

  @override
  String get manageProductListMenuLabel => 'List Menu';

  @override
  String get manageProductProductList => 'Product List';

  @override
  String get manageProductBrandList => 'Brand List';

  @override
  String get manageProductCategoryList => 'Category List';

  @override
  String get productDetailTitle => 'Product Detail';

  @override
  String get productDetailBackTooltip => 'Back';

  @override
  String get productDetailDescriptionSectionTitle => 'Description';

  @override
  String get productDetailPricesWholesaleTitle => 'Prices (Wholesale tiers)';

  @override
  String productDetailPriceRowMin(int minQty) {
    return 'Min. $minQty pcs';
  }

  @override
  String get productDetailSkuSectionTitle => 'SKU';

  @override
  String get productDetailDeleteSuccess => 'Product deleted';

  @override
  String get productDetailDeleteFailed => 'Failed to delete';

  @override
  String get productDetailDeleteButton => 'Delete';

  @override
  String get productDetailEditButton => 'Edit Product';

  @override
  String get productDetailHiddenLabel => 'Hidden';

  @override
  String get productDetailOpenStock => 'Open stock';

  @override
  String get productDetailImageViewerCloseTooltip => 'Close';

  @override
  String get salesTitle => 'Sales';

  @override
  String get salesHistorySuffix => '/history';

  @override
  String get salesSearchHint => 'Search code / reference / status';

  @override
  String get salesDateApply => 'Apply';

  @override
  String get salesFilterAnyTime => 'Any time';

  @override
  String get salesStoreAll => 'All stores';

  @override
  String salesStoreLabelWithName(String storeName) {
    return 'Store: $storeName';
  }

  @override
  String get salesStoreLabelAll => 'Store: All';

  @override
  String get salesTotalAmount => 'Total amount';

  @override
  String get salesQuantity => 'Quantity';

  @override
  String get salesErrorTitle => 'Failed to load sales';

  @override
  String get salesErrorRetry => 'Retry';

  @override
  String get salesEmptyTitle => 'No sales yet';

  @override
  String get salesEmptySubtitle => 'Pull down to refresh.';

  @override
  String get salesAddButton => 'Add sales';

  @override
  String get reportSalesTitle => 'Sales report';

  @override
  String get reportSalesCustomerLabel => 'Customer';

  @override
  String get reportCommonRefresh => 'Refresh';

  @override
  String get reportDateRangeHelp => 'Choose date range';

  @override
  String get reportDateRangeApply => 'Apply range';

  @override
  String get reportFilterTarget => 'Target';

  @override
  String get reportFilterGranularity => 'Granularity';

  @override
  String get reportFilterCustomRange => 'Custom date range';

  @override
  String get reportFilterToggleOn => 'On';

  @override
  String get reportFilterToggleOff => 'Off';

  @override
  String get reportFilterPickDateRange => 'Pick date range';

  @override
  String get reportSummaryTotalRevenue => 'Total revenue';

  @override
  String get reportSummaryTotalQty => 'Total qty';

  @override
  String get reportSummaryTotalTransactions => 'Total transactions';

  @override
  String get reportSortLabel => 'Sort:';

  @override
  String get reportSortPeriod => 'Period';

  @override
  String get reportSortTransactions => 'Transactions';

  @override
  String get reportSortQty => 'Qty';

  @override
  String get reportSortRevenue => 'Revenue';

  @override
  String get reportSortName => 'Name';

  @override
  String get reportSortDescendingTooltip => 'Descending';

  @override
  String get reportSortAscendingTooltip => 'Ascending';

  @override
  String get reportDistributionTitle => 'Revenue distribution';

  @override
  String get reportDistributionNoData => 'No data to visualize';

  @override
  String get reportDistributionOthers => 'Others';

  @override
  String reportTop5CustomerTitle(String customerLabel) {
    return 'Top 5 $customerLabel';
  }

  @override
  String get reportTop5ProductsTitle => 'Top 5 products';

  @override
  String get reportTop5CategoriesTitle => 'Top 5 categories';

  @override
  String get reportTop5BrandsTitle => 'Top 5 brands';

  @override
  String get reportTop5PeriodsTitle => 'Top 5 periods';

  @override
  String get reportTop5Empty => 'No data yet';

  @override
  String get reportTopRowUnnamed => 'Unnamed';

  @override
  String reportTopRowPercentageOfRevenue(String percentage) {
    return '$percentage% of revenue';
  }

  @override
  String reportDetailsByCustomerLabel(String customerLabel) {
    return 'Details by $customerLabel';
  }

  @override
  String get reportDetailsByProduct => 'Details by product';

  @override
  String get reportDetailsByCategory => 'Details by category';

  @override
  String get reportDetailsByBrand => 'Details by brand';

  @override
  String get reportDetailsByPeriod => 'Details by period';

  @override
  String get reportTableColumnQty => 'Qty';

  @override
  String get reportTableColumnRevenue => 'Revenue';

  @override
  String get reportTableColumnAvgTx => 'Avg/Tx';

  @override
  String get reportTableColumnPeriod => 'Period';

  @override
  String get reportTableColumnTransactions => 'Transactions';

  @override
  String reportTableSkuPrefix(String sku) {
    return 'SKU: $sku';
  }

  @override
  String reportTablePhonePrefix(String phone) {
    return 'Phone: $phone';
  }

  @override
  String reportRangeChipLabel(String start, String end) {
    return 'Range: $start — $end';
  }

  @override
  String get reportDetailsTitle => 'Details';

  @override
  String get reportPurchaseTitle => 'Purchase report';

  @override
  String get reportPurchaseSupplierLabel => 'Supplier';

  @override
  String get reportPurchaseSummaryTotalPurchase => 'Total purchase';

  @override
  String get reportPurchaseDistributionTitle => 'Purchase distribution';

  @override
  String get reportPurchaseDistributionNoData => 'No data to visualize';

  @override
  String get reportPurchaseDistributionOthers => 'Others';

  @override
  String reportPurchaseTopRowPercentageOfPurchase(String percentage) {
    return '$percentage% of purchase';
  }

  @override
  String get businessSettingsTitle => 'Business settings';

  @override
  String get businessSettingsSectionManagement => 'Management';

  @override
  String get businessSettingsBusinessEditTitle => 'Business edit';

  @override
  String get businessSettingsBusinessEditSubtitle => 'Manage your business information';

  @override
  String get businessSettingsStoreListTitle => 'Store list';

  @override
  String get businessSettingsStoreListSubtitle => 'Manage your stores and locations';

  @override
  String get trackingReportTitle => 'Tracking report';

  @override
  String get trackingReportSalesToday => 'Sales today';

  @override
  String get trackingReportProductsSoldToday => 'Products sold today';
}
