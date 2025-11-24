import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/constants/app_colors.dart';
import 'package:wa_blast/l10n/app_localizations.dart';
import 'package:wa_blast/providers/auth_provider.dart';
import 'package:wa_blast/widgets/simple_web_view.dart';

class RegisterStep1Clean extends StatefulWidget {
  const RegisterStep1Clean({
    super.key,
    required this.onSuccessNext,
    this.onTapLogin,
    this.onSubStepChanged,
  });

  /// Dipanggil ketika semua sub-step selesai dan register step 1 sukses
  final VoidCallback onSuccessNext;

  final VoidCallback? onTapLogin;

  /// Dipakai RegisterWrapper untuk update progress bar utama.
  /// currentSubStep: 1..4, totalSubStep: 4
  final void Function(int currentSubStep, int totalSubStep)? onSubStepChanged;

  @override
  State<RegisterStep1Clean> createState() => _RegisterStep1CleanState();
}

class _RegisterStep1CleanState extends State<RegisterStep1Clean> {
  final _formKey = GlobalKey<FormState>();

  // controllers
  final _emailC = TextEditingController();
  final _firstNameC = TextEditingController();
  final _lastNameC = TextEditingController();
  final _passwordC = TextEditingController();
  final _confirmPasswordC = TextEditingController();

  bool _showPwd = false;

  // sub-step: 1..4 (Email, Name, Password, Confirm)
  int _currentStep = 1;
  static const int _totalSubSteps = 4;

  // Privacy agreement
  bool _agreePrivacy = false;

  // device & fcm
  String _deviceId = '';
  String _deviceName = '';
  String _fcmToken = '';
  bool _initDone = false;

  AppLocalizations get l10n => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _initDeviceAndFcm();

