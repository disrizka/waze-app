import 'package:flutter/material.dart';

class NetImageSquare extends StatelessWidget {
  final String url;
  final double size;
  const NetImageSquare({super.key, required this.url, this.size = 80});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        // ⬇️ fallback bila 404/time out dll
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          color: const Color(0xFFE5E7EB),
          alignment: Alignment.center,
          child: const Icon(
            Icons.image_not_supported_rounded,
            size: 24,
            color: Color(0xFF9CA3AF),
          ),
        ),
      ),
    );
  }
}
