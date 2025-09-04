import 'dart:io';

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/edit_profile_provider.dart';

class EditProfileScreen extends StatelessWidget {
  static const routeName = '/edit-profile';

  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EditProfileProvider()..initFromPrefs(),
      child: const _EditProfileView(),
    );
  }
}

class _EditProfileView extends StatelessWidget {
  const _EditProfileView();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<EditProfileProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        titleSpacing: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pushReplacementNamed(context, '/splash'),
        ),
        title: const Text(
          'Account',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SizedBox(
              height: 28, // kecil & rapih
              child: TextButton(
                onPressed: p.isSaving
                    ? null
                    : () async {
                        final ok = await context
                            .read<EditProfileProvider>()
                            .saveToPrefs();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            content: Text(ok ? 'Saved' : 'Failed to save'),
                          ),
                        );
                      },
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
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    const blue = Color(0xFF4C6EF5); // biru cantik
                    if (states.contains(WidgetState.disabled)) {
                      return blue.withOpacity(0.5);
                    }
                    return blue;
                  }),
                  foregroundColor: WidgetStateProperty.all(Colors.white),
                  overlayColor: WidgetStateProperty.all(
                    Colors.white.withOpacity(0.12),
                  ),
                  elevation: WidgetStateProperty.all(0),
                ),
                child: Text(
                  p.isSaving ? 'Saving…' : 'Save',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: p.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AccountField(
                      label: 'Email',
                      controller: p.emailC,
                      hint: 'Your Email',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    AccountField(
                      label: 'Phone Number',
                      controller: p.phoneC,
                      hint: 'Your Phone Number',
                      keyboardType: TextInputType.phone,
                    ),
                    AccountField(
                      label: 'First Name',
                      controller: p.firstNameC,
                      hint: 'Your First Name',
                    ),
                    AccountField(
                      label: 'Last Name',
                      controller: p.lastNameC,
                      hint: 'Your Last Name',
                    ),
                    AccountField(
                      label: 'Business Name',
                      controller: p.businessNameC,
                      hint: 'Your Business Name',
                    ),
                    const SizedBox(height: 8),
                    _LogoPicker(),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  const _LabeledField({
    required this.label,
    required this.controller,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
    );
  }
}

class _LogoPicker extends StatelessWidget {
  const _LogoPicker();

  static const _blue = Color(0xFF4C6EF5);
  static const _blueSoft = Color(0xFFE8EDFF);

  @override
  Widget build(BuildContext context) {
    final p = context.watch<EditProfileProvider>();
    final hasFile = p.pickedLogoFile != null;
    final hasUrl = (p.existingLogoPath ?? '').isNotEmpty;

    // ukuran kotak (ikuti desain)
    const double boxHeight = 110;
    const Radius boxRadius = Radius.circular(12);

    // === STATE: ADA GAMBAR ===
    if (hasFile || hasUrl) {
      Widget image;
      if (hasFile) {
        image = Image.file(
          p.pickedLogoFile!,
          width: double.infinity,
          height: boxHeight,
          fit: BoxFit.cover,
        );
      } else {
        image = Image.network(
          p.existingLogoPath!,
          width: double.infinity,
          height: boxHeight,
          fit: BoxFit.cover,
          // fallback: icon kalau URL error
          errorBuilder: (ctx, err, st) => Container(
            width: double.infinity,
            height: boxHeight,
            color: Colors.grey[200],
            alignment: Alignment.center,
            child: const Icon(
              Icons.broken_image_rounded,
              size: 36,
              color: Colors.grey,
            ),
          ),
        );
      }

      return DottedBorder(
        options: const RoundedRectDottedBorderOptions(
          color: _blue,
          dashPattern: <double>[8, 6],
          strokeWidth: 2,
          radius: boxRadius,
          padding: EdgeInsets.all(0),
        ),
        child: Stack(
          children: [
            // gambar memenuhi kotak
            ClipRRect(
              borderRadius: BorderRadius.circular(boxRadius.x),
              child: image,
            ),
            // tombol silang
            Positioned(
              top: 6,
              right: 6,
              child: InkWell(
                onTap: () {
                  final prov = context.read<EditProfileProvider>();
                  if (hasFile) {
                    prov.removePickedLogo();
                  } else {
                    prov.existingLogoPath = null;
                    prov.notifyListeners();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // === STATE: KOSONG (sesuai screenshot) ===
    return DottedBorder(
      options: const RoundedRectDottedBorderOptions(
        color: _blue,
        dashPattern: <double>[8, 6],
        strokeWidth: 2,
        radius: boxRadius,
        padding: EdgeInsets.all(0),
      ),
      child: InkWell(
        onTap: () => context.read<EditProfileProvider>().pickLogo(),
        child: Container(
          height: boxHeight,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(boxRadius.x),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ikon tile
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _blueSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.file_upload_rounded,
                  color: _blue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              // teks
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text.rich(
                      TextSpan(
                        text: 'Add your logo Business',
                        style: TextStyle(fontWeight: FontWeight.w700),
                        children: [
                          TextSpan(
                            text: ' *',
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Format JPG, PNG',
                      style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
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
}

class LogoUploadBox extends StatelessWidget {
  final File? logo;
  final VoidCallback onChooseLogo;

  const LogoUploadBox({
    super.key,
    required this.logo,
    required this.onChooseLogo,
  });

  static const Color _blue = Color(0xFF4C6EF5);
  static const Color _blueSoft = Color(0xFFE8EDFF);
  static const Color _textGray = Color(0xFF374151);
  static const Color _hintGray = Color(0xFF9CA3AF);

  @override
  Widget build(BuildContext context) {
    return DottedBorder(
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
            // Preview / icon
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 52,
                height: 52,
                color: _blueSoft,
                child: logo == null
                    ? const Icon(
                        Icons.file_upload_rounded,
                        size: 22,
                        color: _blue,
                      )
                    : Image.file(logo!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 12),

            // Texts
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
                          text: logo == null
                              ? 'Add your organisation logo'
                              : 'Selected: ${logo!.path.split('/').last}',
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
              onPressed: onChooseLogo,
              child: const Text(
                'Upload',
                style: TextStyle(color: _blue, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AccountField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  const AccountField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 15.5, color: Color(0xFF111827)),
            decoration: InputDecoration(
              // cukup pakai theme di atas, tambah hint bila perlu
              hintText: hint,
            ),
          ),
        ],
      ),
    );
  }
}
