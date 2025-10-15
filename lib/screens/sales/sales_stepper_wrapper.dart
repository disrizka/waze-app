import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/constants/app_colors.dart';
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
  const _WrapperScaffold({super.key});

  @override
  State<_WrapperScaffold> createState() => _WrapperScaffoldState();
}

class _WrapperScaffoldState extends State<_WrapperScaffold> {
  int _lastStep = 0;

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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor:
            Colors.transparent, // ✅ mencegah efek tint saat scroll
        elevation: 0, // ✅ tanpa bayangan
        scrolledUnderElevation: 0, // ✅ tetap putih meski discroll

        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () {
            if (step > 0) {
              prov.goTo(step - 1);
            } else {
              Navigator.pushReplacementNamed(context, '/sales/list');
            }
          },
        ),

        // 🆕 Judul alami: "Sales /create" kecil di samping
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
            Text(
              "/create",
              style: const TextStyle(
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
    );
  }
}
