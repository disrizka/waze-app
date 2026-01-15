// lib/providers/adjustment_provider.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:wa_blast/core/provider_helper.dart';
import 'package:wa_blast/models/product_model.dart';
import 'package:wa_blast/services/api_service.dart';

/// =========================
/// MODELS - ADJUSTMENT
/// =========================

@immutable
class AdjustmentStoreLocationLite {
  final String idStoreLocation;
  final String name;
  final String? cityName;
  final String? provinceName;

  const AdjustmentStoreLocationLite({
    required this.idStoreLocation,
    required this.name,
    this.cityName,
    this.provinceName,
  });

  factory AdjustmentStoreLocationLite.fromJson(Map<String, dynamic> j) {
    final cityJ = (j['city'] as Map?)?.cast<String, dynamic>();
    final provJ = (cityJ?['province'] as Map?)?.cast<String, dynamic>();

    return AdjustmentStoreLocationLite(
      idStoreLocation: j['idStoreLocation']?.toString() ?? '',
      name: j['name']?.toString() ?? '',
      cityName: cityJ?['name']?.toString(),
      provinceName: provJ?['name']?.toString(),
    );
  }
}

@immutable
class AdjustmentSkuAttribute {
  final String name;
  final String value;

  const AdjustmentSkuAttribute({required this.name, required this.value});

  factory AdjustmentSkuAttribute.fromJson(Map<String, dynamic> j) =>
      AdjustmentSkuAttribute(
        name: j['name']?.toString() ?? '',
        value: j['value']?.toString() ?? '',
      );
}

@immutable
class AdjustmentProductSku {
  final String idProductSku;
  final String code;
  final int price;
  final int? qty;
  final List<AdjustmentSkuAttribute> attributes;

  const AdjustmentProductSku({
    required this.idProductSku,
    required this.code,
    required this.price,
    this.qty,
    this.attributes = const [],
  });

