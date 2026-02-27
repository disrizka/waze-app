import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/providers/sales_provider.dart';

import '../../widgets/stepper_header.dart';
import 'steps/make_order_step.dart';
import 'steps/check_order_step.dart';
import 'steps/payment_step.dart';

class SalesStepperWrapper extends StatelessWidget {
  const SalesStepperWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SalesProvider(),
      child: const _WrapperScaffold(),
    );
  }
}

class _WrapperScaffold extends StatefulWidget {
  const _WrapperScaffold();

  @override
  State<_WrapperScaffold> createState() => _WrapperScaffoldState();
}

class _WrapperScaffoldState extends State<_WrapperScaffold> {
  int _lastStep = 0;

  bool _hasUnsavedProgress(SalesProvider prov) {
    if (prov.cartLen > 0) return true;
    if ((prov.storeLocationId ?? '').trim().isNotEmpty) return true;
    if ((prov.customerId ?? '').trim().isNotEmpty) return true;
    if ((prov.note ?? '').trim().isNotEmpty) return true;
    if ((prov.discount ?? 0) > 0) return true;
    if ((prov.paymentMethod ?? 1) != 1) return true;
    return false;
  }

  Future<void> _exitToSalesList(BuildContext context) async {
    if (!mounted) return;
    Navigator.of(
      context,
    ).popUntil((route) => route.settings.name == '/sales/list');
  }

  Future<void> _showExitStepOneDialog(BuildContext context) async {
    final prov = context.read<SalesProvider>();
    if (!_hasUnsavedProgress(prov)) {
      await _exitToSalesList(context);
      return;
    }

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Leave this transaction?'),
          content: const Text('Your changes will be lost.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Leave'),
            ),
          ],
        );
      },
    );

    if (!mounted || shouldLeave != true) {
      return;
    }
    await _exitToSalesList(context);
  }

  Future<void> _handleBack(BuildContext context) async {
    final prov = context.read<SalesProvider>();
    final int step = prov.currentStep;

    // Tampilkan dialog HANYA saat di step terakhir & sedang submitting
    final bool needsDialog = (step == 2 && prov.submitting);

    if (needsDialog) {
      final bool? confirm = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return Dialog(
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 40,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEFF6FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.exit_to_app_rounded,
                      size: 40,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Leave this transaction?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Payment is currently in progress. Leaving now will stop the payment flow.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF374151),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1D4ED8),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text(
                            'Leave now',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );

      if (confirm == true) {
        if (!mounted) return;
        // Tanpa cancel payment — langsung keluar ke list
        Navigator.pushReplacementNamed(context, '/sales/list');
      }
      return; // stop di sini karena kasus dialog sudah ditangani
    }

    // Selain kondisi di atas → back normal:
    if (step > 0) {
      prov.goTo(step - 1); // mundur satu step
    } else {
      await _showExitStepOneDialog(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<SalesProvider>();

    // Disable tombol add product jika store belum dipilih secara global
    final bool addDisabled = prov.isStoreMissingGlobally;

    final pages = const [
      MakeOrderStep(key: ValueKey('step-0'), withHeader: false),
      CheckOrderStep(key: ValueKey('step-1'), withHeader: false),
      PaymentStep(key: ValueKey('step-2'), withHeader: false),
    ];

    final int stepRaw = prov.currentStep;
    final int maxIndex = pages.length - 1;
    final int step = stepRaw.clamp(0, maxIndex);

    if (step != stepRaw) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<SalesProvider>().goTo(step);
      });
    }

    final reverse = step < _lastStep;
    _lastStep = step;

    return WillPopScope(
      onWillPop: () async {
        // Intersep tombol back sistem/gesture
        await _handleBack(context);
        return false; // kita handle sendiri
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => _handleBack(context),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: const [
              Text(
                'Sales',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              SizedBox(width: 8),
              Text(
                "/create",
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9CA3AF),
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          centerTitle: false,
          actions: [
            if (step == 1)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Tooltip(
                  message: addDisabled
                      ? 'Pilih store terlebih dahulu'
                      : 'Tambah produk',
                  child: FilledButton.icon(
                    onPressed: addDisabled
                        ? null
                        : () async {
                            final changed = await openAddProductSheet(context);
                            if (!mounted) return;
                            if (changed == true) setState(() {});
                          },
                    icon: const Icon(
                      Icons.add_shopping_cart_outlined,
                      size: 16,
                    ),
                    label: const Text(
                      'Add product',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF426FD4),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      minimumSize: const Size(0, 34),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: Column(
          children: [
            if (addDisabled && step == 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                margin: const EdgeInsets.only(bottom: 6),
                color: const Color(0xFFFFF7E6),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Color(0xFFB45309),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Silakan pilih store terlebih dahulu sebelum menambah produk.',
                        style: TextStyle(
                          color: Color(0xFF8A4B08),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            StepperHeader(activeIndex: step),
            Expanded(
              child: PageTransitionSwitcher(
                reverse: reverse,
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation, secondaryAnimation) {
                  return SharedAxisTransition(
                    animation: animation,
                    secondaryAnimation: secondaryAnimation,
                    transitionType: SharedAxisTransitionType.horizontal,
                    child: child,
                  );
                },
                child: pages[step],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
