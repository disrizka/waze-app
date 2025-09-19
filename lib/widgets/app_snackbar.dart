import 'package:flutter/material.dart';

enum AppSnackType { success, info, error, warning }

class AppSnackbar {
  AppSnackbar._();

  /// Minimal, consistent snackbar.
  static void show(
    BuildContext context, {
    required String message,
    AppSnackType type = AppSnackType.info,
    String? title,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    final theme = Theme.of(context);
    final colors = _palette(theme, type);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: duration,
          behavior: SnackBarBehavior.floating,
          elevation: 0, // flatter
          backgroundColor: Colors.transparent,
          padding: EdgeInsets.zero,
          content: _SnackContent(
            title: title,
            message: message,
            colors: colors,
            actionLabel: actionLabel,
            onAction: onAction,
          ),
        ),
      );
  }

  static _SnackColors _palette(ThemeData theme, AppSnackType type) {
    // Calmer palette (pastel backgrounds, medium contrast text, subtle accent)
    Color bg, fg, tint, border;
    switch (type) {
      case AppSnackType.success:
        bg = const Color(0xFFEFF8F1);
        fg = const Color(0xFF14532D);
        tint = const Color(0xFF16A34A);
        border = const Color(0xFF16A34A).withOpacity(.18);
        break;
      case AppSnackType.info:
        bg = const Color(0xFFEFF4FF);
        fg = const Color(0xFF0B3C74);
        tint = const Color(0xFF2563EB);
        border = const Color(0xFF2563EB).withOpacity(.18);
        break;
      case AppSnackType.error:
        bg = const Color(0xFFFFF1F2);
        fg = const Color(0xFF7F1D1D);
        tint = const Color(0xFFDC2626);
        border = const Color(0xFFDC2626).withOpacity(.18);
        break;
      case AppSnackType.warning:
        bg = const Color(0xFFFFFBEB);
        fg = const Color(0xFF7C4A03);
        tint = const Color(0xFFD97706);
        border = const Color(0xFFD97706).withOpacity(.18);
        break;
    }

    if (theme.brightness == Brightness.dark) {
      // Keep it subtle in dark mode
      final surf = theme.colorScheme.surface;
      bg = Color.alphaBlend(bg.withOpacity(0.06), surf);
      fg = theme.colorScheme.onSurface.withOpacity(0.9);
      border = theme.colorScheme.outlineVariant.withOpacity(.35);
      // keep tint for icon/accent
    }

    return _SnackColors(bg: bg, fg: fg, tint: tint, border: border);
  }
}

class _SnackColors {
  final Color bg, fg, tint, border;
  const _SnackColors({
    required this.bg,
    required this.fg,
    required this.tint,
    required this.border,
  });
}

class _SnackContent extends StatelessWidget {
  const _SnackContent({
    required this.message,
    required this.colors,
    this.title,
    this.actionLabel,
    this.onAction,
  });

  final String? title;
  final String message;
  final _SnackColors colors;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final icon = _iconFor();
    // Compact spacing, soft corner, no heavy shadow.
    return Semantics(
      liveRegion: true,
      label: [
        if (title?.isNotEmpty == true) title,
        message,
      ].whereType<String>().join(' — '),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border, width: 1),
        ),
        child: Row(
          children: [
            // Small, neutral icon chip
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: colors.tint.withOpacity(.10),
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: colors.tint, size: 14),
            ),
            const SizedBox(width: 10),
            // Text column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null && title!.trim().isNotEmpty) ...[
                    Text(
                      title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.fg,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    message,
                    style: TextStyle(
                      color: colors.fg.withOpacity(.95),
                      height: 1.25,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            // Minimal action (optional). No extra close button to keep it clean.
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: 8),
              _LinkAction(
                label: actionLabel!,
                color: colors.tint,
                onPressed: () {
                  onAction?.call();
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _iconFor() {
    final c = colors.tint.value;
    if (c == const Color(0xFF16A34A).value) return Icons.check_rounded;
    if (c == const Color(0xFF2563EB).value) return Icons.info_outline_rounded;
    if (c == const Color(0xFFDC2626).value) return Icons.error_outline_rounded;
    return Icons.warning_amber_rounded;
  }
}

class _LinkAction extends StatelessWidget {
  const _LinkAction({
    required this.label,
    required this.onPressed,
    required this.color,
  });

  final String label;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: color,
      ),
      onPressed: onPressed,
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}