  factory AdjustmentProductSku.fromJson(Map<String, dynamic> j) {
    int _toInt(dynamic v, {int fallback = 0}) {
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? fallback;
    }

    final attrs = (j['attributes'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(
          (e) => AdjustmentSkuAttribute.fromJson(
            Map<String, dynamic>.from(e.cast<String, dynamic>()),
          ),
        )
        .toList();

    final rawQty = j['qty'];
    final parsedQty = (rawQty is num)
        ? rawQty.toInt()
        : int.tryParse(rawQty?.toString() ?? '');

    return AdjustmentProductSku(
      idProductSku:
          j['idProductSku']?.toString() ??
          j['id_product_sku']?.toString() ??
          '',
      code: j['code']?.toString() ?? '',
      price: _toInt(j['price']),
      qty: parsedQty,
      attributes: attrs,
    );
  }
}

@immutable
class AdjustmentItem {
  final String productId;
  final String productSkuId;

  final Product? product;
  final AdjustmentProductSku? productSku;

  final int qtyIn;
  final int qtyOut;

  const AdjustmentItem({
    required this.productId,
    required this.productSkuId,
    this.product,
    this.productSku,
    required this.qtyIn,
    required this.qtyOut,
  });

  factory AdjustmentItem.fromJson(Map<String, dynamic> j) {
    int _toInt(dynamic v, {int fallback = 0}) {
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? fallback;
    }

    final productJ = (j['product'] as Map?)?.cast<String, dynamic>();
    final skuJ = (j['product_sku'] as Map?)?.cast<String, dynamic>();

    return AdjustmentItem(
      productId: j['product_id']?.toString() ?? '',
      productSkuId: j['product_sku_id']?.toString() ?? '',
      product: productJ != null ? Product.fromJson(productJ) : null,
      productSku: skuJ != null ? AdjustmentProductSku.fromJson(skuJ) : null,
      qtyIn: _toInt(j['qty_in']),
      qtyOut: _toInt(j['qty_out']),
    );
  }

  int get netQty => qtyIn - qtyOut;
}

/// 1 transaksi adjustment (list & detail)
@immutable
class AdjustmentTransaction {
  final String idTransaction;

  final String storeLocationId;
  final AdjustmentStoreLocationLite storeLocation;

  final int type;
  final String number;
  final int storeId;

  final String note;
  final String reference;
  final String status;

  final int amount;
  final int discount;
  final int shippingFee;

  final int orderAt; // unix timestamp seconds
  final int paymentMethod;

  final String createdAt;
  final String updatedAt;

  final List<AdjustmentItem> items;

  const AdjustmentTransaction({
    required this.idTransaction,
    required this.storeLocationId,
    required this.storeLocation,
    required this.type,
    required this.number,
    required this.storeId,
    required this.note,
    required this.reference,
    required this.status,
    required this.amount,
    required this.discount,
    required this.shippingFee,
    required this.orderAt,
    required this.paymentMethod,
    required this.createdAt,
    required this.updatedAt,
    required this.items,
  });

  factory AdjustmentTransaction.fromJson(Map<String, dynamic> j) {
    int _toInt(dynamic v, {int fallback = 0}) {
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? fallback;
    }

    final itemsJ = (j['items'] as List?) ?? const [];
    final parsedItems = itemsJ
        .whereType<Map>()
        .map(
          (e) => AdjustmentItem.fromJson(
            Map<String, dynamic>.from(e.cast<String, dynamic>()),
          ),
        )
        .toList();

    return AdjustmentTransaction(
      idTransaction: j['idTransaction']?.toString() ?? '',
      storeLocationId: j['store_location_id']?.toString() ?? '',
      storeLocation: AdjustmentStoreLocationLite.fromJson(
        (j['store_location'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      type: _toInt(j['type']),
      number: j['number']?.toString() ?? '',
      storeId: _toInt(j['store_id']),
      note: j['note']?.toString() ?? '',
      reference: j['reference']?.toString() ?? '',
      status: j['status']?.toString() ?? '',
      amount: _toInt(j['amount']),
      discount: _toInt(j['discount']),
      shippingFee: _toInt(j['shipping_fee']),
      orderAt: _toInt(j['order_at']),
      paymentMethod: _toInt(j['payment_method']),
      createdAt: j['created_at']?.toString() ?? '',
      updatedAt: j['updated_at']?.toString() ?? '',
      items: parsedItems,
    );
  }
}

/// Payload create adjustment (items)
@immutable
class CreateAdjustmentItemPayload {
  final String productId;
  final String productSkuId;
  final int qty;

  const CreateAdjustmentItemPayload({
    required this.productId,
    required this.productSkuId,
    required this.qty,
  });

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'product_sku_id': productSkuId,
    'qty': qty,
  };
}

/// Detail response
@immutable
class AdjustmentDetailResult {
  final AdjustmentTransaction transaction;
  final Map<String, dynamic>? stockOpname;
  final String? adjustmentStatus;

  const AdjustmentDetailResult({
    required this.transaction,
    this.stockOpname,
    this.adjustmentStatus,
  });
}

/// =========================
/// PROVIDER
/// =========================

class AdjustmentProvider with ChangeNotifier {
  /// --- LIST adjustment
  final List<AdjustmentTransaction> _adjustments = [];
  bool _loadingAdjustments = false;
  PageMeta? _pageAdjustments;
  String? _adjustmentsError;

  /// --- DETAIL adjustment
  AdjustmentDetailResult? _adjustmentDetail;
  bool _loadingAdjustmentDetail = false;
  String? _adjustmentDetailError;

  /// --- CREATE adjustment
  bool _creatingAdjustment = false;
  String? _createAdjustmentError;

  /// --- DELETE adjustment
  bool _deletingAdjustment = false;
  String? _deleteAdjustmentError;

  /// --- EDIT adjustment
  bool _editingAdjustment = false;
  String? _editAdjustmentError;

  /// --- Error umum
  String? _lastError;

  // ===== Getters =====

  List<AdjustmentTransaction> get adjustments =>
      List.unmodifiable(_adjustments);

  bool get loadingAdjustments => _loadingAdjustments;
  PageMeta? get pageAdjustments => _pageAdjustments;
  String? get adjustmentsError => _adjustmentsError;

  AdjustmentDetailResult? get adjustmentDetail => _adjustmentDetail;
  bool get loadingAdjustmentDetail => _loadingAdjustmentDetail;
  String? get adjustmentDetailError => _adjustmentDetailError;

  bool get creatingAdjustment => _creatingAdjustment;
  String? get createAdjustmentError => _createAdjustmentError;

  bool get deletingAdjustment => _deletingAdjustment;
  String? get deleteAdjustmentError => _deleteAdjustmentError;

  bool get editingAdjustment => _editingAdjustment;
  String? get editAdjustmentError => _editAdjustmentError;

  String? get lastError => _lastError;

  bool get isAdjustmentEmpty => !_loadingAdjustments && _adjustments.isEmpty;

  /// =========================
  /// 1) FETCH: Adjustment List (Infinite)
  /// =========================
  ///
  /// GET /waveup/{bizId}/transaction/adjustment?page=1&limit=50
  ///
  /// Response:
  /// {
  ///   "status": 200,
  ///   "data": [ ... ],
  ///   "page": { current_page, row_per_page, total_pages, total_rows }
  /// }
  Future<void> fetchAdjustments(
    BuildContext context, {
    int? page,
    int limit = 50,
    bool append = false, // true kalau infinite scroll page>1
  }) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      if (!append) _adjustments.clear();
      _pageAdjustments = null;
      _adjustmentsError = "Business ID is not available.";
      _lastError = _adjustmentsError;
      notifyListeners();
      return;
    }

    _loadingAdjustments = true;
    _adjustmentsError = null;
    notifyListeners();

    try {
      // endpoint adjustment pakai page & limit (bukan row_per_page)
      final buffer = StringBuffer('/waveup/$bizId/transaction/adjustment');

      final query = <String, String>{};
      if (page != null && page > 0) query['page'] = page.toString();
      if (limit > 0) query['limit'] = limit.toString();

      if (query.isNotEmpty) {
        buffer.write(
          '?' + query.entries.map((e) => '${e.key}=${e.value}').join('&'),
        );
      }

      final path = buffer.toString();
      if (kDebugMode) debugPrint('[AdjustmentProvider] GET $path');

      final jsonMap = await ApiJson.getMap(context, path);

      if (jsonMap == null) {
        if (!append) _adjustments.clear();
        _pageAdjustments = null;
        _adjustmentsError = 'Failed to load adjustment list.';
        _lastError = _adjustmentsError;
        notifyListeners();
        return;
      }

      final status = (jsonMap['status'] as num?)?.toInt() ?? 0;
      if (status < 200 || status >= 300) {
        if (!append) _adjustments.clear();
        _pageAdjustments = null;
        _adjustmentsError =
            jsonMap['message']?.toString() ?? 'Failed to load adjustment list.';
        _lastError = _adjustmentsError;
        notifyListeners();
        return;
      }

      final pageJ = (jsonMap['page'] as Map?)?.cast<String, dynamic>();
      _pageAdjustments = pageJ != null ? PageMeta.fromJson(pageJ) : null;

      final dataList = (jsonMap['data'] as List?) ?? const [];
      final parsed = dataList
          .whereType<Map>()
          .map(
            (e) => AdjustmentTransaction.fromJson(
              Map<String, dynamic>.from(e.cast<String, dynamic>()),
            ),
          )
          .toList();

      if (!append) {
        _adjustments
          ..clear()
          ..addAll(parsed);
      } else {
        _adjustments.addAll(parsed);
      }

      _adjustmentsError = null;
      _lastError = null;
      notifyListeners();
    } catch (e, st) {
      if (!append) _adjustments.clear();
      _pageAdjustments = null;
      _adjustmentsError = e.toString();
      _lastError = _adjustmentsError;
      debugPrint('[AdjustmentProvider] fetchAdjustments error: $e');
      debugPrint('$st');
      notifyListeners();
    } finally {
      _loadingAdjustments = false;
      notifyListeners();
    }
  }

  Future<void> refreshAdjustments(
    BuildContext context, {
    int limit = 50,
  }) async {
    await fetchAdjustments(context, limit: limit);
  }

  void clearAdjustments() {
    _adjustments.clear();
    _pageAdjustments = null;
    _adjustmentsError = null;
    notifyListeners();
  }

  /// =========================
  /// 2) CREATE: Adjustment
  /// =========================
  ///
  /// POST /waveup/{bizId}/transaction/adjustment
  ///
  /// Payload:
  /// {
  ///   "store_location_id": "...",
  ///   "note": "...",
  ///   "items": [ {product_id, product_sku_id, qty}, ... ]
  /// }
  Future<bool> createAdjustment({
    required BuildContext context,
    required String storeLocationId,
    required String note,
    required List<CreateAdjustmentItemPayload> items,
    bool refreshListAfter = true,
    int refreshLimit = 50,
  }) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _lastError = "Business ID is not available.";
      _createAdjustmentError = _lastError;
      notifyListeners();
      return false;
    }

    final payload = <String, dynamic>{
      'store_location_id': storeLocationId,
      'note': note,
      'items': items.map((e) => e.toJson()).toList(),
    };

    _creatingAdjustment = true;
    _createAdjustmentError = null;
    notifyListeners();

    try {
      final path = '/waveup/$bizId/transaction/adjustment';

      if (kDebugMode) {
        debugPrint('[AdjustmentProvider] POST $path');
        debugPrint('[AdjustmentProvider] payload: ${jsonEncode(payload)}');
      }

      final res = await ApiService.post(
        context,
        path,
        payload,
        withAccessToken: true,
      );

      if (kDebugMode && res != null) {
        debugPrint('[AdjustmentProvider] CREATE status: ${res.statusCode}');
        debugPrint('[AdjustmentProvider] CREATE body  : ${res.body}');
      }

      final ok = res != null && res.statusCode >= 200 && res.statusCode < 300;
      if (!ok) {
        _createAdjustmentError =
            'Failed to create adjustment: ${res?.statusCode} ${res?.body}';
        _lastError = _createAdjustmentError;
        notifyListeners();
        return false;
      }

      // body tidak kamu definisikan detailnya, tapi minimal pastikan status==200 kalau ada
      try {
        final decoded = jsonDecode(res!.body);
        final map = (decoded is Map) ? decoded.cast<String, dynamic>() : null;
        if (map != null) {
          final st = (map['status'] as num?)?.toInt() ?? 200;
          if (st < 200 || st >= 300) {
            _createAdjustmentError =
                map['message']?.toString() ?? 'Failed to create adjustment.';
            _lastError = _createAdjustmentError;
            notifyListeners();
            return false;
          }
        }
      } catch (_) {
        // ignore: kalau body bukan JSON, kita tetap anggap ok karena statusCode sudah 2xx
      }

      _createAdjustmentError = null;
      _lastError = null;
      notifyListeners();

      if (refreshListAfter) {
        await fetchAdjustments(
          context,
          page: 1,
          limit: refreshLimit,
          append: false,
        );
      }

      return true;
    } catch (e, st) {
      _createAdjustmentError = e.toString();
      _lastError = _createAdjustmentError;
      debugPrint('[AdjustmentProvider] createAdjustment error: $e');
      debugPrint('$st');
      notifyListeners();
      return false;
    } finally {
      _creatingAdjustment = false;
      notifyListeners();
    }
  }

