// lib/providers/store_provider.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:wa_blast/core/provider_helper.dart'; // untuk FetchHelper & PageMeta
import 'package:wa_blast/services/api_service.dart'; // ApiService & ApiJson

/// =========================
/// MODELS
/// =========================

@immutable
class Province {
  final String id;
  final String name;

  const Province({required this.id, required this.name});

  factory Province.fromJson(Map<String, dynamic> j) => Province(
    id: (j['id'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
  );
}

@immutable
class City {
  final String id;
  final String name;
  final Province? province;

  const City({required this.id, required this.name, this.province});

  factory City.fromJson(Map<String, dynamic> j) => City(
    id: (j['id'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
    province: (j['province'] is Map<String, dynamic>)
        ? Province.fromJson(j['province'] as Map<String, dynamic>)
        : null,
  );
}

@immutable
class BusinessLite {
  final String idBusiness;
  final String name;
  final String? logo;
  final String? logoPath;
  final String? username;
  final String? about;

  const BusinessLite({
    required this.idBusiness,
    required this.name,
    this.logo,
    this.logoPath,
    this.username,
    this.about,
  });

  factory BusinessLite.fromJson(Map<String, dynamic> j) => BusinessLite(
    idBusiness: (j['idBusiness'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
    logo: j['logo']?.toString(),
    logoPath: j['logoPath']?.toString(),
    username: j['username']?.toString(),
    about: j['about']?.toString(),
  );
}

@immutable
class StoreLocation {
  final String idStoreLocation;
  final String name;
  final City? city;
  final BusinessLite? business;

  const StoreLocation({
    required this.idStoreLocation,
    required this.name,
    this.city,
    this.business,
  });

  factory StoreLocation.fromJson(Map<String, dynamic> j) => StoreLocation(
    idStoreLocation: (j['idStoreLocation'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
    city: (j['city'] is Map<String, dynamic>)
        ? City.fromJson(j['city'] as Map<String, dynamic>)
        : null,
    business: (j['business'] is Map<String, dynamic>)
        ? BusinessLite.fromJson(j['business'] as Map<String, dynamic>)
        : null,
  );
}

/// =========================
/// PROVIDER
/// =========================

class StoreProvider with ChangeNotifier {
  final List<StoreLocation> _stores = [];
  bool _loadingList = false;
  PageMeta? _pageStores;

  StoreLocation? _detail;
  bool _loadingDetail = false;

  String? _lastError;

  List<StoreLocation> get stores => List.unmodifiable(_stores);
  bool get loadingList => _loadingList;
  PageMeta? get pageStores => _pageStores;

  StoreLocation? get storeDetail => _detail;
  bool get loadingDetail => _loadingDetail;

  String? get lastError => _lastError;

  void _setLoading({bool? list, bool? detail, bool notify = true}) {
    if (list != null) _loadingList = list;
    if (detail != null) _loadingDetail = detail;
    if (notify) notifyListeners();
  }

  /// Helper ambil bizId sekaligus guard message.
  Future<String?> _requireBizId() async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _lastError = "Business ID is not available.";
      if (kDebugMode) {
        debugPrint("[StoreProvider] ❌ Business ID null/empty");
      }
      return null;
    }
    return bizId;
  }

  /// =========================
  /// FETCH LIST
  /// =========================
  Future<void> fetchStoreLocations(BuildContext context) async {
    final bizId = await _requireBizId();
    if (bizId == null) {
      _stores.clear();
      notifyListeners();
      return;
    }

    _setLoading(list: true);
    try {
      final result = await FetchHelper.fetchList<StoreLocation>(
        context: context,
        path: '/waveup/$bizId/store-location',
        parser: StoreLocation.fromJson,
      );

      if (result == null) {
        _stores.clear();
        _pageStores = null;
        return;
      }

      _stores
        ..clear()
        ..addAll(result.items);
      _pageStores = result.page;
    } finally {
      _setLoading(list: false);
    }
  }

  /// =========================
  /// FETCH DETAIL
  /// =========================
  Future<StoreLocation?> fetchStoreLocationDetail(
    BuildContext context,
    String idStoreLocation,
  ) async {
    final bizId = await _requireBizId();
    if (bizId == null) return null;

    final path = '/waveup/$bizId/store-location/$idStoreLocation';
    if (kDebugMode) debugPrint("[StoreProvider] 🌐 GET $path");

    _setLoading(detail: true);
    try {
      final j = await ApiJson.getMap(context, path);
      if (j == null) {
        _lastError = 'Null JSON response';
        return _detail;
      }
      if ((j['status'] as num?)?.toInt() != 200 ||
          j['data'] is! Map<String, dynamic>) {
        _lastError = 'Failed to get store location detail';
        return _detail;
      }

      final data = j['data'] as Map<String, dynamic>;
      if (kDebugMode) {
        debugPrint("[StoreProvider] detail raw: ${jsonEncode(data)}");
      }

      _detail = StoreLocation.fromJson(data);
      notifyListeners();
      return _detail;
    } catch (e, st) {
      _lastError = '$e';
      if (kDebugMode) {
        debugPrint("[StoreProvider] detail exception: $e");
        debugPrint("$st");
      }
      return _detail;
    } finally {
      _setLoading(detail: false);
    }
  }

  /// =========================
  /// CREATE
  /// =========================
  Future<bool> addStoreLocation({
    required BuildContext context,
    required String name,
    required String cityId,
  }) async {
    final bizId = await _requireBizId();
    if (bizId == null) return false;

    final payload = {'name': name, 'city_id': cityId};

    if (kDebugMode) {
      debugPrint("[StoreProvider] ADD payload: ${jsonEncode(payload)}");
    }

    try {
      final j = await ApiJson.postMap(
        context,
        '/waveup/$bizId/store-location',
        payload,
        withAccessToken: true,
      );

      final ok = j != null && (j['status'] as num?)?.toInt() == 200;
      if (!ok) {
        _lastError =
            j?['msg']?.toString() ??
            j?['message']?.toString() ??
            'Failed to create store location';
        return false;
      }

      await fetchStoreLocations(context);
      return true;
    } catch (e) {
      _lastError = '$e';
      if (kDebugMode) debugPrint("[StoreProvider] ADD exception: $e");
      return false;
    }
  }

  /// =========================
  /// UPDATE
  /// =========================
  Future<bool> updateStoreLocation({
    required BuildContext context,
    required String idStoreLocation,
    required String name,
    required String cityId,
  }) async {
    final bizId = await _requireBizId();
    if (bizId == null) return false;

    final payload = {'name': name, 'city_id': cityId};

    if (kDebugMode) {
      debugPrint("[StoreProvider] UPDATE payload: ${jsonEncode(payload)}");
    }

    try {
      // Catatan: backend menggunakan POST untuk edit.
      final j = await ApiJson.postMap(
        context,
        '/waveup/$bizId/store-location/$idStoreLocation',
        payload,
        withAccessToken: true,
      );

      final ok = j != null && (j['status'] as num?)?.toInt() == 200;
      if (!ok) {
        _lastError =
            j?['msg']?.toString() ??
            j?['message']?.toString() ??
            'Failed to update store location';
        return false;
      }

      await fetchStoreLocations(context);

      // Refresh detail jika sedang menampilkan detail yang sama
      if (_detail?.idStoreLocation == idStoreLocation) {
        await fetchStoreLocationDetail(context, idStoreLocation);
      }

      return true;
    } catch (e) {
      _lastError = '$e';
      if (kDebugMode) debugPrint("[StoreProvider] UPDATE exception: $e");
      return false;
    }
  }

  /// =========================
  /// DELETE
  /// =========================
  Future<bool> deleteStoreLocation(
    BuildContext context,
    String idStoreLocation,
  ) async {
    if (_stores.length <= 1) {
      _lastError = 'At least one store location is required.';
      return false;
    }

    final bizId = await _requireBizId();
    if (bizId == null) return false;

    final path = '/waveup/$bizId/store-location/remove/$idStoreLocation';
    if (kDebugMode) debugPrint("[StoreProvider] 🌐 GET $path (delete)");

    try {
      final j = await ApiJson.getMap(context, path);
      if (j == null) {
        _lastError = 'Empty response';
        return false;
      }

      final ok = (j['status'] as num?)?.toInt() == 200;
      if (!ok) {
        _lastError =
            j['msg']?.toString() ??
            j['message']?.toString() ??
            'Failed to delete store location';
        return false;
      }

      // Bersihkan detail jika sedang menunjuk id yang dihapus
      if (_detail?.idStoreLocation == idStoreLocation) {
        _detail = null;
        notifyListeners();
      }

      await fetchStoreLocations(context);
      return true;
    } catch (e) {
      _lastError = e.toString();
      if (kDebugMode) debugPrint("[StoreProvider] DELETE exception: $e");
      return false;
    }
  }

  /// =========================
  /// MISC
  /// =========================
  Future<void> refresh(BuildContext context) => fetchStoreLocations(context);

  void clearDetail() {
    _detail = null;
    notifyListeners();
  }

  /// Opsional: konsumsi error terakhir (sekali pakai buat snackbar)
  String? consumeLastError() {
    final e = _lastError;
    _lastError = null;
    return e;
  }
}
