import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/providers/hr_provider.dart';

class LinkRegisterProvider extends ChangeNotifier {
  LinkRegisterProvider({
    required this.inviteEmail,
    required this.inviteToken,
    this.inviteBusinessName,
    this.inviteBusinessLogo,
    this.inviteRoleName,
    this.deviceId,
    this.deviceName,
    this.fcmToken,
  });

  /// Helper untuk inisialisasi dari meta undangan (mis. hasil getInviteData)
  factory LinkRegisterProvider.fromInvitePreview({
    required String email,
    required String token,
    required String businessName,
    String? businessLogo,
    String? roleName,
    String? deviceId,
    String? deviceName,
    String? fcmToken,
  }) {
    return LinkRegisterProvider(
      inviteEmail: email,
      inviteToken: token,
      inviteBusinessName: businessName,
      inviteBusinessLogo: businessLogo,
      inviteRoleName: roleName,
      deviceId: deviceId,
      deviceName: deviceName,
      fcmToken: fcmToken,
    );
  }

  // ====== INVITE META ======
  final String inviteEmail; // siapa yang diundang
  final String inviteToken; // token undangan
  final String? inviteBusinessName; // nama bisnis pengundang
  final String? inviteBusinessLogo; // logo bisnis (url/asset)
  final String? inviteRoleName; // role yang akan diberikan

  // ====== DEVICE / PUSH (opsional, isi dari luar bila ada) ======
  String? deviceId;
  String? deviceName;
  String? fcmToken;

  // ====== Convenience getters untuk UI (dengan fallback aman) ======
  String get displayInviteEmail =>
      inviteEmail.isNotEmpty ? inviteEmail : 'your@email.com';

  String get displayBusinessName => (inviteBusinessName ?? '').trim().isNotEmpty
      ? inviteBusinessName!.trim()
      : 'Business';

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

  /// Submit lengkap: panggil HrProvider.completeInvite
  Future<String?> submit(BuildContext context) async {
    final fErr = validateRequired(firstNameC.text);
    final lErr = validateRequired(lastNameC.text);
    if (fErr != null) return fErr;
    if (lErr != null) return lErr;

    _submitting = true;
    notifyListeners();

    try {
      final hrProv = context.read<HrProvider>();

      final res = await hrProv.completeInvite(
        context,
        token: inviteToken,
        user: inviteEmail, // backendmu menerima email pada field "user"
        password: passwordC.text.trim(),
        // kirim dua varian nama depan (firstname & first_name) di dalam HrProvider
        firstName: firstNameC.text.trim(),
        lastName: lastNameC.text.trim(),
        referralCode: '', // isi kalau ada
      );

      if (res == null) {
        // gagal dari sisi provider
        return hrProv.lastError ?? 'Failed to complete invite.';
      }

      // === sukses ===
      // Coba ambil info bisnis/role dari respons jika tersedia.
      // Fallback ke meta undangan bila tidak ada.
      final u = res.user;
      final fromUserBusinessName =
          (u['business_name'] ?? u['business']?['name'] ?? u['businessName'])
              ?.toString();
      final fromUserBusinessLogo =
          (u['business_logo'] ?? u['business']?['logo'] ?? u['logo'])
              ?.toString();
      final fromUserRoleName =
          (u['role_name'] ?? u['userRoleName'] ?? u['role']?['name'])
              ?.toString();

      _joinedBusinessName =
          (fromUserBusinessName != null &&
              fromUserBusinessName.trim().isNotEmpty)
          ? fromUserBusinessName.trim()
          : (inviteBusinessName ?? 'Your Business');

      _joinedBusinessLogo =
          (fromUserBusinessLogo != null &&
              fromUserBusinessLogo.trim().isNotEmpty)
          ? fromUserBusinessLogo.trim()
          : inviteBusinessLogo;

      _joinedRoleName =
          (fromUserRoleName != null && fromUserRoleName.trim().isNotEmpty)
          ? fromUserRoleName.trim()
          : inviteRoleName;

      _completed = true;
      notifyListeners();
      return null; // null = sukses
    } catch (e) {
      return e.toString();
    } finally {
      _submitting = false;
      notifyListeners();
    }
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
