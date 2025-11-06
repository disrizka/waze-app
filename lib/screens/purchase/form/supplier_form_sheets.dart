// lib/screens/suppliers/supplier_form_sheet.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart'; // ⬅️ izin kamera on-demand
import 'package:provider/provider.dart';

import 'package:wa_blast/constants/app_colors.dart';
import 'package:wa_blast/models/supplier_model.dart';
import 'package:wa_blast/providers/purchase_provider.dart';
import 'package:wa_blast/widgets/reusable_pickers.dart';

/// ------------------------------
/// PUBLIC API
/// ------------------------------

/// Open bottom sheet to ADD a new supplier.
/// Return: `true` jika sukses, `false` jika gagal, `null` jika dibatalkan.
Future<bool?> showAddSupplierSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _SupplierFormSheet(mode: _FormMode.add),
  );
}

/// Open bottom sheet to EDIT an existing supplier.
/// Return: `true` jika sukses, `false` jika gagal, `null` jika dibatalkan.
Future<bool?> showEditSupplierSheet(
  BuildContext context, {
  required String supplierId,
}) async {
  final prov = context.read<PurchaseProvider>();
  await prov.fetchSupplierDetail(context, supplierId);
  final detail = prov.supplierDetail;
  if (detail == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Failed to load supplier detail: ${prov.supplierDetailError ?? ''}',
        ),
      ),
    );
    return null;
  }

  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _SupplierFormSheet(mode: _FormMode.edit, editing: detail),
  );
}

/// ------------------------------
/// INTERNAL WIDGETS
/// ------------------------------

enum _FormMode { add, edit }

class _SupplierFormSheet extends StatefulWidget {
  const _SupplierFormSheet({required this.mode, this.editing});

  final _FormMode mode;
  final Supplier? editing;

  @override
  State<_SupplierFormSheet> createState() => _SupplierFormSheetState();
}

