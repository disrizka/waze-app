import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/providers/link_register_provider.dart';
import 'package:wa_blast/screens/register/link/link_success_step.dart';

import 'link_register_password_step.dart';
import 'link_register_details_step.dart';
import 'link_register_welcome_step.dart';

class LinkRegisterStepperWrapper extends StatelessWidget {
  const LinkRegisterStepperWrapper({
    super.key,
    required this.inviteEmail,
    required this.inviteToken,
    this.businessName, // <- opsional dari link
    this.businessLogo, // <- opsional (asset path / url)
    this.inviteRoleName, // <- ✅ role undangan dari preview
  });

  final String inviteEmail;
  final String inviteToken;
  final String? businessName;
  final String? businessLogo;
  final String? inviteRoleName; // ✅ NEW

  Color get _primary => const Color(0xFF426FD4);
  Color get _lineInactive => const Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LinkRegisterProvider(
        inviteEmail: inviteEmail,
        inviteToken: inviteToken,
        inviteBusinessName: businessName,
        inviteBusinessLogo: businessLogo,
        inviteRoleName: inviteRoleName, // ✅ pass role ke provider
      ),
      child: Builder(
        builder: (context) {
          final p = context.watch<LinkRegisterProvider>();
          final steps = const ['Password', 'Details'];

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
                  ),
          );
        },
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
  });

  final List<String> steps;
  final Color primary;
  final Color lineInactive;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<LinkRegisterProvider>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Create Account'),
        centerTitle: false,
        automaticallyImplyLeading: false,
        leading: p.currentStep == 1
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
                child: p.currentStep == 0
                    ? const LinkRegisterPasswordStep(
                        key: ValueKey('PasswordStep'),
                      )
                    : const LinkRegisterDetailsStep(
                        key: ValueKey('DetailsStep'),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
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
