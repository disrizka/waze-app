// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get refresh_success => 'Data berhasil diperbarui';

  @override
  String get refresh_failed => 'Gagal memuat ulang';

  @override
  String get previewReport_title => 'Pratinjau Laporan';

  @override
  String get income_day => 'Pendapatan hari ini';

  @override
  String get income_month => 'Pendapatan bulan ini';

  @override
  String get income_year => 'Pendapatan tahun ini';

  @override
  String get header_account_caption => 'Pengguna Akun';

  @override
  String get header_business_caption => 'Bisnis';

  @override
  String get snackbar_business_switch_success => 'Bisnis aktif berhasil diperbarui';

  @override
  String get grid_hr => 'HR';

  @override
  String get grid_product => 'Produk';

  @override
  String get grid_sales => 'Penjualan';

  @override
  String get grid_purchase => 'Pembelian';

  @override
  String get grid_report => 'Laporan';

  @override
  String get grid_setting => 'Pengaturan';

  @override
  String get sheet_switch_business_title => 'Ganti Bisnis';

  @override
  String get sheet_no_business => 'Tidak ada bisnis';

  @override
  String sheet_business_id_label(String username) {
    return 'id: $username';
  }

  @override
  String get login_username => 'Nama Pengguna';

  @override
  String get login_username_hint => 'Mis. user0001@gmail.com';

  @override
  String get login_password => 'Kata Sandi';

  @override
  String get login_password_hint => 'Isi kata sandi Anda di sini';

  @override
  String get login_forgot_password => 'Lupa kata sandi?';

  @override
  String get login_button => 'Masuk';

  @override
  String get login_button_loading => 'Sedang masuk…';

  @override
  String get login_no_account => 'Belum punya akun? ';

  @override
  String get login_register_now => 'Daftar Sekarang';

  @override
  String get login_empty_fields => 'Nama pengguna dan kata sandi tidak boleh kosong';

  @override
  String get login_failed => 'Login gagal';

  @override
  String get profile_appbar_title => 'Menu Lainnya';

  @override
  String get profile_action_switch_account => 'Ganti Akun';

  @override
  String get profile_section_setting => 'Pengaturan';

  @override
  String get profile_section_others => 'Lainnya';

  @override
  String get profile_menu_account => 'Akun';

  @override
  String get profile_menu_help => 'Bantuan';

  @override
  String get profile_menu_terms => 'Syarat & Ketentuan';

  @override
  String get profile_menu_privacy => 'Kebijakan Privasi';

  @override
  String get profile_button_logout => 'Keluar Akun';

  @override
  String get profile_button_password => 'Ganti Kata Sandi';

  @override
  String get dialog_add_account_title => 'Tambah Akun Lainnya?';

  @override
  String get dialog_add_account_message => 'Apakah kamu ingin menambahkan akun lainnya? Kamu bisa login dan berpindah akun kapan saja.';

  @override
  String get dialog_add_account_cancel => 'Batal';

  @override
  String get dialog_add_account_confirm => 'Ya, Tambahkan';

  @override
  String get sheet_switch_account_title => 'Ganti Akun';

  @override
  String get sheet_add_another_account => 'Tambahkan Akun Lainnya';

  @override
  String get sheet_active_badge => 'Aktif';

  @override
  String get sheet_name_not_found => 'Nama tidak ditemukan';

  @override
  String get sheet_switch_account_failed => 'Gagal switch akun';

  @override
  String get profile_menu_language => 'Bahasa';

  @override
  String get profile_menu_check_updates => 'Cek pembaruan';

  @override
  String get profile_menu_checking_updates => 'Memeriksa pembaruan...';

  @override
  String get profile_thermal_pinter => 'Printer Thermal';

  @override
  String get profile_update_title_available => 'Pembaruan tersedia';

  @override
  String get profile_update_title_latest => 'Aplikasi sudah versi terbaru';

  @override
  String get profile_update_title_unavailable => 'Cek pembaruan tidak tersedia';

  @override
  String get profile_update_msg_available => 'Versi aplikasi yang lebih baru tersedia.';

  @override
  String get profile_update_msg_latest => 'Aplikasi kamu sudah menggunakan versi terbaru.';

  @override
  String get profile_update_msg_unavailable => 'Saat ini pembaruan belum bisa diperiksa. Coba lagi nanti.';

  @override
  String get profile_update_label_current => 'Versi saat ini';

  @override
  String get profile_update_label_latest => 'Versi terbaru';

  @override
  String get profile_update_btn_later => 'Nanti';

  @override
  String get profile_update_btn_update_now => 'Perbarui sekarang';

  @override
  String get profile_update_btn_ok => 'OK';

  @override
  String get language_sheet_title => 'Ubah Bahasa';

  @override
  String get language_use_system => 'Ikuti bahasa sistem';

  @override
  String get language_english => 'Inggris';

  @override
  String get language_indonesian => 'Indonesia';

  @override
  String get language_switched => 'Bahasa diperbarui';

  @override
  String get language_cancel => 'Batal';

  @override
  String get register_welcome_title => 'Yuk daftar akun baru!';

  @override
  String get register_welcome_description => 'Buat akunmu hanya dalam beberapa langkah mudah. Kami akan memandu kamu dengan proses yang ramah dan sederhana.';

  @override
  String get register_welcome_hint_title => 'Kenapa perlu membuat akun WaveUp?';

  @override
  String get register_welcome_hint_point1 => 'Akses data bisnismu dari mana saja';

  @override
  String get register_welcome_hint_point2 => 'Pantau laporan dengan lebih akurat';

  @override
  String get register_welcome_hint_point3 => 'Proses checkout lebih cepat dan insight lebih jelas';

  @override
  String get register_welcome_back_tooltip => 'Kembali ke login';

  @override
  String get register_step1_device_not_ready => 'Kami masih menyiapkan perangkatmu. Silakan coba lagi sebentar lagi.';

  @override
  String get register_step1_registration_failed_default => 'Pendaftaran gagal. Silakan coba lagi.';

  @override
  String get register_step1_primary_continue => 'Lanjut';

  @override
  String get register_step1_primary_create_account => 'Buat akun';

  @override
  String get register_step1_step1_title => 'Apa email kamu?';

  @override
  String get register_step1_step2_title => 'Ceritakan tentang kamu';

  @override
  String get register_step1_step3_title => 'Buat kata sandi yang aman';

  @override
  String get register_step1_step4_title => 'Tinjau dan konfirmasi';

  @override
  String get register_step1_step1_desc => 'Kami akan menggunakan email ini untuk membuat akun WaveUp kamu dan mengirimkan notifikasi penting.';

  @override
  String get register_step1_step2_desc => 'Kami hanya membutuhkan namamu untuk mempersonalisasi pengalaman dan membantu tim mengenalmu.';

  @override
  String get register_step1_step3_desc => 'Pilih kata sandi yang kuat agar akun dan data bisnismu tetap aman.';

  @override
  String get register_step1_step4_desc => 'Silakan tinjau kembali detail di bawah ini sebelum kami membuat akunmu.';

  @override
  String get register_step1_email_label => 'Email';

  @override
  String get register_step1_email_hint => 'mis. yourmail@mail.com';

  @override
  String get register_step1_email_required => 'Email wajib diisi';

  @override
  String get register_step1_email_invalid => 'Silakan masukkan alamat email yang valid';

  @override
  String get register_step1_first_name_label => 'Nama depan';

  @override
  String get register_step1_first_name_hint => 'mis. John';

  @override
  String get register_step1_first_name_required => 'Nama depan wajib diisi';

  @override
  String get register_step1_first_name_min_length => 'Silakan masukkan minimal 2 karakter';

  @override
  String get register_step1_last_name_label => 'Nama belakang';

  @override
  String get register_step1_last_name_hint => 'mis. Doe';

  @override
  String get register_step1_last_name_required => 'Nama belakang wajib diisi';

  @override
  String get register_step1_last_name_min_length => 'Silakan masukkan minimal 2 karakter';

  @override
  String get register_step1_password_label => 'Kata sandi';

  @override
  String get register_step1_password_hint => 'Buat kata sandi yang kuat';

  @override
  String get register_step1_password_required => 'Kata sandi wajib diisi';

  @override
  String get register_step1_password_min_length => 'Kata sandi minimal 8 karakter';

  @override
  String get register_step1_password_rule_not_satisfied => 'Kata sandi harus mengandung huruf besar, huruf kecil, angka, dan karakter khusus';

  @override
  String get register_step1_confirm_password_label => 'Konfirmasi kata sandi';

  @override
  String get register_step1_confirm_password_hint => 'Ulangi kata sandi kamu';

  @override
  String get register_step1_confirm_password_required => 'Silakan konfirmasi kata sandi kamu';

  @override
  String get register_step1_confirm_password_not_match => 'Kata sandi tidak sama';

  @override
  String get register_step1_password_info_title => 'Kata sandi kamu harus berisi:';

  @override
  String get register_step1_password_rule_8_chars => 'Minimal 8 karakter';

  @override
  String get register_step1_password_rule_uppercase => 'Minimal 1 huruf besar (A–Z)';

  @override
  String get register_step1_password_rule_lowercase => 'Minimal 1 huruf kecil (a–z)';

  @override
  String get register_step1_password_rule_number => 'Minimal 1 angka (0–9)';

  @override
  String get register_step1_password_rule_special => 'Minimal 1 karakter khusus (contoh: !, @, #, ?)';

  @override
  String get register_step1_privacy_checkbox_text_prefix => 'Dengan membuat akun, kamu mengonfirmasi bahwa datamu sudah benar dan kamu menyetujui ';

  @override
  String get register_step1_privacy_checkbox_link => 'Kebijakan Privasi';

  @override
  String get register_step1_privacy_policy_title => 'Kebijakan Privasi';

  @override
  String get register_step1_privacy_not_agreed_snackbar => 'Silakan setujui Kebijakan Privasi untuk melanjutkan.';

  @override
  String get register_step1_back_button => 'Kembali';

  @override
  String get register_step1_footer_have_account => 'Sudah punya akun? ';

  @override
  String get register_step1_footer_login => 'Masuk';

  @override
  String get register_step2_camera_perm_permanently_denied => 'Izin kamera ditolak secara permanen. Silakan aktifkan dari Pengaturan.';

  @override
  String get register_step2_image_too_large_prefix => 'Ukuran gambar terlalu besar';

  @override
  String get register_step2_image_too_large_suffix => 'Maksimal yang diperbolehkan adalah';

  @override
  String get register_step2_pick_image_failed_prefix => 'Gagal memilih gambar: ';

  @override
  String get register_step2_logo_from_gallery_title => 'Pilih dari galeri';

  @override
  String get register_step2_logo_from_gallery_subtitle => 'Disarankan untuk foto yang sudah ada';

  @override
  String get register_step2_logo_take_photo_title => 'Ambil foto';

  @override
  String get register_step2_logo_take_photo_subtitle => 'Gunakan kamera untuk mengambil logo';

  @override
  String get register_step2_failed_default => 'Pendaftaran langkah 2 gagal';

  @override
  String get register_step2_title => 'Atur bisnismu';

  @override
  String get register_step2_desc => 'Beritahu kami lebih banyak tentang bisnismu. Ini membantu kami mempersonalisasi laporan dan bagaimana brand-mu tampil ke pelanggan.';

  @override
  String get register_step2_business_name_label => 'Nama bisnis';

  @override
  String get register_step2_business_name_hint => 'mis. Berjaya Selalu Grocery';

  @override
  String get register_step2_business_name_required => 'Nama bisnis wajib diisi';

  @override
  String get register_step2_business_name_min_length => 'Silakan masukkan minimal 2 karakter';

  @override
  String get register_step2_about_label => 'Tentang bisnis (opsional)';

  @override
  String get register_step2_about_hint => 'mis. Minimarket modern yang fokus pada kebutuhan harian dan bahan segar.';

  @override
  String get register_step2_logo_label => 'Logo bisnis';

  @override
  String get register_step2_logo_add => 'Tambahkan logo bisnismu';

  @override
  String get register_step2_logo_selected_prefix => 'Dipilih: ';

  @override
  String get register_step2_logo_hint => 'JPG atau PNG, maksimal 10MB. Logo persegi yang jelas akan terlihat paling baik.';

  @override
  String get register_step2_logo_remove => 'Hapus';

  @override
  String get register_step2_logo_upload => 'Unggah';

  @override
  String get register_step2_finish_button => 'Selesaikan pengaturan';

  @override
  String get manage_report_load_error_prefix => 'Gagal memuat ringkasan laporan: ';

  @override
  String get manage_report_appbar_title => 'Laporan';

  @override
  String get manage_report_section_menu_title => 'Daftar Menu';

  @override
  String get manage_report_menu_sales => 'Laporan Penjualan';

  @override
  String get manage_report_menu_purchase => 'Laporan Pembelian';

  @override
  String get manage_report_dashboard_title => 'Ringkasan Laporan';

  @override
  String get manage_report_sales_revenue_title => 'Pendapatan Penjualan';

  @override
  String get manage_report_purchase_revenue_title => 'Pembelian';

  @override
  String get manage_report_submetric_transactions => 'Transaksi';

  @override
  String get manage_report_submetric_qty => 'Qty';

  @override
  String get make_order_store_location_title => 'Lokasi Toko';

  @override
  String get make_order_required_badge => 'Wajib';

  @override
  String get make_order_store_picker_label => 'Pilih toko';

  @override
  String get make_order_store_picker_empty => 'Pilih toko…';

  @override
  String get make_order_customer_section_title => 'Pelanggan';

  @override
  String get make_order_customer_clear => 'Bersihkan';

  @override
  String get make_order_customer_picker_label => 'Pilih pelanggan';

  @override
  String get make_order_customer_picker_empty => 'Pilih pelanggan...';

  @override
  String get make_order_notes_section_title => 'Catatan';

  @override
  String get make_order_notes_hint => 'Catatan tambahan untuk pesanan ini (opsional)...';

  @override
  String get make_order_cta_check_order => 'Periksa Pesanan';

  @override
  String get make_order_empty_cart_message => 'Belum ada item. Tambahkan produk dari katalog.';

  @override
  String get make_order_table_col_product => 'Produk';

  @override
  String get make_order_table_col_sku => 'SKU';

  @override
  String get make_order_table_col_qty => 'Qty';

  @override
  String get make_order_table_col_disc_per_item => 'Diskon/Item';

  @override
  String get make_order_table_col_unit_base => 'Harga dasar';

  @override
  String get make_order_table_col_unit_effective => 'Harga efektif';

  @override
  String get make_order_table_col_line_total => 'Total baris';

  @override
  String get make_order_table_action_remove => 'Hapus';

  @override
  String get make_order_totals_discount_label => 'Diskon';

  @override
  String get make_order_totals_total_label => 'Total';

  @override
  String get make_order_edit_ref_title => 'Ubah Nomor Referensi';

  @override
  String get make_order_edit_ref_hint => 'REF-123456';

  @override
  String get make_order_edit_ref_cancel => 'Batal';

  @override
  String get make_order_edit_ref_save => 'Simpan';

  @override
  String get add_product_retry => 'Coba lagi';

  @override
  String get add_product_select_products_title => 'Pilih Produk';

  @override
  String get add_product_search_hint => 'Cari produk / SKU';

  @override
  String get add_product_no_products => 'Produk tidak ditemukan';

  @override
  String get add_product_footer_hint_empty => 'Pilih produk lalu tentukan variannya';

  @override
  String add_product_footer_hint_selected(int skuCount, int qtyCount) {
    return '$skuCount SKU • $qtyCount qty';
  }

  @override
  String get add_product_use_selected_button => 'Gunakan yang dipilih';

  @override
  String get common_close => 'Tutup';

  @override
  String add_product_selected_semantics(int count) {
    return 'Dipilih $count';
  }

  @override
  String get add_product_empty_stock_label => 'Stok habis';

  @override
  String add_product_price_from_label(String price) {
    return 'mulai Rp $price';
  }

  @override
  String get add_product_unavailable_button => 'Tidak tersedia';

  @override
  String get add_product_choose_button => 'Pilih';

  @override
  String get variant_sheet_title => 'Pilih Varian';

  @override
  String variant_stock_label(int stock) {
    return 'Stok: $stock';
  }

  @override
  String variant_in_cart_label(int qty) {
    return 'Di keranjang: $qty';
  }

  @override
  String get variant_quantity_label => 'Jumlah';

  @override
  String get variant_cta_select_all_variants => 'Pilih semua varian';

  @override
  String get variant_cta_stock_empty => 'Stok habis';

  @override
  String variant_cta_add_to_cart(String price) {
    return 'Tambah ke keranjang — Rp $price';
  }

  @override
  String get manageProductTitle => 'Kelola Produk';

  @override
  String get manageProductListMenuLabel => 'Daftar Menu';

  @override
  String get manageProductProductList => 'Daftar Produk';

  @override
  String get manageProductBrandList => 'Daftar Merek';

  @override
  String get manageProductCategoryList => 'Daftar Kategori';

  @override
  String get productDetailTitle => 'Detail Produk';

  @override
  String get productDetailBackTooltip => 'Kembali';

  @override
  String get productDetailDescriptionSectionTitle => 'Deskripsi';

  @override
  String get productDetailPricesWholesaleTitle => 'Harga (Grosir)';

  @override
  String productDetailPriceRowMin(int minQty) {
    return 'Min. $minQty pcs';
  }

  @override
  String get productDetailSkuSectionTitle => 'SKU';

  @override
  String get productDetailDeleteSuccess => 'Produk berhasil dihapus';

  @override
  String get productDetailDeleteFailed => 'Gagal menghapus produk';

  @override
  String get productDetailDeleteButton => 'Hapus';

  @override
  String get productDetailEditButton => 'Edit Produk';

  @override
  String get productDetailHiddenLabel => 'Disembunyikan';

  @override
  String get productDetailOpenStock => 'Buka stok';

  @override
  String get productDetailImageViewerCloseTooltip => 'Tutup';

  @override
  String get salesTitle => 'Penjualan';

  @override
  String get salesHistorySuffix => '/riwayat';

  @override
  String get salesSearchHint => 'Cari kode / referensi / status';

  @override
  String get salesDateApply => 'Terapkan';

  @override
  String get salesFilterAnyTime => 'Kapan saja';

  @override
  String get salesStoreAll => 'Semua toko';

  @override
  String salesStoreLabelWithName(String storeName) {
    return 'Toko: $storeName';
  }

  @override
  String get salesStoreLabelAll => 'Toko: Semua';

  @override
  String get salesTotalAmount => 'Total penjualan';

  @override
  String get salesQuantity => 'Kuantitas';

  @override
  String get salesErrorTitle => 'Gagal memuat data penjualan';

  @override
  String get salesErrorRetry => 'Coba lagi';

  @override
  String get salesEmptyTitle => 'Belum ada penjualan';

  @override
  String get salesEmptySubtitle => 'Tarik ke bawah untuk memuat ulang.';

  @override
  String get salesAddButton => 'Tambah penjualan';

  @override
  String get reportSalesTitle => 'Laporan penjualan';

  @override
  String get reportSalesCustomerLabel => 'Pelanggan';

  @override
  String get reportCommonRefresh => 'Muat ulang';

  @override
  String get reportDateRangeHelp => 'Pilih rentang tanggal';

  @override
  String get reportDateRangeApply => 'Pakai rentang';

  @override
  String get reportFilterTarget => 'Target';

  @override
  String get reportFilterGranularity => 'Granularitas';

  @override
  String get reportFilterCustomRange => 'Rentang tanggal khusus';

  @override
  String get reportFilterToggleOn => 'Aktif';

  @override
  String get reportFilterToggleOff => 'Nonaktif';

  @override
  String get reportFilterPickDateRange => 'Pilih rentang tanggal';

  @override
  String get reportSummaryTotalRevenue => 'Total pendapatan';

  @override
  String get reportSummaryTotalQty => 'Total kuantitas';

  @override
  String get reportSummaryTotalTransactions => 'Total transaksi';

  @override
  String get reportSortLabel => 'Urut:';

  @override
  String get reportSortPeriod => 'Periode';

  @override
  String get reportSortTransactions => 'Transaksi';

  @override
  String get reportSortQty => 'Qty';

  @override
  String get reportSortRevenue => 'Pendapatan';

  @override
  String get reportSortName => 'Nama';

  @override
  String get reportSortDescendingTooltip => 'Menurun';

  @override
  String get reportSortAscendingTooltip => 'Menaik';

  @override
  String get reportDistributionTitle => 'Distribusi pendapatan';

  @override
  String get reportDistributionNoData => 'Belum ada data untuk ditampilkan';

  @override
  String get reportDistributionOthers => 'Lainnya';

  @override
  String reportTop5CustomerTitle(String customerLabel) {
    return '5 $customerLabel teratas';
  }

  @override
  String get reportTop5ProductsTitle => '5 produk teratas';

  @override
  String get reportTop5CategoriesTitle => '5 kategori teratas';

  @override
  String get reportTop5BrandsTitle => '5 merek teratas';

  @override
  String get reportTop5PeriodsTitle => '5 periode teratas';

  @override
  String get reportTop5Empty => 'Belum ada data';

  @override
  String get reportTopRowUnnamed => 'Tanpa nama';

  @override
  String reportTopRowPercentageOfRevenue(String percentage) {
    return '$percentage% dari pendapatan';
  }

  @override
  String reportDetailsByCustomerLabel(String customerLabel) {
    return 'Detail per $customerLabel';
  }

  @override
  String get reportDetailsByProduct => 'Detail per produk';

  @override
  String get reportDetailsByCategory => 'Detail per kategori';

  @override
  String get reportDetailsByBrand => 'Detail per merek';

  @override
  String get reportDetailsByPeriod => 'Detail per periode';

  @override
  String get reportTableColumnQty => 'Qty';

  @override
  String get reportTableColumnRevenue => 'Pendapatan';

  @override
  String get reportTableColumnAvgTx => 'Rata2/transaksi';

  @override
  String get reportTableColumnPeriod => 'Periode';

  @override
  String get reportTableColumnTransactions => 'Transaksi';

  @override
  String reportTableSkuPrefix(String sku) {
    return 'SKU: $sku';
  }

  @override
  String reportTablePhonePrefix(String phone) {
    return 'Telepon: $phone';
  }

  @override
  String reportRangeChipLabel(String start, String end) {
    return 'Rentang: $start — $end';
  }

  @override
  String get reportDetailsTitle => 'Detail';

  @override
  String get reportPurchaseTitle => 'Laporan pembelian';

  @override
  String get reportPurchaseSupplierLabel => 'Supplier';

  @override
  String get reportPurchaseSummaryTotalPurchase => 'Total pembelian';

  @override
  String get reportPurchaseDistributionTitle => 'Distribusi pembelian';

  @override
  String get reportPurchaseDistributionNoData => 'Belum ada data untuk ditampilkan';

  @override
  String get reportPurchaseDistributionOthers => 'Lainnya';

  @override
  String reportPurchaseTopRowPercentageOfPurchase(String percentage) {
    return '$percentage% dari pembelian';
  }

  @override
  String get businessSettingsTitle => 'Pengaturan bisnis';

  @override
  String get businessSettingsSectionManagement => 'Manajemen';

  @override
  String get businessSettingsBusinessEditTitle => 'Edit bisnis';

  @override
  String get businessSettingsBusinessEditSubtitle => 'Kelola informasi bisnis Anda';

  @override
  String get businessSettingsStoreListTitle => 'Daftar toko';

  @override
  String get businessSettingsStoreListSubtitle => 'Kelola toko dan lokasi Anda';

  @override
  String get trackingReportTitle => 'Ringkasan penjualan';

  @override
  String get trackingReportSalesToday => 'Penjualan hari ini';

  @override
  String get trackingReportProductsSoldToday => 'Produk terjual hari ini';

  @override
  String get mainNavHomeLabel => 'Beranda';

  @override
  String get mainNavChatsLabel => 'Chat';

  @override
  String get mainNavSettingsLabel => 'Pengaturan';

  @override
  String get stockHistoryTitle => 'Riwayat Stok';

  @override
  String get stockHistoryGuideTooltip => 'Panduan riwayat';

  @override
  String get stockHistoryNoSkuMessage => 'Produk ini belum punya SKU.\nTambahkan SKU terlebih dahulu untuk melihat riwayat stok.';

  @override
  String get stockHistorySelectSkuTitle => 'Pilih SKU';

  @override
  String get stockHistorySelectSkuSearchHint => 'Cari SKU atau varian…';

  @override
  String get stockHistorySelectSkuEmpty => 'Tidak ada SKU untuk produk ini';

  @override
  String get stockHistoryFilterButton => 'Filter';

  @override
  String get stockHistoryFilterSheetTitle => 'Filter Lanjutan';

  @override
  String get stockHistoryFilterReset => 'Reset';

  @override
  String get stockHistoryFilterTypeLabel => 'Tipe';

  @override
  String get stockHistoryFilterSortLabel => 'Urutkan';

  @override
  String get stockHistoryFilterTypeAll => 'Semua';

  @override
  String get stockHistoryFilterTypeIn => 'Masuk';

  @override
  String get stockHistoryFilterTypeOut => 'Keluar';

  @override
  String get stockHistoryFilterNewest => 'Terbaru';

  @override
  String get stockHistoryFilterOldest => 'Terlama';

  @override
  String get stockHistoryFilterDateLabel => 'Tanggal';

  @override
  String get stockHistoryFilterDateFromLabel => 'Dari';

  @override
  String get stockHistoryFilterDateToLabel => 'Sampai';

  @override
  String get stockHistoryFilterDatePickHint => 'Pilih tanggal';

  @override
  String get stockHistoryFilterDatePresetLast7Days => '7 Hari Terakhir';

  @override
  String get stockHistoryFilterDatePresetThisMonth => 'Bulan Ini';

  @override
  String get stockHistoryFilterDatePickerHelp => 'Pilih tanggal';

  @override
  String get stockHistoryFilterCancel => 'Batal';

  @override
  String get stockHistoryFilterApply => 'Terapkan';

  @override
  String get stockHistoryGuideAppbarTitle => 'Panduan Singkat: Riwayat Stok';

  @override
  String get stockHistoryGuideAppbarSubtitle => 'Petunjuk sederhana agar setiap baris mudah dipahami.';

  @override
  String get stockHistoryGuideSlide1Title => 'Pahami ikon transaksi';

  @override
  String get stockHistoryGuideSlide1Subtitle => 'Ikon di sisi kiri setiap kartu menunjukkan jenis pergerakan stok secara cepat.';

  @override
  String get stockHistoryGuideSlide1BadgeSalesOutbound => 'Penjualan / Keluar';

  @override
  String get stockHistoryGuideSlide1BadgePurchaseInbound => 'Pembelian / Masuk';

  @override
  String get stockHistoryGuideSlide1BadgeStockOpname => 'Stok Opname';

  @override
  String get stockHistoryGuideSlide1PointOutbound => 'Merah menandakan pergerakan stok keluar dari penjualan.';

  @override
  String get stockHistoryGuideSlide1PointInbound => 'Hijau menandakan pergerakan stok masuk dari pembelian.';

  @override
  String get stockHistoryGuideSlide1PointAdjustment => 'Biru menandakan penyesuaian dari stok opname.';

  @override
  String get stockHistoryGuideTagOutbound => 'Keluar';

  @override
  String get stockHistoryGuideTagInbound => 'Masuk';

  @override
  String get stockHistoryGuideTagAdjustment => 'Penyesuaian';

  @override
  String get stockHistoryGuideSlide2Title => 'Tanggal dan nomor transaksi';

  @override
  String get stockHistoryGuideSlide2Subtitle => 'Bagian tengah menampilkan waktu transaksi terjadi dan nomor referensinya.';

  @override
  String get stockHistoryGuideSlide2SampleDate => '07 Feb 2026 • 14:32';

  @override
  String get stockHistoryGuideSlide2SampleRef => 'SO-2026-000145';

  @override
  String get stockHistoryGuideSlide2DateHint => 'Waktu transaksi tercatat';

  @override
  String get stockHistoryGuideSlide2ReferenceHint => 'Nomor referensi transaksi';

  @override
  String get stockHistoryGuideSlide2PointTimeline => 'Tanggal menunjukkan waktu transaksi terakhir.';

  @override
  String get stockHistoryGuideSlide2PointReference => 'Nomor bisa berasal dari Number atau Reference ID.';

  @override
  String get stockHistoryGuideTagTimeline => 'Waktu';

  @override
  String get stockHistoryGuideTagReference => 'Referensi';

  @override
  String get stockHistoryGuideSlide3Title => 'Arti dua badge angka';

  @override
  String get stockHistoryGuideSlide3Subtitle => 'Badge di sisi kanan menampilkan kondisi stok akhir dan jumlah pergerakan pada transaksi itu.';

  @override
  String get stockHistoryGuideSlide3BadgeBalanceLabel => 'Saldo';

  @override
  String get stockHistoryGuideSlide3BadgeBalanceDescription => 'Sisa stok setelah transaksi';

  @override
  String get stockHistoryGuideSlide3BadgeQtyLabel => 'Qty';

  @override
  String get stockHistoryGuideSlide3BadgeQtyDescription => 'Jumlah stok yang bergerak';

  @override
  String get stockHistoryGuideSlide3PointEnding => 'Saldo adalah stok akhir setelah catatan ini.';

  @override
  String get stockHistoryGuideSlide3PointMovement => 'Qty positif berarti masuk, qty negatif berarti keluar.';

  @override
  String get stockHistoryGuideSlide3PointTip => 'Ketuk badge apa pun untuk membuka tooltip detailnya.';

  @override
  String get stockHistoryGuideTagEnding => 'Akhir';

  @override
  String get stockHistoryGuideTagMovement => 'Pergerakan';

  @override
  String get stockHistoryGuideTagTip => 'Tips';

  @override
  String get stockHistoryGuideBack => 'Kembali';

  @override
  String get stockHistoryGuideNext => 'Lanjut';

  @override
  String get stockHistoryGuideDone => 'Selesai';

  @override
  String get stockHistorySkuFallback => 'SKU';

  @override
  String get stockHistoryEmptyTitle => 'Belum ada transaksi';

  @override
  String get stockHistoryEmptyMessage => 'Catatan akan muncul di sini setelah ada transaksi.';

  @override
  String get stockHistoryEmptyCtaRefresh => 'Tarik ke bawah untuk refresh';

  @override
  String get stockHistoryErrorTitle => 'Tidak ada riwayat';

  @override
  String get stockHistoryErrorMessage => 'Tekan tombol di bawah untuk memuat ulang.';

  @override
  String get stockHistoryErrorRetry => 'Coba lagi';

  @override
  String get stockHistoryTooltipTransactionTitle => 'Transaksi';

  @override
  String get stockHistoryTooltipTransactionDesc => 'Pergerakan inventori umum.';

  @override
  String get stockHistoryTooltipSalesTitle => 'Penjualan';

  @override
  String get stockHistoryTooltipSalesDesc => 'Stok keluar karena transaksi penjualan.';

  @override
  String get stockHistoryTooltipPurchaseTitle => 'Pembelian';

  @override
  String get stockHistoryTooltipPurchaseDesc => 'Stok masuk dari transaksi pembelian.';

  @override
  String get stockHistoryTooltipStockOpnameTitle => 'Stok Opname';

  @override
  String get stockHistoryTooltipStockOpnameDesc => 'Penyesuaian dari pemeriksaan inventori.';

  @override
  String get stockHistoryTooltipStockOpnameAdjustmentTitle => 'Penyesuaian Stok Opname';

  @override
  String get stockHistoryTooltipStockOpnameAdjustmentDesc => 'Penyesuaian dari proses stok opname.';

  @override
  String get stockHistoryTooltipQtyTitle => 'Qty';

  @override
  String get stockHistoryTooltipQtyDesc => 'Jumlah stok yang bergerak pada transaksi ini.';

  @override
  String get stockHistoryTooltipBalanceTitle => 'Saldo';

  @override
  String get stockHistoryTooltipBalanceDesc => 'Saldo stok setelah transaksi ini.';

  @override
  String get currencyUnitMillion => 'juta';

  @override
  String get currencyUnitBillion => 'miliar';

  @override
  String get currencyUnitTrillion => 'triliun';
}