    // Beri tahu wrapper posisi awal sub-step (1/4)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onSubStepChanged?.call(_currentStep, _totalSubSteps);
    });
  }

  Future<void> _initDeviceAndFcm() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        _deviceId = a.id ?? '';
        _deviceName = '${a.manufacturer} ${a.model}'.trim();
      } else if (Platform.isIOS) {
        final i = await info.iosInfo;
        _deviceId = i.identifierForVendor ?? '';
        _deviceName = '${i.name} (${i.systemName} ${i.systemVersion})';
      } else {
        _deviceId = 'unknown_device';
        _deviceName = 'unknown';
      }
    } catch (_) {
      _deviceId = 'unknown_device';
      _deviceName = 'unknown';
    }

    try {
      _fcmToken = (await FirebaseMessaging.instance.getToken()) ?? '';
    } catch (_) {
      _fcmToken = '';
    }

    if (mounted) {
      setState(() => _initDone = true);
    }
  }

  @override
  void dispose() {
    _emailC.dispose();
    _firstNameC.dispose();
    _lastNameC.dispose();
    _passwordC.dispose();
    _confirmPasswordC.dispose();
    super.dispose();
  }

  OutlineInputBorder _border(Color c) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: c, width: 1),
  );

  void _goToStep(int step) {
    final newStep = step.clamp(1, _totalSubSteps);
    setState(() {
      _currentStep = newStep;
    });
    // kabari wrapper setiap kali sub-step berubah
    widget.onSubStepChanged?.call(_currentStep, _totalSubSteps);
  }

  bool _validateCurrentStep() {
    final form = _formKey.currentState;
    if (form == null) return false;
    return form.validate();
  }

  Future<void> _submitRegistration() async {
    if (!_initDone) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.register_step1_device_not_ready)),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final ok = await auth.registerStep1(
      email: _emailC.text.trim(),
      password: _passwordC.text,
      referralCode: '',
      deviceId: _deviceId,
      deviceName: _deviceName,
      fcmToken: _fcmToken,
      first_name: _firstNameC.text.trim(),
      last_name: _lastNameC.text.trim(),
    );

    if (!mounted) return;

    if (ok) {
      widget.onSuccessNext();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            auth.error ?? l10n.register_step1_registration_failed_default,
          ),
        ),
      );
    }
  }

  void _onPrimaryPressed() {
    if (!_validateCurrentStep()) return;

    if (_currentStep < _totalSubSteps) {
      // Pindah ke sub-step berikutnya (1 -> 2 -> 3 -> 4)
      _goToStep(_currentStep + 1);
    } else {
      // Final sub-step: wajib centang Privacy Policy
      if (!_agreePrivacy) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.register_step1_privacy_not_agreed_snackbar),
          ),
        );
        return;
      }

      _submitRegistration();
    }
  }

  String get _primaryButtonLabel {
    switch (_currentStep) {
      case 1:
      case 2:
      case 3:
        return l10n.register_step1_primary_continue;
      case 4:
      default:
        return l10n.register_step1_primary_create_account;
    }
  }

  String get _stepTitle {
    switch (_currentStep) {
      case 1:
        return l10n.register_step1_step1_title;
      case 2:
        return l10n.register_step1_step2_title;
      case 3:
        return l10n.register_step1_step3_title;
      case 4:
      default:
        return l10n.register_step1_step4_title;
    }
  }

  String get _stepDescription {
    switch (_currentStep) {
      case 1:
        return l10n.register_step1_step1_desc;
      case 2:
        return l10n.register_step1_step2_desc;
      case 3:
        return l10n.register_step1_step3_desc;
      case 4:
      default:
        return l10n.register_step1_step4_desc;
    }
  }

  // ------------------------
  // STEP CONTENTS
  // ------------------------
  Widget _buildEmailStep({
    required Color borderGray,
    required Color hintGray,
    required Color buttonBlue,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Text(
          _stepTitle,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          _stepDescription,
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 20),
        Text(
          l10n.register_step1_email_label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _emailC,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: l10n.register_step1_email_hint,
            hintStyle: TextStyle(color: hintGray),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            enabledBorder: _border(borderGray),
            focusedBorder: _border(buttonBlue),
            border: _border(borderGray),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) {
              return l10n.register_step1_email_required;
            }
            final ok = RegExp(r'^\S+@\S+\.\S+$').hasMatch(v.trim());
            if (!ok) return l10n.register_step1_email_invalid;
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildNameStep({
    required Color borderGray,
    required Color hintGray,
    required Color buttonBlue,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Text(
          _stepTitle,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          _stepDescription,
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 20),
        Text(
          l10n.register_step1_first_name_label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _firstNameC,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: l10n.register_step1_first_name_hint,
            hintStyle: TextStyle(color: hintGray),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            enabledBorder: _border(borderGray),
            focusedBorder: _border(buttonBlue),
            border: _border(borderGray),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) {
              return l10n.register_step1_first_name_required;
            }
            if (v.trim().length < 2) {
              return l10n.register_step1_first_name_min_length;
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        Text(
          l10n.register_step1_last_name_label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _lastNameC,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: l10n.register_step1_last_name_hint,
            hintStyle: TextStyle(color: hintGray),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            enabledBorder: _border(borderGray),
            focusedBorder: _border(buttonBlue),
            border: _border(borderGray),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) {
              return l10n.register_step1_last_name_required;
            }
            if (v.trim().length < 2) {
              return l10n.register_step1_last_name_min_length;
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPasswordStep({
    required Color borderGray,
    required Color hintGray,
    required Color buttonBlue,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Text(
          _stepTitle,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          _stepDescription,
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 20),

        // Password
        Text(
          l10n.register_step1_password_label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _passwordC,
          obscureText: !_showPwd,
          decoration: InputDecoration(
            hintText: l10n.register_step1_password_hint,
            hintStyle: TextStyle(color: hintGray, fontSize: 14),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            enabledBorder: _border(borderGray),
            focusedBorder: _border(buttonBlue),
            border: _border(borderGray),
            suffixIcon: IconButton(
              icon: Icon(
                _showPwd ? Icons.visibility_off : Icons.visibility,
                color: hintGray,
              ),
              onPressed: () => setState(() => _showPwd = !_showPwd),
            ),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) {
              return l10n.register_step1_password_required;
            }
            if (v.length < 8) {
              return l10n.register_step1_password_min_length;
            }
            final hasUpper = RegExp(r'[A-Z]').hasMatch(v);
            final hasLower = RegExp(r'[a-z]').hasMatch(v);
            final hasDigit = RegExp(r'[0-9]').hasMatch(v);
            final hasSpecial = RegExp(
              r'[!@#\$%^&*(),.?":{}|<>_\-]',
            ).hasMatch(v);

            if (!hasUpper || !hasLower || !hasDigit || !hasSpecial) {
              return l10n.register_step1_password_rule_not_satisfied;
            }
            return null;
          },
        ),

        const SizedBox(height: 12),

        // Confirm password (hanya validasi lokal, tidak disubmit)
        Text(
          l10n.register_step1_confirm_password_label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _confirmPasswordC,
          obscureText: !_showPwd,
          decoration: InputDecoration(
            hintText: l10n.register_step1_confirm_password_hint,
            hintStyle: TextStyle(color: hintGray, fontSize: 14),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            enabledBorder: _border(borderGray),
            focusedBorder: _border(buttonBlue),
            border: _border(borderGray),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) {
              return l10n.register_step1_confirm_password_required;
            }
            if (v != _passwordC.text) {
              return l10n.register_step1_confirm_password_not_match;
            }
            return null;
          },
        ),

        const SizedBox(height: 12),

        // Info box password rules
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PasswordInfoHeader(),
              const SizedBox(height: 6),
              _BulletText(l10n.register_step1_password_rule_8_chars),
              _BulletText(l10n.register_step1_password_rule_uppercase),
              _BulletText(l10n.register_step1_password_rule_lowercase),
              _BulletText(l10n.register_step1_password_rule_number),
              _BulletText(l10n.register_step1_password_rule_special),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmStep() {
    const buttonBlue = Color(0xFF4069E6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Text(
          _stepTitle,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          _stepDescription,
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            children: [
              _ConfirmRow(
                label: l10n.register_step1_email_label,
                value: _emailC.text.trim(),
              ),
              const SizedBox(height: 8),
              _ConfirmRow(
                label: l10n.register_step1_first_name_label,
                value: _firstNameC.text.trim(),
              ),
              const SizedBox(height: 8),
              _ConfirmRow(
                label: l10n.register_step1_last_name_label,
                value: _lastNameC.text.trim(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Checkbox + Privacy Policy link
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: _agreePrivacy,
                onChanged: (val) {
                  setState(() {
                    _agreePrivacy = val ?? false;
                  });
                },
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                activeColor: buttonBlue, // warna kotak saat dicentang
                checkColor: Colors.white, // warna centang
                side: const BorderSide(
                  // outline saat belum dicentang
                  color: AppColors.black,
                  width: 1.6,
                ),
              ),
            ),

            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                  children: [
                    TextSpan(
                      text: l10n.register_step1_privacy_checkbox_text_prefix,
                    ),
                    TextSpan(
                      text: l10n.register_step1_privacy_checkbox_link,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: buttonBlue,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => SimpleWebView(
                                initialUrl: 'https://wave.id/privacy-policy',
                                title: l10n.register_step1_privacy_policy_title,
                              ),
                            ),
                          );
                        },
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const borderGray = Color(0xFFE5E7EB);
    const hintGray = Color(0xFF9CA3AF);
    const buttonBlue = Color(0xFF4069E6);

    final loading = context.watch<AuthProvider>().isLoading;
    final isFinalStep = _currentStep == _totalSubSteps;

    // tombol disable kalau:
    // - lagi loading, atau
    // - di step final tapi belum centang privacy
    final bool disableButton =
        loading || (isFinalStep && _agreePrivacy == false);

    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('content-step1'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== STEP CONTENT =====
          if (_currentStep == 1)
            _buildEmailStep(
              borderGray: borderGray,
              hintGray: hintGray,
              buttonBlue: buttonBlue,
            )
          else if (_currentStep == 2)
            _buildNameStep(
              borderGray: borderGray,
              hintGray: hintGray,
              buttonBlue: buttonBlue,
            )
          else if (_currentStep == 3)
            _buildPasswordStep(
              borderGray: borderGray,
              hintGray: hintGray,
              buttonBlue: buttonBlue,
            )
          else
            _buildConfirmStep(),

          const SizedBox(height: 24),

          // ===== Primary Button (Continue / Create account) =====
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: disableButton ? null : _onPrimaryPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: isFinalStep && loading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _primaryButtonLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 8),

          // ===== Back text (hanya muncul di sub-step > 1, di bawah tombol, center) =====
          if (_currentStep > 1)
            Center(
              child: TextButton(
                onPressed: (isFinalStep && loading)
                    ? null
                    : () => _goToStep(_currentStep - 1),
                child: Text(
                  l10n.register_step1_back_button,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 16),

          // ===== Footer (hanya di sub-step 1) =====
          if (_currentStep == 1)
            Center(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    l10n.register_step1_footer_have_account,
                    style: const TextStyle(color: Colors.black87, fontSize: 13),
                  ),
                  InkWell(
                    onTap: widget.onTapLogin,
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                      child: Text(
                        // pakai l10n di atas? lebih gampang biar const, kita pakai di bawah
                        '',
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
}

/// Header info inside password helper box
class _PasswordInfoHeader extends StatelessWidget {
  const _PasswordInfoHeader();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: 18, color: Color(0xFF4069E6)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            l10n.register_step1_password_info_title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
        ),
      ],
    );
  }
}

/// Simple bullet text used under password rules
class _BulletText extends StatelessWidget {
  final String text;
  const _BulletText(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• '),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  final String label;
  final String value;

  const _ConfirmRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final displayedValue = (value.isEmpty) ? '-' : value;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            displayedValue,
            style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
          ),
        ),
      ],
    );
  }
}
