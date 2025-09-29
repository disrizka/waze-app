import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/providers/link_register_provider.dart';

class LinkRegisterPasswordStep extends StatelessWidget {
  const LinkRegisterPasswordStep({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<LinkRegisterProvider>();
    final primary = const Color(0xFF426FD4);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InviteInfo(email: p.inviteEmail),
          const SizedBox(height: 12),

          // Password
          TextFormField(
            controller: p.passwordC,
            obscureText: p.obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter a strong password',
              suffixIcon: IconButton(
                icon: Icon(
                  p.obscurePassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () =>
                    context.read<LinkRegisterProvider>().toggleObscure(),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: p.validatePassword,
            autovalidateMode: AutovalidateMode.onUserInteraction,
          ),
          const SizedBox(height: 12),

          // Confirm
          TextFormField(
            controller: p.confirmC,
            obscureText: p.obscurePassword,
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              hintText: 'Retype your password',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: p.validateConfirm,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onFieldSubmitted: (_) => _handleContinue(context),
          ),
          const SizedBox(height: 20),

          // Continue
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => _handleContinue(context),
              child: const Text(
                'Continue',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleContinue(BuildContext context) {
    FocusScope.of(context).unfocus();
    final p = context.read<LinkRegisterProvider>();
    final err = p.onContinuePasswordStep();
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }
}

class _InviteInfo extends StatelessWidget {
  const _InviteInfo({required this.email});
  final String email;

  @override
  Widget build(BuildContext context) {
    final textColor = const Color(0xFF111827);
    final subColor = const Color(0xFF6B7280);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F9FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          const Icon(Icons.mark_email_unread_rounded),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: DefaultTextStyle.of(context).style.copyWith(height: 1.4),
                children: [
                  TextSpan(
                    text: 'You are accepting an invitation for\n',
                    style: TextStyle(color: subColor),
                  ),
                  TextSpan(
                    text: email,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
