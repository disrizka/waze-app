import 'package:flutter/material.dart';

/// Stepper horizontal minimalis bergaya garis rapat.
/// - Tanpa ikon.
/// - Garis dan teks lebih berdekatan.
/// - Terlihat seperti tab bar progress.
class StepperLine extends StatelessWidget {
  final int currentStep;
  final List<String> steps;
  final ValueChanged<int>? onStepTap;
  final Color activeColor;
  final Color inactiveColor;

  const StepperLine({
    super.key,
    required this.currentStep,
    required this.steps,
    this.onStepTap,
    this.activeColor = const Color(0xFF1565C0),
    this.inactiveColor = const Color(0xFFB0B0B0),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(steps.length, (i) {
          final isActive = i == currentStep;
          final color = isActive ? activeColor : inactiveColor;

          return Expanded(
            child: InkWell(
              onTap: onStepTap != null ? () => onStepTap!(i) : null,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      steps[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: color,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: 3,
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: isActive
                            ? LinearGradient(
                                colors: [
                                  activeColor.withOpacity(0.3),
                                  activeColor,
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              )
                            : LinearGradient(
                                colors: [
                                  inactiveColor.withOpacity(0.1),
                                  inactiveColor.withOpacity(0.05),
                                ],
                              ),
                      ),
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
