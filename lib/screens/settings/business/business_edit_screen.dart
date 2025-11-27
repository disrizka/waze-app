// lib/screens/business_edit_screen.dart
import 'dart:convert';
import 'dart:io';

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wa_blast/constants/app_colors.dart';
import 'package:wa_blast/providers/auth_provider.dart';
import 'package:wa_blast/providers/edit_profile_provider.dart';

class BusinessEditScreen extends StatefulWidget {
  static const routeName = '/business/edit';
  const BusinessEditScreen({super.key});

  @override
  State<BusinessEditScreen> createState() => _BusinessEditScreenState();
}

class _BusinessEditScreenState extends State<BusinessEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _aboutC = TextEditingController(); // default: kosong (tidak dari prefs)
  final _usernameC = TextEditingController(); // read-only (dari prefs)
  final _businessNameC = TextEditingController(); // read-only (dari prefs)

  bool _loading = true;
  bool _saving = false;

  String _currentName = '';
  String _currentLogoUrl = '';
  String _currentUsername = '';
  File? _pickedOrgLogoFile;

  /// Switch: allow selling when stock is empty (out of stock)
  bool _allowOutOfStock = false;

  @override
  void initState() {
    super.initState();
    _loadDefaultsFromPrefs();
  }

  bool _parseOutOfStockFlag(dynamic raw, bool defaultValue) {
    if (raw == null) return defaultValue;
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      final s = raw.toLowerCase();
      if (s == '1' || s == 'true' || s == 'yes') return true;
      if (s == '0' || s == 'false' || s == 'no') return false;
    }
    return defaultValue;
  }

  /// Baca flag boleh jual stok kosong dari berbagai sumber prefs
  bool _readAllowOutOfStockFromPrefs(SharedPreferences prefs, String activeId) {
    bool? flag;

    // 1) Flag eksplisit di prefs
    final direct = prefs.getBool('activeBizCanSellOutOfStock');
    if (direct != null) flag = direct;

    // 2) Fallback: dari business_full
    if (flag == null) {
      final rawFull = prefs.getString('business_full');
      final id = activeId.isNotEmpty
          ? activeId
          : (prefs.getString('activeBizId') ?? '').trim();
      if (rawFull != null && rawFull.isNotEmpty && id.isNotEmpty) {
        try {
          final list = (jsonDecode(rawFull) as List)
              .cast<Map<String, dynamic>>();
          final match = list.firstWhere(
            (e) => (e['idBusiness'] ?? '').toString() == id,
            orElse: () => <String, dynamic>{},
          );
          if (match.isNotEmpty) {
            final raw =
                match['canBeSoldOutOfStock'] ??
                match['canSellOutOfStock'] ??
                match['can_be_sold_out_of_stock'];
            flag = _parseOutOfStockFlag(raw, false);
          }
        } catch (_) {}
      }
    }

    // 3) Fallback tambahan: dari list "business"
    if (flag == null) {
      final rawBiz = prefs.getString('business');
      final id = activeId.isNotEmpty
          ? activeId
          : (prefs.getString('activeBizId') ?? '').trim();
      if (rawBiz != null && rawBiz.isNotEmpty && id.isNotEmpty) {
        try {
          final list = (jsonDecode(rawBiz) as List)
              .cast<Map<String, dynamic>>();
          final match = list.firstWhere(
            (e) => (e['idBusiness'] ?? '').toString() == id,
            orElse: () => <String, dynamic>{},
          );
          if (match.isNotEmpty) {
            final raw =
                match['can_be_sold_out_of_stock'] ??
                match['canBeSoldOutOfStock'] ??
                match['canSellOutOfStock'];
            flag = _parseOutOfStockFlag(raw, false);
          }
        } catch (_) {}
      }
    }

    return flag ?? false;
  }

  Future<void> _loadDefaultsFromPrefs() async {
    setState(() => _loading = true);

    final prefs = await SharedPreferences.getInstance();

    final activeId = (prefs.getString('activeBizId') ?? '').trim();
    String businessName = '';
    String businessUsername = '';
    String businessLogoPath = '';

    final businessJson = prefs.getString('business');
    if (businessJson != null && businessJson.isNotEmpty) {
      try {
        final list = (jsonDecode(businessJson) as List)
            .cast<Map<String, dynamic>>();
        Map<String, dynamic>? match;
        if (activeId.isNotEmpty) {
          match = list.firstWhere(
            (e) => (e['idBusiness'] ?? '').toString() == activeId,
            orElse: () => <String, dynamic>{},
          );
        }

        if (match != null && match.isNotEmpty) {
          businessName = (match['name'] ?? '').toString();
          businessUsername = (match['username'] ?? '').toString();
          businessLogoPath = (match['logoPath'] ?? match['logo'] ?? '')
              .toString();
        } else {
          businessName = prefs.getString('activeBizName') ?? '';
          businessUsername = prefs.getString('activeBizUsername') ?? '';
          businessLogoPath = prefs.getString('activeBizLogoPath') ?? '';
        }
      } catch (_) {
        businessName = prefs.getString('activeBizName') ?? '';
        businessUsername = prefs.getString('activeBizUsername') ?? '';
        businessLogoPath = prefs.getString('activeBizLogoPath') ?? '';
      }
    } else {
      businessName = prefs.getString('activeBizName') ?? '';
      businessUsername = prefs.getString('activeBizUsername') ?? '';
      businessLogoPath = prefs.getString('activeBizLogoPath') ?? '';
    }

    // baca flag out-of-stock dari prefs (mengikuti pola AddProductSheet)
    final allowOutOfStock = _readAllowOutOfStockFromPrefs(prefs, activeId);

    // set default form: name & username dari prefs; about dikosongkan
    _businessNameC.text = businessName;
    _usernameC.text = businessUsername;

    if (!mounted) return;
    setState(() {
      _currentName = businessName;
      _currentUsername = businessUsername;
      _currentLogoUrl = businessLogoPath;
      _allowOutOfStock = allowOutOfStock;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _aboutC.dispose();
    _usernameC.dispose();
    _businessNameC.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final XFile? x = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x != null) {
      setState(() => _pickedOrgLogoFile = File(x.path));
    }
  }

  void _removePickedLogo() {
    setState(() => _pickedOrgLogoFile = null);
  }

  Future<void> _applyLatestBusinessFromPrefs(String lockedId) async {
    final prefs = await SharedPreferences.getInstance();

    String businessName = '';
    String businessUsername = '';
    String businessLogoPath = '';

    final businessJson = prefs.getString('business');
    if (businessJson != null && businessJson.isNotEmpty) {
      try {
        final list = (jsonDecode(businessJson) as List)
            .cast<Map<String, dynamic>>();
        Map<String, dynamic>? match;
        if (lockedId.isNotEmpty) {
          match = list.firstWhere(
            (e) => (e['idBusiness'] ?? '').toString() == lockedId,
            orElse: () => <String, dynamic>{},
          );
        }

        if (match != null && match.isNotEmpty) {
          businessName = (match['name'] ?? '').toString();
          businessUsername = (match['username'] ?? '').toString();
          businessLogoPath = (match['logoPath'] ?? match['logo'] ?? '')
              .toString();
        } else {
          businessName = prefs.getString('activeBizName') ?? '';
          businessUsername = prefs.getString('activeBizUsername') ?? '';
          businessLogoPath = prefs.getString('activeBizLogoPath') ?? '';
        }
      } catch (_) {
        businessName = prefs.getString('activeBizName') ?? '';
        businessUsername = prefs.getString('activeBizUsername') ?? '';
        businessLogoPath = prefs.getString('activeBizLogoPath') ?? '';
      }
    } else {
      businessName = prefs.getString('activeBizName') ?? '';
      businessUsername = prefs.getString('activeBizUsername') ?? '';
      businessLogoPath = prefs.getString('activeBizLogoPath') ?? '';
    }

    // baca lagi flag terbaru dari prefs (supaya sinkron dengan hasil refresh)
    final allowOutOfStock = _readAllowOutOfStockFromPrefs(
      prefs,
      lockedId.trim(),
    );

    // Terapkan ke controller & state aktif
    _businessNameC.text = businessName;
    _usernameC.text = businessUsername;

    if (!mounted) return;
    setState(() {
      _currentName = businessName;
      _currentUsername = businessUsername;
      _currentLogoUrl = businessLogoPath;
      _allowOutOfStock = allowOutOfStock;
    });

    debugPrint(
      '🔄 [BusinessEdit] Applied latest prefs: name="$businessName" user="$businessUsername" logo="$businessLogoPath" allowOutOfStock=$_allowOutOfStock',
    );
  }

  Future<void> _onSave() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final prov = context.read<EditProfileProvider>();

      final (ok, uploadedFilename) = await prov.submitEditBusiness(
        context,
        organisationName: _businessNameC.text.trim().isEmpty
            ? null
            : _businessNameC.text.trim(),
        about: _aboutC.text.trim().isEmpty ? null : _aboutC.text.trim(),
        organisationLogoFile: _pickedOrgLogoFile,
        canBeSoldOutOfStock: _allowOutOfStock,
      );

      debugPrint(
        '✅ submitEditBusiness result: ok=$ok, uploaded="$uploadedFilename"',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(ok ? 'Business saved' : 'Failed to save business'),
        ),
      );

      if (ok) {
        final auth = context.read<AuthProvider>();
        final prefs = await SharedPreferences.getInstance();

        // simpan juga ke prefs explicit flag-nya
        await prefs.setBool('activeBizCanSellOutOfStock', _allowOutOfStock);

        // Kunci active id saat ini
        final lockedId = (prefs.getString('activeBizId') ?? '').trim();
        debugPrint('🔐 [BusinessEdit] lockedId="$lockedId" before refresh');

        final refreshed = await auth.refreshCurrentUser(context);
        debugPrint('♻️ [BusinessEdit] refreshCurrentUser -> $refreshed');

        await _applyLatestBusinessFromPrefs(lockedId);

        if (refreshed && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text('Data refreshed'),
            ),
          );
        }

        if (mounted) Navigator.pop(context);
      } else {
        setState(() => _saving = false);
      }
    } catch (e, st) {
      debugPrint('🔥 _onSave exception: $e\n$st');
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EditProfileProvider()..initFromPrefs(),
      child: Consumer<EditProfileProvider>(
        builder: (_, __, ___) {
          return Scaffold(
            backgroundColor: AppColors.white,
            appBar: AppBar(
              backgroundColor: AppColors.white,
              titleSpacing: 0,
              centerTitle: false,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: AppColors.black,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                'Business Edit',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: SizedBox(
                    height: 28,
                    child: TextButton(
                      onPressed: _saving ? null : _onSave,
                      style: ButtonStyle(
                        padding: WidgetStateProperty.all(
                          const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        minimumSize: WidgetStateProperty.all(const Size(0, 28)),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: WidgetStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        backgroundColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.disabled)
                              ? AppColors.blueButton.withOpacity(0.5)
                              : AppColors.blueButton,
                        ),
                        foregroundColor: WidgetStateProperty.all(
                          AppColors.white,
                        ),
                        overlayColor: WidgetStateProperty.all(
                          AppColors.white.withOpacity(0.12),
                        ),
                        elevation: WidgetStateProperty.all(0),
                      ),
                      child: Text(
                        _saving ? 'Saving…' : 'Save Update',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            body: _loading
                ? const Center(child: CircularProgressIndicator())
                : SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ===== Business Name =====
                            _AccountField(
                              label: 'Business Name',
                              controller: _businessNameC,
                              hint: 'Your Business Name',
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Business name is required';
                                }
                                return null;
                              },
                            ),

                            // ===== Business Username (read-only, from prefs) =====
                            _AccountField(
                              label: 'Business Username',
                              controller: _usernameC,
                              hint: 'Business Username',
                              enabled: false,
                              readOnly: true,
                            ),

                            // ===== About (optional, tidak default dari prefs) =====
                            _AccountField(
                              label: 'About',
                              controller: _aboutC,
                              hint: 'Describe your business (optional)',
                              maxLines: 5,
                            ),

                            const SizedBox(height: 8),

                            // ===== Switch: allow out-of-stock sales =====
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'Allow selling products with zero stock',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              value: _allowOutOfStock,
                              onChanged: (v) async {
                                setState(() => _allowOutOfStock = v);

                                final prefs =
                                    await SharedPreferences.getInstance();
                                await prefs.setBool(
                                  'activeBizCanSellOutOfStock',
                                  v,
                                );

                                final activeId =
                                    (prefs.getString('activeBizId') ?? '')
                                        .trim();

                                // update snapshot business_full
                                try {
                                  final rawFull = prefs.getString(
                                    'business_full',
                                  );
                                  if (rawFull != null &&
                                      rawFull.isNotEmpty &&
                                      activeId.isNotEmpty) {
                                    final list = (jsonDecode(rawFull) as List)
                                        .cast<Map<String, dynamic>>();
                                    bool changed = false;
                                    for (final b in list) {
                                      if ((b['idBusiness'] ?? '').toString() ==
                                          activeId) {
                                        b['canSellOutOfStock'] = v;
                                        b['canBeSoldOutOfStock'] = v;
                                        b['can_be_sold_out_of_stock'] = v;
                                        changed = true;
                                        break;
                                      }
                                    }
                                    if (changed) {
                                      await prefs.setString(
                                        'business_full',
                                        jsonEncode(list),
                                      );
                                    }
                                  }
                                } catch (_) {}

                                // update snapshot business
                                try {
                                  final rawBiz = prefs.getString('business');
                                  if (rawBiz != null &&
                                      rawBiz.isNotEmpty &&
                                      activeId.isNotEmpty) {
                                    final list = (jsonDecode(rawBiz) as List)
                                        .cast<Map<String, dynamic>>();
                                    bool changed = false;
                                    for (final b in list) {
                                      if ((b['idBusiness'] ?? '').toString() ==
                                          activeId) {
                                        b['canSellOutOfStock'] = v;
                                        b['canBeSoldOutOfStock'] = v;
                                        b['can_be_sold_out_of_stock'] = v;
                                        changed = true;
                                        break;
                                      }
                                    }
                                    if (changed) {
                                      await prefs.setString(
                                        'business',
                                        jsonEncode(list),
                                      );
                                    }
                                  }
                                } catch (_) {}
                              },
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'When this option is enabled, products can be sold even if their stock is zero. Your inventory quantity will be allowed to go negative when you sell with no stock available.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.disabledFg,
                              ),
                            ),

                            const SizedBox(height: 18),

                            // ===== Label di atas Logo Picker =====
                            const _FieldLabel('Business Logo'),
                            const SizedBox(height: 8),

                            // ===== Logo Uploader (dotted, sama feel) =====
                            _BusinessLogoPicker(
                              currentLogoUrl: _currentLogoUrl,
                              pickedFile: _pickedOrgLogoFile,
                              fallbackInitial:
                                  (_currentName.isNotEmpty
                                          ? _currentName[0].toUpperCase()
                                          : '?')
                                      .toString(),
                              onPick: _pickLogo,
                              onRemovePicked: _removePickedLogo,
                              onClearCurrent: () {
                                setState(() => _currentLogoUrl = '');
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          );
        },
      ),
    );
  }
}

