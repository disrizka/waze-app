part of '../../providers/purchase_provider.dart';

/// Entitas purchase/order
class PurchaseItem {
  final String idTransaction; // <-- NEW
  final String code;
  final DateTime time;
  final String supplierName;
  final String note;
  final int quantity;
  final int totalAmount;
  // kalau kamu sudah hapus status di UI, biarkan properti ini tetap ada atau hapus sekalian.
  final PurchaseStatus status;

  // Detail (tetap)
  final String servicedByName;
  final String servicedById;
  final String servicedByAvatarUrl;
  final double serviceFeePercent;
  final List<OrderLine> lines;

  const PurchaseItem({
    required this.idTransaction, // <-- NEW (wajib diisi)
    required this.code,
    required this.time,
    required this.supplierName,
    required this.note,
    required this.quantity,
    required this.totalAmount,
    required this.status,
    required this.servicedByName,
    required this.servicedById,
    required this.servicedByAvatarUrl,
    required this.serviceFeePercent,
    required this.lines,
  });

  // ...
  PurchaseItem copyWith({
    String? idTransaction, // <-- NEW
    String? code,
    DateTime? time,
    String? supplierName,
    String? note,
    int? quantity,
    int? totalAmount,
    PurchaseStatus? status,
    String? servicedByName,
    String? servicedById,
    String? servicedByAvatarUrl,
    double? serviceFeePercent,
    List<OrderLine>? lines,
  }) {
    return PurchaseItem(
      idTransaction: idTransaction ?? this.idTransaction, // <-- NEW
      code: code ?? this.code,
      time: time ?? this.time,
      supplierName: supplierName ?? this.supplierName,
      note: note ?? this.note,
      quantity: quantity ?? this.quantity,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      servicedByName: servicedByName ?? this.servicedByName,
      servicedById: servicedById ?? this.servicedById,
      servicedByAvatarUrl: servicedByAvatarUrl ?? this.servicedByAvatarUrl,
      serviceFeePercent: serviceFeePercent ?? this.serviceFeePercent,
      lines: lines ?? this.lines,
    );
  }
}
