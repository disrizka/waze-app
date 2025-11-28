import 'dart:io';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/l10n/app_localizations.dart';
import 'package:wa_blast/providers/auth_provider.dart';

class RegisterStep2Clean extends StatefulWidget {
  const RegisterStep2Clean({super.key});

  @override
  State<RegisterStep2Clean> createState() => _RegisterStep2CleanState();
}

class _RegisterStep2CleanState extends State<RegisterStep2Clean> {
  final _formKey = GlobalKey<FormState>();

  final _orgC = TextEditingController();
  final _aboutC = TextEditingController();

  File? _logo;
  XFile? _logoX;
  final _picker = ImagePicker();

  static const int _maxBytes = 10 * 1024 * 1024; // 10 MB

  AppLocalizations get l10n => AppLocalizations.of(context)!;

  @override
  void dispose() {
    _orgC.dispose();
    _aboutC.dispose();
    super.dispose();
  }

  // ---- STYLE TOKENS ----
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
  Future<bool> _ensureCameraPermission() async {
    try {
      final st = await Permission.camera.status;
      if (st.isGranted) return true;
      if (st.isPermanentlyDenied) {
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.register_step2_camera_perm_permanently_denied),
          ),
        );
        await openAppSettings();
        return false;
      }
      final req = await Permission.camera.request();
      return req.isGranted;
    } catch (_) {
      return false;
    }
  }

  Future<void> _pick(ImageSource src) async {
    if (src == ImageSource.camera) {
      final ok = await _ensureCameraPermission();
      if (!ok) return;
    }

    try {
      final x = await _picker.pickImage(
        source: src,
        imageQuality: 88,
        maxWidth: 1600,
        maxHeight: 1600,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (x == null) return;

      if (!kIsWeb) {
        final f = File(x.path);
        final len = await f.length();
        if (len > _maxBytes) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${l10n.register_step2_image_too_large_prefix} '
                '(${_fmtBytes(len)}). '
                '${l10n.register_step2_image_too_large_suffix} '
                '${_fmtBytes(_maxBytes)}.',
              ),
            ),
          );
          return;
        }
        setState(() {
          _logo = f;
          _logoX = x;
        });
      } else {
        setState(() {
          _logo = null;
          _logoX = x;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.register_step2_pick_image_failed_prefix}$e'),
        ),
      );
    }
  }

  Future<void> _chooseLogoSource() async {
    // pakai context dari builder supaya l10n tetap mengikuti locale bottom sheet
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final l10nSheet = AppLocalizations.of(ctx)!;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(l10nSheet.register_step2_logo_from_gallery_title),
                subtitle: Text(
                  l10nSheet.register_step2_logo_from_gallery_subtitle,
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _pick(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text(l10nSheet.register_step2_logo_take_photo_title),
                subtitle: Text(
                  l10nSheet.register_step2_logo_take_photo_subtitle,
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _pick(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _removeLogo() {
    setState(() {
      _logo = null;
      _logoX = null;
    });
  }

  Future<void> _onCreate() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();

    final ok = await auth.registerStep2(
      context: context,
      organisationName: _orgC.text.trim(),
      organisationLogo: _logo,
      organisationAbout: _aboutC.text.trim(),
    );

    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? l10n.register_step2_failed_default),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AuthProvider>().isLoading;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== Intro =====
          Text(
            l10n.register_step2_title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: _textGray,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.register_step2_desc,
            style: const TextStyle(fontSize: 13, color: _hintGray),
          ),
          const SizedBox(height: 20),

          // ===== Business Name =====
          Text(
            l10n.register_step2_business_name_label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: _textGray,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _orgC,
            decoration: _inputDec(l10n.register_step2_business_name_hint),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return l10n.register_step2_business_name_required;
              }
              if (v.trim().length < 2) {
                return l10n.register_step2_business_name_min_length;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // ===== About (optional) =====
          Text(
            l10n.register_step2_about_label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: _textGray,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _aboutC,
            maxLines: 3,
            decoration: _inputDec(l10n.register_step2_about_hint),
            // optional: no validator
          ),
          const SizedBox(height: 16),

          // ===== Business Logo =====
          Text(
            l10n.register_step2_logo_label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: _textGray,
            ),
          ),
          const SizedBox(height: 8),

          GestureDetector(
            onTap: _chooseLogoSource,
            child: DottedBorder(
              options: const RoundedRectDottedBorderOptions(
                color: _blue,
                dashPattern: [8, 6],
                strokeWidth: 2,
                radius: Radius.circular(12),
                padding: EdgeInsets.all(0),
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
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                                      ? l10n.register_step2_logo_add
                                      : '${l10n.register_step2_logo_selected_prefix}'
                                            '${_logoX?.name ?? _logo!.path.split('/').last}',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.register_step2_logo_hint,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _hintGray,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_logo != null)
                      TextButton(
                        onPressed: _removeLogo,
                        child: Text(
                          l10n.register_step2_logo_remove,
                          style: const TextStyle(
                            color: _blue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      TextButton(
                        onPressed: _chooseLogoSource,
                        child: Text(
                          l10n.register_step2_logo_upload,
                          style: const TextStyle(
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
                  : Text(
                      l10n.register_step2_finish_button,
                      style: const TextStyle(
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

  String _fmtBytes(int b) {
    const units = ['B', 'KB', 'MB', 'GB'];
    double size = b.toDouble();
    var i = 0;
    while (size >= 1024 && i < units.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(size < 10 && i > 0 ? 1 : 0)} ${units[i]}';
  }
}
