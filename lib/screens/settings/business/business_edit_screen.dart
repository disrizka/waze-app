// lib/screens/business_edit_screen.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
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

  bool _isPremiumBiz = false;

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

  bool _readIsPremiumFromPrefs(SharedPreferences prefs, String activeId) {
    bool? flag;

    // 1) Paling cepat: pref eksplisit yang diset oleh AuthProvider
    final direct = prefs.getBool('activeBizIsPremium');
    if (direct != null) flag = direct;

    // 2) Fallback: dari "business" simplified
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
            final raw = match['isPremium'] ?? match['is_premium'];
            flag = _parseOutOfStockFlag(raw, false); // reuse bool-like parser
          }
        } catch (_) {}
      }
    }

    // 3) Fallback terakhir: dari "business_full"
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
            final raw = match['isPremium'] ?? match['is_premium'];
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
    // baca premium dari prefs
    final isPremiumBiz = _readIsPremiumFromPrefs(prefs, activeId);

    // baca flag out-of-stock dari prefs
    bool allowOutOfStock = _readAllowOutOfStockFromPrefs(prefs, activeId);

    // ✅ RULE: jika FREE plan -> selalu ON & tidak boleh diubah
    if (!isPremiumBiz) {
      allowOutOfStock = true;

      // pastikan pref ikut konsisten (biar layar lain juga baca true)
      await prefs.setBool('activeBizCanSellOutOfStock', true);
    }

    // set default form: name & username dari prefs; about dikosongkan
    _businessNameC.text = businessName;
    _usernameC.text = businessUsername;

    if (!mounted) return;
    setState(() {
      _currentName = businessName;
      _currentUsername = businessUsername;
      _currentLogoUrl = businessLogoPath;
      _isPremiumBiz = isPremiumBiz;
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
    // ===== Switch: allow out-of-stock sales =====
    final bool isFreePlan = !_isPremiumBiz;
    final bool switchValue = isFreePlan ? true : _allowOutOfStock;
    Future<void> _showUpgradeToPremiumDialog() async {
      if (!mounted) return;

      return showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) {
          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            titlePadding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
            contentPadding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            title: Row(
              children: const [
                Expanded(
                  child: Text(
                    'Upgrade to Premium',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            content: const Text(
              'This feature is available for Premium only. Upgrade to Premium to manage out-of-stock selling settings.',
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: AppColors.disabledFg,
              ),
            ),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.blueButton,
                  side: const BorderSide(color: AppColors.blueButton),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Not now',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();

                  // TODO: arahkan ke halaman upgrade kamu
                  // Contoh (sesuaikan route app kamu):
                  Navigator.of(context).pushNamed('/subscription');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blueButton,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Upgrade',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          );
        },
      );
    }

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
                            const _FieldLabel('Business Logo'),
                            const SizedBox(height: 8),
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
                            const SizedBox(height: 16),

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

                            InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: isFreePlan
                                  ? _showUpgradeToPremiumDialog
                                  : null,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Row(
                                    children: const [
                                      Expanded(
                                        child: Text(
                                          'Allow selling products with zero stock',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      // ✅ badge SELALU tampil (free/premium)
                                      _PremiumInlineBadge(),
                                    ],
                                  ),
                                  subtitle: const Padding(
                                    padding: EdgeInsets.only(top: 6),
                                    child: Text(
                                      'When enabled, products can be sold even if their stock is zero. Inventory may go negative after sales.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.disabledFg,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                  trailing: IgnorePointer(
                                    ignoring:
                                        isFreePlan, // ✅ free plan: switch tidak bisa diubah
                                    child: Switch.adaptive(
                                      value:
                                          switchValue, // ✅ free plan: selalu ON
                                      onChanged: isFreePlan
                                          ? null
                                          : (v) async {
                                              setState(
                                                () => _allowOutOfStock = v,
                                              );

                                              final prefs =
                                                  await SharedPreferences.getInstance();
                                              await prefs.setBool(
                                                'activeBizCanSellOutOfStock',
                                                v,
                                              );

                                              final activeId =
                                                  (prefs.getString(
                                                            'activeBizId',
                                                          ) ??
                                                          '')
                                                      .trim();

                                              // update snapshot business_full
                                              try {
                                                final rawFull = prefs.getString(
                                                  'business_full',
                                                );
                                                if (rawFull != null &&
                                                    rawFull.isNotEmpty &&
                                                    activeId.isNotEmpty) {
                                                  final list =
                                                      (jsonDecode(rawFull)
                                                              as List)
                                                          .cast<
                                                            Map<String, dynamic>
                                                          >();
                                                  bool changed = false;
                                                  for (final b in list) {
                                                    if ((b['idBusiness'] ?? '')
                                                            .toString() ==
                                                        activeId) {
                                                      b['canSellOutOfStock'] =
                                                          v;
                                                      b['canBeSoldOutOfStock'] =
                                                          v;
                                                      b['can_be_sold_out_of_stock'] =
                                                          v;
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
                                                final rawBiz = prefs.getString(
                                                  'business',
                                                );
                                                if (rawBiz != null &&
                                                    rawBiz.isNotEmpty &&
                                                    activeId.isNotEmpty) {
                                                  final list =
                                                      (jsonDecode(rawBiz)
                                                              as List)
                                                          .cast<
                                                            Map<String, dynamic>
                                                          >();
                                                  bool changed = false;
                                                  for (final b in list) {
                                                    if ((b['idBusiness'] ?? '')
                                                            .toString() ==
                                                        activeId) {
                                                      b['canSellOutOfStock'] =
                                                          v;
                                                      b['canBeSoldOutOfStock'] =
                                                          v;
                                                      b['can_be_sold_out_of_stock'] =
                                                          v;
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
                                  ),
                                ),
                              ),
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

class _PremiumInlineBadge extends StatelessWidget {
  const _PremiumInlineBadge({this.compact = true});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final padH = compact ? 8.0 : 10.0;
    final padV = compact ? 4.0 : 5.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF6366F1), Color(0xFF22C55E)],
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.14),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.gem, size: 13, color: Colors.white),
          if (!compact) ...[
            const SizedBox(width: 6),
            const Text(
              'Premium',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ],
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
    const double avatarSize = 108;
    final hasPicked = pickedFile != null;
    final hasCurrent = currentLogoUrl.trim().isNotEmpty;
    final hasImage = hasPicked || hasCurrent;

    Widget avatarContent;
    if (hasPicked) {
      avatarContent = Image.file(
        pickedFile!,
        fit: BoxFit.cover,
        width: avatarSize,
        height: avatarSize,
      );
    } else if (hasCurrent) {
      avatarContent = Image.network(
        currentLogoUrl,
        fit: BoxFit.cover,
        width: avatarSize,
        height: avatarSize,
        errorBuilder: (ctx, err, st) => _fallbackAvatar(avatarSize),
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return Stack(
            alignment: Alignment.center,
            children: [
              _fallbackAvatar(avatarSize),
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded /
                            (progress.expectedTotalBytes ?? 1)
                      : null,
                ),
              ),
            ],
          );
        },
      );
    } else {
      avatarContent = _fallbackAvatar(avatarSize);
    }

    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.greyBackground, width: 2),
                ),
                child: ClipOval(child: avatarContent),
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onPick,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.blueButton,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.blueButton.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        color: AppColors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
              if (hasImage)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: hasPicked ? onRemovePicked : onClearCurrent,
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: AppColors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: onPick,
            child: Text(
              hasImage ? 'Change logo' : 'Add logo',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.blueButton,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackAvatar(double size) {
    return Container(
      color: AppColors.greyBackground,
      width: size,
      height: size,
      alignment: Alignment.center,
      child: Text(
        fallbackInitial,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: AppColors.blueButton,
          fontSize: 32,
        ),
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
