import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class LinkRegisterProvider extends ChangeNotifier {
  LinkRegisterProvider({
    required this.inviteEmail,
    required this.inviteToken,
    this.inviteBusinessName,
    this.inviteBusinessLogo,
    this.inviteRoleName, // ✅ NEW: role yang akan diberikan
  });

  /// Helper untuk inisialisasi dari meta undangan (mis. hasil getInviteData)
  factory LinkRegisterProvider.fromInvitePreview({
    required String email,
    required String token,
    required String businessName,
    String? businessLogo,
    String? roleName,
  }) {
    return LinkRegisterProvider(
      inviteEmail: email,
      inviteToken: token,
      inviteBusinessName: businessName,
      inviteBusinessLogo: businessLogo,
      inviteRoleName: roleName,
    );
  }

  // ====== INVITE META ======
  final String inviteEmail; // siapa yang diundang
  final String inviteToken; // token undangan
  final String? inviteBusinessName; // nama bisnis pengundang
  final String? inviteBusinessLogo; // logo bisnis (url/asset)
  final String? inviteRoleName; // ✅ role yang akan diberikan

  // ====== Convenience getters untuk UI (dengan fallback aman) ======
  String get displayInviteEmail =>
      inviteEmail.isNotEmpty ? inviteEmail : 'your@email.com';

  String get displayBusinessName => (inviteBusinessName ?? '').trim().isNotEmpty
      ? inviteBusinessName!.trim()
      : 'Business';

  /// bisa null -> UI sediakan fallback icon
  String? get displayBusinessLogo =>
      (inviteBusinessLogo ?? '').trim().isNotEmpty
      ? inviteBusinessLogo!.trim()
      : null;

  String get displayRoleName => (inviteRoleName ?? '').trim().isNotEmpty
      ? inviteRoleName!.trim()
      : 'Member';

  // ====== WELCOME STATE ======
  bool _showWelcome = true;
  bool get showWelcome => _showWelcome;
  void dismissWelcome() {
    if (!_showWelcome) return;
    _showWelcome = false;
    notifyListeners();
  }

  // ====== STEPPER STATE (tanpa welcome) ======
  // 0 = Password, 1 = Details
  int _currentStep = 0;
  int get currentStep => _currentStep;

  void nextStep() {
    if (_currentStep < 1) {
      _currentStep++;
      notifyListeners();
    }
  }

  void prevStep() {
    if (_currentStep > 0) {
      _currentStep--;
      notifyListeners();
    }
  }

  // ====== FORM CONTROLLERS ======
  final TextEditingController passwordC = TextEditingController();
  final TextEditingController confirmC = TextEditingController();
  bool _obscurePassword = true;
  bool get obscurePassword => _obscurePassword;
  void toggleObscure() {
    _obscurePassword = !_obscurePassword;
    notifyListeners();
  }

  final TextEditingController firstNameC = TextEditingController();
  final TextEditingController lastNameC = TextEditingController();

  // ====== LOADING / SUBMIT / RESULT STATE ======
  bool _submitting = false;
  bool get submitting => _submitting;

  bool _completed = false;
  bool get completed => _completed;

  String? _joinedBusinessName;
  String? get joinedBusinessName => _joinedBusinessName;

  String? _joinedBusinessLogo; // asset path / url
  String? get joinedBusinessLogo => _joinedBusinessLogo;

  // (opsional) role yang tersimpan setelah join (kalau backend kirim)
  String? _joinedRoleName;
  String? get joinedRoleName => _joinedRoleName ?? inviteRoleName;

  // ====== VALIDATORS ======
  String? validatePassword(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Password is required';
    if (t.length < 8) return 'Min. 8 characters';
    return null;
  }

  String? validateConfirm(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Please confirm your password';
    if (t != passwordC.text.trim()) return 'Passwords do not match';
    return null;
  }

  String? validateRequired(String? v) {
    if (v == null || v.trim().isEmpty) return 'This field is required';
    return null;
  }

  // ====== ACTIONS ======
  String? onContinuePasswordStep() {
    final pErr = validatePassword(passwordC.text);
    final cErr = validateConfirm(confirmC.text);
    if (pErr != null) return pErr;
    if (cErr != null) return cErr;
    nextStep();
    return null;
  }

  Future<String?> submit() async {
    final fErr = validateRequired(firstNameC.text);
    final lErr = validateRequired(lastNameC.text);
    if (fErr != null) return fErr;
    if (lErr != null) return lErr;

    final payload = {
      "user": inviteEmail,
      "password": passwordC.text.trim(),
      "referral_code": "",
      "device_id": "YOUR_DEVICE_ID",
      "device_name": "YOUR_DEVICE_NAME",
      "fcm_token": "YOUR_FCM_TOKEN",
      "first_name": firstNameC.text.trim(),
      "last_name": lastNameC.text.trim(),
      "invite_token": inviteToken,
    };

    _submitting = true;
    notifyListeners();

    try {
      final result = await acceptInviteAndRegister(payload);

      // Simpan hasil join business
      _joinedBusinessName =
          (result['business_name'] as String?)?.trim().isNotEmpty == true
          ? (result['business_name'] as String).trim()
          : inviteBusinessName ?? 'Your Business';

      _joinedBusinessLogo =
          (result['business_logo'] as String?)?.trim().isNotEmpty == true
          ? (result['business_logo'] as String).trim()
          : inviteBusinessLogo;

      // Simpan role jika backend mengembalikan, kalau tidak ya pakai role undangan
      _joinedRoleName =
          (result['role_name'] as String?)?.trim().isNotEmpty == true
          ? (result['role_name'] as String).trim()
          : inviteRoleName;

      _completed = true;
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  /// ====== API STUB (ganti dengan service/API asli) ======
  /// Idealnya ini memanggil HrProvider.completeInvite(...)
  Future<Map<String, dynamic>> acceptInviteAndRegister(
    Map<String, dynamic> payload,
  ) async {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[LinkRegister] Submit payload: $payload');
    }
    await Future.delayed(const Duration(milliseconds: 700));

    // Contoh response backend:
    // {
    //   "status": 200,
    //   "msg": "Registrasi berhasil",
    //   "business_name": "PT. Coffee Roasters",
    //   "business_logo": "https://....",
    //   "role_name": "Product Manager",
    //   "token": {...}, "data": {...}
    // }

    return {
      'business_name': inviteBusinessName ?? 'Wave Cafe',
      'business_logo': inviteBusinessLogo,
      'role_name': inviteRoleName ?? 'Member',
    };
  }

  @override
  void dispose() {
    passwordC.dispose();
    confirmC.dispose();
    firstNameC.dispose();
    lastNameC.dispose();
    super.dispose();
  }
}
