import 'package:flutter/services.dart'; // for HapticFeedback
import 'package:flutter/material.dart';
import 'package:wa_blast/constants/app_colors.dart';

void showFancySnackBar(
  BuildContext context, {
  required String message,
  IconData icon = Icons.info_outline,
  String actionLabel = 'Got it',
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 3),
}) {
  HapticFeedback.mediumImpact();

  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      elevation: 12,
      backgroundColor: Colors.white,
      duration: duration,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.divider),
      ),
      content: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      action: SnackBarAction(
        label: actionLabel,
        textColor: AppColors.primary,
        onPressed: onAction ?? () {},
      ),
    ),
  );
}
