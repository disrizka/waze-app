import 'package:flutter/material.dart';
import '../constants/design_system.dart';

class StepperHeader extends StatelessWidget {
  final int activeIndex; // 0,1,2
  final List<String> labels;
  const StepperHeader({
    super.key,
    required this.activeIndex,
    this.labels = const ['Create Order', 'Detail Order', 'Payment'],
  });

  @override
  Widget build(BuildContext context) {
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
              // Disable tap: user tidak bisa klik step header
              onTap: null,
              // Opsional: hapus semua efek visual saat tap/hover/focus
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
              focusColor: Colors.transparent,
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
