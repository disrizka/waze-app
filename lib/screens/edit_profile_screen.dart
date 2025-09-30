import 'dart:io';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
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
          'Account',
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
                    if (states.contains(WidgetState.disabled)) {
                      return AppColors.blueButton.withOpacity(0.5);
                    }
                    return AppColors.blueButton;
                  }),
                  foregroundColor: WidgetStateProperty.all(AppColors.white),
                  overlayColor: WidgetStateProperty.all(
                    AppColors.white.withOpacity(0.12),
                  ),
                  elevation: WidgetStateProperty.all(0),
                ),
                child: Text(
                  p.isSaving ? 'Saving…' : 'Save',
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
                    const _LogoPicker(),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
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
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _LogoPicker extends StatelessWidget {
  const _LogoPicker();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<EditProfileProvider>();
    final hasFile = p.pickedLogoFile != null;
    final hasUrl = (p.existingLogoPath ?? '').isNotEmpty;

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
          errorBuilder: (ctx, err, st) => Container(
            width: double.infinity,
            height: boxHeight,
            color: AppColors.greyBackground,
            alignment: Alignment.center,
            child: const Icon(
              Icons.broken_image_rounded,
              size: 36,
              color: AppColors.grey,
            ),
          ),
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
                    color: AppColors.black.withOpacity(0.54),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: AppColors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // === STATE: KOSONG ===
    return DottedBorder(
      options: const RoundedRectDottedBorderOptions(
        color: AppColors.blueButton,
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
            color: AppColors.white,
            borderRadius: BorderRadius.circular(boxRadius.x),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.greyBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.file_upload_rounded,
                  color: AppColors.blueButton,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
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
}

class LogoUploadBox extends StatelessWidget {
  final File? logo;
  final VoidCallback onChooseLogo;

  const LogoUploadBox({
    super.key,
    required this.logo,
    required this.onChooseLogo,
  });

  @override
  Widget build(BuildContext context) {
    return DottedBorder(
      options: const RoundedRectDottedBorderOptions(
        color: AppColors.blueButton,
        dashPattern: <double>[8, 6],
        strokeWidth: 2,
        radius: Radius.circular(12),
        padding: EdgeInsets.all(0),
      ),
      child: Container(
        height: 110,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
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
                color: AppColors.greyBackground,
                child: logo == null
                    ? const Icon(
                        Icons.file_upload_rounded,
                        size: 22,
                        color: AppColors.blueButton,
                      )
                    : Image.file(logo!, fit: BoxFit.cover),
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
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      children: [
                        TextSpan(
                          text: logo == null
                              ? 'Add your organisation logo'
                              : 'Selected: ???',
                        ),
                        const TextSpan(
                          text: ' *',
                          style: TextStyle(color: AppColors.red),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Format JPG, PNG (maks 5–10MB)',
                    style: TextStyle(fontSize: 12, color: AppColors.disabledFg),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onChooseLogo,
              child: const Text(
                'Upload',
                style: TextStyle(
                  color: AppColors.blueButton,
                  fontWeight: FontWeight.w600,
                ),
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
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(
              fontSize: 15.5,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(hintText: hint),
          ),
        ],
      ),
    );
  }
}
