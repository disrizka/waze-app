import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/providers/sales_provider.dart';
import '../constants/design_system.dart';

class StepperHeader extends StatelessWidget {
  final int activeIndex; // 0,1,2
  const StepperHeader({super.key, required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    // Masih boleh keep ini kalau kamu butuh provider untuk hal lain,
    // tapi sekarang kita tidak memanggil prov.goTo dari tap.
    context.read<SalesProvider>();

    const labels = ['Create Order', 'Detail Order', 'Payment'];

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
