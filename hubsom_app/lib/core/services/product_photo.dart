import 'dart:typed_data';

class ProductPhoto {
  const ProductPhoto({
    required this.bytes,
    required this.mimeType,
    this.name = 'photo.jpg',
  });

  final Uint8List bytes;
  final String mimeType;
  final String name;
}