// =========================
// Widgets (gaya referensi)
// =========================

class _BusinessLogoPicker extends StatelessWidget {
  const _BusinessLogoPicker({
    required this.currentLogoUrl,
    required this.pickedFile,
    required this.fallbackInitial,
    required this.onPick,
    required this.onRemovePicked,
    required this.onClearCurrent,
  });

  final String currentLogoUrl;
  final File? pickedFile;
  final String fallbackInitial;
  final VoidCallback onPick;
  final VoidCallback onRemovePicked;
  final VoidCallback onClearCurrent;

  @override
  Widget build(BuildContext context) {
    const double boxHeight = 110;
    const Radius boxRadius = Radius.circular(12);

    // STATE: ada gambar (dipilih / dari URL)
    if (pickedFile != null || (currentLogoUrl).isNotEmpty) {
      Widget image;
      if (pickedFile != null) {
        image = Image.file(
          pickedFile!,
          width: double.infinity,
          height: boxHeight,
          fit: BoxFit.cover,
        );
      } else {
        image = Image.network(
          currentLogoUrl,
          width: double.infinity,
          height: boxHeight,
          fit: BoxFit.cover,
          errorBuilder: (ctx, err, st) => _fallbackBox(boxHeight),
        );
      }

      return DottedBorder(
        options: const RoundedRectDottedBorderOptions(
          color: AppColors.blueButton,
          dashPattern: <double>[8, 6],
          strokeWidth: 2,
          radius: boxRadius,
          padding: EdgeInsets.all(0),
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(boxRadius.x),
              child: image,
            ),
            Positioned(
              top: 6,
              right: 6,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Remove/clear button
                  InkWell(
                    onTap: pickedFile != null ? onRemovePicked : onClearCurrent,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.black.withOpacity(0.54),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Change button
                  InkWell(
                    onTap: onPick,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.black.withOpacity(0.54),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.image_rounded,
                        size: 16,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // STATE: kosong
    return DottedBorder(
      options: const RoundedRectDottedBorderOptions(
        color: AppColors.blueButton,
        dashPattern: <double>[8, 6],
        strokeWidth: 2,
        radius: boxRadius,
        padding: EdgeInsets.all(0),
      ),
      child: InkWell(
        onTap: onPick,
        child: Container(
          height: boxHeight,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(boxRadius.x),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Kotak thumbnail kecil kiri
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.greyBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  fallbackInitial,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.blueButton,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: 'Add your logo Business',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        children: [
                          TextSpan(
                            text: ' *',
                            style: TextStyle(color: AppColors.red),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Format JPG, PNG',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.disabledFg,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallbackBox(double boxHeight) {
    return Container(
      width: double.infinity,
      height: boxHeight,
      color: AppColors.greyBackground,
      alignment: Alignment.center,
      child: const Icon(
        Icons.broken_image_rounded,
        size: 36,
        color: AppColors.grey,
      ),
    );
  }
}

class _AccountField extends StatelessWidget {
  const _AccountField({
    required this.label,
    required this.controller,
    this.hint,
    this.maxLines = 1,
    this.validator,
    this.enabled,
    this.readOnly = false,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final int maxLines;
  final String? Function(String?)? validator;
  final bool? enabled; // null => default true
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final isEnabled = enabled ?? true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(label),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            maxLines: maxLines,
            validator: validator,
            readOnly: readOnly,
            enabled: isEnabled,
            style: const TextStyle(
              fontSize: 15.5,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: hint,
              filled: !isEnabled,
              fillColor: !isEnabled ? AppColors.greyBackground : null,
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppColors.greyBackground,
                  width: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: AppColors.textPrimary,
      ),
    );
  }
}
