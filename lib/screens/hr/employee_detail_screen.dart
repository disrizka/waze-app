import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wa_blast/providers/hr_provider.dart';

class EmployeeDetailScreen extends StatelessWidget {
  const EmployeeDetailScreen({super.key, required this.employee});

  final EmployeeUser employee;

  static const _primary = Color(0xFF4C6EF5);

  @override
  Widget build(BuildContext context) {
    final fullName = employee.fullName.isNotEmpty
        ? employee.fullName
        : (employee.email.isNotEmpty ? employee.email : 'Unknown Employee');

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFC),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 220,
            foregroundColor: const Color(0xFF111827),
            backgroundColor: const Color(0xFFF9FAFC),
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: const Color(0xFFF9FAFC),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 64, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _buildAvatar(size: 76),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fullName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    employee.userRoleName.isNotEmpty
                                        ? employee.userRoleName
                                        : 'No role assigned',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _chip(
                              employee.isDeactivated ? 'Inactive' : 'Active',
                              employee.isDeactivated
                                  ? const Color(0xFFFFE5EA)
                                  : const Color(0xFFDFF7EA),
                              employee.isDeactivated
                                  ? const Color(0xFFD7263D)
                                  : const Color(0xFF11895B),
                            ),
                            _chip(
                              employee.hasPage
                                  ? 'Has Dashboard Access'
                                  : 'No Dashboard Access',
                              const Color(0xFFEAF0FF),
                              const Color(0xFF2B59D9),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                children: [
                  _detailCard(
                    title: 'Contact Information',
                    rows: [
                      _detailRow(
                        icon: Icons.email_rounded,
                        label: 'Email',
                        value: employee.email,
                        onCopy: employee.email.isNotEmpty
                            ? () => _copy(context, 'Email', employee.email)
                            : null,
                      ),
                      _detailRow(
                        icon: Icons.phone_rounded,
                        label: 'Phone',
                        value: employee.phone,
                        onCopy: employee.phone.isNotEmpty
                            ? () => _copy(context, 'Phone', employee.phone)
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _detailCard(
                    title: 'Account Information',
                    rows: [
                      _detailRow(
                        icon: Icons.person_rounded,
                        label: 'Username',
                        value: employee.username,
                      ),
                      _detailRow(
                        icon: Icons.badge_rounded,
                        label: 'Role',
                        value: employee.userRoleName,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar({double size = 44}) {
    final initials = _initialsFromName(
      employee.fullName.isNotEmpty
          ? employee.fullName
          : (employee.email.isNotEmpty ? employee.email : 'U'),
    );
    final url = employee.photoPath;

    if (url.isEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: const Color(0xFFE0E7FF),
        child: Text(
          initials,
          style: TextStyle(
            color: _primary,
            fontSize: size * 0.32,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFE0E7FF),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFD5DEFF)),
      ),
      child: ClipOval(
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Center(
            child: Text(
              initials,
              style: TextStyle(
                color: _primary,
                fontSize: size * 0.32,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _detailCard({
    required String title,
    required List<Widget> rows,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120E1A3A),
            blurRadius: 20,
            offset: Offset(0, 7),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...rows,
        ],
      ),
    );
  }

  Widget _detailRow({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onCopy,
    int maxLines = 1,
  }) {
    final safeValue = value.isNotEmpty ? value : '-';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF0FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: _primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  safeValue,
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (onCopy != null)
            IconButton(
              onPressed: onCopy,
              icon: const Icon(Icons.copy_rounded, size: 18),
              visualDensity: VisualDensity.compact,
              color: Colors.grey.shade700,
              tooltip: 'Copy',
            ),
        ],
      ),
    );
  }

  String _initialsFromName(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    final two = parts.take(2).map((e) => e[0].toUpperCase()).join();
    return two.isNotEmpty ? two : 'U';
  }

  Future<void> _copy(BuildContext context, String label, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied')),
    );
  }
}
