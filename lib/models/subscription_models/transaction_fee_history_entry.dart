part of '../../providers/subscription_provider.dart';

class TransactionFeeHistoryEntry {
  final String id;
  final String number;
  final int amount;
  final String status; // paid / etc
  final DateTime? createdAt;

  final String storeLocationName;
  final String cityName;

  final List<TransactionFeeHistoryLineItem> items;

  const TransactionFeeHistoryEntry({
    required this.id,
    required this.number,
    required this.amount,
    required this.status,
    required this.createdAt,
    required this.storeLocationName,
    required this.cityName,
    required this.items,
  });

  factory TransactionFeeHistoryEntry.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String? raw) {
      if (raw == null || raw.isEmpty) return null;
      try {
        return DateTime.parse(raw);
      } catch (_) {
        return null;
      }
    }

    final store = (json['store_location'] is Map)
        ? (json['store_location'] as Map)
        : null;

    final city = (store?['city'] is Map) ? (store?['city'] as Map) : null;

    final rawItems = (json['items'] is List)
        ? (json['items'] as List)
        : const [];
    final items = rawItems
        .whereType<Map>()
        .map(
          (e) =>
              TransactionFeeHistoryLineItem.fromJson(e.cast<String, dynamic>()),
        )
        .toList();

    return TransactionFeeHistoryEntry(
      id: json['id']?.toString() ?? '',
      number: json['number']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? '',
      createdAt: parseDate(json['created_at']?.toString()),
      storeLocationName: (store?['name'])?.toString() ?? '-',
      cityName: (city?['name'])?.toString() ?? '',
      items: items,
    );
  }
}
