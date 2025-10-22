import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/constants/app_colors.dart';
import 'package:wa_blast/providers/sales_provider.dart';

import '../../widgets/stepper_header.dart';
import 'steps/make_order_step.dart';
import 'steps/check_order_step.dart';
import 'steps/payment_step.dart';

String _pmLabel(int? id) {
  switch (id) {
    case 1:
      return 'Cash';
    case 2:
      return 'EDC';
    case 3:
      return 'QRIS/VA';
    default:
      return 'Payment';
  }
}

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
  const _WrapperScaffold({super.key});

  @override
  State<_WrapperScaffold> createState() => _WrapperScaffoldState();
}

class _WrapperScaffoldState extends State<_WrapperScaffold> {
  int _lastStep = 0;

  Future<void> _handleBack(BuildContext context) async {
    final prov = context.read<SalesProvider>();
    final step = prov.currentStep;

    // Jika bukan di PaymentStep atau tidak sedang submitting → back normal
    if (step != 2 || !prov.submitting) {
      if (step > 0) {
        prov.goTo(step - 1);
      } else {
        Navigator.pushReplacementNamed(context, '/sales/list');
      }
      return;
    }

    // Di PaymentStep & sedang submitting → minta konfirmasi cancel
    final confirm = await showDialog<bool>(
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
                // 🔴 Icon warning
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2), // red-100
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFDC2626), // red-600
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),

                // 🧾 Title
                const Text(
                  'Cancel Ongoing Payment?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 10),

                // 💬 Description
                const Text(
                  'Are you sure you want to cancel this payment? '
                  'This will stop the current transaction payment flow.',
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),

                // 🧭 Buttons
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
                          'No',
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
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text(
                          'Cancel payment',
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

    if (confirm != true) return;

    // Jalankan cancel flow seperti tombol "Cancel payment"
    final ok = await prov.cancelPendingPayment(
      context,
      payload: const {'reason': 'user_cancel'},
    );

    if (!mounted) return;
    if (ok) {
      await showPaymentCancelledDialog(
        context,
        reference: prov.currentReference ?? '-',
        paymentMethodLabel: _pmLabel(prov.paymentMethod),
      );
    } else {
      final err = prov.consumeLastError() ?? 'Failed to cancel payment';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<SalesProvider>();

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
            children: [
              const Text(
                'Sales',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
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
            if (step == 0)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FilledButton.icon(
                  onPressed: () async {
                    final changed = await openAddProductSheet(context);
                    if (!mounted) return;
                    if (changed == true) setState(() {});
                  },
                  icon: const Icon(Icons.add_shopping_cart_outlined, size: 16),
                  label: const Text(
                    'Add product',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
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
          ],
        ),

        body: Column(
          children: [
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
