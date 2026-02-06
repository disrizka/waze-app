part of '../../providers/product_provider.dart';

@immutable
class NewSku {
  final String code;
  final int price;
  final List<NewSkuAttribute> attributes;
  const NewSku({
    required this.code,
    required this.price,
    this.attributes = const [],
  });

  Map<String, dynamic> toJson() => {
    'code': code,
    'price': price,
    'attributes': attributes.map((e) => e.toJson()).toList(),
  };
}
