class PremiumPlan {
  final String idPlan;
  final String name;
  final int price;
  final int months;
  final bool isActive;

  PremiumPlan({
    required this.idPlan,
    required this.name,
    required this.price,
    required this.months,
    required this.isActive,
  });

  factory PremiumPlan.fromJson(Map<String, dynamic> json) {
    return PremiumPlan(
      idPlan: json['idPlan']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: json['price'] is int
          ? json['price'] as int
          : int.tryParse(json['price'].toString()) ?? 0,
      months: json['months'] is int
          ? json['months'] as int
          : int.tryParse(json['months'].toString()) ?? 0,
      isActive: json['isActive'] == true,
    );
  }
}
