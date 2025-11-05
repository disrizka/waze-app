import 'package:flutter/material.dart';

/// Gunakan warna brand kalau kamu punya, fallback ke Colors.blue.
Color brandBlue(BuildContext context) {
  // kalau kamu punya AppColors.primaryColor, ganti return di bawah:
  // return AppColors.primaryColor;
  return Colors.blue;
}

void showErrorDialog(BuildContext context, String message) {
  showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) {
      final blue = const Color(0xFF1565C0);
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // === ICON HEADER ===
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.error_outline, color: blue, size: 34),
              ),
              const SizedBox(height: 16),

              // === TITLE ===
              Text(
                'Oops!',
                style: TextStyle(
                  color: blue,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),

              // === MESSAGE ===
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 24),

              // === OK BUTTON ===
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'OK',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Ilustrasi bulat simpel di bagian atas step.
class TopIllustration extends StatelessWidget {
  final IconData icon;
  const TopIllustration({super.key, required this.icon});

  @override
  Widget build(BuildContext context) {
    final blue = brandBlue(context);
    return CircleAvatar(
      radius: 44,
      backgroundColor: blue.withOpacity(0.08),
      child: Icon(icon, size: 42, color: blue),
    );
  }
}

/// Kotak-kotak input OTP sederhana yang sinkron ke controller.
class OtpBoxes extends StatefulWidget {
  final TextEditingController controller;
  final int length;
  const OtpBoxes({super.key, required this.controller, this.length = 6});

  @override
  State<OtpBoxes> createState() => _OtpBoxesState();
}

class _OtpBoxesState extends State<OtpBoxes> {
  final _nodes = <FocusNode>[];

  @override
  void initState() {
    super.initState();
    _nodes.addAll(List.generate(widget.length, (_) => FocusNode()));
  }

  @override
  void dispose() {
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<String> chars() {
      final text = widget.controller.text;
      return List<String>.generate(
        widget.length,
        (i) => (i < text.length) ? text[i] : '',
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(widget.length, (i) {
        return SizedBox(
          width: 44,
          child: TextField(
            focusNode: _nodes[i],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            decoration: const InputDecoration(
              counterText: '',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) {
              final c = chars();
              final buf = StringBuffer();
              for (var j = 0; j < widget.length; j++) {
                if (j == i) {
                  buf.write((v.isNotEmpty ? v[0] : ''));
                } else {
                  buf.write(c[j]);
                }
              }
              widget.controller.text = buf.toString();
              widget.controller.selection = TextSelection.collapsed(
                offset: widget.controller.text.length,
              );

              if (v.isNotEmpty && i < widget.length - 1) {
                _nodes[i + 1].requestFocus();
              } else if (v.isEmpty && i > 0) {
                _nodes[i - 1].requestFocus();
              }
              setState(() {});
            },
          ),
        );
      }),
    );
  }
}
