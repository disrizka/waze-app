// lib/providers/change_password_provider.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:wa_blast/core/provider_helper.dart'; // BizIdCache, ApiJson
import 'package:wa_blast/services/api_service.dart';
import 'package:wa_blast/utils/safe_change_notifier.dart';

class ChangePasswordProvider extends SafeChangeNotifier {
  bool _loading = false;
  String? _lastError;
  String? _lastOtp; // menyimpan OTP terakhir dari step 1

  bool get loading => _loading;
  String? get lastError => _lastError;
  String? get lastOtp => _lastOtp;

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  void _setError(String? e) {
    _lastError = e;
    notifyListeners();
  }

  void _setOtp(String? v) {
    _lastOtp = v;
    notifyListeners();
  }

  /// Hapus dan kembalikan error terakhir
  String? consumeLastError() {
    final e = _lastError;
    _lastError = null;
    return e;
  }

  // =========================================================
  // 1) CHANGE PASSWORD (Private API - User login)
  // =========================================================
  Future<bool> changePassword(
    BuildContext context, {
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (oldPassword.isEmpty) {
      _setError('Old password is required.');
      return false;
    }
    if (newPassword.isEmpty) {
      _setError('New password is required.');
      return false;
    }
    if (confirmPassword.isEmpty) {
      _setError('Please confirm the new password.');
      return false;
    }
    if (newPassword != confirmPassword) {
      _setError('New password and confirmation do not match.');
      return false;
    }
    if (newPassword.length < 6) {
      _setError('New password must be at least 6 characters.');
      return false;
    }

    const path = '/user/edit/password';
    final payload = {
      'password_old': oldPassword,
      'password_new': newPassword,
      'password_confirm': confirmPassword,
    };

    if (kDebugMode) {
      debugPrint('[ChangePasswordProvider] POST $path');
      debugPrint('[ChangePasswordProvider] payload: $payload');
    }

    _setError(null);
    _setLoading(true);
    try {
      final j = await ApiJson.postMap(
        context,
        path,
        payload,
        withAccessToken: true,
      );

      final ok = j != null && (j['status'] as num?)?.toInt() == 200;
      if (!ok) {
        _setError(j?['message']?.toString() ?? 'Failed to change password');
        return false;
      }

      _setError(null);
      return true;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[ChangePasswordProvider] exception: $e\n$st');
      }
      _setError('$e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // =========================================================
  // 2) FORGOT PASSWORD STEP-1: REQUEST OTP
  // =========================================================
  Future<String?> forgotPasswordStep1(
    BuildContext context, {
    required String emailOrUser,
  }) async {
    if (emailOrUser.trim().isEmpty) {
      _setError('Email is required.');
      return null;
    }

    const endpoint = '/user/forgot-password-1';
    final body = {'user': emailOrUser.trim()};

    if (kDebugMode) {
      debugPrint('[ForgotPassword1] POST $endpoint');
      debugPrint('[ForgotPassword1] payload: $body');
    }

    _setError(null);
    _setLoading(true);

    try {
      final resp = await ApiService.postJson(
        endpoint,
        body,
        withAccessToken: false,
      );
      final j = jsonDecode(resp.body);

      if (kDebugMode) debugPrint('[ForgotPassword1] resp: $j');

      final ok = (j['status'] as num?)?.toInt() == 200;
      if (!ok) {
        _setError(j['message']?.toString() ?? 'Failed to request OTP');
        _setOtp(null);
        return null;
      }

      return null;
    } catch (e, st) {
      if (kDebugMode) debugPrint('[ForgotPassword1] exception: $e\n$st');
      _setOtp(null);
      _setError('$e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // =========================================================
  // 3) FORGOT PASSWORD STEP-3: SUBMIT OTP + NEW PASSWORD
  // =========================================================
  Future<bool> forgotPasswordStep3(
    BuildContext context, {
    required String emailOrUser,
    required String otp,
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (emailOrUser.trim().isEmpty) {
      _setError('Email is required.');
      return false;
    }
    if (otp.trim().isEmpty) {
      _setError('OTP is required.');
      return false;
    }
    if (newPassword.isEmpty) {
      _setError('New password is required.');
      return false;
    }
    if (confirmPassword.isEmpty) {
      _setError('Please confirm the new password.');
      return false;
    }
    if (newPassword != confirmPassword) {
      _setError('New password and confirmation do not match.');
      return false;
    }
    if (newPassword.length < 6) {
      _setError('New password must be at least 6 characters.');
      return false;
    }

    const endpoint = '/user/forgot-password-3';
    final body = {
      'user': emailOrUser.trim(),
      'otp': otp.trim(),
      'password_new': newPassword,
      'password_confirm': confirmPassword,
    };

    if (kDebugMode) {
      debugPrint('[ForgotPassword3] POST $endpoint');
      debugPrint('[ForgotPassword3] payload: $body');
    }

    _setError(null);
    _setLoading(true);

    try {
      final resp = await ApiService.postJson(
        endpoint,
        body,
        withAccessToken: false,
      );
      final j = jsonDecode(resp.body);

      if (kDebugMode) debugPrint('[ForgotPassword3] resp: $j');

      final ok = (j['status'] as num?)?.toInt() == 200;
      if (!ok) {
        _setError(j['message']?.toString() ?? 'Failed to reset password');
        return false;
      }

      _setError(null);
      return true;
    } catch (e, st) {
      if (kDebugMode) debugPrint('[ForgotPassword3] exception: $e\n$st');
      _setError('$e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
}
