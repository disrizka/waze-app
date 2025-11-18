import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

// (Opsional) kalau kamu punya global scaffoldMessengerKey, aktifkan ini:
// import 'package:wa_blast/core/provider_helper.dart'; // berisi AppScaffoldMessenger.show(...)

import 'package:wa_blast/services/api_service.dart';

// ⬇️ Tambahan import untuk kompresi
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// ⬇️ Tambahan: ambil BizIdCache dari provider_helper
import 'package:wa_blast/core/provider_helper.dart' show BizIdCache;

enum _UsernameCheck { available, taken, error }

class EditProfileProvider with ChangeNotifier {
  // Controllers
  final emailC = TextEditingController();
  final firstNameC = TextEditingController();
  final lastNameC = TextEditingController();
  final usernameC = TextEditingController();

  File? pickedPhotoFile;
  String? existingPhotoPath;

  bool _loading = false;
  bool _saving = false;

  bool get isLoading => _loading;
  bool get isSaving => _saving;

  // ===================== INIT =====================
  Future<void> initFromPrefs() async {
    _loading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();

      final email = prefs.getString('email') ?? '';

      final userRaw = prefs.getString('user');
      String first = '';
      String last = '';
      String username = '';
      String userPhoto = '';
      if (userRaw != null && userRaw.isNotEmpty) {
        try {
          final Map<String, dynamic> user = jsonDecode(userRaw);
          first = (user['firstname'] ?? '').toString();
          last = (user['lastname'] ?? '').toString();
          username = (user['username'] ?? '').toString();
          userPhoto = user['photoPath'] ?? '';
        } catch (_) {}
      }

      emailC.text = email;
      firstNameC.text = first;
      lastNameC.text = last;
      usernameC.text = username;
      existingPhotoPath = (userPhoto.isNotEmpty) ? userPhoto : null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ===================== UI HELPERS =====================
  void _snack(BuildContext? ctx, String msg) {
    final m = (ctx != null) ? ScaffoldMessenger.maybeOf(ctx) : null;
    if (m != null) {
      m.showSnackBar(SnackBar(content: Text(msg)));
    } else {
      // Jika kamu punya global key:
      // AppScaffoldMessenger.show(msg);
      debugPrint('[SnackBar Fallback] $msg');
    }
  }

  Map<String, dynamic>? _tryDecodeBody(String body) {
    if (body.isEmpty) return null;
    try {
      final obj = jsonDecode(body);
      return (obj is Map<String, dynamic>) ? obj : null;
    } catch (_) {
      return null;
    }
  }

  bool _isOk(Map<String, dynamic>? j, {int? http}) {
    // success: true
    final s1 = j?['success'];
    if (s1 is bool && s1) return true;

    // status: 2xx (int)
    final s2 = j?['status'];
    if (s2 is int && s2 >= 200 && s2 < 300) return true;

    // status: "success"
    if (s2 is String && s2.toLowerCase() == 'success') return true;

    // code: 0 atau 2xx
    final code = j?['code'];
    if (code is int && (code == 0 || (code >= 200 && code < 300))) return true;

    // fallback: HTTP 2xx
    if (http != null && http >= 200 && http < 300) return true;

    return false;
  }

  String _pickMsg(
    Map<String, dynamic>? j, {
    int? http,
    String fallback = 'Request failed',
  }) {
    try {
      if (j != null) {
        final m = j['msg'] ?? j['message'] ?? j['error'] ?? j['detail'];
        if (m != null && m.toString().trim().isNotEmpty) return m.toString();
      }
    } catch (_) {}
    return (http != null) ? '$fallback ($http)' : fallback;
  }

  // ===================== IMAGE COMPRESS HELPERS =====================
  /// Kompres gambar ke JPEG/PNG sesuai ekstensi.
  /// - Target ukuran default 1200x1200 (max sisi), kualitas 80.
  /// - HEIC/HEIF otomatis dikonversi ke JPEG.
  /// - Mengembalikan file hasil kompres, atau file asli jika gagal.
  Future<File> _compressImageFile(
    File input, {
    int maxWidth = 1200,
    int maxHeight = 1200,
    int quality = 80,
  }) async {
    try {
      final tmpDir = await getTemporaryDirectory();
      final ext = p.extension(input.path).toLowerCase();

      final isHeic = ext == '.heic' || ext == '.heif';
      final isPng = ext == '.png';
      // Gunakan JPEG untuk kebanyakan foto / HEIC
      final fmt = (isPng && !isHeic) ? CompressFormat.png : CompressFormat.jpeg;

      final outPath = p.join(
        tmpDir.path,
        'cmp_${DateTime.now().millisecondsSinceEpoch}'
        '${fmt == CompressFormat.png ? '.png' : '.jpg'}',
      );

      final out = await FlutterImageCompress.compressAndGetFile(
        input.path, // ✅ fix: jangan pakai input.absolute.path
        outPath,
        quality: quality.clamp(1, 100),
        minWidth: maxWidth,
        minHeight: maxHeight,
        format: fmt,
        autoCorrectionAngle: true,
        keepExif: true,
      );

      if (out == null) return input;

      // Jika masih terlalu besar (> 2.5MB), coba kompres lagi dengan kualitas lebih rendah.
      final tooBig = await out.length() > 2_500_000;
      if (tooBig) {
        final outPath2 = p.join(
          tmpDir.path,
          'cmp2_${DateTime.now().millisecondsSinceEpoch}'
          '${fmt == CompressFormat.png ? '.png' : '.jpg'}',
        );
        final out2 = await FlutterImageCompress.compressAndGetFile(
          out.path,
          outPath2,
          quality: 65,
          minWidth: (maxWidth * 0.9).round(),
          minHeight: (maxHeight * 0.9).round(),
          format: fmt,
          autoCorrectionAngle: true,
          keepExif: true,
        );
        if (out2 != null) return File(out2.path);
      }

      return File(out.path);
    } catch (e, st) {
      debugPrint('[_compressImageFile] ❌ $e\n$st');
      return input; // fallback ke file asli jika gagal
    }
  }

  // ===================== MEDIA =====================
  Future<void> pickLogo() async {
    final picker = ImagePicker();
    final XFile? x = await picker.pickImage(
      source: ImageSource.gallery,
      // biarkan kualitas asli, kita kompres manual agar konsisten
      imageQuality: null,
    );
    if (x != null) {
      final rawFile = File(x.path);
      // Kompres setelah pilih
      final compressed = await _compressImageFile(
        rawFile,
        maxWidth: 1200,
        maxHeight: 1200,
        quality: 80,
      );
      pickedPhotoFile = compressed;
      notifyListeners();
    }
  }

  void removePickedLogo() {
    pickedPhotoFile = null;
    notifyListeners();
  }

  // ===================== USERNAME CHECK =====================
  Future<(_UsernameCheck, String?)> _checkUsernameAvailability(
    String username,
  ) async {
    try {
      // NOTE: endpoint publik → pakai postJson (tanpa context)
      final res = await ApiService.postJson(
        '/username/check',
        {"username": username},
        withAccessToken: true, // kalau endpoint butuh token, set true
      );

      final j = _tryDecodeBody(res.body);
      final code = (j?['status'] is int) ? j!['status'] as int : res.statusCode;
      final msg = (j?['msg'] ?? j?['message'] ?? '').toString();

      if (code == 200)
        return (_UsernameCheck.available, msg.isEmpty ? null : msg);
      if (code == 409) {
        return (
          _UsernameCheck.taken,
          msg.isEmpty ? 'username has been taken' : msg,
        );
      }
      return (
        _UsernameCheck.error,
        msg.isEmpty ? 'Username check failed ($code)' : msg,
      );
    } catch (e, st) {
      debugPrint('_checkUsernameAvailability ❌ $e\n$st');
      return (_UsernameCheck.error, 'Unable to check username');
    }
  }

  // ===================== SUBMIT PROFILE =====================
  Future<bool> submitEditProfile(BuildContext context) async {
    _saving = true;
    notifyListeners();

    bool didAnything = false;
    bool allOk = true;
    final successNotes = <String>[];

    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUsername = prefs.getString('username') ?? '';

      final firstName = firstNameC.text.trim();
      final lastName = lastNameC.text.trim();
      final username = usernameC.text.trim();

      // 0) Username check (paling atas)
      if (username.isNotEmpty && username != currentUsername) {
        final (status, message) = await _checkUsernameAvailability(username);
        if (status != _UsernameCheck.available) {
          _saving = false;
          notifyListeners();
          _snack(context, message ?? 'Invalid username');
          return false;
        }
      }

      // 1) Update text info
      final hasTextUpdate =
          firstName.isNotEmpty || lastName.isNotEmpty || username.isNotEmpty;
      if (hasTextUpdate) {
        didAnything = true;

        // gunakan ApiService.post (dengan context) → auto refresh token bila 401
        final res = await ApiService.post(context, '/user/edit/account', {
          "firstname": firstName,
          "lastname": lastName,
          "username": username,
        }, withAccessToken: true);

        final j = _tryDecodeBody(res.body);
        if (_isOk(j, http: res.statusCode)) {
          successNotes.add('Profile info updated');
        } else {
          allOk = false;
          _snack(
            context,
            _pickMsg(
              j,
              http: res.statusCode,
              fallback: 'Update profile failed',
            ),
          );
        }
      }

      // 2) Update photo (KOMPRES DULU)
      final File? photo = pickedPhotoFile;
      if (photo != null) {
        didAnything = true;

        // Kompres sebelum upload
        final fileToUpload = await _compressImageFile(
          photo,
          maxWidth: 1200,
          maxHeight: 1200,
          quality: 80,
        );

        String? uploadedFilename;
        try {
          final uploadRes = await ApiService.uploadFile(fileToUpload.path);
          if (uploadRes != null) {
            final data =
                (uploadRes['data'] as Map?)?.cast<String, dynamic>() ??
                const {};
            uploadedFilename = (data['filename'] ?? '').toString();
          }
        } catch (e, st) {
          debugPrint('UPLOAD PHOTO ❌ $e\n$st');
        }

        if (uploadedFilename == null || uploadedFilename.isEmpty) {
          allOk = false;
          _snack(context, 'Failed to upload photo');
        } else {
          final res = await ApiService.post(context, '/user/edit/photo', {
            "photo": uploadedFilename,
          }, withAccessToken: true);

          final j = _tryDecodeBody(res.body);
          if (_isOk(j, http: res.statusCode)) {
            successNotes.add('Photo updated');
          } else {
            allOk = false;
            _snack(
              context,
              _pickMsg(
                j,
                http: res.statusCode,
                fallback: 'Update photo failed',
              ),
            );
          }
        }
      }

      // 3) Tidak ada perubahan
      if (!didAnything) {
        _saving = false;
        notifyListeners();
        _snack(context, 'Nothing to update');
        return true;
      }

      // 4) Refresh user ketika ada yang sukses
      if (successNotes.isNotEmpty) {
        await _refreshUserFromServer(context);
        _snack(context, successNotes.join(' · '));
      }

      _saving = false;
      notifyListeners();
      return allOk;
    } catch (e, st) {
      _saving = false;
      notifyListeners();
      debugPrint('submitEditProfile ❌ $e\n$st');
      _snack(context, 'Failed to edit profile.');
      return false;
    }
  }

