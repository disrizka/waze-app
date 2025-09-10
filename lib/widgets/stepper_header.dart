import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import '../constants/design_system.dart';
import '../providers/purchase_stepper_provider.dart';

class StepperHeader extends StatelessWidget {
  final int activeIndex; // 0,1,2
  const StepperHeader({super.key, required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    final prov = context.read<PurchaseStepperProvider>();
    const labels = ['Select Product', 'Check Order', 'Payment'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = i == activeIndex;
          final completed = i < activeIndex;

          final lineState = completed
              ? StepLineState.completed
              : (selected ? StepLineState.active : StepLineState.inactive);

          return Expanded(
            child: InkWell(
              onTap: () => prov.goTo(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      labels[i],
                      textAlign: TextAlign.center,
                      style: selected
                          ? DS.tsStepperActive
                          : (completed
                                ? DS
                                      .tsStepperActive // teks biru untuk completed
                                : DS.tsStepperInactive),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 4,
                      decoration: DS.stepperLineState(lineState),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
