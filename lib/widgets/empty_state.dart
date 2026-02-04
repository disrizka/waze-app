// lib/widgets/empty_state.dart
import 'package:flutter/material.dart';
import 'package:wa_blast/constants/app_colors.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.description,
    this.imagePath = 'assets/empty_box.png',
    this.colorPrimary = AppColors.primary,

    // ✅ NEW: control illustration size to prevent overflow in sheets
    this.illustrationSize = 180,
    this.titleTextStyle,
    this.descriptionTextStyle,
    this.tight = false,
  });

  final String title;
  final String description;
  final String imagePath;
  final Color colorPrimary;

  /// ✅ default 180 (same as before), can set smaller e.g. 120-150 for bottom sheet
  final double illustrationSize;

  /// optional style override
  final TextStyle? titleTextStyle;
  final TextStyle? descriptionTextStyle;

  /// ✅ if true: reduce vertical spacing (useful for tight layouts)
  final bool tight;

  @override
  Widget build(BuildContext context) {
    final double gapTop = tight ? 14 : 24;
    final double gapMid = tight ? 6 : 8;
    final double gapBottom = tight ? 12 : 24;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min, // ✅ helps inside tight containers/sheets
      children: [
        Center(
          child: SizedBox(
            width: illustrationSize,
            height: illustrationSize,
            child: Image.asset(imagePath, fit: BoxFit.contain),
          ),
        ),
        SizedBox(height: gapTop),
        Center(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style:
                titleTextStyle ??
                const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryText,
                ),
          ),
        ),
        SizedBox(height: gapMid),
        Center(
          child: Text(
            description,
            textAlign: TextAlign.center,
            style:
                descriptionTextStyle ??
                const TextStyle(
                  height: 1.4,
                  color: AppColors.secondaryText,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
        SizedBox(height: gapBottom),
      ],
    );
  }
}
