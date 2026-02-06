part of '../../providers/product_provider.dart';

@immutable
class NewImage {
  final String filename; // value from /file/upload -> data.filename
  final int position;
  const NewImage({required this.filename, required this.position});

  Map<String, dynamic> toJson() => {'image': filename, 'position': position};
}
