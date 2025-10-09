import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/providers/link_register_provider.dart';
import 'package:wa_blast/screens/register/link/link_success_step.dart';

import 'link_register_password_step.dart';
import 'link_register_details_step.dart';
import 'link_register_welcome_step.dart';
import 'link_register_login_step.dart';

class LinkRegisterStepperWrapper extends StatefulWidget {
  const LinkRegisterStepperWrapper({
    super.key,
    required this.inviteEmail,
    required this.inviteToken,
    this.businessName,
    this.businessLogo,
    this.inviteRoleName,

    /// Kondisi #2: hanya Welcome + LoginStep
    this.loginOnlyFlow =
        false, // ⬅️ ADD (default false supaya tidak ubah alur existing)
  });

  final String inviteEmail;
  final String inviteToken;
  final String? businessName;
  final String? businessLogo;
  final String? inviteRoleName;
  final bool loginOnlyFlow; // ⬅️ ADD

  @override
  State<LinkRegisterStepperWrapper> createState() =>
      _LinkRegisterStepperWrapperState();
}

class _LinkRegisterStepperWrapperState
    extends State<LinkRegisterStepperWrapper> {
  bool _popGuard = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _popGuard = false);
    });
  }

  Color get _primary => const Color(0xFF426FD4);
  Color get _lineInactive => const Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LinkRegisterProvider(
        inviteEmail: widget.inviteEmail,
        inviteToken: widget.inviteToken,
        inviteBusinessName: widget.businessName,
        inviteBusinessLogo: widget.businessLogo,
        inviteRoleName: widget.inviteRoleName,
        // kalau provider kamu butuh tahu mode ini, bisa ditambahkan field opsional juga
      ),
      child: WillPopScope(
        onWillPop: () async => !_popGuard,
        child: Builder(
          builder: (context) {
            final p = context.watch<LinkRegisterProvider>();

            // ===== Step titles tergantung mode =====
            final steps = widget.loginOnlyFlow
                ? const ['Login'] // di UI stepper hanya 1 (setelah Welcome)
                : const ['Password', 'Details'];

            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (currentChild, previousChildren) => Stack(
                children: [
                  ...previousChildren,
                  if (currentChild != null) currentChild,
                ],
              ),
              transitionBuilder: (child, animation) {
                final key = (child.key is ValueKey)
                    ? (child.key as ValueKey).value
                    : '';
                final slideIn = (key == 'stepper' || key == 'success');
                final offsetAnim = Tween<Offset>(
                  begin: slideIn ? const Offset(0.08, 0) : Offset.zero,
                  end: Offset.zero,
                ).animate(animation);

                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: offsetAnim, child: child),
                );
              },
              child: p.showWelcome
                  ? const _WelcomeStage(key: ValueKey('welcome'))
                  : p.completed
                  ? const _SuccessStage(key: ValueKey('success'))
                  : _StepperStage(
                      key: const ValueKey('stepper'),
                      steps: steps,
                      primary: _primary,
                      lineInactive: _lineInactive,
                      loginOnlyFlow: widget.loginOnlyFlow, // ⬅️ ADD
                    ),
            );
          },
        ),
      ),
    );
  }
}

class _WelcomeStage extends StatelessWidget {
  const _WelcomeStage({super.key});
  @override
  Widget build(BuildContext context) => const LinkRegisterWelcomeStep();
}

class _SuccessStage extends StatelessWidget {
  const _SuccessStage({super.key});
  @override
  Widget build(BuildContext context) => const LinkRegisterSuccessStep();
}

class _StepperStage extends StatelessWidget {
  const _StepperStage({
    super.key,
    required this.steps,
    required this.primary,
    required this.lineInactive,
    required this.loginOnlyFlow, // ⬅️ ADD
  });

  final List<String> steps;
  final Color primary;
  final Color lineInactive;
  final bool loginOnlyFlow; // ⬅️ ADD

  @override
  Widget build(BuildContext context) {
    final p = context.watch<LinkRegisterProvider>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(loginOnlyFlow ? 'Login to Continue' : 'Create Account'),
        centerTitle: false,
        automaticallyImplyLeading: false,
        leading: p.currentStep == 1 || loginOnlyFlow
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () {
                  context.read<LinkRegisterProvider>().prevStep();
                },
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            _StepLine(
              total: steps.length,
              currentIndex: p.currentStep,
              activeColor: primary,
              inactiveColor: lineInactive,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Step ${p.currentStep + 1} of ${steps.length}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text(
                    steps[p.currentStep],
                    style: const TextStyle(color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: _buildStepContent(context, p),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent(BuildContext context, LinkRegisterProvider p) {
    if (loginOnlyFlow) {
      // ===== Kondisi #2: hanya LoginStep =====
      return LinkRegisterLoginStep(
        key: const ValueKey('LoginStep'),
        inviteEmail: p.inviteEmail,
        inviteToken: p.inviteToken,
      );
    }

    // ===== Flow default: Password → Details (seperti existing)
    switch (p.currentStep) {
      case 0:
        return const LinkRegisterPasswordStep(key: ValueKey('PasswordStep'));
      default:
        return const LinkRegisterDetailsStep(key: ValueKey('DetailsStep'));
    }
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine({
    required this.total,
    required this.currentIndex,
    required this.activeColor,
    required this.inactiveColor,
  });

  final int total;
  final int currentIndex;
  final Color activeColor;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(total, (i) {
          final isActive = i <= currentIndex;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(
                left: i == 0 ? 0 : 4,
                right: i == total - 1 ? 0 : 4,
              ),
              height: 6,
              decoration: BoxDecoration(
                color: isActive ? activeColor : inactiveColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          );
        }),
      ),
    );
  }
}
