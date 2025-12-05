// lib/utils/business_premium_helper.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BusinessPremiumHelper {
  const BusinessPremiumHelper._(); // private constructor (static-only)

  /// Cek apakah ACTIVE business saat ini premium atau tidak.
  ///
  /// Urutan logic:
  /// 1. Baca `activeBizId`
  /// 2. Baca list `business` (JSON array)
  ///    - Kalau ada item dengan `idBusiness == activeBizId` → ambil `isPremium`
  /// 3. Kalau tidak ketemu / parsing error → fallback ke `activeBizIsPremium`
  static Future<bool> isActiveBusinessPremium() async {
    final prefs = await SharedPreferences.getInstance();

    final activeId = (prefs.getString('activeBizId') ?? '').trim();
    bool isPremium = false;

    final businessJson = prefs.getString('business');
    if (businessJson != null && businessJson.isNotEmpty) {
      try {
        final list = (jsonDecode(businessJson) as List)
            .cast<Map<String, dynamic>>();

        Map<String, dynamic>? match;
        if (activeId.isNotEmpty) {
          match = list.firstWhere(
            (e) => (e['idBusiness'] ?? '').toString() == activeId,
            orElse: () => <String, dynamic>{},
          );
        }

        if (match != null && match.isNotEmpty) {
          // Sama persis dengan logic di _HeaderGradient._loadPrefs
          isPremium = (match['isPremium'] ?? false) == true;
        } else {
          // fallback ke flag lama di prefs
          isPremium = (prefs.getBool('activeBizIsPremium') ?? false);
        }
      } catch (e, s) {
        if (kDebugMode) {
          debugPrint('[BusinessPremiumHelper] parse error: $e\n$s');
        }
        // kalau JSON business rusak → fallback saja
        isPremium = (prefs.getBool('activeBizIsPremium') ?? false);
      }
    } else {
      // kalau tidak ada list `business` sama sekali → fallback
      isPremium = (prefs.getBool('activeBizIsPremium') ?? false);
    }

    return isPremium;
  }

  /// Optional: cek premium untuk business tertentu (bukan hanya active).
  /// Bisa berguna kalau suatu saat kamu mau cek beberapa bisnis sekaligus.
  static Future<bool> isBusinessPremiumById(String idBusiness) async {
    final prefs = await SharedPreferences.getInstance();
    final businessJson = prefs.getString('business');

    if (businessJson == null || businessJson.isEmpty) {
      // kalau tidak ada list, tapi id sama dengan active → fallback ke activeBizIsPremium
      final activeId = (prefs.getString('activeBizId') ?? '').trim();
      if (activeId == idBusiness) {
        return (prefs.getBool('activeBizIsPremium') ?? false);
      }
      return false;
    }

    try {
      final list = (jsonDecode(businessJson) as List)
          .cast<Map<String, dynamic>>();

      final match = list.firstWhere(
        (e) => (e['idBusiness'] ?? '').toString() == idBusiness,
        orElse: () => <String, dynamic>{},
      );

      if (match.isEmpty) {
        // lagi-lagi fallback: kalau id ini ternyata active, pakai flag prefs lama
        final activeId = (prefs.getString('activeBizId') ?? '').trim();
        if (activeId == idBusiness) {
          return (prefs.getBool('activeBizIsPremium') ?? false);
        }
        return false;
      }

      return (match['isPremium'] ?? false) == true;
    } catch (e, s) {
      if (kDebugMode) {
        debugPrint(
          '[BusinessPremiumHelper] isBusinessPremiumById error: $e\n$s',
        );
      }
      // fallback ke activeBizIsPremium hanya kalau id itu adalah active
      final activeId = (prefs.getString('activeBizId') ?? '').trim();
      if (activeId == idBusiness) {
        return (prefs.getBool('activeBizIsPremium') ?? false);
      }
      return false;
    }
  }
}
