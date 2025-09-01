import 'dart:io';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/providers/auth_provider.dart';

class RegisterStep2Clean extends StatefulWidget {
  const RegisterStep2Clean({super.key});

  @override
  State<RegisterStep2Clean> createState() => _RegisterStep2CleanState();
}

class _RegisterStep2CleanState extends State<RegisterStep2Clean> {
  final _formKey = GlobalKey<FormState>();
  final _firstC = TextEditingController();
  final _lastC = TextEditingController();
  final _orgC = TextEditingController();
  File? _logo;

  @override
  void dispose() {
    _firstC.dispose();
    _lastC.dispose();
    _orgC.dispose();
    super.dispose();
  }

  // ---- STYLE TOKENS (match desain) ----
  static const _borderGray = Color(0xFFE5E7EB);
  static const _hintGray = Color(0xFF9CA3AF);
  static const _textGray = Color(0xFF111827);
  static const _blue = Color(0xFF4069E6);
  static const _blueSoft = Color(0xFFEFF4FF);

  OutlineInputBorder _fieldBorder(Color c) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: c, width: 1),
  );

  InputDecoration _inputDec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: _hintGray),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    enabledBorder: _fieldBorder(_borderGray),
    focusedBorder: _fieldBorder(_blue),
    border: _fieldBorder(_borderGray),
  );

  // ===== Permission helpers =====
  Future<bool> _ensureGalleryPermission() async {
    if (Platform.isIOS) {
      final status = await Permission.photos.request();
      return status.isGranted;
    } else {
      final status = await Permission.storage.request();
      return status.isGranted;
    }
  }

  Future<bool> _ensureCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  Future<void> _pickFromGallery() async {
    final ok = await _ensureGalleryPermission();
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Izin galeri ditolak')));
      return;
    }
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x != null) setState(() => _logo = File(x.path));
  }

  Future<void> _pickFromCamera() async {
    final ok = await _ensureCameraPermission();
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Izin kamera ditolak')));
      return;
    }
    final x = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (x != null) setState(() => _logo = File(x.path));
  }

  Future<void> _chooseLogoSource() async {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari Galeri'),
              onTap: () async {
                Navigator.pop(context);
                await _pickFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Ambil dari Kamera'),
              onTap: () async {
                Navigator.pop(context);
                await _pickFromCamera();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onCreate() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();

    final ok = await auth.registerStep2(
      context: context, // provider-mu yang handle redirect ke /splash
      firstName: _firstC.text.trim(),
      lastName: _lastC.text.trim(),
      organisationName: _orgC.text.trim(),
      organisationLogo: _logo,
    );

    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Register Step 2 gagal')),
      );
    }
    // Jika ok, provider sudah navigasi ke /splash.
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AuthProvider>().isLoading;

    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('content-step2'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== First Name =====
          const Text(
            'First Name',
            style: TextStyle(fontWeight: FontWeight.w600, color: _textGray),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _firstC,
            decoration: _inputDec('E.g. Abi'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
          ),
          const SizedBox(height: 16),

          // ===== Last Name =====
          const Text(
            'Last Name',
            style: TextStyle(fontWeight: FontWeight.w600, color: _textGray),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _lastC,
            decoration: _inputDec('E.g. Mamat'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
          ),
          const SizedBox(height: 16),

          // ===== Organisation Name =====
          const Text(
            'Organisation Name',
            style: TextStyle(fontWeight: FontWeight.w600, color: _textGray),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _orgC,
            decoration: _inputDec('E.g. Berjaya Selalu Grocery'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
          ),
          const SizedBox(height: 16),

          // ===== Organisation Logo =====
          const Text(
            'Organisation Logo',
            style: TextStyle(fontWeight: FontWeight.w600, color: _textGray),
          ),
          const SizedBox(height: 8),

          GestureDetector(
            onTap: _chooseLogoSource,
            child: DottedBorder(
              // dotted_border: ^3.1.0
              options: RoundedRectDottedBorderOptions(
                color: _blue,
                dashPattern: const <double>[8, 6],
                strokeWidth: 2,
                radius: const Radius.circular(12),
                padding: const EdgeInsets.all(0),
              ),
              child: Container(
                height: 110,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // preview / icon tile
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 52,
                        height: 52,
                        color: _blueSoft,
                        child: _logo == null
                            ? const Icon(
                                Icons.file_upload_rounded,
                                size: 22,
                                color: _blue,
                              )
                            : Image.file(_logo!, fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Texts
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // "Add your logo Business*"
                          RichText(
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                              style: const TextStyle(
                                color: _textGray,
                                fontWeight: FontWeight.w600,
                              ),
                              children: [
                                TextSpan(
                                  text: _logo == null
                                      ? 'Add your organisation logo'
                                      : 'Selected: ${_logo!.path.split('/').last}',
                                ),
                                const TextSpan(
                                  text: ' *',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Format JPG, PNG (maks 5–10MB)',
                            style: TextStyle(fontSize: 12, color: _hintGray),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _chooseLogoSource,
                      child: const Text(
                        'Upload',
                        style: TextStyle(
                          color: _blue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 22),

          // ===== Create button =====
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: loading ? null : _onCreate,
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: loading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Create',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
