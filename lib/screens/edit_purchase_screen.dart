// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';
// import 'package:wa_blast/widgets/net_image_square.dart';
// import '../constants/app_colors.dart';
// import '../providers/purchase_provider.dart';

// class EditPurchaseScreen extends StatelessWidget {
//   final String code;
//   const EditPurchaseScreen({super.key, required this.code});

//   void _showAddProductSheet(BuildContext context, String code) {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: AppColors.white,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       builder: (ctx) {
//         final products = ctx.read<PurchaseProvider>().products;
//         final fMoney = NumberFormat.decimalPattern('id_ID');

//         return SafeArea(
//           child: Padding(
//             padding: EdgeInsets.only(
//               left: 16,
//               right: 16,
//               top: 12,
//               bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
//             ),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 // handle bar
//                 Container(
//                   width: 40,
//                   height: 4,
//                   margin: const EdgeInsets.only(bottom: 12),
//                   decoration: BoxDecoration(
//                     color: AppColors.divider,
//                     borderRadius: BorderRadius.circular(2),
//                   ),
//                 ),
//                 const Align(
//                   alignment: Alignment.centerLeft,
//                   child: Text(
//                     'List Product',
//                     style: TextStyle(
//                       fontSize: 16,
//                       fontWeight: FontWeight.w700,
//                       color: AppColors.textPrimary,
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 8),

//                 // daftar produk
//                 Flexible(
//                   child: ListView.separated(
//                     shrinkWrap: true,
//                     itemCount: products.length,
//                     separatorBuilder: (_, __) => const SizedBox(height: 14),
//                     itemBuilder: (_, i) {
//                       final p = products[i];
//                       return Row(
//                         crossAxisAlignment: CrossAxisAlignment.center,
//                         children: [
//                           const SizedBox(width: 2),
//                           NetImageSquare(url: p.imageUrl, size: 72),
//                           const SizedBox(width: 12),

