// lib/providers/subscription_provider.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';
import 'package:intl/intl.dart';
import 'package:midtrans_sdk/midtrans_sdk.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' as p;
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wa_blast/screens/subscription/subscription_payment_success_screen.dart';

import '../core/provider_helper.dart';
import '../models/premium_plan_model.dart';
import '../services/api_service.dart';
import '../widgets/payment_webview_screen.dart';

// -------------------------------------------------------------
// ENUM: BillingCycle
// -------------------------------------------------------------
enum BillingCycle { monthly, yearly }

// -------------------------------------------------------------
// Result cek voucher
// -------------------------------------------------------------

class SubscriptionHistoryItem {
  final String id;
  final String number;
  final int amount;
  final DateTime? createdAt;
  final int paid; // 0 / 1
  final DateTime? paidAt;
  final String paidStatus;

  final int paymentMethod;
  final String paymentMethodName;

  final String planId;
  final String planName;
  final String pricingId;

  final String description;
  final String period;
  final String type;

  final String paymentLink;
  final String paymentToken;

  final String transactionFeeId;

  SubscriptionHistoryItem({
    required this.id,
    required this.number,
    required this.amount,
    required this.createdAt,
    required this.paid,
    required this.paidAt,
    required this.paidStatus,
    required this.paymentMethod,
    required this.paymentMethodName,
    required this.planId,
    required this.planName,
    required this.pricingId,
    required this.description,
    required this.period,
    required this.type,
    required this.paymentLink,
    required this.paymentToken,
    required this.transactionFeeId,
  });

  factory SubscriptionHistoryItem.fromJson(Map<String, dynamic> json) {
    DateTime? _parseDate(String? raw) {
      if (raw == null || raw.isEmpty) return null;
      try {
        return DateTime.parse(raw);
      } catch (_) {
        return null;
      }
    }

    String _pickTxFeeId(Map<String, dynamic> j) {
      final candidates = [
        'idTransactionFee',
        'id_transaction_fee',
        'transaction_fee_id',
        'transactionFeeId',
        'transaction_fee',
      ];

      for (final k in candidates) {
        final v = j[k];
        if (v == null) continue;

        if (v is Map && v['id'] != null) {
          final s = v['id'].toString().trim();
          if (s.isNotEmpty) return s;
        }

        final s = v.toString().trim();
        if (s.isNotEmpty && s.toLowerCase() != 'null') return s;
      }
      return '';
    }

    return SubscriptionHistoryItem(
      id: json['id']?.toString() ?? '',
      number: json['number']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      createdAt: _parseDate(json['created_at']?.toString()),
      paid: (json['paid'] as num?)?.toInt() ?? 0,
      paidAt: _parseDate(json['paid_at']?.toString()),
      paidStatus: json['paid_status']?.toString() ?? '',
      paymentMethod: (json['payment_method'] as num?)?.toInt() ?? 0,
      paymentMethodName: json['payment_method_name']?.toString() ?? '',
      planId: json['plan_id']?.toString() ?? '',
      planName: json['plan_name']?.toString() ?? '',
      pricingId: json['pricing_id']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      period: json['period']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      paymentLink: json['payment_link']?.toString() ?? '',
      paymentToken: json['payment_token']?.toString() ?? '',
      transactionFeeId: _pickTxFeeId(json),
    );
  }
}

class TransactionFeeInfo {
  final String id;
  final int month;
  final int year;
  final String period;
  final String status; // pending / paid / etc
  final int totalFee;
  final int transactionCount;

  const TransactionFeeInfo({
    required this.id,
    required this.month,
    required this.year,
    required this.period,
    required this.status,
    required this.totalFee,
    required this.transactionCount,
  });

