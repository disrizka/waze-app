import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/providers/link_register_provider.dart';

class LinkRegisterSuccessStep extends StatelessWidget {
  const LinkRegisterSuccessStep({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<LinkRegisterProvider>();
    final name = p.joinedBusinessName ?? 'Your Business';
    final logo = p.joinedBusinessLogo;

    Widget logoWidget() {
      if (logo != null && logo.isNotEmpty && !logo.startsWith('http')) {
        return Image.asset(
          logo,
          width: 84,
          height: 84,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _BusinessInitials(name: name),
        );
      }
      if (logo != null && logo.startsWith('http')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.network(
            logo,
            width: 84,
            height: 84,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _BusinessInitials(name: name),
          ),
        );
      }
      return _BusinessInitials(name: name);
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF42A5F5), // biru muda
              Color(0xFF2DD4BF),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
            child: Column(
              children: [
                const Spacer(),
                logoWidget(),
                const SizedBox(height: 16),
                const Text(
                  'Congratulations!',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "You're successfully registered and joined",
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Color(0xFF42A5F5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).pushNamedAndRemoveUntil('/login', (r) => false);
                    },
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text(
                      'Start using Wave',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BusinessInitials extends StatelessWidget {
  const _BusinessInitials({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .take(2)
        .map((e) => e[0].toUpperCase())
        .join();

    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white38),
      ),
      alignment: Alignment.center,
      child: Text(
        initials.isEmpty ? 'B' : initials,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}
