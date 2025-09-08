import 'package:flutter/material.dart';
import 'app_colors.dart';

enum StepLineState { inactive, active, completed }

class DS {
  // Radius
  static const r6 = 6.0;
  static const r8 = 8.0;
  static const r10 = 10.0;
  static const r12 = 12.0;

  // Spacing
  static const p16 = EdgeInsets.all(16);
  static const ph16 = EdgeInsets.symmetric(horizontal: 16);
  static const listTilePad = EdgeInsets.symmetric(horizontal: 16, vertical: 10);

  // TextStyles
  static const tsTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  static const tsPrice = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );
  static const tsOutOfStock = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AppColors.danger,
  );
  static const tsStepperActive = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.blueButton,
  );
  static const tsStepperInactive = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.disabledFg,
  );

  // Buttons
  static ButtonStyle primaryBtn({bool enabled = true}) =>
      ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        backgroundColor: enabled ? AppColors.blueButton : AppColors.disabledBg,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r8)),
        foregroundColor: enabled ? Colors.white : AppColors.disabledFg,
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      );

  static ButtonStyle pillChoose() => ElevatedButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    backgroundColor: AppColors.blueButton,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r10)),
    foregroundColor: Colors.white,
    textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
  );

  // Stepper gradient bar
  static BoxDecoration stepperLine({required bool active}) => BoxDecoration(
    borderRadius: BorderRadius.circular(999),
    gradient: active
        ? const LinearGradient(
            colors: [AppColors.blueButton, AppColors.divider],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          )
        : const LinearGradient(
            colors: [AppColors.disabledBg, AppColors.disabledBg],
          ),
  );

  static BoxDecoration stepperLineState(StepLineState state) {
    switch (state) {
      case StepLineState.completed:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: AppColors.blueButton, // penuh biru
        );
      case StepLineState.active:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: const LinearGradient(
            colors: [AppColors.blueButton, AppColors.divider],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        );
      case StepLineState.inactive:
      default:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: AppColors.disabledBg,
        );
    }
  }
}

// Simple rupiah formatter (tanpa intl)
String formatRp(int v) {
  final s = v.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final reversedIndex = s.length - i;
    buf.write(s[i]);
    final isThousand = reversedIndex > 1 && reversedIndex % 3 == 1;
    if (isThousand) buf.write('.');
  }
  return 'Rp. ${buf.toString()}';
}
