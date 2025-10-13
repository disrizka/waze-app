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
}
