import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/hr_provider.dart';

class ReimbursementScreen extends StatelessWidget {
  const ReimbursementScreen({super.key, required this.index});
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

    final history = hr.reimbursementHistory(employee.name);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        title: const Text(
          'Reimbursement',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
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
                '/hr/reimbursement/request',
                arguments: {
                  'index': index,
                }, // pastikan ReimbursementScreen punya index
              );
            },
            child: const Text('Request Reimbursement'),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          const Text(
            'History',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),

          ...List.generate(history.length, (i) {
            final item = history[history.length - 1 - i]; // terbaru di atas
            final seq = (history.length - i).toString().padLeft(3, '0');
            return _HistoryTile(
              title: 'Reimbursement - $seq',
              subtitle: 'Your request was accepted',
              timeLabel: '19:00 PM', // dummy sesuai desain
              status: item.status == 'Paid' ? 'Accepted' : item.status,
            );
          }),
        ],
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
            child: const Icon(Icons.payments_outlined, color: Colors.white),
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
