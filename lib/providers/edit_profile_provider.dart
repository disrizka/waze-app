import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EditProfileProvider with ChangeNotifier {
  // Controllers untuk form
  final emailC = TextEditingController();
  final phoneC = TextEditingController();
  final firstNameC = TextEditingController();
  final lastNameC = TextEditingController();
  final businessNameC = TextEditingController();

  // Logo (pilih baru) & logo path lama (dari prefs)
  File? pickedLogoFile;
  String? existingLogoPath; // contoh: path/URL/logo sebelumnya

  bool _loading = false;
  bool _saving = false;

  bool get isLoading => _loading;
  bool get isSaving => _saving;

  /// Ambil default dari SharedPreferences
  Future<void> initFromPrefs() async {
    _loading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();

    // Email
    final email = prefs.getString('email') ?? '';

    // User JSON -> firstname, lastname, phone
    final userRaw = prefs.getString('user');
    String first = '';
    String last = '';
    String phone = '';
    if (userRaw != null && userRaw.isNotEmpty) {
      try {
        final Map<String, dynamic> user = jsonDecode(userRaw);
        first = (user['firstname'] ?? '').toString();
        last = (user['lastname'] ?? '').toString();
        phone = (user['phone'] ?? '').toString();
      } catch (_) {}
    }

    // Business name & logo path
    final bizName = prefs.getString('activeBizName') ?? '';
    final bizLogo = prefs.getString('activeBizLogoPath'); // bisa null

    emailC.text = email;
    phoneC.text = phone;
    firstNameC.text = first;
    lastNameC.text = last;
    businessNameC.text = bizName;
    existingLogoPath = (bizLogo != null && bizLogo.isNotEmpty) ? bizLogo : null;

    _loading = false;
    notifyListeners();
  }

  /// Pilih logo dari galeri
  Future<void> pickLogo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? x = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x != null) {
      pickedLogoFile = File(x.path);
      notifyListeners();
    }
  }

  void removePickedLogo() {
    pickedLogoFile = null;
    notifyListeners();
  }

  /// Simpan ke SharedPreferences (lokal).
  /// - Update keys: 'user' (firstname, lastname, phone), 'email', 'activeBizName'
  /// - Untuk logo: saat ini hanya menyimpan path lama; jika mau upload, ganti dengan filename/URL dari server.
  Future<bool> saveToPrefs() async {
    _saving = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();

      // 1) Update user JSON
      Map<String, dynamic> user = {};
      final userRaw = prefs.getString('user');
      if (userRaw != null && userRaw.isNotEmpty) {
        try {
          user = jsonDecode(userRaw) as Map<String, dynamic>;
        } catch (_) {}
      }
      user['firstname'] = firstNameC.text.trim();
      user['lastname'] = lastNameC.text.trim();
      user['phone'] = phoneC.text.trim();
      user['email'] = emailC.text.trim(); // jaga-jaga
      await prefs.setString('user', jsonEncode(user));

      // 2) Single keys
      await prefs.setString('email', emailC.text.trim());
      await prefs.setString('activeBizName', businessNameC.text.trim());

      // 3) Logo
      if (pickedLogoFile != null) {
        // TODO: upload ke server, dapatkan filename/URL, lalu simpan ke prefs.
        // Contoh setelah upload:
        // final filename = await _uploadLogoAndGetFilename(pickedLogoFile!);
        // if (filename != null) {
        //   await prefs.setString('activeBizLogoPath', filename);
        //   existingLogoPath = filename;
        // }
        // Untuk sekarang, hanya menandai bahwa user sudah memilih file baru.
        // Agar UI tetap konsisten, kita tidak overwrite existingLogoPath
      }

      _saving = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('SAVE PREFS ❌ $e');
      _saving = false;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    emailC.dispose();
    phoneC.dispose();
    firstNameC.dispose();
    lastNameC.dispose();
    businessNameC.dispose();
    super.dispose();
  }
}
