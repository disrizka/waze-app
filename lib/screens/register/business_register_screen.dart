// lib/screens/register/business_register_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/providers/auth_provider.dart';

class BusinessRegisterScreen extends StatefulWidget {
  const BusinessRegisterScreen({super.key});

  @override
  State<BusinessRegisterScreen> createState() => _BusinessRegisterScreenState();
}

class _BusinessRegisterScreenState extends State<BusinessRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameC = TextEditingController();
  final _usernameC = TextEditingController();
  bool _usernameEditedManually = false;

  File? _logoFile;
  XFile? _logoX;
  Uint8List? _logoBytesWeb;
  final _picker = ImagePicker();
  static const int _maxBytes = 10 * 1024 * 1024; // 10MB

  // ===== STYLE TOKENS =====
  static const _borderGray = Color(0xFFE5E7EB);
  static const _hintGray = Color(0xFF9CA3AF);
  static const _textGray = Color(0xFF111827);
  static const _blue = Color(0xFF4069E6);
  static const _blueSoft = Color(0xFFEFF4FF);

  @override
  void initState() {
    super.initState();
    _nameC.addListener(() {
      if (!_usernameEditedManually) {
        _usernameC.text = _slugify(_nameC.text);
      }
    });
    _usernameC.addListener(() {
      _usernameEditedManually = true;
    });
  }

  @override
  void dispose() {
    _nameC.dispose();
    _usernameC.dispose();
    super.dispose();
  }

  // ===== Helper Functions =====
  String _slugify(String v) {
    final s = v.toLowerCase().trim();
    final clean = s
        .replaceAll(RegExp(r'[^a-z0-9_]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final trimmed = clean.replaceAll(RegExp(r'^_+|_+$'), '');
    if (trimmed.isEmpty) return '';
    if (!RegExp(r'^[a-z]').hasMatch(trimmed)) return 'biz_$trimmed';
    return trimmed;
  }

  OutlineInputBorder _fieldBorder(Color c) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: c, width: 1),
  );

  InputDecoration _inputDec(String hint, {String? helper}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: _hintGray),
    helperText: helper,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    enabledBorder: _fieldBorder(_borderGray),
    focusedBorder: _fieldBorder(_blue),
    border: _fieldBorder(_borderGray),
  );

  Future<bool> _ensureCameraPermission() async {
    if (kIsWeb) return true;
    final st = await Permission.camera.status;
    if (st.isGranted) return true;
    if (st.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }
    final req = await Permission.camera.request();
    return req.isGranted;
  }

  Future<void> _pick(ImageSource src) async {
    if (src == ImageSource.camera && !(await _ensureCameraPermission())) return;
    try {
      final x = await _picker.pickImage(
        source: src,
        imageQuality: 88,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (x == null) return;

      if (kIsWeb) {
        final bytes = await x.readAsBytes();
        if (bytes.length > _maxBytes) {
          _showMsg(
            'Ukuran gambar terlalu besar (${_fmtBytes(bytes.length)}). Maksimal ${_fmtBytes(_maxBytes)}.',
          );
          return;
        }
        setState(() {
          _logoFile = null;
          _logoX = x;
          _logoBytesWeb = bytes;
        });
      } else {
        final f = File(x.path);
        final len = await f.length();
        if (len > _maxBytes) {
          _showMsg(
            'Ukuran gambar terlalu besar (${_fmtBytes(len)}). Maksimal ${_fmtBytes(_maxBytes)}.',
          );
          return;
        }
        setState(() {
          _logoFile = f;
          _logoX = x;
          _logoBytesWeb = null;
        });
      }
    } catch (e) {
      _showMsg('Gagal memilih gambar: $e');
    }
  }

  void _showMsg(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _chooseLogoSource() async {
    if (kIsWeb) return _pick(ImageSource.gallery);
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
                await _pick(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Ambil dari Kamera'),
              onTap: () async {
                Navigator.pop(context);
                await _pick(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _removeLogo() {
    setState(() {
      _logoFile = null;
      _logoX = null;
      _logoBytesWeb = null;
    });
  }

  Future<void> _onCreate() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameC.text.trim();
    final username = _slugify(_usernameC.text.trim());
    final auth = context.read<AuthProvider>();

    final ok = await auth.createBusiness(
      context: context,
      name: name,
      username: username,
      logoFile: _logoFile,
    );

    if (!mounted) return;
    if (ok) {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false);
    } else {
      _showMsg(auth.error ?? 'Create business gagal.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AuthProvider?>()?.isLoading == true
        ? true
        : false;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ===== Header =====
                      const Text(
                        'Hold up!',
                        style: TextStyle(
                          color: _blue,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'You need to create your first business account before login to WaveUp.',
                        style: TextStyle(
                          color: _textGray,
                          fontSize: 14.5,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 26),

                      // ===== Business Name =====
                      const Text(
                        'Business Name',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _textGray,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameC,
                        textInputAction: TextInputAction.next,
                        decoration: _inputDec('e.g. Berjaya Selalu Grocery'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Wajib diisi';
                          }
                          if (v.trim().length < 3) {
                            return 'Minimal 3 karakter';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // ===== Username =====
                      const Text(
                        'Business Username',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _textGray,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _usernameC,
                        decoration: _inputDec(
                          'e.g. berjaya_selalu',
                          helper:
                              'Only lowercase letters, numbers, and underscores.',
                        ),
                        validator: (v) {
                          final val = _slugify(v?.trim() ?? '');
                          if (val.isEmpty) return 'Username wajib diisi';
                          if (val.length < 3) return 'Minimal 3 karakter';
                          if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(val)) {
                            return 'Gunakan huruf kecil/angka/underscore dan mulai dengan huruf';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // ===== Logo (optional) =====
                      const Text(
                        'Business Logo (optional)',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _textGray,
                        ),
                      ),
                      const SizedBox(height: 8),

                      GestureDetector(
                        onTap: _chooseLogoSource,
                        child: DottedBorder(
                          options: RoundedRectDottedBorderOptions(
                            color: _blue,
                            dashPattern: const [8, 6],
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
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: 56,
                                    height: 56,
                                    color: _blueSoft,
                                    child: _buildLogoPreview(),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _logoFile == null &&
                                                _logoBytesWeb == null
                                            ? 'Add your business logo'
                                            : 'Selected: ${_logoX?.name ?? _logoFile!.path.split('/').last}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: _textGray,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'JPG / PNG (max 10MB)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _hintGray,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (_logoFile != null || _logoBytesWeb != null)
                                  TextButton(
                                    onPressed: _removeLogo,
                                    child: const Text(
                                      'Remove',
                                      style: TextStyle(
                                        color: _blue,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  )
                                else
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
                      const SizedBox(height: 28),

                      // ===== Button =====
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
                                  'Create Business & Login',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoPreview() {
    if (kIsWeb) {
      if (_logoBytesWeb == null) {
        return const Icon(Icons.file_upload_rounded, size: 22, color: _blue);
      }
      return Image.memory(_logoBytesWeb!, fit: BoxFit.cover);
    } else {
      if (_logoFile == null) {
        return const Icon(Icons.file_upload_rounded, size: 22, color: _blue);
      }
      return Image.file(_logoFile!, fit: BoxFit.cover);
    }
  }

  String _fmtBytes(int b) {
    const units = ['B', 'KB', 'MB', 'GB'];
    double size = b.toDouble();
    int i = 0;
    while (size >= 1024 && i < units.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${units[i]}';
  }
}
