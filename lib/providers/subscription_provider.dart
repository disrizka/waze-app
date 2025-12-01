// lib/providers/subscription_provider.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:midtrans_sdk/midtrans_sdk.dart';

import '../core/provider_helper.dart';
import '../models/premium_plan_model.dart';
import '../services/api_service.dart'; // SESUAIKAN path ApiService

// -------------------------------------------------------------
// ENUM: BillingCycle
// -------------------------------------------------------------
enum BillingCycle { monthly, yearly }

// -------------------------------------------------------------
// Helper result Midtrans (hapus kalau kamu sudah punya PaymentResult sendiri)
// -------------------------------------------------------------
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

// -------------------------------------------------------------
// SubscriptionProvider
// -------------------------------------------------------------
class SubscriptionProvider with ChangeNotifier {
  // ====== Harga default (fallback kalau belum ada data plan) ======
  double _monthlyPrice = 11.0;
  double _yearlyPrice = 120.0;

  BillingCycle _selectedCycle = BillingCycle.monthly;

  // ====== State UI umum ======
  bool _isProcessing = false; // loading saat proses upgrade/payment
  bool _isLoadingPlans = false; // loading saat fetch plan list
  String? _errorMessage;

  // ====== Premium plan list ======
  List<PremiumPlan> _plans = [];

  // ====== Midtrans related ======
  MidtransSDK? _midtrans;
  Completer<PaymentResult>? _snapCompleter;
  Timer? _paymentCheckTimer;
  String? _currentTransactionNumber;

  // ---------------------------------------------------------------------------
  // HELPER FORMAT RUPIAH
  // ---------------------------------------------------------------------------
  /// Format angka jadi Rupiah dengan pemisah tiap 3 digit.
  /// Contoh: 1500000 -> "Rp 1.500.000"
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

  /// Plan pertama dari /premium-plan (jika ada).
  PremiumPlan? get firstPlan => _plans.isNotEmpty ? _plans.first : null;

  /// Label harga plan pertama, hanya "Rp 150.000"
  String get firstPlanPriceLabel {
    final plan = firstPlan;
    if (plan == null) return '-';
    return _formatRupiah(plan.price);
  }

  /// Label harga plan pertama lengkap dengan periodenya
  /// - 1 bulan  -> "Rp 150.000 / month"
  /// - 12 bulan -> "Rp 1.500.000 / year"
  /// - lainnya  -> "Rp 300.000 / 3 months"
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

  /// Label harga yang bisa langsung dipakai di UI.
  /// Sekarang:
  /// - kalau sudah ada data plan -> pakai plan pertama (Rupiah, 3 digit)
  /// - kalau belum ada plan -> fallback pakai _monthlyPrice/_yearlyPrice (juga Rupiah)
  String get selectedPriceLabel {
    // ✅ Pakai plan pertama kalau sudah ada data
    if (firstPlan != null) {
      return firstPlanPricePerPeriodLabel;
    }

    // Fallback: pakai harga default
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
  // 1) GET PREMIUM PLAN LIST (GET /premium-plan)
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

      // Contoh: kalau ada plan 12 bulan aktif, jadikan patokan harga yearly
      PremiumPlan? yearlyPlan;
      for (final p in _plans) {
        if (p.months == 12 && p.isActive) {
          yearlyPlan = p;
          break;
        }
      }

      // Update _monthlyPrice & _yearlyPrice supaya fallback juga pakai Rupiah dari API
      final first = firstPlan;

      if (yearlyPlan != null) {
        _yearlyPrice = yearlyPlan.price.toDouble();
        final months = yearlyPlan.months == 0 ? 1 : yearlyPlan.months;
        _monthlyPrice = yearlyPlan.price / months;
      } else if (first != null) {
        // Kalau tidak ada plan 12 bulan, pakai plan pertama sebagai referensi
        _yearlyPrice = first.price.toDouble();
        final months = first.months == 0 ? 1 : first.months;
        _monthlyPrice = first.price / months;
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
  // 2) UPGRADE PREMIUM (POST /premium/business/upgrade + Midtrans)
  //     business_id diambil dari BizIdCache.get()
  // ---------------------------------------------------------------------------
  Future<void> goToPayment({
    required BuildContext context,
    required String planId,
    int paymentMethod = 2,
  }) async {
    if (_isProcessing) return;

    _isProcessing = true;
    _errorMessage = null;
    notifyListeners();

    const path = '/premium/business/upgrade';

    try {
      // 🔹 Ambil business id dari BizIdCache
      final bizId = await BizIdCache.get();
      if (bizId == null || bizId.toString().trim().isEmpty) {
        throw Exception(
          'Business ID not found. Please select a business first.',
        );
      }

      final payload = {
        'plan_id': planId,
        'business_id': bizId,
        'payment_method': paymentMethod,
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

      if (transactionNumber.isEmpty || paymentToken.isEmpty) {
        throw Exception('Invalid upgrade response (no token / transaction id)');
      }

      _currentTransactionNumber = transactionNumber;

      // Mulai polling status pembayaran
      _startPaymentStatusPolling(context);

      // Jalankan Midtrans Snap UI
      final snapResult = await _startSnap(paymentToken, context);
      debugPrint(
        '🏁 [Subscription] Snap selesai dengan status: ${snapResult?.status}',
      );

      // Catatan:
      // - Walaupun Snap bilang "success", keputusan final tetap dari
      //   /premium/business/payment/check yang kita polling.
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

  // ---------------------------------------------------------------------------
  // 3) PAYMENT CHECK (POST /premium/business/payment/check)
  // ---------------------------------------------------------------------------
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
        // contoh: { "status": 400, "msg": "transaction not yet paid" }
        debugPrint(
          '[Subscription] Transaction belum dibayar: ${json['msg'] ?? ''}',
        );
        return; // biarkan timer jalan terus
      }

      if (status == 200) {
        debugPrint('[Subscription] Payment success! Hentikan polling.');

        _paymentCheckTimer?.cancel();
        _paymentCheckTimer = null;
        _currentTransactionNumber = null;

        _isProcessing = false;
        notifyListeners();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment success. Premium activated!')),
        );

        // TODO:
        // Kalau ada API get current user / business,
        // panggil di sini untuk refresh status plan (free -> premium)
        return;
      }

      // Status lain (kalau backend nanti tambahkan expired/failed, dsb.)
      debugPrint(
        '[Subscription] Payment check status tidak dikenal: $status (json=$json)',
      );
    } catch (e, st) {
      debugPrint('[Subscription] Error cek payment: $e\n$st');
      // Bisa diabaikan, nanti timer akan coba lagi 6 detik kemudian.
    }
  }

  // ---------------------------------------------------------------------------
  // MIDTRANS (diadaptasi dari SalesProvider)
  // ---------------------------------------------------------------------------
  Future<void> _initMidtransIfNeeded(BuildContext context) async {
    final midtransClientKey = dotenv.env['MIDTRANS_CLIENT_KEY'];

    if (_midtrans != null) return;

    _midtrans = await MidtransSDK.init(
      config: MidtransConfig(
        clientKey: midtransClientKey!,
        merchantBaseUrl: '',
        colorTheme: ColorTheme(
          colorPrimary: Theme.of(context).colorScheme.primary,
          colorPrimaryDark: Theme.of(context).colorScheme.primary,
          colorSecondary: Theme.of(context).colorScheme.secondary,
        ),
        enableLog: true,
      ),
    );
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
  // DISPOSE
  // ---------------------------------------------------------------------------
  @override
  void dispose() {
    _paymentCheckTimer?.cancel();
    _paymentCheckTimer = null;
    super.dispose();
  }
}
