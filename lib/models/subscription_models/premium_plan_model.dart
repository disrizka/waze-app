// lib/models/premium_plan_model.dart

import 'package:flutter/foundation.dart';

@immutable
class PremiumPlan {
  final String idPlan;
  final String name;
  final bool isActive;

  /// List harga/durasi untuk plan ini
  final List<PlanPricing> pricing;

  const PremiumPlan({
    required this.idPlan,
    required this.name,
    required this.isActive,
    this.pricing = const [],
  });

  factory PremiumPlan.fromJson(Map<String, dynamic> json) {
    final List<dynamic> pricingJson = json['pricing'] as List<dynamic>? ?? [];

    return PremiumPlan(
      idPlan: (json['idPlan'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      isActive: json['isActive'] as bool? ?? false,
      pricing: pricingJson
          .map((e) => PlanPricing.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'idPlan': idPlan,
      'name': name,
      'isActive': isActive,
      'pricing': pricing.map((e) => e.toJson()).toList(),
    };
  }

  // OPTIONAL: supaya kode lama yang masih pakai months/price nggak langsung rusak
  // Misal, anggap pricing[0] sebagai default
  int get months {
    if (pricing.isEmpty) return 0;
    return pricing.first.period;
  }

  double get price {
    if (pricing.isEmpty) return 0;
    return pricing.first.price.toDouble();
  }
}

/// Model untuk 1 opsi harga di dalam sebuah plan
@immutable
class PlanPricing {
  final String id;

  /// Durasi dalam bulan (3, 6, 12, dst)
  final int period;

  /// Harga dalam rupiah
  final int price;

  const PlanPricing({
    required this.id,
    required this.period,
    required this.price,
  });

  factory PlanPricing.fromJson(Map<String, dynamic> json) {
    return PlanPricing(
      id: (json['id'] ?? '').toString(),
      period: (json['period'] ?? 0) as int,
      price: (json['price'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'period': period, 'price': price};
  }
}