  /// =========================
  /// 3) FETCH: Adjustment Detail
  /// =========================
  ///
  /// GET /waveup/{bizId}/transaction/adjustment/:idtransaction
  ///
  /// Response:
  /// {
  ///   "status": 200,
  ///   "data": { AdjustmentTransaction },
  ///   "stockOpname": {...},
  ///   "adjustmentStatus": "ADJUSTED"
  /// }
  Future<AdjustmentDetailResult?> fetchAdjustmentDetail(
    BuildContext context,
    String idTransaction,
  ) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _adjustmentDetail = null;
      _adjustmentDetailError = "Business ID is not available.";
      _lastError = _adjustmentDetailError;
      notifyListeners();
      return null;
    }

    _loadingAdjustmentDetail = true;
    _adjustmentDetailError = null;
    notifyListeners();

    try {
      final path = '/waveup/$bizId/transaction/adjustment/$idTransaction';
      if (kDebugMode) debugPrint('[AdjustmentProvider] GET $path');

      final jsonMap = await ApiJson.getMap(context, path);

      if (jsonMap == null) {
        _adjustmentDetail = null;
        _adjustmentDetailError = 'Empty response';
        _lastError = _adjustmentDetailError;
        notifyListeners();
        return null;
      }

      final status = (jsonMap['status'] as num?)?.toInt() ?? 0;
      if (status < 200 || status >= 300) {
        _adjustmentDetail = null;
        _adjustmentDetailError =
            jsonMap['message']?.toString() ??
            'Failed to load adjustment detail.';
        _lastError = _adjustmentDetailError;
        notifyListeners();
        return null;
      }

      final dataJ =
          (jsonMap['data'] as Map?)?.cast<String, dynamic>() ?? const {};
      if (kDebugMode) {
        debugPrint('[AdjustmentProvider] detail data: ${jsonEncode(dataJ)}');
      }

      final txn = AdjustmentTransaction.fromJson(dataJ);
      final stockOpname = (jsonMap['stockOpname'] as Map?)
          ?.cast<String, dynamic>();
      final adjStatus = jsonMap['adjustmentStatus']?.toString();

      final result = AdjustmentDetailResult(
        transaction: txn,
        stockOpname: stockOpname,
        adjustmentStatus: adjStatus,
      );

      _adjustmentDetail = result;
      _adjustmentDetailError = null;
      _lastError = null;
      notifyListeners();

      return result;
    } catch (e, st) {
      _adjustmentDetail = null;
      _adjustmentDetailError = e.toString();
      _lastError = _adjustmentDetailError;
      debugPrint('[AdjustmentProvider] fetchAdjustmentDetail error: $e');
      debugPrint('$st');
      notifyListeners();
      return null;
    } finally {
      _loadingAdjustmentDetail = false;
      notifyListeners();
    }
  }

  void clearAdjustmentDetail() {
    _adjustmentDetail = null;
    _adjustmentDetailError = null;
    notifyListeners();
  }

  /// =========================
  /// 4) DELETE: Adjustment
  /// =========================
  ///
  /// GET /waveup/{bizId}/transaction/adjustment/remove/:idtransaction
  ///
  /// Response:
  /// { "status": 200 } atau { "status": 400, "message": "..." }
  Future<bool> deleteAdjustment({
    required BuildContext context,
    required String idTransaction,
    bool removeFromListOnSuccess = true,
  }) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _lastError = "Business ID is not available.";
      _deleteAdjustmentError = _lastError;
      notifyListeners();
      return false;
    }

    _deletingAdjustment = true;
    _deleteAdjustmentError = null;
    notifyListeners();

    try {
      final path =
          '/waveup/$bizId/transaction/adjustment/remove/$idTransaction';
      if (kDebugMode) debugPrint('[AdjustmentProvider] GET $path');

      final jsonMap = await ApiJson.getMap(context, path);

      if (jsonMap == null) {
        _deleteAdjustmentError = 'Empty response';
        _lastError = _deleteAdjustmentError;
        notifyListeners();
        return false;
      }

      final status = (jsonMap['status'] as num?)?.toInt() ?? 0;
      if (status < 200 || status >= 300) {
        _deleteAdjustmentError =
            jsonMap['message']?.toString() ??
            'Adjustment yang sudah diproses tidak dapat dihapus';
        _lastError = _deleteAdjustmentError;
        notifyListeners();
        return false;
      }

      if (removeFromListOnSuccess) {
        _adjustments.removeWhere((x) => x.idTransaction == idTransaction);
      }

      // kalau kebetulan detail yg kebuka adalah ini, clear
      if (_adjustmentDetail?.transaction.idTransaction == idTransaction) {
        _adjustmentDetail = null;
        _adjustmentDetailError = null;
      }

      _deleteAdjustmentError = null;
      _lastError = null;
      notifyListeners();
      return true;
    } catch (e, st) {
      _deleteAdjustmentError = e.toString();
      _lastError = _deleteAdjustmentError;
      debugPrint('[AdjustmentProvider] deleteAdjustment error: $e');
      debugPrint('$st');
      notifyListeners();
      return false;
    } finally {
      _deletingAdjustment = false;
      notifyListeners();
    }
  }

  /// =========================
  /// 5) EDIT: Adjustment
  /// =========================
  ///
  /// POST /waveup/:idBusiness/transaction/adjustment/:idtransaction
  ///
  /// Payload:
  /// { "qty": 10, "note": "Correction note" }
  ///
  /// Response:
  /// { "status": 200 } atau { "status": 400, "message": "..." }
  Future<bool> editAdjustment({
    required BuildContext context,
    required String idTransaction,
    required int qty,
    required String note,
    bool refreshDetailAfter = true,
  }) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _lastError = "Business ID is not available.";
      _editAdjustmentError = _lastError;
      notifyListeners();
      return false;
    }

    final payload = <String, dynamic>{'qty': qty, 'note': note};

    _editingAdjustment = true;
    _editAdjustmentError = null;
    notifyListeners();

    try {
      final path = '/waveup/$bizId/transaction/adjustment/$idTransaction';

      if (kDebugMode) {
        debugPrint('[AdjustmentProvider] POST $path');
        debugPrint('[AdjustmentProvider] payload: ${jsonEncode(payload)}');
      }

      final res = await ApiService.post(
        context,
        path,
        payload,
        withAccessToken: true,
      );

      if (kDebugMode && res != null) {
        debugPrint('[AdjustmentProvider] EDIT status: ${res.statusCode}');
        debugPrint('[AdjustmentProvider] EDIT body  : ${res.body}');
      }

      final ok = res != null && res.statusCode >= 200 && res.statusCode < 300;
      if (!ok) {
        _editAdjustmentError =
            'Failed to edit adjustment: ${res?.statusCode} ${res?.body}';
        _lastError = _editAdjustmentError;
        notifyListeners();
        return false;
      }

      // Pastikan status==200 kalau body JSON
      try {
        final decoded = jsonDecode(res!.body);
        final map = (decoded is Map) ? decoded.cast<String, dynamic>() : null;
        if (map != null) {
          final st = (map['status'] as num?)?.toInt() ?? 200;
          if (st < 200 || st >= 300) {
            _editAdjustmentError =
                map['message']?.toString() ??
                'Adjustment yang sudah diproses tidak dapat diubah';
            _lastError = _editAdjustmentError;
            notifyListeners();
            return false;
          }
        }
      } catch (_) {
        // ignore
      }

      _editAdjustmentError = null;
      _lastError = null;
      notifyListeners();

      if (refreshDetailAfter) {
        await fetchAdjustmentDetail(context, idTransaction);
      }

      return true;
    } catch (e, st) {
      _editAdjustmentError = e.toString();
      _lastError = _editAdjustmentError;
      debugPrint('[AdjustmentProvider] editAdjustment error: $e');
      debugPrint('$st');
      notifyListeners();
      return false;
    } finally {
      _editingAdjustment = false;
      notifyListeners();
    }
  }
}
