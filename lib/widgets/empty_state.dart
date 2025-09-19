import 'package:flutter/material.dart';
import 'package:wa_blast/constants/app_colors.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.description,
    this.imagePath = 'assets/empty_box.png',
    this.colorPrimary = AppColors.primary,
  });

  final String title;
  final String description;
  final String imagePath;
  final Color colorPrimary;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Center(
          child: Image.asset(
            imagePath,
            width: 180,
            height: 180,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryText,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(height: 1.4, color: AppColors.secondaryText),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
