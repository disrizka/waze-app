// lib/providers/subscription_provider.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:midtrans_sdk/midtrans_sdk.dart';

import '../core/provider_helper.dart';
import '../models/premium_plan_model.dart';
import '../services/api_service.dart';
import '../widgets/payment_webview_screen.dart'; // SESUAIKAN path ApiService

// -------------------------------------------------------------
// ENUM: BillingCycle
// -------------------------------------------------------------
enum BillingCycle { monthly, yearly }

// -------------------------------------------------------------
// Helper result Midtrans (hapus kalau kamu sudah punya PaymentResult sendiri)
// -------------------------------------------------------------

// -------------------------------------------------------------
// Result cek voucher
// -------------------------------------------------------------
class VoucherCheckResult {
  final bool isValid;
  final int originalPrice;
  final int finalPrice;
  final int discount;
  final String? voucherName;
  final String? voucherDesc;
  final String? message; // isi msg dari backend kalau gagal

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

  // Cari plan + pricing berdasarkan planId (di sini diasumsikan planId = PlanPricing.id)
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
  // CEK VOUCHER (POST /premium/voucher/check)
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

      // ✅ Berhasil
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

      // ❌ Gagal (contoh: status 400)
      // kembalikan saja apapun message-nya
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

      // Error network / lainnya, tetap bungkus di result supaya UI bisa handle
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
      // 🔹 Ambil business id dari BizIdCache
      final bizId = await BizIdCache.get();
      if (bizId == null || bizId.toString().trim().isEmpty) {
        throw Exception(
          'Business ID not found. Please select a business first.',
        );
      }

      final payload = {
        'plan_id': planId, // idPlan (encrypted di backend)
        'business_id': bizId,
        'pricing_id': pricingId, // PlanPricing.id (encrypted di backend)
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

      // 🔁 Mulai polling status pembayaran (konfirmasi dari backend)
      _startPaymentStatusPolling(context);

      // ===========================
      // 🔸 KHUSUS PAYMENT METHOD 6
      // ===========================
      if (paymentMethodFromResponse == 6) {
        if (paymentLink.isEmpty) {
          throw Exception(
            'Invalid upgrade response (no payment link for method 6)',
          );
        }

        debugPrint(
          '[Subscription] Open WebView for payment_method=6: $paymentLink',
        );

        // Buka halaman WebView, ada tombol "Finish payment" untuk menutup
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PaymentWebViewScreen(initialUrl: paymentLink),
            fullscreenDialog: true,
          ),
        );

        // ⚠️ Jangan panggil Snap kalau metode 6
        // Polling tetap jalan, dan kalau sukses akan muncul dialog + redirect ke /splash
        return;
      }

      // ===========================
      // Metode lain tetap pakai Snap
      // ===========================
      if (paymentToken.isEmpty) {
        throw Exception('Invalid upgrade response (no token for Snap)');
      }

      final snapResult = await _startSnap(paymentToken, context);
      debugPrint(
        '🏁 [Subscription] Snap selesai dengan status: ${snapResult?.status}',
      );

      // Keputusan final tetap dari _checkPaymentStatus (polling backend).
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
    //
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

        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text('Payment success. Premium activated!')),
        // );

        // // 🔹 Setelah backend konfirmasi pembayaran sukses, langsung ke /splash
        // Navigator.of(
        //   context,
        // ).pushNamedAndRemoveUntil('/splash', (route) => false);

        await _showPaymentSuccessDialog(context);

        // (opsional) sebelum redirect, kalau kamu mau refresh data bisnis/user,
        // bisa panggil API lain di sini dulu.
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

  Future<void> _showPaymentSuccessDialog(BuildContext context) async {
    // Default fallback kalau info plan/pricing tidak ketemu
    final planName = _lastPaidPlan?.name ?? 'Premium Plan';
    final period = _lastPaidPricing?.period;
    final price = _lastPaidPricing?.price;

    String periodLabel;
    if (period == null || period <= 0) {
      periodLabel = 'Selected period';
    } else if (period == 1) {
      periodLabel = '1 month';
    } else if (period == 12) {
      periodLabel = '12 months';
    } else {
      periodLabel = '$period months';
    }

    final amountLabel = price != null ? _formatRupiah(price) : '—';

    await showDialog(
      context: context,
      barrierDismissible: false, // wajib tekan Continue
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon sukses
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
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
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),

                const Text(
                  'Your premium subscription has been activated.\nThank you for your payment. Enjoy all premium features for your business.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 20),

                // Card detail plan
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
                        'Subscription details',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Plan',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              planName,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Billing period',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          Text(
                            periodLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
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
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

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
                      // Langsung arahkan ke /splash, hapus semua route sebelumnya
                      Navigator.of(
                        ctx,
                        rootNavigator: true,
                      ).pushNamedAndRemoveUntil('/splash', (route) => false);
                    },
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
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