  // ===================== REFRESH USER =====================
  Future<void> _refreshUserFromServer(BuildContext context) async {
    try {
      final res = await ApiService.get(context, '/user', withAccessToken: true);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final j = _tryDecodeBody(res.body) ?? {};
        final userObj = (j['data'] ?? {}) as Map<String, dynamic>;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', jsonEncode(userObj));

        final firstname = (userObj['firstname'] ?? '').toString();
        final lastname = (userObj['lastname'] ?? '').toString();
        final email = (userObj['email'] ?? '').toString();
        final photoPath = (userObj['photoPath'] ?? '').toString();
        final username = (userObj['username'] ?? '').toString();
        final phone = (userObj['phone'] ?? '').toString();

        if (email.isNotEmpty) await prefs.setString('email', email);
        await prefs.setString('username', username);
        await prefs.setString('photoPath', photoPath);
        await prefs.setString('phone', phone);

        // sinkron UI
        firstNameC.text = firstname;
        lastNameC.text = lastname;
        emailC.text = email;
        usernameC.text = username;

        notifyListeners();
      }
    } catch (e, st) {
      debugPrint('_refreshUserFromServer ❌ $e\n$st');
    }
  }

  /// Submit edit business (semua parameter boleh null).
  /// - Jika [organisationLogoFile] != null → **kompres dulu**, upload, ambil `uploadedFilename`,
  ///   lalu masukkan ke payload `organisation_logo`.
  /// - Jika [organisationLogoFile] == null → tidak kirim field `organisation_logo`.
  ///
  /// Return: (ok, uploadedFilename)
  Future<(bool ok, String? uploadedFilename)> submitEditBusiness(
    BuildContext context, {
    String? name,
    String? about,
    String? organisationName,
    File? organisationLogoFile,

    /// business out of stock flag:
    /// - true  → 1
    /// - false → 0
    /// - null  → tidak kirim field
    bool? canBeSoldOutOfStock,
  }) async {
    bool allOk = true;
    String? uploadedFilename;
    final successNotes = <String>[];
    bool didAnything = false;

    debugPrint('🟦 [submitEditBusiness] START');
    debugPrint('  ↳ name=$name');
    debugPrint('  ↳ about=$about');
    debugPrint('  ↳ organisationName=$organisationName');
    debugPrint('  ↳ canBeSoldOutOfStock=$canBeSoldOutOfStock');
    debugPrint('  ↳ organisationLogoFile=${organisationLogoFile?.path}');

    try {
      // 1) Upload organisation logo (jika ada)
      if (organisationLogoFile != null) {
        didAnything = true;
        debugPrint('📤 [1] Compressing & Uploading organisation logo...');

        // ⬇️ Kompres sebelum upload (logo biasanya kecil, tapi tetap dibatasi)
        final logoToUpload = await _compressImageFile(
          organisationLogoFile,
          maxWidth: 1200,
          maxHeight: 1200,
          quality: 80,
        );

        try {
          final uploadRes = await ApiService.uploadFile(logoToUpload.path);
          debugPrint('📦 Upload result: $uploadRes');

          if (uploadRes != null) {
            final data =
                (uploadRes['data'] as Map?)?.cast<String, dynamic>() ??
                const {};
            uploadedFilename = (data['filename'] ?? '').toString();
            debugPrint('✅ Uploaded filename: $uploadedFilename');
          }
        } catch (e, st) {
          debugPrint('❌ Upload photo failed: $e\n$st');
        }

        if (uploadedFilename == null || uploadedFilename.isEmpty) {
          allOk = false;
          debugPrint('🚫 No uploaded filename found, upload failed.');
          _snack(context, 'Failed to upload organisation logo');
        }
      }

      // 2) Bangun payload
      final payload = <String, dynamic>{};

      if (name != null && name.trim().isNotEmpty) {
        payload['business_name'] = name.trim(); // 🔄 pakai business_name
        debugPrint(
          '🧩 Payload add: business_name="${payload['business_name']}"',
        );
      }
      if (about != null && about.trim().isNotEmpty) {
        payload['about'] = about.trim();
        debugPrint('🧩 Payload add: about="${payload['about']}"');
      }
      if (organisationName != null && organisationName.trim().isNotEmpty) {
        payload['organisation_name'] = organisationName.trim();
        debugPrint(
          '🧩 Payload add: organisation_name="${payload['organisation_name']}"',
        );
      }
      if (uploadedFilename != null && uploadedFilename.isNotEmpty) {
        payload['organisation_logo'] = uploadedFilename;
        debugPrint(
          '🧩 Payload add: organisation_logo="${payload['organisation_logo']}"',
        );
      }

      // ⬇️ Tambahan field can_be_sold_out_of_stock
      if (canBeSoldOutOfStock != null) {
        // Bisa dikirim sebagai 0/1 (masih sesuai spesifikasi backend)
        payload['can_be_sold_out_of_stock'] = canBeSoldOutOfStock
            ? 1
            : 0; // atau 'true' / 'false'
        debugPrint(
          '🧩 Payload add: can_be_sold_out_of_stock=${payload['can_be_sold_out_of_stock']}',
        );
      }

      if (payload.isNotEmpty) {
        didAnything = true;
      }

      // 3) Jika tidak ada perubahan
      if (!didAnything) {
        debugPrint('ℹ️ Nothing to update, skipping API call.');
        _snack(context, 'Nothing to update');
        return (true, uploadedFilename);
      }

      // 4) Ambil idBusiness dari BizIdCache dan build endpoint
      final bizId = await BizIdCache.get();
      if (bizId == null || bizId.isEmpty) {
        debugPrint(
          '❌ [submitEditBusiness] active business id is empty / null. Abort.',
        );
        _snack(context, 'Active business not found.');
        return (false, uploadedFilename);
      }

      final endpoint = '/waveup/business/$bizId/edit';
      debugPrint('🚀 [2] Sending API request to $endpoint');
      debugPrint('    Payload: $payload');

      final res = await ApiService.post(
        context,
        endpoint,
        payload,
        withAccessToken: true,
      );

      debugPrint('📥 Response status: ${res.statusCode}');
      debugPrint('📥 Response body: ${res.body}');

      final j = _tryDecodeBody(res.body);
      final ok = _isOk(j, http: res.statusCode);

      if (ok) {
        successNotes.add('Business updated');
        debugPrint('✅ Business edit success');
      } else {
        allOk = false;
        final msg = _pickMsg(
          j,
          http: res.statusCode,
          fallback: 'Update business failed',
        );
        debugPrint('❌ Business edit failed: $msg');
        _snack(context, msg);
      }

      // 5) Feedback
      if (successNotes.isNotEmpty) {
        final joined = successNotes.join(' · ');
        debugPrint('📢 Success notes: $joined');
        _snack(context, joined);
      }

      debugPrint(
        '🟩 [submitEditBusiness] END → ok=$allOk uploaded="$uploadedFilename"',
      );
      return (allOk, uploadedFilename);
    } catch (e, st) {
      debugPrint('🔥 [submitEditBusiness] EXCEPTION: $e\n$st');
      _snack(context, 'Failed to edit business.');
      return (false, uploadedFilename);
    }
  }

  // ===================== DISPOSE =====================
  @override
  void dispose() {
    emailC.dispose();
    firstNameC.dispose();
    lastNameC.dispose();
    usernameC.dispose();
    super.dispose();
  }
}
