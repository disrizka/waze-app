import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/hr_provider.dart';

class LeaveDaysScreen extends StatelessWidget {
  const LeaveDaysScreen({super.key, required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    final hr = context.watch<HrProvider>();
    final employee = hr.getByIndex(index);
    if (employee == null) {
      return const Scaffold(
        body: Center(child: Text('Employee tidak ditemukan')),
      );
    }

    final remaining = hr.leaveBalance(employee.name); // Work Leave Allowance
    final used = hr.usedLeaveAllowance(employee.name); // Used Leave Allowance
    final history = hr.leaveHistory(employee.name); // List<LeaveDay>

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        title: const Text(
          'Leave Days',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  value: '$remaining Days',
                  caption: 'Work Leave Allowance',
                  icon: Icons.description_outlined,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatCard(
                  value: '$used Days',
                  caption: 'Used Leave Allowance',
                  icon: Icons.description_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF4463FF), width: 1.4),
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              foregroundColor: const Color(0xFF4463FF),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/hr/leave-days/request',
                arguments: {'index': index},
              );
            },
            child: const Text('Request Leave Days'),
          ),
          const SizedBox(height: 20),
          const _SectionTitle('History'),
          const SizedBox(height: 8),

          // HISTORY LIST
          ...List.generate(history.length, (i) {
            final item =
                history[history.length - 1 - i]; // render terbaru di atas
            final seq = (history.length - i).toString().padLeft(3, '0');
            return _HistoryTile(
              title: 'Leave Days - $seq',
              subtitle: item.status == 'Approved' || item.status == 'Accepted'
                  ? 'Your request was accepted'
                  : 'Your request is ${item.status.toLowerCase()}',
              timeLabel: '19:00 PM', // dummy sesuai desain
              status: (item.status == 'Approved') ? 'Accepted' : item.status,
            );
          }),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.caption,
    required this.icon,
  });

  final String value;
  final String caption;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF4463FF).withOpacity(.18),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: const Color(0xFF4463FF)),
          ),
          const SizedBox(height: 18),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            caption,
            style: TextStyle(
              color: const Color(0xFF334155).withOpacity(.8),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: Color(0xFF111827),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.title,
    required this.subtitle,
    required this.timeLabel,
    required this.status,
  });

  final String title;
  final String subtitle;
  final String timeLabel;
  final String status;

  @override
  Widget build(BuildContext context) {
    final green = const Color(0xFF16A34A);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF4463FF).withOpacity(.9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.description_outlined, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: const Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                timeLabel,
                style: TextStyle(
                  color: const Color(0xFF6B7280),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: (status == 'Accepted') ? green : Colors.grey,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
