import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/providers/link_register_provider.dart';

class LinkRegisterDetailsStep extends StatelessWidget {
  const LinkRegisterDetailsStep({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<LinkRegisterProvider>();
    final primary = const Color(0xFF426FD4);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // First name
          TextFormField(
            controller: p.firstNameC,
            decoration: InputDecoration(
              labelText: 'First Name',
              hintText: 'Enter your first name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: p.validateRequired,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),

          // Last name
          TextFormField(
            controller: p.lastNameC,
            decoration: InputDecoration(
              labelText: 'Last Name',
              hintText: 'Enter your last name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: p.validateRequired,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleSubmit(context),
          ),
          const SizedBox(height: 20),

          // Submit
          SizedBox(
            height: 48,
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: p.submitting ? null : () => _handleSubmit(context),
              child: p.submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Create Your Account',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSubmit(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final p = context.read<LinkRegisterProvider>();
    final err = await p.submit();
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      // TODO: Navigate ke home/login sesuai kebutuhan
      // Navigator.of(context).pushReplacementNamed('/home');
    }
  }
}
