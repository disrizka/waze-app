// lib/widgets/show_fancy_bar.dart
import 'package:flutter/material.dart';

enum FancyBarType { info, success, warning, error }

void showFancyBar(
  BuildContext context, {
  required String title,
  required String message,
  FancyBarType type = FancyBarType.info,
  int milliseconds = 2600,
}) {
  final theme = Theme.of(context);
  final (bg, fg, icon) = switch (type) {
    FancyBarType.success => (
      const Color(0xFFE8F5E9), // hijau muda
      const Color(0xFF2E7D32), // hijau teks
      Icons.check_circle_rounded,
    ),
    FancyBarType.warning => (
      const Color(0xFFFFF3E0),
      const Color(0xFFEF6C00),
      Icons.warning_amber_rounded,
    ),
    FancyBarType.error => (
      const Color(0xFFFFEBEE),
      const Color(0xFFC62828),
      Icons.error_outline_rounded,
    ),
    _ => (
      const Color(0xFFE3F2FD),
      const Color(0xFF1565C0),
      Icons.info_outline_rounded,
    ),
  };

  // Hapus snackbar sebelumnya biar tidak numpuk
  ScaffoldMessenger.of(context).clearSnackBars();

  final snack = SnackBar(
    behavior: SnackBarBehavior.floating,
    duration: Duration(milliseconds: milliseconds),
    elevation: 0,
    backgroundColor: Colors.transparent, // biar card-nya yang berwarna
    content: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: ShapeDecoration(
        color: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        shadows: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: DefaultTextStyle(
              style: theme.textTheme.bodyMedium!.copyWith(
                color: fg,
                height: 1.2,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(message),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
            child: Icon(Icons.close_rounded, color: fg),
          ),
        ],
      ),
    ),
    margin: const EdgeInsets.all(16),
  );

  ScaffoldMessenger.of(context).showSnackBar(snack);
}