  factory TransactionFeeInfo.fromJson(Map<String, dynamic> json) {
    return TransactionFeeInfo(
      id: json['id']?.toString() ?? '',
      month: (json['month'] as num?)?.toInt() ?? 0,
      year: (json['year'] as num?)?.toInt() ?? 0,
      period: json['period']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      totalFee: (json['total_fee'] as num?)?.toInt() ?? 0,
      transactionCount: (json['transaction_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class TransactionFeeHistoryLineItem {
  final String transactionReference;
  final int qtyIn;
  final int qtyOut;
  final int price;
  final int discount;

  final String productId;
  final String productName;

  const TransactionFeeHistoryLineItem({
    required this.transactionReference,
    required this.qtyIn,
    required this.qtyOut,
    required this.price,
    required this.discount,
    required this.productId,
    required this.productName,
  });

  factory TransactionFeeHistoryLineItem.fromJson(Map<String, dynamic> json) {
    final product = (json['product'] is Map) ? (json['product'] as Map) : null;

    return TransactionFeeHistoryLineItem(
      transactionReference: json['transaction_reference']?.toString() ?? '',
      qtyIn: (json['qty_in'] as num?)?.toInt() ?? 0,
      qtyOut: (json['qty_out'] as num?)?.toInt() ?? 0,
      price: (json['price'] as num?)?.toInt() ?? 0,
      discount: (json['discount'] as num?)?.toInt() ?? 0,
      productId:
          (product?['idProduct'] ?? json['product_id'])?.toString() ?? '',
      productName: (product?['name'])?.toString() ?? '-',
    );
  }
}

class TransactionFeeHistoryEntry {
  final String id;
  final String number;
  final int amount;
  final String status; // paid / etc
  final DateTime? createdAt;

  final String storeLocationName;
  final String cityName;

  final List<TransactionFeeHistoryLineItem> items;

  const TransactionFeeHistoryEntry({
    required this.id,
    required this.number,
    required this.amount,
    required this.status,
    required this.createdAt,
    required this.storeLocationName,
    required this.cityName,
    required this.items,
  });

  factory TransactionFeeHistoryEntry.fromJson(Map<String, dynamic> json) {
    DateTime? _parseDate(String? raw) {
      if (raw == null || raw.isEmpty) return null;
      try {
        return DateTime.parse(raw);
      } catch (_) {
        return null;
      }
    }

    final store = (json['store_location'] is Map)
        ? (json['store_location'] as Map)
        : null;

    final city = (store?['city'] is Map) ? (store?['city'] as Map) : null;

    final rawItems = (json['items'] is List)
        ? (json['items'] as List)
        : const [];
    final items = rawItems
        .whereType<Map>()
        .map(
          (e) =>
              TransactionFeeHistoryLineItem.fromJson(e.cast<String, dynamic>()),
        )
        .toList();

    return TransactionFeeHistoryEntry(
      id: json['id']?.toString() ?? '',
      number: json['number']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? '',
      createdAt: _parseDate(json['created_at']?.toString()),
      storeLocationName: (store?['name'])?.toString() ?? '-',
      cityName: (city?['name'])?.toString() ?? '',
      items: items,
    );
  }
}

class _TransactionFeeDetailPagingState {
  TransactionFeeInfo? info;
  List<TransactionFeeHistoryEntry> items = [];

  bool isLoading = false;
  bool isLoadingMore = false;

  String? error;
  String? moreError;

  int page = 1;
  int totalPages = 1;
  int rowPerPage = 10;
  int totalRows = 0;

  bool hasMore = true;

  int limit = 10;
}

class VoucherCheckResult {
  final bool isValid;
  final int originalPrice;
  final int finalPrice;
  final int discount;
  final String? voucherName;
  final String? voucherDesc;
  final String? message;

  const VoucherCheckResult({
    required this.isValid,
    required this.originalPrice,
    required this.finalPrice,
    required this.discount,
    this.voucherName,
    this.voucherDesc,
    this.message,
  });
}

class PaymentResult {
  final String status;
  final String? transactionId;
  final String? paymentType;
  final String? message;
  final String? raw;

  PaymentResult(
    this.status, {
    this.transactionId,
    this.paymentType,
    this.message,
    this.raw,
  });
}

class TransactionFeeItem {
  final String idTransactionFee;
  final String idBusiness;
  final int month;
  final int year;
  final int transactionCount;
  final int totalFee;
  final String status; // pending / paid / etc

  const TransactionFeeItem({
    required this.idTransactionFee,
    required this.idBusiness,
    required this.month,
    required this.year,
    required this.transactionCount,
    required this.totalFee,
    required this.status,
  });

  factory TransactionFeeItem.fromJson(Map<String, dynamic> json) {
    return TransactionFeeItem(
      idTransactionFee: json['idTransactionFee']?.toString() ?? '',
      idBusiness: json['idBusiness']?.toString() ?? '',
      month: (json['month'] as num?)?.toInt() ?? 0,
      year: (json['year'] as num?)?.toInt() ?? 0,
      transactionCount: (json['transaction_count'] as num?)?.toInt() ?? 0,
      totalFee: (json['total_fee'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? '',
    );
  }
}

class _HistoryPagingState {
  List<SubscriptionHistoryItem> items = [];

  bool isLoading = false;
  bool isLoadingMore = false;

  String? error;
  String? moreError;

  int page = 1;
  int totalPages = 1;
  int rowPerPage = 10;
  int totalRows = 0;

  bool hasMore = true;

  int limit = 10;
  String search = '';
}

/// StoreKit delegate (required by in_app_purchase_storekit for some flows)
class _WaveUpPaymentQueueDelegate implements SKPaymentQueueDelegateWrapper {
  @override
  bool shouldContinueTransaction(
    SKPaymentTransactionWrapper transaction,
    SKStorefrontWrapper storefront,
  ) {
    return true;
  }

  @override
  bool shouldShowPriceConsent() {
    return false;
  }
}

// -------------------------------------------------------------
// SubscriptionProvider
// -------------------------------------------------------------
class SubscriptionProvider with ChangeNotifier {
  // ====== Harga default (fallback kalau belum ada data plan) ======
  double _monthlyPrice = 11.0;
  double _yearlyPrice = 120.0;

  PremiumPlan? _lastPaidPlan;
  PlanPricing? _lastPaidPricing;

  BillingCycle _selectedCycle = BillingCycle.monthly;

  // ====== State UI umum ======
  bool _isProcessing = false;
  bool _isLoadingPlans = false;
  String? _errorMessage;

  // ====== Premium plan list ======
  List<PremiumPlan> _plans = [];

  // ====== Midtrans related ======
  MidtransSDK? _midtrans;
  Completer<PaymentResult>? _snapCompleter;
  Timer? _paymentCheckTimer;
  String? _currentTransactionNumber;

  // ---------------------------------------------------------------------------
  // ✅ iOS App Store Subscription / StoreKit (moved from screen)
  // ---------------------------------------------------------------------------
  bool get isIOS => !kIsWeb && Platform.isIOS;

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _iapPurchaseSub;

  bool _iosIapInitDone = false;
  bool _iosIapInitLoading = false;
  bool _iosIapAvailable = false;

  bool _iosPurchasing = false;
  String? _iosIapError;

  // ---------------------------------------------------------------------------
  // ✅ Apple verify endpoint (after purchase success)
  // ---------------------------------------------------------------------------
  BuildContext? _iosLastContext;
  final Set<String> _verifiedAppleTransactionIds = <String>{};

  Future<int> _getUserIdForAppleVerify() async {
    // Ambil user_id dari SharedPreferences (coba beberapa key umum).
    // Kalau di project kamu user id disimpan di key lain, tinggal tambahin di candidates.
    final prefs = await SharedPreferences.getInstance();

    final candidates = <String>[
      'user_id',
      'userId',
      'id_user',
      'idUser',
      'uid',
    ];

    for (final k in candidates) {
      final v = prefs.get(k);
      if (v == null) continue;

      if (v is int) return v;
      final parsed = int.tryParse(v.toString());
      if (parsed != null && parsed > 0) return parsed;
    }

    // fallback
    debugPrint(
      '[IAP][AppleVerify] ⚠️ user_id not found in SharedPreferences. Using 0.',
    );
    return 0;
  }

  Map<String, dynamic>? _safeJsonMap(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _postAppleVerify({
    required String transactionId,
    required String receiptToken,
  }) async {
    final ctx = _iosLastContext;
    if (ctx == null) {
      debugPrint('[IAP][AppleVerify] ❌ No context available to call API.');
      return;
    }

    if (!ctx.mounted) {
      debugPrint('[IAP][AppleVerify] ❌ Context not mounted.');
      return;
    }

    if (transactionId.trim().isEmpty) {
      debugPrint('[IAP][AppleVerify] ❌ Missing transaction_id.');
      return;
    }

    if (_verifiedAppleTransactionIds.contains(transactionId)) {
      debugPrint(
        '[IAP][AppleVerify] ⏭️ Already verified tx=$transactionId, skip.',
      );
      return;
    }

    final userId = await _getUserIdForAppleVerify();

    const path = '/premium/apple/verify';
    final payload = <String, dynamic>{
      "transaction_id": transactionId,
      "receipt_token": receiptToken,
      "user_id": userId,
    };

    // Debug payload (receipt token panjang, jadi kita chunk)
    debugPrint(
      '📤 [IAP][AppleVerify] POST $path payload:\n'
      '${const JsonEncoder.withIndent("  ").convert({"transaction_id": transactionId, "user_id": userId, "receipt_token_len": receiptToken.length})}',
    );

    try {
      final res = await ApiService.post(
        ctx,
        path,
        payload,
        withAccessToken: true,
      );

      final raw = res.body;
      debugPrint(
        '[IAP][AppleVerify] ◀︎ ${res.statusCode} '
        '${raw.length > 500 ? raw.substring(0, 500) + "…" : raw}',
      );

      // Anggap berhasil kalau HTTP 2xx dan/atau JSON status==200
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final m = _safeJsonMap(raw);
        final apiStatus = (m?['status'] as num?)?.toInt();
        if (apiStatus == null || apiStatus == 200) {
          _verifiedAppleTransactionIds.add(transactionId);
          debugPrint('[IAP][AppleVerify] ✅ Verified OK tx=$transactionId');
          return;
        }

        debugPrint(
          '[IAP][AppleVerify] ⚠️ API status != 200 (status=$apiStatus)',
        );
        return;
      }

      debugPrint('[IAP][AppleVerify] ❌ HTTP error ${res.statusCode}');
    } catch (e, st) {
      debugPrint('[IAP][AppleVerify] ❌ error: $e\n$st');
    }
  }

  /// Dipakai UI untuk show snackbar sekali (screen akan clear).
  String? _iosLastMessage;

  /// Cache product details
  final Map<String, ProductDetails> _iosProductsById = {};

  InAppPurchaseStoreKitPlatformAddition? _iosAddition;
  final _WaveUpPaymentQueueDelegate _queueDelegate =
      _WaveUpPaymentQueueDelegate();

  /// Mapping productId App Store Connect (sesuaikan dengan product kamu)
  static const Map<int, String> _iosProductIdByMonths = {
    1: 'premium_monthly',
    6: 'premium_6_months',
    12: 'premium_12_months',
  };

  /// Opsi mapping by pricingId (id pricing dari backend)
  static const Map<String, String> _iosProductIdByPricingId = {
    // 'pricing_id_123': 'com.company.app.premium.monthly',
  };

  bool get iosIapInitDone => _iosIapInitDone;
  bool get iosIapInitLoading => _iosIapInitLoading;
  bool get iosIapAvailable => _iosIapAvailable;

  bool get iosPurchasing => _iosPurchasing;
  String? get iosIapError => _iosIapError;

  String? get iosLastMessage => _iosLastMessage;

  void clearIosLastMessage() {
    if ((_iosLastMessage ?? '').isEmpty) return;
    _iosLastMessage = null;
    notifyListeners();
  }

  void _iapLog(String msg) {
    if (kDebugMode) debugPrint('[IAP][Provider] $msg');
  }

  Set<String> _allKnownIosProductIds() {
    final ids = <String>{};
    ids.addAll(_iosProductIdByMonths.values.where((e) => e.trim().isNotEmpty));
    ids.addAll(
      _iosProductIdByPricingId.values.where((e) => e.trim().isNotEmpty),
    );
    return ids;
  }

  String? iosProductIdForPricing(PlanPricing pricing) {
    final pricingKey = pricing.id.toString();
    final byPricing = _iosProductIdByPricingId[pricingKey];
    if (byPricing != null && byPricing.trim().isNotEmpty) return byPricing;

    final byMonths = _iosProductIdByMonths[pricing.period];
    if (byMonths != null && byMonths.trim().isNotEmpty) return byMonths;

    return null;
  }

  ProductDetails? iosCachedProductForPricing(PlanPricing pricing) {
    final id = iosProductIdForPricing(pricing);
    if (id == null) return null;
    return _iosProductsById[id];
  }

  Future<void> initIosIap() async {
    if (!isIOS) {
      _iosIapInitDone = true;
      _iosIapInitLoading = false;
      _iosIapAvailable = false;
      return;
    }
    if (_iosIapInitLoading) return;

    _iapLog('init start');
    _iosIapInitLoading = true;
    _iosIapInitDone = false;
    _iosIapAvailable = false;
    _iosIapError = null;
    notifyListeners();

    try {
      _iapPurchaseSub?.cancel();
      _iapPurchaseSub = _iap.purchaseStream.listen(
        (purchases) {
          _iapLog('purchaseStream -> ${purchases.length} item(s)');
          unawaited(_handlePurchaseUpdates(purchases));
        },
        onError: (e) {
          _iapLog('purchaseStream onError: $e');
          _iosIapError = e.toString();
          _iosLastMessage = _iosIapError;
          notifyListeners();
        },
      );

      _iosAddition = _iap
          .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
      await _iosAddition!.setDelegate(_queueDelegate);

      await Future.delayed(const Duration(milliseconds: 350));

      final available = await _iap.isAvailable();
      _iapLog('isAvailable=$available');

      _iosIapAvailable = available;

      if (available) {
        await _preloadIosProductsWithRetry();
      }

      _iosIapInitDone = true;
      _iosIapInitLoading = false;
      notifyListeners();

      _iapLog(
        'init done (available=$_iosIapAvailable, cached=${_iosProductsById.length})',
      );
    } catch (e) {
      _iapLog('init error: $e');
      _iosIapAvailable = false;
      _iosIapInitDone = true;
      _iosIapInitLoading = false;
      _iosIapError = e.toString();
      _iosLastMessage = _iosIapError;
      notifyListeners();
    }
  }

  Future<void> _preloadIosProductsWithRetry() async {
    final ids = _allKnownIosProductIds();
    _iapLog('preload products: $ids');
    if (ids.isEmpty) return;

    final ok1 = await _preloadIosProductsOnce(ids);
    if (ok1) return;

    await Future.delayed(const Duration(milliseconds: 900));
    await _preloadIosProductsOnce(ids);
  }

  Future<bool> _preloadIosProductsOnce(Set<String> ids) async {
    final resp = await _iap.queryProductDetails(ids);

    _iapLog(
      'query error code=${resp.error?.code} message=${resp.error?.message}',
    );
    _iapLog('notFound=${resp.notFoundIDs}');
    _iapLog('found=${resp.productDetails.map((e) => e.id).toList()}');

    if (resp.error != null) {
      _iosIapError = resp.error.toString();
      notifyListeners();
      return false;
    }

    for (final p in resp.productDetails) {
      _iosProductsById[p.id] = p;
    }

    notifyListeners();
    return resp.productDetails.isNotEmpty;
  }

  Future<ProductDetails?> _getIosProduct(String productId) async {
    final cached = _iosProductsById[productId];
    if (cached != null) return cached;

    final resp1 = await _iap.queryProductDetails({productId});
    if (resp1.error == null && resp1.productDetails.isNotEmpty) {
      _iosProductsById[productId] = resp1.productDetails.first;
      notifyListeners();
      return resp1.productDetails.first;
    }

    await Future.delayed(const Duration(milliseconds: 800));

    final resp2 = await _iap.queryProductDetails({productId});
    if (resp2.error == null && resp2.productDetails.isNotEmpty) {
      _iosProductsById[productId] = resp2.productDetails.first;
      notifyListeners();
      return resp2.productDetails.first;
    }

    if (resp2.error != null) {
      throw Exception(resp2.error!.message);
    }

    return null;
  }

  Future<void> startIosSubscriptionPurchase({
    required BuildContext context,
    required PlanPricing pricing,
  }) async {
    if (!isIOS) return;

    // simpan context untuk dipakai verify
    _iosLastContext = context;

    if (!_iosIapInitDone || _iosIapInitLoading) {
      await initIosIap();
    }

    if (!_iosIapAvailable) {
      _iosLastMessage =
          'App Store payment is unavailable on this device. Check StoreKit config / restrictions.';
      notifyListeners();
      return;
    }

    final productId = iosProductIdForPricing(pricing);
    if (productId == null || productId.isEmpty) {
      _iosLastMessage = 'iOS Product ID mapping is not set.';
      notifyListeners();
      return;
    }

    _iosPurchasing = true;
    _iosIapError = null;
    notifyListeners();

    try {
      final product = await _getIosProduct(productId);
      if (product == null) {
        throw Exception('Product not found on App Store / StoreKit config.');
      }

      final purchaseParam = PurchaseParam(productDetails: product);

      final ok = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      if (!ok) {
        _iosPurchasing = false;
        _iosLastMessage = 'Failed to start purchase.';
        notifyListeners();
      }
    } catch (e) {
      _iosPurchasing = false;
      _iosIapError = e.toString();
      _iosLastMessage = 'Purchase error: $e';
      notifyListeners();
    }
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.status == PurchaseStatus.pending) {
        _iosPurchasing = true;
        notifyListeners();
        continue;
      }

      if (p.status == PurchaseStatus.error) {
        _iosPurchasing = false;
        _iosIapError = p.error?.message ?? 'Unknown purchase error';
        _iosLastMessage = _iosIapError;
        notifyListeners();
        continue;
      }

      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        _iosPurchasing = false;

        // ===== StoreKit 2 JWS =====
        final receiptToken = p.verificationData.serverVerificationData;

        // 1) purchaseID sering sudah berisi transactionId (bergantung platform wrapper)
        String? transactionId = p.purchaseID;
        String? originalTransactionId;

        // 2) Kalau SK2, coba parse transactionId & originalTransactionId dari JWS payload
        if (p is SK2PurchaseDetails) {
          final parts = receiptToken.split('.');
          if (parts.length == 3) {
            try {
              final payloadJson = utf8.decode(
                base64Url.decode(base64Url.normalize(parts[1])),
              );
              final payloadMap =
                  jsonDecode(payloadJson) as Map<String, dynamic>;

              transactionId ??= payloadMap['transactionId']?.toString();
              originalTransactionId ??= payloadMap['originalTransactionId']
                  ?.toString();
            } catch (_) {
              // ignore parse error, still print payload with what we have
            }
          }
        }

        // ===== Payload yang mau kamu kirim ke backend =====
        final payload = <String, dynamic>{
          "platform": "ios",
          "store": "apple",
          "product_id": p.productID,
          "transaction_id": transactionId,
          "original_transaction_id": originalTransactionId,
          "receipt_token": receiptToken, // JWS (SK2) biasanya panjang
        };

        void _printLong(String label, String text, {int chunkSize = 800}) {
          debugPrint('----- $label (len=${text.length}) -----');
          for (var i = 0; i < text.length; i += chunkSize) {
            final end = (i + chunkSize < text.length)
                ? i + chunkSize
                : text.length;
            debugPrint(text.substring(i, end));
          }
          debugPrint('----- end $label -----');
        }

        _printLong('receipt_token', receiptToken);

        // ===== Print payload (rapi) =====
        debugPrint(
          '✅ [IAP][SK2] PURCHASE SUCCESS PAYLOAD:\n${const JsonEncoder.withIndent("  ").convert(payload)}',
        );

        _iosLastMessage = 'Subscription purchased successfully.';
        notifyListeners();
      }

      if (p.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(p);
        } catch (e) {
          _iapLog('completePurchase error: $e');
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // HELPER FORMAT RUPIAH
  // ---------------------------------------------------------------------------
  String _formatRupiah(num value) {
    final intVal = value.floor();
    final s = intVal.toString();
    final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
    final withDot = s.replaceAllMapped(reg, (m) => '.');
    return 'Rp $withDot';
  }

  // ---------------------------------------------------------------------------
  // GETTER
  // ---------------------------------------------------------------------------
  BillingCycle get selectedCycle => _selectedCycle;

  bool get isProcessing => _isProcessing;
  bool get isLoadingPlans => _isLoadingPlans;
  String? get errorMessage => _errorMessage;

  List<PremiumPlan> get plans => List.unmodifiable(_plans);

  double get monthlyPrice => _monthlyPrice;
  double get yearlyPrice => _yearlyPrice;

  PremiumPlan? get firstPlan => _plans.isNotEmpty ? _plans.first : null;

  static const String _historyType = 'premium_business';

  final Map<String, _HistoryPagingState> _historyStates = {};

  final Map<String, _TransactionFeeDetailPagingState> _txFeeDetailStates = {};

  _TransactionFeeDetailPagingState _txFeeState(String idTransactionFee) =>
      _txFeeDetailStates.putIfAbsent(
        idTransactionFee,
        () => _TransactionFeeDetailPagingState(),
      );

  TransactionFeeInfo? transactionFeeInfoOf(String idTransactionFee) =>
      _txFeeState(idTransactionFee).info;

  List<TransactionFeeHistoryEntry> transactionFeeHistoryOf(
    String idTransactionFee,
  ) => List.unmodifiable(_txFeeState(idTransactionFee).items);

  bool isLoadingTransactionFeeHistoryOf(String idTransactionFee) =>
      _txFeeState(idTransactionFee).isLoading;

  bool isLoadingMoreTransactionFeeHistoryOf(String idTransactionFee) =>
      _txFeeState(idTransactionFee).isLoadingMore;

  String? transactionFeeHistoryErrorOf(String idTransactionFee) =>
      _txFeeState(idTransactionFee).error;

  String? transactionFeeHistoryMoreErrorOf(String idTransactionFee) =>
      _txFeeState(idTransactionFee).moreError;

  bool transactionFeeHistoryHasMoreOf(String idTransactionFee) =>
      _txFeeState(idTransactionFee).hasMore;

  Future<void> fetchTransactionFeeHistoryDetail(
    BuildContext context, {
    required String idTransactionFee,
    bool refresh = true,
    int limit = 10,
  }) async {
    final st = _txFeeState(idTransactionFee);
    if (st.isLoading) return;

    if (refresh) {
      st.page = 1;
      st.totalPages = 1;
      st.rowPerPage = limit;
      st.totalRows = 0;
      st.hasMore = true;

      st.error = null;
      st.moreError = null;
      st.items = [];
      st.info = null;

      st.limit = limit;
    }

    st.isLoading = true;
    st.error = null;
    notifyListeners();

    try {
      final bizId = await BizIdCache.get();
      if (bizId == null || bizId.toString().trim().isEmpty) {
        throw Exception(
          'Business ID not found. Please select a business first.',
        );
      }

      final path =
          '/waveup/$bizId/transaction-fee/transaction-history-fee-increase/$idTransactionFee'
          '?page=1&limit=$limit';

      final res = await ApiService.get(context, path, withAccessToken: true);

      final raw = res.body;
      debugPrint(
        '[SubscriptionProvider] GET $path ◀︎ ${res.statusCode} '
        '${raw.length > 400 ? raw.substring(0, 400) + "…" : raw}',
      );

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('HTTP ${res.statusCode}');
      }

      Map<String, dynamic>? decoded;
      try {
        decoded = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        decoded = null;
      }
      if (decoded == null) throw Exception('Invalid JSON response');

      final status = (decoded['status'] as num?)?.toInt() ?? 0;
      if (status != 200) {
        final msg = decoded['msg']?.toString() ?? 'Failed to load fee detail';
        throw Exception('$msg (status=$status)');
      }

      final infoRaw = decoded['transaction_fee_info'];
      if (infoRaw is Map) {
        st.info = TransactionFeeInfo.fromJson(infoRaw.cast<String, dynamic>());
      }

      final data = decoded['data'];
      final items = (data is List)
          ? data
                .whereType<Map>()
                .map(
                  (e) => TransactionFeeHistoryEntry.fromJson(
                    e.cast<String, dynamic>(),
                  ),
                )
                .toList()
          : <TransactionFeeHistoryEntry>[];

      final page = decoded['page'];
      final currentPage = (page is Map)
          ? (page['current_page'] as num?)?.toInt() ?? 1
          : 1;
      final totalPages = (page is Map)
          ? (page['total_pages'] as num?)?.toInt() ?? 1
          : 1;
      final rowPerPage = (page is Map)
          ? (page['row_per_page'] as num?)?.toInt() ?? limit
          : limit;
      final totalRows = (page is Map)
          ? (page['total_rows'] as num?)?.toInt() ?? items.length
          : items.length;

      st.page = currentPage;
      st.totalPages = totalPages;
      st.rowPerPage = rowPerPage;
      st.totalRows = totalRows;

      st.items = items;
      st.hasMore = st.page < st.totalPages;

      st.error = null;
      st.moreError = null;
    } catch (e, stTrace) {
      debugPrint(
        '[SubscriptionProvider] fetchTransactionFeeHistoryDetail error: $e\n$stTrace',
      );
      st.error = 'Failed to load fee detail: $e';
      st.items = [];
      st.hasMore = false;
    } finally {
      st.isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMoreTransactionFeeHistoryDetail(
    BuildContext context, {
    required String idTransactionFee,
    int? limit,
  }) async {
    final st = _txFeeState(idTransactionFee);

    if (st.isLoading || st.isLoadingMore) return;
    if (!st.hasMore) return;

    final effectiveLimit = limit ?? st.limit;
    st.isLoadingMore = true;
    st.moreError = null;
    notifyListeners();

    final nextPage = st.page + 1;

    try {
      final bizId = await BizIdCache.get();
      if (bizId == null || bizId.toString().trim().isEmpty) {
        throw Exception(
          'Business ID not found. Please select a business first.',
        );
      }

      final path =
          '/waveup/$bizId/transaction-fee/transaction-history-fee-increase/$idTransactionFee'
          '?page=$nextPage&limit=$effectiveLimit';

      final res = await ApiService.get(context, path, withAccessToken: true);

      final raw = res.body;
      debugPrint(
        '[SubscriptionProvider] GET $path ◀︎ ${res.statusCode} '
        '${raw.length > 400 ? raw.substring(0, 400) + "…" : raw}',
      );

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('HTTP ${res.statusCode}');
      }

      Map<String, dynamic>? decoded;
      try {
        decoded = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        decoded = null;
      }
      if (decoded == null) throw Exception('Invalid JSON response');

      final status = (decoded['status'] as num?)?.toInt() ?? 0;
      if (status != 200) {
        final msg =
            decoded['msg']?.toString() ?? 'Failed to load more fee detail';
        throw Exception('$msg (status=$status)');
      }

      final infoRaw = decoded['transaction_fee_info'];
      if (st.info == null && infoRaw is Map) {
        st.info = TransactionFeeInfo.fromJson(infoRaw.cast<String, dynamic>());
      }

      final data = decoded['data'];
      final items = (data is List)
          ? data
                .whereType<Map>()
                .map(
                  (e) => TransactionFeeHistoryEntry.fromJson(
                    e.cast<String, dynamic>(),
                  ),
                )
                .toList()
          : <TransactionFeeHistoryEntry>[];

      final page = decoded['page'];
      final currentPage = (page is Map)
          ? (page['current_page'] as num?)?.toInt() ?? nextPage
          : nextPage;
      final totalPages = (page is Map)
          ? (page['total_pages'] as num?)?.toInt() ?? st.totalPages
          : st.totalPages;

      st.page = currentPage;
      st.totalPages = totalPages;

      st.items = [...st.items, ...items];
      st.hasMore = st.page < st.totalPages;

      st.moreError = null;
    } catch (e, stTrace) {
      debugPrint(
        '[SubscriptionProvider] fetchMoreTransactionFeeHistoryDetail error: $e\n$stTrace',
      );
      st.moreError = 'Failed to load more fee detail: $e';
    } finally {
      st.isLoadingMore = false;
      notifyListeners();
    }
  }

  _HistoryPagingState _hs(String type) =>
      _historyStates.putIfAbsent(type, () => _HistoryPagingState());

  List<SubscriptionHistoryItem> historyOf(String type) =>
      List.unmodifiable(_hs(type).items);

  bool isLoadingHistoryOf(String type) => _hs(type).isLoading;
  bool isLoadingMoreHistoryOf(String type) => _hs(type).isLoadingMore;

  String? historyErrorOf(String type) => _hs(type).error;
  String? historyMoreErrorOf(String type) => _hs(type).moreError;

  bool historyHasMoreOf(String type) => _hs(type).hasMore;
  int historyCurrentPageOf(String type) => _hs(type).page;
  int historyTotalPagesOf(String type) => _hs(type).totalPages;

  static const String kHistoryTypePremiumBusiness = 'premium_business';
  static const String kHistoryTypeTransactionFee = 'transaction_fee';

  List<SubscriptionHistoryItem> get history =>
      historyOf(kHistoryTypePremiumBusiness);
  bool get isLoadingHistory => isLoadingHistoryOf(kHistoryTypePremiumBusiness);
  bool get isLoadingMoreHistory =>
      isLoadingMoreHistoryOf(kHistoryTypePremiumBusiness);
  String? get historyError => historyErrorOf(kHistoryTypePremiumBusiness);
  String? get historyMoreError =>
      historyMoreErrorOf(kHistoryTypePremiumBusiness);
  bool get historyHasMore => historyHasMoreOf(kHistoryTypePremiumBusiness);

  // -------------------------------------------------------------
  // Transaction fee state
  // -------------------------------------------------------------
  List<TransactionFeeItem> _transactionFees = [];
  bool _isLoadingTransactionFees = false;
  String? _transactionFeeError;
  int _totalUnpaidTransactionFee = 0;

  List<TransactionFeeItem> get transactionFees =>
      List.unmodifiable(_transactionFees);
  bool get isLoadingTransactionFees => _isLoadingTransactionFees;
  String? get transactionFeeError => _transactionFeeError;
  int get totalUnpaidTransactionFee => _totalUnpaidTransactionFee;

  String get totalUnpaidTransactionFeeLabel =>
      _formatRupiah(_totalUnpaidTransactionFee);

  bool _isProcessingTransactionFee = false;
  String? _transactionFeePaymentError;

  Timer? _transactionFeeCheckTimer;
  String? _currentTransactionFeeNumber;

  int? _lastTransactionFeeAmount;
  String? _lastTransactionFeePeriod;

  bool get isProcessingTransactionFee => _isProcessingTransactionFee;
  String? get transactionFeePaymentError => _transactionFeePaymentError;

  String get firstPlanPriceLabel {
    final plan = firstPlan;
    if (plan == null) return '-';
    return _formatRupiah(plan.price);
  }

  String get firstPlanPricePerPeriodLabel {
    final plan = firstPlan;
    if (plan == null) return '-';
    final priceText = _formatRupiah(plan.price);

    if (plan.months == 1) {
      return '$priceText / month';
    } else if (plan.months == 12) {
      return '$priceText / year';
    } else {
      return '$priceText / ${plan.months} months';
    }
  }

  double get yearlyDiscountPercent {
    final normalYearly = _monthlyPrice * 12;
    if (normalYearly == 0) return 0;
    final discount = 100 - (_yearlyPrice / normalYearly * 100);
    return discount;
  }

  void _rememberPaidPlanForPayment(String planId, String pricingId) {
    PremiumPlan? foundPlan;
    PlanPricing? foundPricing;

    for (final p in _plans) {
      if (p.idPlan == planId) {
        foundPlan = p;
        for (final pr in p.pricing) {
          if (pr.id == pricingId) {
            foundPricing = pr;
            break;
          }
        }
        break;
      }
    }

    _lastPaidPlan = foundPlan;
    _lastPaidPricing = foundPricing;
  }

  String get selectedPriceLabel {
    if (firstPlan != null) {
      return firstPlanPricePerPeriodLabel;
    }

    switch (_selectedCycle) {
      case BillingCycle.monthly:
        return '${_formatRupiah(_monthlyPrice)} / month';
      case BillingCycle.yearly:
        return '${_formatRupiah(_yearlyPrice)} / year';
    }
  }

  // ---------------------------------------------------------------------------
  // SELECT CYCLE
  // ---------------------------------------------------------------------------
  void selectCycle(BillingCycle cycle) {
    if (_selectedCycle == cycle) return;
    _selectedCycle = cycle;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // CEK VOUCHER
  // ---------------------------------------------------------------------------
  Future<VoucherCheckResult> checkVoucher({
    required BuildContext context,
    required String code,
    required int originalPrice,
  }) async {
    const path = '/premium/business/check-voucher';

    try {
      final payload = {'code': code, 'original_price': originalPrice};

      final res = await ApiService.post(
        context,
        path,
        payload,
        withAccessToken: true,
      );

      final raw = res.body;
      debugPrint(
        '[SubscriptionProvider] POST $path ◀︎ ${res.statusCode} '
        '${raw.length > 400 ? raw.substring(0, 400) + "…" : raw}',
      );

      Map<String, dynamic>? json;
      try {
        json = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        json = null;
      }

      if (json == null) {
        return VoucherCheckResult(
          isValid: false,
          originalPrice: originalPrice,
          finalPrice: originalPrice,
          discount: 0,
          message: 'Invalid JSON from voucher API',
        );
      }

      final status = (json['status'] as num?)?.toInt() ?? 0;

      if (status == 200) {
        final op = (json['original_price'] as num?)?.toInt() ?? originalPrice;
        final fp = (json['final_price'] as num?)?.toInt() ?? op;
        final disc = (json['discount'] as num?)?.toInt() ?? 0;

        return VoucherCheckResult(
          isValid: true,
          originalPrice: op,
          finalPrice: fp,
          discount: disc,
          voucherName: json['voucher_name']?.toString(),
          voucherDesc: json['voucher_desc']?.toString(),
        );
      }

      final msg = json['msg']?.toString() ?? 'Voucher is not valid';

      return VoucherCheckResult(
        isValid: false,
        originalPrice: originalPrice,
        finalPrice: originalPrice,
        discount: 0,
        message: msg,
      );
    } catch (e, st) {
      debugPrint('[SubscriptionProvider] checkVoucher error: $e\n$st');

      return VoucherCheckResult(
        isValid: false,
        originalPrice: originalPrice,
        finalPrice: originalPrice,
        discount: 0,
        message: e.toString(),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // GET PREMIUM PLAN LIST
  // ---------------------------------------------------------------------------
  Future<void> fetchPremiumPlans(BuildContext context) async {
    _isLoadingPlans = true;
    notifyListeners();

    const path = '/premium-plan';

    try {
      final res = await ApiService.get(context, path, withAccessToken: true);

      final raw = res.body;
      debugPrint(
        '[SubscriptionProvider] GET $path ◀︎ ${res.statusCode} '
        '${raw.length > 400 ? raw.substring(0, 400) + "…" : raw}',
      );

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('HTTP ${res.statusCode}');
      }

      Map<String, dynamic>? decoded;
      try {
        decoded = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        decoded = null;
      }

      if (decoded == null) {
        throw Exception('Invalid JSON response');
      }

      final status = (decoded['status'] as num?)?.toInt() ?? 0;
      if (status != 200) {
        final msg =
            decoded['msg']?.toString() ?? 'Failed to load premium plans';
        throw Exception('$msg (status=$status)');
      }

      final data = decoded['data'];
      if (data is! List) {
        _plans = [];
      } else {
        _plans = data
            .map(
              (e) => PremiumPlan.fromJson((e as Map).cast<String, dynamic>()),
            )
            .toList();
      }

      _errorMessage = null;

      PremiumPlan? yearlyPlan;
      for (final p in _plans) {
        if (p.months == 12 && p.isActive) {
          yearlyPlan = p;
          break;
        }
      }

      final first = firstPlan;

      if (yearlyPlan != null) {
        _yearlyPrice = yearlyPlan.price.toDouble();
        final months = yearlyPlan.months == 0 ? 1 : yearlyPlan.months;
        _monthlyPrice = yearlyPlan.price / months;
      } else if (first != null) {
        _yearlyPrice = first.price.toDouble();
        final months = first.months == 0 ? 1 : first.months;
        _monthlyPrice = first.price / months;
      }

      // ✅ kalau iOS, preload lagi setelah plans ada (biar mapping period kebaca)
      if (isIOS && _iosIapAvailable) {
        unawaited(_preloadIosProductsWithRetry());
      }
    } catch (e, st) {
      debugPrint('[SubscriptionProvider] fetchPremiumPlans error: $e\n$st');
      _errorMessage = 'Failed to load premium plans: $e';
    } finally {
      _isLoadingPlans = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // GET TRANSACTION FEE LIST
  // ---------------------------------------------------------------------------
  Future<void> fetchTransactionFees(BuildContext context) async {
    _isLoadingTransactionFees = true;
    _transactionFeeError = null;
    notifyListeners();

    try {
      final bizId = await BizIdCache.get();
      if (bizId == null || bizId.toString().trim().isEmpty) {
        throw Exception(
          'Business ID not found. Please select a business first.',
        );
      }

      final path = '/waveup/$bizId/transaction-fee';

      final res = await ApiService.get(context, path, withAccessToken: true);

      final raw = res.body;
      debugPrint(
        '[SubscriptionProvider] GET $path ◀︎ ${res.statusCode} '
        '${raw.length > 400 ? raw.substring(0, 400) + "…" : raw}',
      );

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('HTTP ${res.statusCode}');
      }

      Map<String, dynamic>? decoded;
      try {
        decoded = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        decoded = null;
      }

      if (decoded == null) {
        throw Exception('Invalid JSON response');
      }

      final status = (decoded['status'] as num?)?.toInt() ?? 0;
      if (status != 200) {
        final msg =
            decoded['msg']?.toString() ?? 'Failed to load transaction fee';
        throw Exception('$msg (status=$status)');
      }

      final data = decoded['data'];
      if (data is List) {
        _transactionFees = data
            .map(
              (e) => TransactionFeeItem.fromJson(
                (e as Map).cast<String, dynamic>(),
              ),
            )
            .toList();
      } else {
        _transactionFees = [];
      }

      _totalUnpaidTransactionFee =
          (decoded['total_unpaid'] as num?)?.toInt() ?? 0;

      _transactionFeeError = null;
    } catch (e, st) {
      debugPrint('[SubscriptionProvider] fetchTransactionFees error: $e\n$st');
      _transactionFeeError = 'Failed to load transaction fee: $e';
      _transactionFees = [];
      _totalUnpaidTransactionFee = 0;
    } finally {
      _isLoadingTransactionFees = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // PAY TRANSACTION FEE
  // ---------------------------------------------------------------------------
  Future<void> goToTransactionFeePayment({
    required BuildContext context,
  }) async {
    if (_isProcessingTransactionFee) return;

    _isProcessingTransactionFee = true;
    _transactionFeePaymentError = null;
    notifyListeners();

    try {
      final bizId = await BizIdCache.get();
      if (bizId == null || bizId.toString().trim().isEmpty) {
        throw Exception(
          'Business ID not found. Please select a business first.',
        );
      }

      final path = '/waveup/$bizId/transaction-fee/pay';

      final res = await ApiService.post(
        context,
        path,
        const <String, dynamic>{},
        withAccessToken: true,
      );

      final raw = res.body;
      debugPrint(
        '[SubscriptionProvider] POST $path ◀︎ ${res.statusCode} '
        '${raw.length > 400 ? raw.substring(0, 400) + "…" : raw}',
      );

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('HTTP ${res.statusCode}');
      }

      Map<String, dynamic>? json;
      try {
        json = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        json = null;
      }
      if (json == null) {
        throw Exception('Invalid JSON from transaction-fee/pay');
      }

      final status = (json['status'] as num?)?.toInt() ?? 0;
      if (status != 200) {
        final msg = json['message']?.toString() ?? 'Failed to create payment';
        throw Exception('$msg (status=$status)');
      }

      final transactionNumber = json['transaction_number']?.toString() ?? '';
      final paymentToken = json['payment_token']?.toString() ?? '';
      final totalAmount = (json['total_amount'] as num?)?.toInt() ?? 0;
      final feePeriod = json['fee_period']?.toString() ?? '';
      final message = json['message']?.toString() ?? '';

      if (transactionNumber.trim().isEmpty) {
        throw Exception('Invalid response: missing transaction_number');
      }
      if (paymentToken.trim().isEmpty) {
        throw Exception('Invalid response: missing payment_token');
      }

      _currentTransactionFeeNumber = transactionNumber;
      _lastTransactionFeeAmount = totalAmount;
      _lastTransactionFeePeriod = feePeriod;

      _startTransactionFeePaymentStatusPolling(context);

      if (message.trim().isNotEmpty && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }

      await _startSnap(paymentToken, context);
    } catch (e, st) {
      debugPrint(
        '[SubscriptionProvider] goToTransactionFeePayment error: $e\n$st',
      );

      _isProcessingTransactionFee = false;
      _transactionFeePaymentError =
          'Failed to start transaction fee payment: $e';
      notifyListeners();

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_transactionFeePaymentError!)));
      }
    }
  }

  void _startTransactionFeePaymentStatusPolling(BuildContext context) {
    _transactionFeeCheckTimer?.cancel();

    final number = _currentTransactionFeeNumber;
    if (number == null || number.isEmpty) {
      debugPrint('[TransactionFee] No transaction_number to poll.');
      return;
    }

    debugPrint(
      '[TransactionFee] Start polling payment status every 6 seconds...',
    );

    _transactionFeeCheckTimer = Timer.periodic(
      const Duration(seconds: 6),
      (_) => _checkTransactionFeePaymentStatus(context),
    );
  }

  Future<void> _checkTransactionFeePaymentStatus(BuildContext context) async {
    final number = _currentTransactionFeeNumber;
    if (number == null || number.isEmpty) return;

    try {
      final bizId = await BizIdCache.get();
      if (bizId == null || bizId.toString().trim().isEmpty) {
        debugPrint('[TransactionFee] Missing business id while polling.');
        return;
      }

      final path = '/waveup/$bizId/transaction-fee/payment/check';

      debugPrint('[TransactionFee] Check payment status number=$number');

      final payload = {'number': number};

      final res = await ApiService.post(
        context,
        path,
        payload,
        withAccessToken: true,
      );

      final raw = res.body;
      debugPrint(
        '[SubscriptionProvider] POST $path ◀︎ ${res.statusCode} '
        '${raw.length > 400 ? raw.substring(0, 400) + "…" : raw}',
      );

      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint(
          '[TransactionFee] payment/check HTTP error ${res.statusCode}',
        );
        return;
      }

      Map<String, dynamic>? json;
      try {
        json = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        json = null;
      }
      if (json == null) {
        debugPrint('[TransactionFee] payment/check invalid json');
        return;
      }

      final status = (json['status'] as num?)?.toInt() ?? 0;

      if (status == 400) {
        debugPrint(
          '[TransactionFee] Not paid yet: ${json['message']?.toString() ?? ''}',
        );
        return;
      }

      if (status == 200) {
        debugPrint('[TransactionFee] Payment success! Stop polling.');

        _transactionFeeCheckTimer?.cancel();
        _transactionFeeCheckTimer = null;
        _currentTransactionFeeNumber = null;

        _isProcessingTransactionFee = false;
        notifyListeners();

        if (context.mounted) {
          await fetchTransactionFees(context);
          await _showTransactionFeePaidDialog(context);
        }
        return;
      }

      debugPrint('[TransactionFee] Unknown status=$status (json=$json)');
    } catch (e, st) {
      debugPrint('[TransactionFee] polling error: $e\n$st');
    }
  }

  Future<void> _showTransactionFeePaidDialog(BuildContext context) async {
    final amount = _lastTransactionFeeAmount ?? totalUnpaidTransactionFee;
    final period = (_lastTransactionFeePeriod ?? '').trim();

    final amountLabel = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(amount);

    final periodLabel = period.isNotEmpty ? period : 'Selected period';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F5E9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified_rounded,
                    size: 36,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Payment Successful',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Thank you for paying the WaveUp platform fee.\n'
                  'Every contribution matters to us.\n'
                  'You can now enjoy WaveUp services normally again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: const Color(0xFFF5F7FB),
                    border: Border.all(color: const Color(0xFFE1E5F2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payment details',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Fee period',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          Text(
                            periodLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Amount paid',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          Text(
                            amountLabel,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    onPressed: () {
                      final nav = Navigator.of(context, rootNavigator: true);
                      nav.pop();
                      nav.pushNamedAndRemoveUntil(
                        '/home',
                        (r) => false,
                        arguments: const {'refresh': true},
                      );
                    },
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // CANCEL / RESET PREMIUM PAYMENT STATE
  // ---------------------------------------------------------------------------
  void cancelPaymentTimer() {
    debugPrint('🧹 [SubscriptionProvider] cancelPaymentTimer() CALLED');

    _paymentCheckTimer?.cancel();
    _paymentCheckTimer = null;

    _currentTransactionNumber = null;
  }

  void resetPaymentState() {
    debugPrint('🧹 [SubscriptionProvider] resetPaymentState() CALLED');

    // stop polling timer
    _paymentCheckTimer?.cancel();
    _paymentCheckTimer = null;

    // reset tx number
    _currentTransactionNumber = null;

    // stop processing flags
    _isProcessing = false;
    _errorMessage = null;

    // optional: force-complete midtrans completer supaya gak menggantung
    if (_snapCompleter != null && !(_snapCompleter!.isCompleted)) {
      _snapCompleter!.complete(
        PaymentResult('aborted', message: 'Cancelled by user'),
      );
    }
    _snapCompleter = null;

    notifyListeners();
  }

  /// Alias yang bisa dipanggil dari screen (biar jelas niatnya)
  Future<void> cancelPendingPayment({BuildContext? context}) async {
    // Saat ini yang bisa kita lakukan hanya stop polling + reset state lokal.
    // (Midtrans UI flow tidak punya API cancel dari sini; user sudah menutup/back.)
    resetPaymentState();

    // kalau kamu mau, bisa juga show snackbar di sini (optional)
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Payment cancelled.')));
    }
  }

  // ---------------------------------------------------------------------------
  // UPGRADE PREMIUM (Midtrans)
  // ---------------------------------------------------------------------------
  Future<void> goToPayment({
    required BuildContext context,
    required String planId,
    required String pricingId,
    int paymentMethod = 2,
    String voucherCode = '',
  }) async {
    if (_isProcessing) return;

    _isProcessing = true;
    _errorMessage = null;

    _rememberPaidPlanForPayment(planId, pricingId);
    notifyListeners();

    const path = '/premium/business/upgrade';

    try {
      final bizId = await BizIdCache.get();
      if (bizId == null || bizId.toString().trim().isEmpty) {
        throw Exception(
          'Business ID not found. Please select a business first.',
        );
      }

      final payload = {
        'plan_id': planId,
        'business_id': bizId,
        'pricing_id': pricingId,
        'payment_method': paymentMethod,
        'voucher_code': voucherCode,
      };

      final res = await ApiService.post(
        context,
        path,
        payload,
        withAccessToken: true,
      );

      final raw = res.body;
      debugPrint(
        '[SubscriptionProvider] POST $path ◀︎ ${res.statusCode} '
        '${raw.length > 400 ? raw.substring(0, 400) + "…" : raw}',
      );

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('HTTP ${res.statusCode}');
      }

      Map<String, dynamic>? json;
      try {
        json = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        json = null;
      }

      if (json == null) {
        throw Exception('Invalid JSON from upgrade API');
      }

      final status = (json['status'] as num?)?.toInt() ?? 0;
      if (status != 200) {
        final msg = json['msg']?.toString() ?? 'Upgrade API error';
        throw Exception('$msg (status=$status)');
      }

      final transactionNumber = json['transaction_number']?.toString() ?? '';
      final paymentToken = json['payment_token']?.toString() ?? '';
      final paymentLink = json['payment_link']?.toString() ?? '';
      final paymentMethodFromResponse =
          (json['payment_method'] as num?)?.toInt() ?? paymentMethod;

      if (transactionNumber.isEmpty) {
        throw Exception('Invalid upgrade response (no transaction number)');
      }

      _currentTransactionNumber = transactionNumber;

      _startPaymentStatusPolling(context);

      if (paymentMethodFromResponse == 6) {
        if (paymentLink.isEmpty) {
          throw Exception(
            'Invalid upgrade response (no payment link for method 6)',
          );
        }

        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PaymentWebViewScreen(initialUrl: paymentLink),
            fullscreenDialog: true,
          ),
        );
        return;
      }

      if (paymentToken.isEmpty) {
        throw Exception('Invalid upgrade response (no token for Snap)');
      }

      await _startSnap(paymentToken, context);
    } catch (e, st) {
      debugPrint('[SubscriptionProvider] goToPayment error: $e\n$st');
      _isProcessing = false;
      _errorMessage = 'Failed to start premium payment: $e';
      notifyListeners();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage!)));
    }
  }

  Future<void> retryPaymentFromHistory({
    required BuildContext context,
    required SubscriptionHistoryItem item,
  }) async {
    final isPaid = item.paid == 1 || item.paidStatus.toLowerCase() == 'paid';
    if (isPaid) return;

    final number = item.number.trim();
    if (number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot continue payment: missing invoice number.'),
        ),
      );
      return;
    }

    _currentTransactionNumber = number;
    _startPaymentStatusPolling(context);

    if (item.paymentMethod == 6) {
      final link = item.paymentLink.trim();
      if (link.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment link not available for this transaction.'),
          ),
        );
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PaymentWebViewScreen(initialUrl: link),
          fullscreenDialog: true,
        ),
      );
      return;
    }

    final token = item.paymentToken.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment token not available for this transaction.'),
        ),
      );
      return;
    }

    await _startSnap(token, context);
  }

  void _startPaymentStatusPolling(BuildContext context) {
    _paymentCheckTimer?.cancel();

    final number = _currentTransactionNumber;
    if (number == null || number.isEmpty) {
      debugPrint('[Subscription] Tidak ada transaction_number untuk dicek.');
      return;
    }

    debugPrint('[Subscription] Mulai polling payment status tiap 6 detik...');

    _paymentCheckTimer = Timer.periodic(
      const Duration(seconds: 6),
      (_) => _checkPaymentStatus(context),
    );
  }

  Future<void> _checkPaymentStatus(BuildContext context) async {
    final number = _currentTransactionNumber;
    if (number == null || number.isEmpty) return;

    const path = '/premium/business/payment/check';
    debugPrint('[Subscription] Cek payment status untuk number=$number');

    try {
      final payload = {'number': number};

      final res = await ApiService.post(
        context,
        path,
        payload,
        withAccessToken: true,
      );

      final raw = res.body;
      debugPrint(
        '[SubscriptionProvider] POST $path ◀︎ ${res.statusCode} '
        '${raw.length > 400 ? raw.substring(0, 400) + "…" : raw}',
      );

      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint('[Subscription] payment/check HTTP error ${res.statusCode}');
        return;
      }

      Map<String, dynamic>? json;
      try {
        json = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        json = null;
      }

      if (json == null) {
        debugPrint('[Subscription] payment/check invalid json');
        return;
      }

      final status = (json['status'] as num?)?.toInt() ?? 0;

      if (status == 400) {
        debugPrint(
          '[Subscription] Transaction belum dibayar: ${json['msg'] ?? ''}',
        );
        return;
      }

      if (status == 200) {
        debugPrint('[Subscription] Payment success! Hentikan polling.');

        _paymentCheckTimer?.cancel();
        _paymentCheckTimer = null;
        _currentTransactionNumber = null;

        _isProcessing = false;
        notifyListeners();

        await _goToSuccessStep(context);
        return;
      }

      debugPrint(
        '[Subscription] Payment check status tidak dikenal: $status (json=$json)',
      );
    } catch (e, st) {
      debugPrint('[Subscription] Error cek payment: $e\n$st');
    }
  }

  Future<void> _goToSuccessStep(BuildContext context) async {
    final planName = _lastPaidPlan?.name ?? 'Premium Plan';

    final period = _lastPaidPricing?.period ?? 0;
    String periodLabel;
    if (period <= 0) {
      periodLabel = 'Selected period';
    } else if (period == 1) {
      periodLabel = '1 month';
    } else if (period == 12) {
      periodLabel = '12 months';
    } else {
      periodLabel = '$period months';
    }

    final price = _lastPaidPricing?.price;
    final amountLabel = price == null
        ? '—'
        : NumberFormat.currency(
            locale: 'id_ID',
            symbol: 'Rp ',
            decimalDigits: 0,
          ).format(price);

    if (!context.mounted) return;

    final nav = Navigator.of(context, rootNavigator: true);
    nav.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => SubscriptionPaymentSuccessScreen(
          planName: planName,
          periodLabel: periodLabel,
          amountLabel: amountLabel,
        ),
      ),
      (r) => false,
    );
  }

  MidtransConfig? _midtransConfigSnapshot;

  Future<void> _initMidtransIfNeeded(BuildContext context) async {
    const midtransClientKey = "SB-Mid-client-OlAvtRicKKPMklc4";
    // const midtransClientKey = "Mid-client-ej_BQW5VVp_G2hAy";

    const merchantBaseUrl = "https://wave-api.eon.id";
    final cs = Theme.of(context).colorScheme;

    debugPrint("[Midtrans][init] Clearing previous instance/config...");

    // 1) detach callback lama (pakai no-op, karena tidak bisa null)
    _clearMidtransCallbacks();

    // 2) clear snapshot + instance dart-side
    _midtrans = null;
    _midtransConfigSnapshot = null;

    await Future<void>.delayed(const Duration(milliseconds: 50));

    // 3) init baru
    final cfg = MidtransConfig(
      merchantBaseUrl: merchantBaseUrl,
      clientKey: midtransClientKey,
      colorTheme: ColorTheme(
        colorPrimary: cs.primary,
        colorPrimaryDark: cs.primary,
        colorSecondary: cs.secondary,
      ),
      enableLog: true,
    );

    _midtransConfigSnapshot = cfg;

    debugPrint("[Midtrans][init] Initializing...");
    _midtrans = await MidtransSDK.init(config: cfg);

    debugPrint(
      "[Midtrans][init] SUCCESS ✅ instanceType=${_midtrans.runtimeType}",
    );
    debugMidtransSnapshot();
  }

  void _clearMidtransCallbacks() {
    try {
      _midtrans?.setTransactionFinishedCallback((result) {
        // no-op: intentionally empty to detach previous handler
        debugPrint(
          "[Midtrans] (noop) transaction finished callback fired: $result",
        );
      });
    } catch (e) {
      debugPrint("[Midtrans] (info) cannot reset callback: $e");
    }
  }

  void debugMidtransSnapshot() {
    final cfg = _midtransConfigSnapshot;
    if (cfg == null) {
      debugPrint("[Midtrans][snapshot] config snapshot is null");
      return;
    }

    debugPrint("[Midtrans][snapshot] merchantBaseUrl=${cfg.merchantBaseUrl}");
    debugPrint("[Midtrans][snapshot] clientKey=${(cfg.clientKey)}");
    debugPrint("[Midtrans][snapshot] enableLog=${cfg.enableLog}");
  }

  String _maskKey(String key) {
    if (key.length <= 8) return "****";
    final head = key.substring(0, 4);
    final tail = key.substring(key.length - 4);
    return "$head****$tail";
  }

  Future<PaymentResult?> _startSnap(String token, BuildContext context) async {
    debugPrint('🚀 [Midtrans] _startSnap() BEGIN dengan token: $token');

    try {
      await _initMidtransIfNeeded(context);
      debugPrint('✅ [Midtrans] SDK sudah di-init');
    } catch (e, st) {
      debugPrint('❌ [Midtrans] init error: $e\n$st');
      return PaymentResult('error', message: 'Init Midtrans gagal: $e');
    }

    if (_snapCompleter != null && !(_snapCompleter!.isCompleted)) {
      debugPrint(
        '[Midtrans] Completer lama belum complete, diselesaikan paksa.',
      );
      _snapCompleter!.complete(
        PaymentResult('aborted', message: 'Flow sebelumnya digantikan'),
      );
    }
    _snapCompleter = Completer<PaymentResult>();

    try {
      _midtrans?.removeTransactionFinishedCallback();
      debugPrint('[Midtrans] Callback lama dihapus');
    } catch (_) {}

    _midtrans?.setTransactionFinishedCallback((result) {
      debugPrint(' [Midtrans] CALLBACK TERPANGGIL!');
      try {
        debugPrint(' result = ${result.toString()}');
        debugPrint('   transactionId=${result.transactionId}');
        debugPrint('   status=${result.status}');
        debugPrint('   message=${result.message}');
        debugPrint('   paymentType=${result.paymentType}');
      } catch (e) {
        debugPrint('[Midtrans] gagal print result: $e');
      }

      String? _s(Object? v) => v?.toString();
      final status = (_s(result.status) ?? '').toLowerCase();
      final pr = PaymentResult(
        status.isEmpty ? 'unknown' : status,
        transactionId: _s(result.transactionId),
        paymentType: _s(result.paymentType),
        message: _s(result.message),
        raw: result.toString(),
      );

      if (!(_snapCompleter?.isCompleted ?? true)) {
        debugPrint('✅ [Midtrans] Completer diselesaikan via callback');
        _snapCompleter!.complete(pr);
      }
    });

    try {
      debugPrint('▶️ [Midtrans] Memulai startPaymentUiFlow...');
      await _midtrans?.startPaymentUiFlow(token: token);
      debugPrint(
        '⏳ [Midtrans] startPaymentUiFlow() selesai, menunggu callback...',
      );
    } catch (e, st) {
      debugPrint('❌ [Midtrans] startPaymentUiFlow error: $e\n$st');
      if (!(_snapCompleter?.isCompleted ?? true)) {
        _snapCompleter!.complete(
          PaymentResult('error', message: 'Gagal membuka Snap UI: $e'),
        );
      }
    }

    PaymentResult result;
    try {
      result = await _snapCompleter!.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          debugPrint('⏰ [Midtrans] Timeout 5 menit, callback tidak diterima.');
          return PaymentResult('timeout', message: 'Tidak ada callback');
        },
      );
    } catch (e, st) {
      debugPrint('❌ [Midtrans] Future error: $e\n$st');
      result = PaymentResult('error', message: 'Future error: $e');
    } finally {
      try {
        _midtrans?.removeTransactionFinishedCallback();
        debugPrint('🧹 [Midtrans] Callback dilepas setelah flow selesai.');
      } catch (_) {}
      _snapCompleter = null;
    }

    debugPrint(
      '🏁 [Midtrans] _startSnap() SELESAI dengan status: ${result.status}',
    );
    return result;
  }

  // ---------------------------------------------------------------------------
  // DOWNLOAD PDF INVOICE (tetap)
  // ---------------------------------------------------------------------------
  Future<File?> downloadInvoicePdfFromHistory({
    required BuildContext context,
    required SubscriptionHistoryItem item,
    bool openAfterSave = true,
  }) async {
    try {
      String safePdfText(String input) {
        var s = input;

        s = s.replaceAll('•', '-');
        s = s.replaceAll('—', '-');
        s = s.replaceAll('–', '-');
        s = s.replaceAll('…', '...');
        s = s.replaceAll('“', '"').replaceAll('”', '"');
        s = s.replaceAll('‘', "'").replaceAll('’', "'");

        s = s.replaceAll(RegExp(r'[^\x00-\x7F]'), '');
        s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

        return s.isEmpty ? '-' : s;
      }

      String prettyTypeLabel(String raw) {
        final t = raw.trim().toLowerCase();
        if (t == 'premium_business') return 'Premium Business';
        if (t == 'transaction_fee') return 'Platform Transaction Fee';
        if (t.isEmpty) return '-';

        final parts = t.split('_').where((e) => e.isNotEmpty).toList();
        if (parts.isEmpty) return raw.trim();
        return parts
            .map(
              (w) => w.isEmpty
                  ? ''
                  : w[0].toUpperCase() + (w.length > 1 ? w.substring(1) : ''),
            )
            .join(' ')
            .trim();
      }

      final prefs = await SharedPreferences.getInstance();
      final activeBizNameRaw = (prefs.getString('activeBizName') ?? '').trim();
      final activeBizUsernameRaw = (prefs.getString('activeBizUsername') ?? '')
          .trim();

      final paidByName = safePdfText(
        activeBizNameRaw.isNotEmpty ? activeBizNameRaw : '-',
      );
      final paidByUser = safePdfText(
        activeBizUsernameRaw.isNotEmpty ? '@$activeBizUsernameRaw' : '-',
      );

      final rupiah = NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      );
      final dateFmt = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
      String fmtDate(DateTime? d) =>
          d == null ? '-' : dateFmt.format(d.toLocal());

      final createdAt = safePdfText(fmtDate(item.createdAt));
      final paidAt = safePdfText(fmtDate(item.paidAt));

      final isPaid = item.paid == 1 || item.paidStatus.toLowerCase() == 'paid';

      final statusText = safePdfText(
        item.paidStatus.trim().isNotEmpty
            ? item.paidStatus.trim()
            : (isPaid ? 'Paid' : 'Unpaid'),
      );

      final methodName = safePdfText(
        item.paymentMethodName.trim().isNotEmpty
            ? item.paymentMethodName.trim()
            : 'Payment method ${item.paymentMethod}',
      );

      final invoiceNo = safePdfText(
        item.number.trim().isNotEmpty ? item.number.trim() : '-',
      );

      String itemTitle() {
        final desc = item.description.trim();
        if (desc.isNotEmpty) return safePdfText(desc);

        final plan = item.planName.trim();
        if (plan.isNotEmpty) return safePdfText(plan);

        final t = item.type.trim().toLowerCase();
        if (t == 'transaction_fee') return 'Platform Transaction Fee';
        if (t == 'premium_business') return 'Premium Business';
        return 'WaveUp Invoice Item';
      }

      final periodLabel = safePdfText(
        item.period.trim().isNotEmpty ? item.period.trim() : '-',
      );
      final typeLabel = safePdfText(prettyTypeLabel(item.type));

      const pdfBlue = p.PdfColor.fromInt(0xFF1D4ED8);
      const pdfBlueSoft = p.PdfColor.fromInt(0xFFEFF6FF);

      const pdfGreenBg = p.PdfColor.fromInt(0xFFE8F5E9);
      const pdfGreen = p.PdfColor.fromInt(0xFF2E7D32);

      const pdfRedBg = p.PdfColor.fromInt(0xFFFEE2E2);
      const pdfRed = p.PdfColor.fromInt(0xFFB91C1C);

      final doc = pw.Document();

      pw.Widget kv(String k, String v) => pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              safePdfText(k),
              style: pw.TextStyle(fontSize: 9, color: p.PdfColors.grey700),
            ),
            pw.SizedBox(height: 2),
            pw.Text(safePdfText(v), style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      );

      pw.Widget statusBadge() {
        final bg = isPaid ? pdfGreenBg : pdfRedBg;
        final fg = isPaid ? pdfGreen : pdfRed;

        return pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: pw.BoxDecoration(
            color: bg,
            borderRadius: pw.BorderRadius.circular(10),
            border: pw.Border.all(color: fg, width: 0.8),
          ),
          child: pw.Text(
            statusText,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: fg,
            ),
          ),
        );
      }

      pw.Widget sectionTitle(String t) => pw.Text(
        safePdfText(t),
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: pdfBlue,
        ),
      );

      doc.addPage(
        pw.Page(
          pageFormat: p.PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (_) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'WaveUp',
                          style: pw.TextStyle(
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                            color: pdfBlue,
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          'Jakarta, Indonesia',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                        pw.Text(
                          'www.up.wave.id',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Invoice No',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          invoiceNo,
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          'Status',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        statusBadge(),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 14),
                pw.Divider(color: p.PdfColors.grey300),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: pdfBlueSoft,
                    borderRadius: pw.BorderRadius.circular(12),
                    border: pw.Border.all(
                      color: p.PdfColors.grey300,
                      width: 0.6,
                    ),
                  ),
                  child: pw.Row(
                    children: [
                      kv('Created at', createdAt),
                      pw.SizedBox(width: 10),
                      kv('Paid at', paidAt),
                    ],
                  ),
                ),
                pw.SizedBox(height: 16),
                sectionTitle('Paid by'),
                pw.SizedBox(height: 8),
                pw.Row(
                  children: [
                    kv('Business name', paidByName),
                    kv('Username', paidByUser),
                  ],
                ),
                pw.SizedBox(height: 14),
                pw.Divider(color: p.PdfColors.grey300),
                pw.SizedBox(height: 10),
                sectionTitle('Transaction details'),
                pw.SizedBox(height: 8),
                pw.Row(children: [kv('Payment method', methodName)]),
                pw.SizedBox(height: 6),
                pw.Row(
                  children: [kv('Type', typeLabel), kv('Period', periodLabel)],
                ),
                pw.SizedBox(height: 14),
                pw.Divider(color: p.PdfColors.grey300),
                pw.SizedBox(height: 10),
                sectionTitle('Items'),
                pw.SizedBox(height: 8),
                pw.Table(
                  border: pw.TableBorder.all(
                    color: p.PdfColors.grey300,
                    width: 0.8,
                  ),
                  columnWidths: const {
                    0: pw.FlexColumnWidth(5),
                    1: pw.FlexColumnWidth(1),
                    2: pw.FlexColumnWidth(2),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: pdfBlueSoft),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Description',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: pdfBlue,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Qty',
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: pdfBlue,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Price',
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: pdfBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            itemTitle(),
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            '1',
                            textAlign: pw.TextAlign.right,
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            safePdfText(rupiah.format(item.amount)),
                            textAlign: pw.TextAlign.right,
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 14),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Container(
                      width: 240,
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(
                          color: p.PdfColors.grey300,
                          width: 0.8,
                        ),
                        borderRadius: pw.BorderRadius.circular(10),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                'TOTAL',
                                style: pw.TextStyle(
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold,
                                  color: pdfBlue,
                                ),
                              ),
                              pw.Text(
                                safePdfText(rupiah.format(item.amount)),
                                style: pw.TextStyle(
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold,
                                  color: pdfBlue,
                                ),
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 6),
                          pw.Divider(color: p.PdfColors.grey300),
                          pw.Text(
                            'Generated automatically by WaveUp app.',
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: p.PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.Spacer(),
                pw.Divider(color: p.PdfColors.grey300),
                pw.SizedBox(height: 6),
                pw.Text(
                  'WaveUp - Jakarta, Indonesia',
                  style: pw.TextStyle(fontSize: 9, color: p.PdfColors.grey700),
                ),
              ],
            );
          },
        ),
      );

      final dir = await getApplicationDocumentsDirectory();
      String safe(String s) => s.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');

      final typeSlugRaw = item.type.trim().toLowerCase();
      final typeSlug = (typeSlugRaw == 'premium_business')
          ? 'premium'
          : (typeSlugRaw == 'transaction_fee')
          ? 'transaction_fee'
          : (typeSlugRaw.isEmpty ? 'unknown' : typeSlugRaw);

      final dateSlug = DateFormat(
        'yyyyMMdd',
        'id_ID',
      ).format((item.createdAt ?? DateTime.now()).toLocal());

      final invoiceNoSafe = safe(invoiceNo);

      final fileName = 'waveup_invoice_${safe(typeSlug)}_${safe(dateSlug)}.pdf';
      final file = File('${dir.path}/$fileName');
      debugPrint(fileName);

      if (await file.exists()) {
        await file.delete();
      }

      final bytes = await doc.save();
      await file.writeAsBytes(bytes, flush: true);

      if (context.mounted) {
        final messenger = ScaffoldMessenger.of(context);

        final parts = file.path.split('/');
        final last2 = parts.length >= 2
            ? '${parts[parts.length - 2]}/${parts.last}'
            : parts.last;

        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.transparent,
              elevation: 0,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              duration: const Duration(seconds: 4),
              content: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 22,
                      offset: Offset(0, 12),
                      color: Color(0x1A111827),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF4C6EF5), Color(0xFF2B59FF)],
                        ),
                        boxShadow: const [
                          BoxShadow(
                            blurRadius: 14,
                            offset: Offset(0, 8),
                            color: Color(0x264C6EF5),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.download_done_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Invoice saved',
                            style: TextStyle(
                              color: Color(0xFF111827),
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            last2,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (openAfterSave)
                      TextButton(
                        onPressed: () => OpenFilex.open(file.path),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          backgroundColor: const Color(0xFFEFF6FF),
                          foregroundColor: const Color(0xFF1D4ED8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                            side: const BorderSide(color: Color(0xFFD7E6FF)),
                          ),
                        ),
                        child: const Text(
                          'OPEN',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
      }

      // ignore unused variable (keperluan log/debug)
      // ignore: unused_local_variable
      final _ = invoiceNoSafe;

      return file;
    } catch (e, st) {
      debugPrint(
        '[SubscriptionProvider] downloadInvoicePdfFromHistory error: $e\n$st',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal download invoice: $e')));
      }
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // GET PAYMENT HISTORY
  // ---------------------------------------------------------------------------
  Future<void> fetchPaymentHistory(
    BuildContext context, {
    required String type,
    bool refresh = true,
    int limit = 10,
    String search = '',
  }) async {
    final st = _hs(type);

    if (st.isLoading) return;

    if (refresh) {
      st.page = 1;
      st.totalPages = 1;
      st.rowPerPage = limit;
      st.totalRows = 0;
      st.hasMore = true;

      st.error = null;
      st.moreError = null;
      st.items = [];

      st.limit = limit;
      st.search = search;
    }

    st.isLoading = true;
    st.error = null;
    notifyListeners();

    try {
      final bizId = await BizIdCache.get();
      if (bizId == null || bizId.toString().trim().isEmpty) {
        throw Exception(
          'Business ID not found. Please select a business first.',
        );
      }

      final safeSearch = Uri.encodeQueryComponent(search);
      final path =
          '/waveup/$bizId/payment-history?type=$type&page=1&limit=$limit&search=$safeSearch';

      final res = await ApiService.get(context, path, withAccessToken: true);

      final raw = res.body;
      debugPrint(
        '[SubscriptionProvider] GET $path ◀︎ ${res.statusCode} '
        '${raw.length > 400 ? raw.substring(0, 400) + "…" : raw}',
      );

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('HTTP ${res.statusCode}');
      }

      Map<String, dynamic>? decoded;
      try {
        decoded = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        decoded = null;
      }
      if (decoded == null) throw Exception('Invalid JSON response');

      final status = (decoded['status'] as num?)?.toInt() ?? 0;
      if (status != 200) {
        final msg =
            decoded['msg']?.toString() ?? 'Failed to load payment history';
        throw Exception('$msg (status=$status)');
      }

      final data = decoded['data'];
      final pageItems = (data is List)
          ? data
                .map(
                  (e) => SubscriptionHistoryItem.fromJson(
                    (e as Map).cast<String, dynamic>(),
                  ),
                )
                .toList()
          : <SubscriptionHistoryItem>[];

      final page = decoded['page'];
      final currentPage = (page is Map)
          ? (page['current_page'] as num?)?.toInt() ?? 1
          : 1;
      final totalPages = (page is Map)
          ? (page['total_pages'] as num?)?.toInt() ?? 1
          : 1;
      final rowPerPage = (page is Map)
          ? (page['row_per_page'] as num?)?.toInt() ?? limit
          : limit;
      final totalRows = (page is Map)
          ? (page['total_rows'] as num?)?.toInt() ?? pageItems.length
          : pageItems.length;

      st.page = currentPage;
      st.totalPages = totalPages;
      st.rowPerPage = rowPerPage;
      st.totalRows = totalRows;

      st.items = pageItems;
      st.hasMore = st.page < st.totalPages;

      st.error = null;
      st.moreError = null;
    } catch (e, stTrace) {
      debugPrint(
        '[SubscriptionProvider] fetchPaymentHistory error: $e\n$stTrace',
      );
      st.error = 'Failed to load payment history: $e';
      st.items = [];
      st.hasMore = false;
    } finally {
      st.isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMorePaymentHistory(
    BuildContext context, {
    required String type,
    int? limit,
    String? search,
  }) async {
    final st = _hs(type);

    if (st.isLoading || st.isLoadingMore) return;
    if (!st.hasMore) return;

    final effectiveLimit = limit ?? st.limit;
    final effectiveSearch = search ?? st.search;

    st.isLoadingMore = true;
    st.moreError = null;
    notifyListeners();

    final nextPage = st.page + 1;

    try {
      final bizId = await BizIdCache.get();
      if (bizId == null || bizId.toString().trim().isEmpty) {
        throw Exception(
          'Business ID not found. Please select a business first.',
        );
      }

      final safeSearch = Uri.encodeQueryComponent(effectiveSearch);
      final path =
          '/waveup/$bizId/payment-history?type=$type&page=$nextPage&limit=$effectiveLimit&search=$safeSearch';

      final res = await ApiService.get(context, path, withAccessToken: true);

      final raw = res.body;
      debugPrint(
        '[SubscriptionProvider] GET $path ◀︎ ${res.statusCode} '
        '${raw.length > 400 ? raw.substring(0, 400) + "…" : raw}',
      );

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('HTTP ${res.statusCode}');
      }

      Map<String, dynamic>? decoded;
      try {
        decoded = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        decoded = null;
      }
      if (decoded == null) throw Exception('Invalid JSON response');

      final status = (decoded['status'] as num?)?.toInt() ?? 0;
      if (status != 200) {
        final msg = decoded['msg']?.toString() ?? 'Failed to load more history';
        throw Exception('$msg (status=$status)');
      }

      final data = decoded['data'];
      final pageItems = (data is List)
          ? data
                .map(
                  (e) => SubscriptionHistoryItem.fromJson(
                    (e as Map).cast<String, dynamic>(),
                  ),
                )
                .toList()
          : <SubscriptionHistoryItem>[];

      final page = decoded['page'];
      final currentPage = (page is Map)
          ? (page['current_page'] as num?)?.toInt() ?? nextPage
          : nextPage;
      final totalPages = (page is Map)
          ? (page['total_pages'] as num?)?.toInt() ?? st.totalPages
          : st.totalPages;

      st.page = currentPage;
      st.totalPages = totalPages;

      st.items = [...st.items, ...pageItems];
      st.hasMore = st.page < st.totalPages;

      st.moreError = null;
    } catch (e, stTrace) {
      debugPrint(
        '[SubscriptionProvider] fetchMorePaymentHistory error: $e\n$stTrace',
      );
      st.moreError = 'Failed to load more history: $e';
    } finally {
      st.isLoadingMore = false;
      notifyListeners();
    }
  }

  void resetTransactionFeeState() {
    debugPrint('🧹 [SubscriptionProvider] resetTransactionFeeState() CALLED');

    _transactionFeeCheckTimer?.cancel();
    _transactionFeeCheckTimer = null;

    _isLoadingTransactionFees = false;
    _isProcessingTransactionFee = false;

    _transactionFees = [];
    _totalUnpaidTransactionFee = 0;
    _transactionFeeError = null;
    _transactionFeePaymentError = null;

    _currentTransactionFeeNumber = null;
    _lastTransactionFeeAmount = null;
    _lastTransactionFeePeriod = null;

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // DISPOSE
  // ---------------------------------------------------------------------------
  @override
  void dispose() {
    _paymentCheckTimer?.cancel();
    _paymentCheckTimer = null;

    _transactionFeeCheckTimer?.cancel();
    _transactionFeeCheckTimer = null;

    _iapPurchaseSub?.cancel();
    _iapPurchaseSub = null;

    if (isIOS) {
      unawaited(_iosAddition?.setDelegate(null));
    }

    super.dispose();
  }
}

class _ParsedSk2Ids {
  final String? transactionId;
  final String? originalTransactionId;
  const _ParsedSk2Ids({this.transactionId, this.originalTransactionId});
}

_ParsedSk2Ids? _tryParseSk2IdsFromJws(String jws) {
  // JWS format: header.payload.signature
  final parts = jws.split('.');
  if (parts.length != 3) return null;

  Map<String, dynamic>? payload;
  try {
    final normalized = base64Url.normalize(parts[1]);
    final bytes = base64Url.decode(normalized);
    payload = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }

  // Apple StoreKit2 JWS biasanya pakai key: "transactionId" & "originalTransactionId"
  final txId = payload['transactionId']?.toString();
  final origTxId = payload['originalTransactionId']?.toString();

  return _ParsedSk2Ids(transactionId: txId, originalTransactionId: origTxId);
}
