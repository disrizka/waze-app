// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../providers/hr_provider.dart';

// class DetailEmployeeScreen extends StatelessWidget {
//   const DetailEmployeeScreen({super.key, required this.index});
//   final int index;

//   @override
//   Widget build(BuildContext context) {
//     final hr = context.watch<HrProvider>();
//     final employee = hr.getByIndex(index);

//     if (employee == null) {
//       return const _NotFound();
//     }

//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         elevation: 0,
//         backgroundColor: Colors.white,
//         foregroundColor: const Color(0xFF0F172A),
//         title: const Text(
//           'Detail Employee',
//           style: TextStyle(fontWeight: FontWeight.w800),
//         ),
//       ),
//       body: ListView(
//         padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
//         children: [
//           _HeaderCard(employee: employee),
//           const SizedBox(height: 20),
//           const Text(
//             'List Menu',
//             style: TextStyle(
//               fontSize: 18,
//               fontWeight: FontWeight.w800,
//               color: Color(0xFF0F172A),
//             ),
//           ),
//           const SizedBox(height: 12),
//           _MenuItem(
//             icon: Icons.description_outlined,
//             label: 'Leave Days',
//             onTap: () {
//               Navigator.pushNamed(
//                 context,
//                 '/hr/leave-days',
//                 arguments: {'index': index}, // pastikan index di-pass
//               );
//             },
//           ),
//           _MenuItem(
//             icon: Icons.sync_alt_rounded,
//             label: 'Reimbursement',
//             onTap: () {
//               Navigator.pushNamed(
//                 context,
//                 '/hr/reimbursement',
//                 arguments: {'index': index},
//               );
//             },
//           ),
//           _MenuItem(
//             icon: Icons.history_rounded,
//             label: 'History Leave Days',
//             onTap: () {
//               final list = hr.leaveHistory(employee.name);
//               _toast(context, 'Ada ${list.length} riwayat cuti');
//             },
//           ),
//           _MenuItem(
//             icon: Icons.receipt_long_outlined,
//             label: 'History Reimbursement',
//             onTap: () {
//               final list = hr.reimbursementHistory(employee.name);
//               _toast(context, 'Ada ${list.length} riwayat reimbursement');
//             },
//           ),
//         ],
//       ),
//     );
//   }

//   void _toast(BuildContext context, String msg) {
//     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
//   }
// }

// class _HeaderCard extends StatelessWidget {
//   const _HeaderCard({required this.employee});
//   final Employee employee;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(20),
//       ),
//       padding: const EdgeInsets.all(16),
//       child: Row(
//         children: [
//           CircleAvatar(
//             radius: 28,
//             backgroundImage: employee.avatarProvider,
//             backgroundColor: const Color(0xFFE2E8F0),
//           ),
//           const SizedBox(width: 16),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   employee.name,
//                   style: const TextStyle(
//                     fontSize: 22,
//                     fontWeight: FontWeight.w800,
//                   ),
//                 ),
//                 const SizedBox(height: 6),
//                 Text(
//                   'ID ${employee.id}',
//                   style: TextStyle(
//                     color: const Color(0xFF334155).withOpacity(.7),
//                     fontSize: 14,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   employee.checkInTime,
//                   style: TextStyle(
//                     color: const Color(0xFF64748B).withOpacity(.9),
//                     fontSize: 12,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           _OnlinePill(isOnline: employee.online),
//         ],
//       ),
//     );
//   }
// }

// class _OnlinePill extends StatelessWidget {
//   const _OnlinePill({required this.isOnline});
//   final bool isOnline;

//   @override
//   Widget build(BuildContext context) {
//     final green = const Color(0xFF16A34A);
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//       decoration: BoxDecoration(
//         color: isOnline ? green.withOpacity(.12) : Colors.grey.shade200,
//         borderRadius: BorderRadius.circular(999),
//       ),
//       child: Row(
//         children: [
//           Container(
//             width: 8,
//             height: 8,
//             decoration: BoxDecoration(
//               color: isOnline ? green : Colors.grey,
//               shape: BoxShape.circle,
//             ),
//           ),
//           const SizedBox(width: 6),
//           Text(
//             isOnline ? 'Online' : 'Offline',
//             style: TextStyle(
//               color: isOnline ? green : Colors.grey.shade600,
//               fontSize: 12,
//               fontWeight: FontWeight.w800,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _MenuItem extends StatelessWidget {
//   const _MenuItem({required this.icon, required this.label, this.onTap});

//   final IconData icon;
//   final String label;
//   final VoidCallback? onTap;

//   @override
//   Widget build(BuildContext context) {
//     return InkWell(
//       onTap: onTap,
//       borderRadius: BorderRadius.circular(14),
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
//         child: Row(
//           children: [
//             Container(
//               width: 44,
//               height: 44,
//               decoration: BoxDecoration(
//                 color: const Color(0xFF4463FF).withOpacity(.18),
//                 shape: BoxShape.circle,
//               ),
//               child: Icon(icon, size: 22, color: const Color(0xFF4463FF)),
//             ),
//             const SizedBox(width: 14),
//             Expanded(
//               child: Text(
//                 label,
//                 style: const TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.w700,
//                   color: Color(0xFF1F2937),
//                 ),
//               ),
//             ),
//             const Icon(Icons.chevron_right_rounded, color: Color(0xFF111827)),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _NotFound extends StatelessWidget {
//   const _NotFound();

//   @override
//   Widget build(BuildContext context) {
//     return const Scaffold(
//       body: Center(child: Text('Employee tidak ditemukan')),
//     );
//   }
// }