//                           Expanded(
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Text(
//                                   p.name,
//                                   maxLines: 1,
//                                   overflow: TextOverflow.ellipsis,
//                                   style: const TextStyle(
//                                     fontWeight: FontWeight.w700,
//                                     fontSize: 16,
//                                     color: AppColors.textPrimary,
//                                   ),
//                                 ),
//                                 const SizedBox(height: 4),
//                                 Text(
//                                   'Rp. ${fMoney.format(p.price)}',
//                                   style: const TextStyle(
//                                     color: AppColors.textSecondary,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),

//                           // ====== Tombol Add / Added ======
//                           Selector<PurchaseProvider, int>(
//                             selector: (_, prov) =>
//                                 prov.getQtyForProduct(code, p.name),
//                             builder: (ctx2, qty, _) {
//                               final isAdded = qty > 0;
//                               return SizedBox(
//                                 width: 90,
//                                 height: 36,
//                                 child: ElevatedButton(
//                                   onPressed: isAdded
//                                       ? null // disabled ketika sudah ada
//                                       : () {
//                                           ctx2
//                                               .read<PurchaseProvider>()
//                                               .addProductToOrder(code, p);
//                                           ScaffoldMessenger.of(
//                                             ctx2,
//                                           ).showSnackBar(
//                                             SnackBar(
//                                               behavior:
//                                                   SnackBarBehavior.floating,
//                                               margin:
//                                                   const EdgeInsets.symmetric(
//                                                     horizontal: 16,
//                                                     vertical: 12,
//                                                   ),
//                                               shape: RoundedRectangleBorder(
//                                                 borderRadius:
//                                                     BorderRadius.circular(12),
//                                               ),
//                                               backgroundColor:
//                                                   AppColors.success,
//                                               content: Row(
//                                                 children: [
//                                                   const Icon(
//                                                     Icons.check_circle,
//                                                     color: AppColors.white,
//                                                   ),
//                                                   const SizedBox(width: 12),
//                                                   Expanded(
//                                                     child: Text(
//                                                       '${p.name} berhasil ditambahkan',
//                                                       style: const TextStyle(
//                                                         color: AppColors.white,
//                                                         fontWeight:
//                                                             FontWeight.w600,
//                                                       ),
//                                                     ),
//                                                   ),
//                                                 ],
//                                               ),
//                                               duration: const Duration(
//                                                 seconds: 2,
//                                               ),
//                                             ),
//                                           );
//                                         },
//                                   style: ElevatedButton.styleFrom(
//                                     backgroundColor: AppColors.blueButton,
//                                     foregroundColor: AppColors.white,
//                                     disabledBackgroundColor:
//                                         AppColors.disabledBg,
//                                     disabledForegroundColor:
//                                         AppColors.disabledFg,
//                                     elevation: 0,
//                                     shape: RoundedRectangleBorder(
//                                       borderRadius: BorderRadius.circular(10),
//                                     ),
//                                     padding: EdgeInsets.zero,
//                                   ),
//                                   child: Text(isAdded ? 'Added' : 'Add'),
//                                 ),
//                               );
//                             },
//                           ),
//                         ],
//                       );
//                     },
//                   ),
//                 ),

//                 const SizedBox(height: 16),
//                 SizedBox(
//                   width: double.infinity,
//                   height: 48,
//                   child: ElevatedButton(
//                     onPressed: () => Navigator.pop(ctx),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: AppColors.blueButton,
//                       foregroundColor: AppColors.white,
//                       elevation: 0,
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                     ),
//                     child: const Text(
//                       'Done',
//                       style: TextStyle(
//                         fontWeight: FontWeight.w600,
//                         fontSize: 16,
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final item = context.select<PurchaseProvider, PurchaseItem?>(
//       (p) => p.getByCode(code),
//     );
//     final fMoney = NumberFormat.decimalPattern('id_ID');

//     if (item == null) {
//       return Scaffold(
//         backgroundColor: AppColors.white,
//         appBar: AppBar(
//           title: const Text(
//             'Edit Order',
//             style: TextStyle(color: AppColors.textPrimary),
//           ),
//           backgroundColor: AppColors.white,
//           iconTheme: const IconThemeData(color: AppColors.black),
//         ),
//         body: const Center(
//           child: Text(
//             'Order tidak ditemukan',
//             style: TextStyle(color: AppColors.textPrimary),
//           ),
//         ),
//       );
//     }

//     return Scaffold(
//       backgroundColor: AppColors.white,
//       appBar: AppBar(
//         backgroundColor: AppColors.white,
//         title: const Text(
//           'Edit Order',
//           style: TextStyle(color: AppColors.textPrimary),
//         ),
//         leading: IconButton(
//           icon: const Icon(
//             Icons.arrow_back_ios_new_rounded,
//             color: AppColors.black,
//           ),
//           onPressed: () => Navigator.of(context).maybePop(),
//         ),
//       ),

//       body: ListView(
//         padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
//         children: [
//           const Text(
//             'Delivery order',
//             style: TextStyle(
//               fontWeight: FontWeight.w600,
//               color: AppColors.textSecondary,
//             ),
//           ),
//           const SizedBox(height: 6),
//           Row(
//             children: [
//               const Text(
//                 'Order number:',
//                 style: TextStyle(color: AppColors.disabledFg),
//               ),
//               const SizedBox(width: 8),
//               Text(
//                 item.code,
//                 style: const TextStyle(
//                   fontWeight: FontWeight.w600,
//                   color: AppColors.textSecondary,
//                 ),
//               ),
//               const SizedBox(width: 6),
//               IconButton(
//                 icon: const Icon(
//                   Icons.copy_rounded,
//                   size: 18,
//                   color: AppColors.disabledFg,
//                 ),
//                 padding: EdgeInsets.zero,
//                 onPressed: () {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(content: Text('Disalin: ${item.code}')),
//                   );
//                 },
//               ),
//             ],
//           ),
//           const SizedBox(height: 12),
//           const Divider(height: 1, color: AppColors.divider),

//           const SizedBox(height: 12),
//           Row(
//             children: [
//               const Expanded(
//                 child: Text(
//                   'Order summary',
//                   style: TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.w700,
//                     color: AppColors.textPrimary,
//                   ),
//                 ),
//               ),
//               TextButton(
//                 onPressed: () => _showAddProductSheet(context, code),
//                 child: const Text(
//                   'Add other products',
//                   style: TextStyle(
//                     color: AppColors.blueButton,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ),
//             ],
//           ),

//           // ======= Lines =======
//           Consumer<PurchaseProvider>(
//             builder: (context, prov, _) {
//               final current = prov.getByCode(code)!;

//               return Column(
//                 children: List.generate(current.lines.length, (i) {
//                   final l = current.lines[i];
//                   return Padding(
//                     padding: const EdgeInsets.symmetric(vertical: 10),
//                     child: Row(
//                       crossAxisAlignment: CrossAxisAlignment.center,
//                       children: [
//                         NetImageSquare(size: 64, url: l.imageUrl),
//                         const SizedBox(width: 12),
//                         Expanded(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 l.name,
//                                 style: const TextStyle(
//                                   fontWeight: FontWeight.w700,
//                                   fontSize: 16,
//                                   color: AppColors.textPrimary,
//                                 ),
//                                 maxLines: 1,
//                                 overflow: TextOverflow.ellipsis,
//                               ),
//                               const SizedBox(height: 4),
//                               Text(
//                                 'Rp. ${fMoney.format(l.price)}',
//                                 style: const TextStyle(
//                                   color: AppColors.textSecondary,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),

//                         // Stepper
//                         Row(
//                           children: [
//                             _RoundIconButton(
//                               icon: Icons.remove_rounded,
//                               onTap: () => prov.decrementLineQty(code, i),
//                             ),
//                             Padding(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 12,
//                               ),
//                               child: Text(
//                                 '${l.qty}',
//                                 style: const TextStyle(
//                                   fontWeight: FontWeight.w700,
//                                   fontSize: 16,
//                                   color: AppColors.textPrimary,
//                                 ),
//                               ),
//                             ),
//                             _RoundIconButton(
//                               icon: Icons.add_rounded,
//                               filled: true,
//                               onTap: () => prov.incrementLineQty(code, i),
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   );
//                 }),
//               );
//             },
//           ),

