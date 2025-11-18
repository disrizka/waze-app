import 'dart:io';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wa_blast/providers/auth_provider.dart';

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
          onPressed: () => Navigator.pop(context, {'tab': 'settings'}),
        ),
        title: const Text(
          'Account',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          // Tombol Save ke prefs (tetap dipertahankan)
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
                            .submitEditProfile(context);
                        if (!context.mounted) return;

                        if (ok) {
                          // ✅ REFRESH DATA TERBARU
                          final auth = context.read<AuthProvider>();
                          final prefs = await SharedPreferences.getInstance();

                          // Kunci active id saat ini
                          final lockedId =
                              (prefs.getString('activeBizId') ?? '').trim();
                          debugPrint(
                            '🔐 [BusinessEdit] lockedId="$lockedId" before refresh',
                          );

                          // Jalankan refresh profil/user yang juga memuat ulang daftar bisnis di prefs
                          final refreshed = await auth.refreshCurrentUser(
                            context,
                          );
                          debugPrint(
                            '♻️ [BusinessEdit] refreshCurrentUser -> $refreshed',
                          );
                        }
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
                  p.isSaving ? 'Saving…' : 'Save Update',
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
                    // ====== NEW: Avatar Picker Circle (gaya sosmed) ======
                    const _AvatarPickerCircle(),
                    const SizedBox(height: 16),

                    // Email (read-only / disabled) — diletakkan setelah avatar
                    AccountField(
                      label: 'Email',
                      controller: p.emailC,
                      hint: 'Your Email',
                      keyboardType: TextInputType.emailAddress,
                      readOnly: true,
                      enabled: false, // <-- disabled UI
                    ),
                    // Username (editable)
                    AccountField(
                      label: 'Username',
                      controller: p.usernameC,
                      hint: 'Your Username',
                      keyboardType: TextInputType.text,
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
                    const SizedBox(height: 24),

                    // Danger zone di tengah layar (horizontal center)
                    Center(
                      child: _DangerZoneCard(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _startDeleteOrDeactivateEntry(context);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// =============================================================
/// AVATAR PICKER CIRCLE — dengan fallback icon manusia saat 404
/// =============================================================
class _AvatarPickerCircle extends StatelessWidget {
  const _AvatarPickerCircle();

  static const double _size = 108;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<EditProfileProvider>();
    final hasLocal = p.pickedPhotoFile != null;
    final url = (p.existingPhotoPath ?? '').trim();
    final hasUrl = url.isNotEmpty;

    Widget avatarContent;

    if (hasLocal) {
      // Foto lokal dipastikan ada
      avatarContent = Image.file(
        p.pickedPhotoFile!,
        fit: BoxFit.cover,
        width: _size,
        height: _size,
      );
    } else if (hasUrl) {
      // Foto dari server + fallback bila 404/invalid
      avatarContent = Image.network(
        url,
        fit: BoxFit.cover,
        width: _size,
        height: _size,
        // tampilkan placeholder icon jika gagal (mis. 404)
        errorBuilder: (ctx, err, st) => _placeholderIcon(),
        // optional: loading indicator halus
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return Stack(
            alignment: Alignment.center,
            children: [
              _placeholderIcon(),
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
      // Tidak ada foto sama sekali
      avatarContent = _placeholderIcon();
    }

    return Center(
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Lingkaran dengan border tipis
              Container(
                width: _size,
                height: _size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.greyBackground, width: 2),
                ),
                child: ClipOval(child: avatarContent),
              ),
              // Tombol edit kecil
              Positioned(
                bottom: -2,
                right: -2,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showAvatarActionSheet(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.blueButton,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.blueButton.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => _showAvatarActionSheet(context),
            child: const Text(
              'Change photo',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.blueButton,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Placeholder icon manusia bergaya sosmed
  Widget _placeholderIcon() {
    return Container(
      color: AppColors.greyBackground,
      width: _size,
      height: _size,
      alignment: Alignment.center,
      child: const Icon(Icons.person_rounded, size: 42, color: AppColors.grey),
    );
  }

  void _showAvatarActionSheet(BuildContext context) {
    final p = context.read<EditProfileProvider>();
    final hasImage =
        p.pickedPhotoFile != null || (p.existingPhotoPath ?? '').isNotEmpty;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text(
                  'Choose photo',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('Pick from gallery or files'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await p.pickLogo(); // provider kamu
                },
              ),
              if (hasImage)
                ListTile(
                  leading: const Icon(
                    Icons.delete_rounded,
                    color: AppColors.red,
                  ),
                  title: const Text(
                    'Remove photo',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.red,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    if (p.pickedPhotoFile != null) {
                      p.removePickedLogo();
                    } else {
                      p.existingPhotoPath = null;
                      p.notifyListeners();
                    }
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _DangerZoneCard extends StatelessWidget {
  final VoidCallback onTap;
  const _DangerZoneCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
        child: const Text(
          'Delete your account',
          style: TextStyle(
            color: AppColors.red,
            fontSize: 14,
            fontWeight: FontWeight.w500,
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

/// ====== (Legacy) Komponen lama — tidak lagi dipakai ======
/// Disisakan untuk referensi / jika nanti ingin pakai kembali.
class _LogoPicker extends StatelessWidget {
  const _LogoPicker();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<EditProfileProvider>();
    final hasFile = p.pickedPhotoFile != null;
    final hasUrl = (p.existingPhotoPath ?? '').isNotEmpty;

    const double boxHeight = 110;
    const Radius boxRadius = Radius.circular(12);

    // === STATE: ADA GAMBAR ===
    if (hasFile || hasUrl) {
      Widget image;
      if (hasFile) {
        image = Image.file(
          p.pickedPhotoFile!,
          width: double.infinity,
          height: boxHeight,
          fit: BoxFit.cover,
        );
      } else {
        image = Image.network(
          p.existingPhotoPath!,
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
                    prov.existingPhotoPath = null;
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
              const Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: 'Add your profile picture',
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
  final bool readOnly; // <-- tambahan
  final bool? enabled; // <-- tambahan (null = default true)

  const AccountField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.readOnly = false,
    this.enabled, // jika null => TextField default (enabled = true)
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = enabled ?? true;

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
            readOnly: readOnly,
            enabled: isEnabled,
            style: const TextStyle(
              fontSize: 15.5,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: hint,
              // Tambahkan style disabled agar jelas (opsional)
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppColors.greyBackground,
                  width: 1,
                ),
              ),
              filled: !isEnabled,
              fillColor: !isEnabled ? AppColors.greyBackground : null,
            ),
          ),
        ],
      ),
    );
  }
}

// =========================
// Dialog builders & flows
// =========================

// =========================
// Account delete/deactivate flow
// =========================

enum _Choice { delete, deactivate }

Future<void> _startDeleteOrDeactivateEntry(BuildContext context) async {
  final choice = await _showChoiceDialog(
    context,
    title: 'Account options',
    message:
        'Would you like to permanently delete your account or just deactivate it temporarily?',
    primaryLabel: 'Delete account',
    secondaryLabel: 'Deactivate account',
  );

  if (choice == null) return;

  if (choice == _Choice.delete) {
    // === DELETE: password → confirm → execute
    final password = await _showPasswordDialog(context);
    if (password == null || password.isEmpty) return;

    final confirm = await _showConfirmDialog(
      context,
      title: 'Confirm deletion',
      message:
          'Are you sure you want to permanently delete your account? This action cannot be undone.',
      yesLabel: 'Delete',
      noLabel: 'Cancel',
      destructive: false,
    );
    if (confirm == true) {
      await _executeDelete(context, password);
    }
  } else {
    // === DEACTIVATE: password → confirm → execute (dibuat sama seperti delete)
    final password = await _showPasswordDialog(context);
    if (password == null || password.isEmpty) return;

    final confirm = await _showConfirmDialog(
      context,
      title: 'Deactivate account?',
      message:
          'Are you sure you want to deactivate your account? You can log in again later to reactivate it.',
      yesLabel: 'Deactivate',
      noLabel: 'Cancel',
      destructive: false,
    );
    if (confirm == true) {
      await _executeDeactivate(context, password);
    }
  }
}

/// dialog: pilih delete vs deactivate
Future<_Choice?> _showChoiceDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String primaryLabel,
  required String secondaryLabel,
}) async {
  return showDialog<_Choice>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Dialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // header
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.disabledFg,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Column(
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(_Choice.delete),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.red,
                    foregroundColor: AppColors.white,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    primaryLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(_Choice.deactivate),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blueButton,
                    foregroundColor: AppColors.white,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    secondaryLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// dialog: input password
Future<String?> _showPasswordDialog(BuildContext context) async {
  final controller = TextEditingController();
  bool showPassword = false;
  String? errorText;

  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Dialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Confirm your password',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(null),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Please enter your password to continue.',
                  style: TextStyle(fontSize: 14, color: AppColors.disabledFg),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                obscureText: !showPassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter your password',
                  errorText: errorText,
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => showPassword = !showPassword),
                    icon: Icon(
                      showPassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final pass = controller.text.trim();
                        if (pass.isEmpty) {
                          setState(
                            () => errorText = 'Password cannot be empty.',
                          );
                          return;
                        }
                        Navigator.of(ctx).pop(pass);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blueButton,
                        foregroundColor: AppColors.white,
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'OK',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// dialog: konfirmasi yes/no
Future<bool?> _showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String yesLabel,
  required String noLabel,
  required bool destructive,
}) async {
  final yesColor = destructive ? AppColors.red : AppColors.blueButton;

  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Dialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.disabledFg,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.red,
                      foregroundColor: AppColors.white,
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      noLabel,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: yesColor,
                      foregroundColor: AppColors.white,
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      yesLabel,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

// ===== EXECUTION HELPERS =====

Future<void> _executeDelete(BuildContext context, String password) async {
  final auth = context.read<AuthProvider>();

  // Pegang root navigator SEBELUM await agar context-nya valid
  final rootNav = Navigator.of(context, rootNavigator: true);

  // Tampilkan loading di root
  showDialog(
    context: rootNav.context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (_) => _buildLoadingDialog('Deleting account…'),
  );

  // Eksekusi
  final ok = await auth.deleteAccountPermanently(context, password: password);

  // Tutup loading dengan navigator yang sama (aman meski stack berubah)
  if (rootNav.mounted) {
    try {
      await rootNav.maybePop();
    } catch (_) {
      /* ignore */
    }
  }

  if (!ok) {
    // optional: extra feedback di sini
  }
}

Future<void> _executeDeactivate(BuildContext context, String password) async {
  final auth = context.read<AuthProvider>();

  // Pegang root navigator SEBELUM await
  final rootNav = Navigator.of(context, rootNavigator: true);

  // Tampilkan loading di root
  showDialog(
    context: rootNav.context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (_) => _buildLoadingDialog('Deactivating account…'),
  );

  // Eksekusi
  final ok = await auth.deactivateAccount(context, password: password);

  // Tutup loading secara aman
  if (rootNav.mounted) {
    try {
      await rootNav.maybePop();
    } catch (_) {
      /* ignore */
    }
  }

  if (!ok) {
    // optional
  }
}

Widget _buildLoadingDialog(String text) {
  return Dialog(
    backgroundColor: AppColors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    ),
  );
}
