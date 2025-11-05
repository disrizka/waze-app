import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:wa_blast/providers/change_password_provider.dart';
import 'forgot_shared.dart';
import 'forgot_step1_screen.dart';
import 'forgot_step2_screen.dart';
import 'forgot_step3_screen.dart';
import 'forgot_stepper_line.dart'; // <— tambahkan ini

class ForgotPasswordWrapperScreen extends StatefulWidget {
  static const routeName = '/auth/forgot/wrapper';
  final String? initialEmail;

  const ForgotPasswordWrapperScreen({super.key, this.initialEmail});

  @override
  State<ForgotPasswordWrapperScreen> createState() =>
      _ForgotPasswordWrapperScreenState();
}

class _ForgotPasswordWrapperScreenState
    extends State<ForgotPasswordWrapperScreen> {
  int _step = 0; // 0: email, 1: otp, 2: new password
  String? _email;
  String? _otp;

  final stepLabels = const ['Email', 'Verify OTP', 'New Password'];

  @override
  void initState() {
    super.initState();
    _email = widget.initialEmail;
  }

  void _goBack() {
    if (_step > 0) {
      setState(() => _step--);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _onEmailSubmitted(String email, {String? otpFromServer}) {
    setState(() {
      _email = email.trim();
      _otp = otpFromServer;
      _step = 1;
    });
  }

  void _onOtpSubmitted(String otp) {
    setState(() {
      _otp = otp.trim();
      _step = 2;
    });
  }

  void _onPasswordResetDone() {
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final title = _step == 0
        ? 'Forgot Password'
        : _step == 1
        ? 'Verify Your Email'
        : 'Create New Password';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: _goBack,
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: Colors.black87,
        ),
        title: Text(title, style: const TextStyle(color: Colors.black87)),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ChangeNotifierProvider.value(
          value: context.read<ChangePasswordProvider>(),
          child: Column(
            children: [
              // ===== Stepper Line tepat di bawah AppBar =====
              StepperLine(currentStep: _step, steps: stepLabels),
              // ===== Konten tiap step =====
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _step == 0
                      ? ForgotStep1Screen(
                          key: const ValueKey('step1'),
                          initialEmail: _email,
                          onNext: _onEmailSubmitted,
                        )
                      : _step == 1
                      ? ForgotStep2Screen(
                          key: const ValueKey('step2'),
                          email: _email!,
                          initialOtp: _otp,
                          onNext: _onOtpSubmitted,
                        )
                      : ForgotStep3Screen(
                          key: const ValueKey('step3'),
                          email: _email!,
                          otp: _otp ?? '',
                          onDone: _onPasswordResetDone,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
