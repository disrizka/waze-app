import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/purchase_stepper_provider.dart';
import '../../widgets/stepper_header.dart';
import 'steps/select_product_step.dart';
import 'steps/check_order_step.dart';
import 'steps/payment_step.dart';

class PurchaseStepperWrapper extends StatelessWidget {
  const PurchaseStepperWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PurchaseStepperProvider(),
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
    final prov = context.watch<PurchaseStepperProvider>();
    final step = prov.currentStep;

    final reverse = step < _lastStep;
    _lastStep = step;

    final pages = const [
      SelectProductStep(key: ValueKey('step-0'), withHeader: false),
      CheckOrderStep(key: ValueKey('step-1'), withHeader: false),
      PaymentStep(key: ValueKey('step-2'), withHeader: false),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (prov.currentStep > 0) {
              prov.goTo(prov.currentStep - 1);
            } else {
              Navigator.pushNamed(context, '/splash');
            }
          },
        ),
        title: const Text('Sales'),
        centerTitle: false,
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