class _SupplierFormSheetState extends State<_SupplierFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameC = TextEditingController();
  final _phoneC = TextEditingController();
  final _emailC = TextEditingController();
  final _addressC = TextEditingController();

  // state pengganti City ID input → pakai picker
  String? _cityId;
  String? _cityName;
  String? _provinceName;

  final ImagePicker _picker = ImagePicker();
  XFile? _picked; // new picked file
  String? _existingLogoUrl; // preview (edit mode)

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.mode == _FormMode.edit && widget.editing != null) {
      final s = widget.editing!;
      _nameC.text = s.name;
      _phoneC.text = s.phone ?? '';
      _emailC.text = s.email ?? '';
      _addressC.text = s.address ?? '';
      _existingLogoUrl = _resolveLogoUrl(s.logoPath);

      // Prefill city (jika ada)
      _cityId = s.city?.id;
      _cityName = s.city?.name;
      _provinceName = s.city?.province.name; // sesuaikan model
    }
  }

  @override
  void dispose() {
    _nameC.dispose();
    _phoneC.dispose();
    _emailC.dispose();
    _addressC.dispose();
    super.dispose();
  }

  // ====== CITY PICKER ======
  Future<void> _pickCity() async {
    final picked = await showCityPickerSheet(
      context,
      selectedId: _cityId, // langsung String
    );
    if (picked != null && mounted) {
      setState(() {
        _cityId = picked.id; // String
        _cityName = picked.label;
        _provinceName = picked.data?.province.name; // Province.name
      });
    }
  }

  // ====== CAMERA PERMISSION (on-demand) ======
  Future<bool> _ensureCameraPermission() async {
    try {
      final st = await Permission.camera.status;
      if (st.isGranted) return true;
      if (st.isPermanentlyDenied) {
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Camera permission is permanently denied. Enable it in Settings.',
            ),
          ),
        );
        return false;
      }
      final req = await Permission.camera.request();
      return req.isGranted;
    } catch (_) {
      return false;
    }
  }

  // ====== IMAGE PICK (gallery/camera) ======
  Future<XFile?> _pickOne(ImageSource source) async {
    if (source == ImageSource.camera) {
      final ok = await _ensureCameraPermission();
      if (!ok) return null;
    }
    return _picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 88,
      preferredCameraDevice: CameraDevice.rear,
    );
  }

  Future<void> _chooseImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 8, bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              subtitle: const Text('No extra permission needed'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      final picked = await _pickOne(source);
      if (picked != null) {
        setState(() {
          _picked = picked;
          _existingLogoUrl = null; // stop preview lama
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
    }
  }

  void _removeImage() {
    setState(() {
      _picked = null;
      if (widget.mode == _FormMode.edit) {
        _existingLogoUrl = _resolveLogoUrl(widget.editing?.logoPath);
      } else {
        _existingLogoUrl = null;
      }
    });
  }

  // ====== SUBMIT ======
  Future<void> _onSubmit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    final prov = context.read<PurchaseProvider>();
    setState(() => _submitting = true);

    try {
      final name = _nameC.text.trim();
      final phone = _phoneC.text.trim().isEmpty ? null : _phoneC.text.trim();
      final email = _emailC.text.trim().isEmpty ? null : _emailC.text.trim();
      final address = _addressC.text.trim().isEmpty
          ? null
          : _addressC.text.trim();
      final cityId = _cityId ?? '';
      if (cityId.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please select a city')));
        setState(() => _submitting = false);
        return;
      }

      bool ok = false;
      File? logoFile;
      if (_picked != null) logoFile = File(_picked!.path);

      if (widget.mode == _FormMode.add) {
        ok = await prov.addSupplier(
          context: context,
          name: name,
          logoFile: logoFile, // provider akan upload & set filename
          phone: phone,
          email: email,
          cityId: cityId,
          address: address,
        );
      } else {
        if (prov.respondsToUpdateSupplier) {
          ok = await prov.updateSupplier(
            context: context,
            idSupplier: widget.editing!.idSupplier,
            name: name,
            logoFile: logoFile, // null → pakai logo lama di server
            phone: phone,
            email: email,
            cityId: cityId,
            address: address,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Update supplier belum diimplementasi di provider'),
            ),
          );
          ok = false;
        }
      }

      if (!mounted) return;
      Navigator.pop(context, ok);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.mode == _FormMode.add
                  ? 'Supplier added successfully'
                  : 'Supplier updated successfully',
            ),
          ),
        );
      } else if (widget.mode == _FormMode.add) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(prov.supplierDetailError ?? 'Failed to add supplier'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              prov.supplierDetailError ?? 'Failed to update supplier',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final padBottom = MediaQuery.of(context).viewInsets.bottom;

    final title = (widget.mode == _FormMode.add)
        ? 'Add Supplier'
        : 'Edit Supplier';

    // tombol aktif kalau nama terisi; field lain optional/validasi lewat Form
    final isValid = _nameC.text.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: padBottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, controller) {
          return Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Form(
                    key: _formKey,
                    onChanged: () => setState(() {}),
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // LOGO
                        const Text(
                          'Logo',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _chooseImage,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 120,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF4C6EF5),
                                width: 2,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Builder(
                              builder: (_) {
                                if (_picked != null) {
                                  return Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.file(
                                        File(_picked!.path),
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, e, s) =>
                                            const _LogoPlaceholder(),
                                      ),
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: _closeBtn(_removeImage),
                                      ),
                                    ],
                                  );
                                }
                                if (_existingLogoUrl != null &&
                                    _existingLogoUrl!.isNotEmpty) {
                                  return Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.network(
                                        _existingLogoUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, e, s) =>
                                            const _LogoPlaceholder(),
                                      ),
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: _closeBtn(_removeImage),
                                      ),
                                    ],
                                  );
                                }
                                return const Center(
                                  child: Text(
                                    'Tap to upload logo',
                                    style: TextStyle(color: Colors.black54),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // NAME
                        const Text('Name', style: _labelStyle),
                        const SizedBox(height: 8),
                        _Field(
                          controller: _nameC,
                          hintText: 'PT Supplier ABC',
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                        const SizedBox(height: 16),

                        // PHONE
                        const Text('Phone', style: _labelStyle),
                        const SizedBox(height: 8),
                        _Field(
                          controller: _phoneC,
                          hintText: '081234567890',
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),

                        // EMAIL
                        const Text('Email', style: _labelStyle),
                        const SizedBox(height: 8),
                        _Field(
                          controller: _emailC,
                          hintText: 'supplier@abc.com',
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            final t = (v ?? '').trim();
                            if (t.isEmpty) return null; // optional
                            final ok = RegExp(
                              r'^[^@]+@[^@]+\.[^@]+$',
                            ).hasMatch(t);
                            return ok ? null : 'Invalid email';
                          },
                        ),
                        const SizedBox(height: 16),

                        // CITY (Picker)
                        FormField<String>(
                          initialValue: _cityId,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Required' : null,
                          builder: (ff) => SelectFieldTile(
                            label: 'City',
                            valueText: (_cityName == null)
                                ? null
                                : ((_provinceName ?? '').isEmpty
                                      ? _cityName
                                      : '$_cityName • $_provinceName'),
                            emptyHint: 'Select city',
                            errorText: ff.errorText,
                            onTap: () async {
                              final picked = await showCityPickerSheet(
                                context,
                                selectedId: _cityId,
                              );
                              if (picked != null && mounted) {
                                setState(() {
                                  _cityId = picked.id;
                                  _cityName = picked.label;
                                  _provinceName = picked.data?.province.name;
                                });
                                ff.didChange(_cityId);
                              }
                            },
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ADDRESS
                        const Text('Address', style: _labelStyle),
                        const SizedBox(height: 8),
                        _Field(
                          controller: _addressC,
                          hintText: 'Jl. Supplier No. 123',
                          keyboardType: TextInputType.streetAddress,
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),

              // FOOTER
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (isValid && !_submitting)
                          ? AppColors.primary
                          : const Color(0xFFE5E7EB),
                      foregroundColor: (isValid && !_submitting)
                          ? Colors.white
                          : const Color(0xFF9CA3AF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: (isValid && !_submitting) ? _onSubmit : null,
                    child: Text(
                      _submitting
                          ? 'Saving...'
                          : (widget.mode == _FormMode.add
                                ? 'Create supplier'
                                : 'Save changes'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _closeBtn(VoidCallback onTap) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
    ),
  );

  String? _resolveLogoUrl(String? logoPath) {
    if (logoPath == null || logoPath.isEmpty) return null;
    if (logoPath.startsWith('http')) return logoPath;
    const baseCdn = 'https://wave-cdn.eon.id'; // TODO: sesuaikan base CDN kamu
    return '$baseCdn${logoPath.startsWith('/') ? '' : '/'}$logoPath';
  }
}

/// ---------- UI Helpers ----------

const _labelStyle = TextStyle(
  fontWeight: FontWeight.w600,
  color: Color(0xFF111827),
);

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    this.hintText,
    this.keyboardType,
    this.validator,
    this.textInputAction,
    this.onSubmitted,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String? hintText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final void Function(String)? onSubmitted;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      maxLines: maxLines,
      decoration: InputDecoration(
        isDense: true,
        hintText: hintText,
        filled: true,
        fillColor: const Color(0xFFF3F4F6),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

class _LogoPlaceholder extends StatelessWidget {
  const _LogoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.image_not_supported_outlined,
        size: 32,
        color: Color(0xFF9CA3AF),
      ),
    );
  }
}
