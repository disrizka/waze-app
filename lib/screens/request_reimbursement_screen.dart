// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';
// import '../providers/hr_provider.dart';

// class RequestReimbursementScreen extends StatefulWidget {
//   const RequestReimbursementScreen({super.key, required this.index});
//   final int index;

//   @override
//   State<RequestReimbursementScreen> createState() =>
//       _RequestReimbursementScreenState();
// }

// class _RequestReimbursementScreenState
//     extends State<RequestReimbursementScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final _titleC = TextEditingController(text: 'Invoice Event 001');
//   final _amountC = TextEditingController(text: 'IDR 850.000');
//   final _accountC = TextEditingController(text: '998877665');
//   String _bank = 'BNI ( Bank Negara Indonesia )';
//   String? _attachmentName; // dummy attachment

//   final _banks = const [
//     'BNI ( Bank Negara Indonesia )',
//     'BCA ( Bank Central Asia )',
//     'BRI ( Bank Rakyat Indonesia )',
//     'Mandiri ( Bank Mandiri )',
//   ];

//   @override
//   void dispose() {
//     _titleC.dispose();
//     _amountC.dispose();
//     _accountC.dispose();
//     super.dispose();
//   }

//   String _onlyDigits(String s) => s.replaceAll(RegExp(r'[^\d]'), '');

//   String _formatIdr(String digits) {
//     final n = int.tryParse(digits) ?? 0;
//     final f = NumberFormat.currency(
//       locale: 'id_ID',
//       symbol: 'IDR ',
//       decimalDigits: 0,
//     );
//     return f.format(n);
//   }

//   void _onAmountChanged(String raw) {
//     final digits = _onlyDigits(raw);
//     _amountC
//       ..text = _formatIdr(digits)
//       ..selection = TextSelection.fromPosition(
//         TextPosition(offset: _amountC.text.length),
//       );
//     setState(() {});
//   }

//   void _pickAttachmentMock() {
//     setState(
//       () =>
//           _attachmentName = 'nota-${DateTime.now().millisecondsSinceEpoch}.jpg',
//     );
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(content: Text('Attachment selected (dummy)')),
//     );
//   }

//   void _submit() {
//     if (!_formKey.currentState!.validate()) return;

//     final hr = context.read<HrProvider>();
//     final emp = hr.getByIndex(widget.index);
//     if (emp == null) return;

//     final amountDigits = _onlyDigits(_amountC.text);
//     final amount = (int.tryParse(amountDigits) ?? 0).toDouble();

//     hr.requestReimbursement(
//       employeeName: emp.name,
//       title: _titleC.text.trim(),
//       amount: amount,
//       bank: _bank,
//       accountNumber: _accountC.text.trim(),
//       attachmentName: _attachmentName,
//     );

//     Navigator.pop(context); // kembali ke ReimbursementScreen
//     ScaffoldMessenger.of(
//       context,
//     ).showSnackBar(const SnackBar(content: Text('Reimbursement submitted')));
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         elevation: 0,
//         backgroundColor: Colors.white,
//         foregroundColor: const Color(0xFF0F172A),
//         title: const Text(
//           'Request Reimbursement',
//           style: TextStyle(fontWeight: FontWeight.w800),
//         ),
//       ),
//       body: Form(
//         key: _formKey,
//         child: ListView(
//           padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
//           children: [
//             const _Label('Title Reimbursement'),
//             TextFormField(
//               controller: _titleC,
//               decoration: _decoration(),
//               validator: (v) =>
//                   (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
//             ),
//             const SizedBox(height: 12),

//             const _Label('Total Amount'),
//             TextFormField(
//               controller: _amountC,
//               keyboardType: TextInputType.number,
//               inputFormatters: [
//                 FilteringTextInputFormatter.allow(RegExp(r'[0-9IDR\s.,]')),
//               ],
//               onChanged: _onAmountChanged,
//               decoration: _decoration(),
//               validator: (_) =>
//                   _onlyDigits(_amountC.text).isEmpty ? 'Wajib diisi' : null,
//             ),
//             const SizedBox(height: 12),

//             const _Label('Bank'),
//             DropdownButtonFormField<String>(
//               value: _bank,
//               items: _banks
//                   .map((e) => DropdownMenuItem(value: e, child: Text(e)))
//                   .toList(),
//               onChanged: (v) => setState(() => _bank = v ?? _bank),
//               decoration: _decoration(),
//             ),
//             const SizedBox(height: 12),

//             const _Label('Number Account Bank'),
//             TextFormField(
//               controller: _accountC,
//               keyboardType: TextInputType.number,
//               decoration: _decoration(),
//               validator: (v) =>
//                   (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
//             ),
//             const SizedBox(height: 16),

//             // Attachment dummy
//             InkWell(
//               onTap: _pickAttachmentMock,
//               borderRadius: BorderRadius.circular(12),
//               child: Container(
//                 padding: const EdgeInsets.all(16),
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.circular(12),
//                   border: Border.all(color: const Color(0xFFCBD5E1)),
//                 ),
//                 child: Row(
//                   children: [
//                     Container(
//                       width: 40,
//                       height: 40,
//                       decoration: BoxDecoration(
//                         color: const Color(0xFF4463FF).withOpacity(.18),
//                         shape: BoxShape.circle,
//                       ),
//                       child: const Icon(
//                         Icons.upload_rounded,
//                         color: Color(0xFF4463FF),
//                       ),
//                     ),
//                     const SizedBox(width: 14),
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             _attachmentName ?? 'Upload Attachment',
//                             overflow: TextOverflow.ellipsis,
//                             style: const TextStyle(
//                               fontWeight: FontWeight.w700,
//                               fontSize: 16,
//                               color: Color(0xFF3B82F6),
//                             ),
//                           ),
//                           const SizedBox(height: 6),
//                           const Text(
//                             'Format JPG, PNG',
//                             style: TextStyle(
//                               color: Color(0xFF94A3B8),
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),

//             const SizedBox(height: 24),
//             SizedBox(
//               height: 52,
//               child: ElevatedButton(
//                 onPressed: _submit,
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: const Color(0xFF3B5BDB),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   elevation: 0,
//                   foregroundColor: Colors.white,
//                   textStyle: const TextStyle(
//                     fontWeight: FontWeight.w700,
//                     fontSize: 16,
//                   ),
//                 ),
//                 child: const Text('Request Form'),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   InputDecoration _decoration() {
//     return const InputDecoration(
//       filled: true,
//       fillColor: Colors.white,
//       contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
//       border: OutlineInputBorder(
//         borderRadius: BorderRadius.all(Radius.circular(10)),
//         borderSide: BorderSide(color: Color(0xFFE5E7EB), width: 1.4),
//       ),
//       enabledBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.all(Radius.circular(10)),
//         borderSide: BorderSide(color: Color(0xFFE5E7EB), width: 1.4),
//       ),
//       focusedBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.all(Radius.circular(10)),
//         borderSide: BorderSide(color: Color(0xFF4C6EF5), width: 1.6),
//       ),
//     );
//   }
// }

// class _Label extends StatelessWidget {
//   const _Label(this.text);
//   final String text;
//   @override
//   Widget build(BuildContext context) => Padding(
//     padding: const EdgeInsets.only(bottom: 8),
//     child: Text(
//       text,
//       style: const TextStyle(
//         fontWeight: FontWeight.w800,
//         fontSize: 16,
//         color: Color(0xFF0F172A),
//       ),
//     ),
//   );
// }