//           const SizedBox(height: 8),
//           const Divider(color: AppColors.divider),

//           // Totals (re-calc live via getters)
//           Consumer<PurchaseProvider>(
//             builder: (context, prov, _) {
//               final cur = prov.getByCode(code)!;
//               return Column(
//                 children: [
//                   _rowTotal('Subtotal', 'Rp ${fMoney.format(cur.subtotal)}'),
//                   _rowTotal(
//                     'Service Fee ${(cur.serviceFeePercent * 100).toStringAsFixed(0)}%',
//                     'Rp ${fMoney.format(cur.serviceFee)}',
//                   ),
//                   const SizedBox(height: 6),
//                   const Row(
//                     children: [
//                       Expanded(
//                         child: Text(
//                           'Total',
//                           style: TextStyle(
//                             fontWeight: FontWeight.w700,
//                             fontSize: 16,
//                             color: AppColors.textPrimary,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                   Row(
//                     children: [
//                       const Expanded(child: SizedBox()),
//                       Text(
//                         'Rp ${fMoney.format(cur.grandTotal)}',
//                         style: const TextStyle(
//                           fontWeight: FontWeight.w800,
//                           fontSize: 16,
//                           color: AppColors.textPrimary,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               );
//             },
//           ),
//         ],
//       ),

//       // Bottom fixed button
//       bottomNavigationBar: SafeArea(
//         minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
//         child: SizedBox(
//           width: double.infinity,
//           height: 48,
//           child: ElevatedButton(
//             onPressed: () {
//               ScaffoldMessenger.of(
//                 context,
//               ).showSnackBar(const SnackBar(content: Text('Order updated')));
//               Navigator.maybePop(context);
//             },
//             style: ElevatedButton.styleFrom(
//               backgroundColor: AppColors.blueButton,
//               foregroundColor: AppColors.white,
//               elevation: 0,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(12),
//               ),
//             ),
//             child: const Text(
//               'Update Order',
//               style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _rowTotal(String label, String value) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 6),
//       child: Row(
//         children: [
//           Expanded(
//             child: Text(
//               label,
//               style: const TextStyle(color: AppColors.textSecondary),
//             ),
//           ),
//           Text(value, style: const TextStyle(color: AppColors.textPrimary)),
//         ],
//       ),
//     );
//   }
// }

// class _RoundIconButton extends StatelessWidget {
//   final IconData icon;
//   final bool filled;
//   final VoidCallback onTap;

//   const _RoundIconButton({
//     required this.icon,
//     required this.onTap,
//     this.filled = false,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final bg = filled ? AppColors.blueButton : AppColors.disabledBg;
//     final fg = filled ? AppColors.white : AppColors.textSecondary;
//     return InkWell(
//       onTap: onTap,
//       borderRadius: BorderRadius.circular(20),
//       child: Container(
//         width: 32,
//         height: 32,
//         decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
//         alignment: Alignment.center,
//         child: Icon(icon, size: 18, color: fg),
//       ),
//     );
//   }
// }
