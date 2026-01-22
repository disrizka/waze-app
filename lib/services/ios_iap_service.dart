import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';

/// Wrapper delegate StoreKit (wajib biar transaksi iOS stabil)
class _SkPaymentQueueDelegate implements SKPaymentQueueDelegateWrapper {
  @override
  bool shouldContinueTransaction(
    SKPaymentTransactionWrapper transaction,
    SKStorefrontWrapper storefront,
  ) {
    // Umumnya return true agar transaksi lanjut.
    // Kalau kamu punya logic region restriction, bisa ditaruh di sini.
    return true;
  }

  @override
  bool shouldShowPriceConsent() {
    // iOS bisa minta persetujuan harga (jika ada perubahan).
    return false;
  }
}

class IosIapService {
  IosIapService._();
  static final IosIapService instance = IosIapService._();

  final InAppPurchase _iap = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _sub;
  bool _initialized = false;
  bool _available = false;

  bool get isInitialized => _initialized;
  bool get isAvailable => _available;

  /// simpan product detail hasil query
  final Map<String, ProductDetails> products = {};

  /// init + set delegate (ini inti pemakaian in_app_purchase_storekit)
  Future<void> init({
    required void Function(List<PurchaseDetails> purchases) onPurchaseUpdate,
    required void Function(Object error) onPurchaseError,
  }) async {
    if (!Platform.isIOS) return;
    if (_initialized) return;

    // Set delegate StoreKit (PENTING)
    final addition = _iap
        .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
    await addition.setDelegate(_SkPaymentQueueDelegate());

    // Listen stream
    _sub?.cancel();
    _sub = _iap.purchaseStream.listen(
      onPurchaseUpdate,
      onError: onPurchaseError,
    );

    _available = await _iap.isAvailable();
    _initialized = true;
  }

  Future<void> dispose() async {
    if (!Platform.isIOS) return;

    // Lepas delegate biar tidak nempel saat hot restart / keluar halaman
    final addition = _iap
        .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
    await addition.setDelegate(null);

    await _sub?.cancel();
    _sub = null;
    _initialized = false;
  }

  Future<void> queryProducts(Set<String> ids) async {
    if (!Platform.isIOS) return;
    final resp = await _iap.queryProductDetails(ids);

    if (kDebugMode) {
      debugPrint('[IAP] query error=${resp.error}');
      debugPrint('[IAP] notFound=${resp.notFoundIDs}');
      debugPrint(
        '[IAP] found=${resp.productDetails.map((e) => e.id).toList()}',
      );
    }

    if (resp.error != null) {
      throw Exception('${resp.error!.code}: ${resp.error!.message}');
    }

    products
      ..clear()
      ..addEntries(resp.productDetails.map((p) => MapEntry(p.id, p)));
  }

  /// Untuk subscription, pakai buyNonConsumable juga (ini memang pattern plugin).
  Future<void> buySubscription(String productId) async {
    final product = products[productId];
    if (product == null) {
      throw Exception('ProductDetails not loaded for id=$productId');
    }

    final param = PurchaseParam(productDetails: product);
    final ok = await _iap.buyNonConsumable(purchaseParam: param);

    if (!ok) {
      throw Exception(
        'Failed to start purchase (buyNonConsumable returned false)',
      );
    }
  }

  Future<void> restore() async {
    await _iap.restorePurchases();
  }

  /// helper: selalu complete kalau pendingCompletePurchase
  Future<void> completeIfNeeded(PurchaseDetails p) async {
    if (p.pendingCompletePurchase) {
      await _iap.completePurchase(p);
    }
  }
}
