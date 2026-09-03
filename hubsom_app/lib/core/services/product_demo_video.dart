import 'dart:typed_data';

/// A short product demo clip (max 15 seconds).
class ProductDemoVideo {
  const ProductDemoVideo({
    required this.bytes,
    required this.mimeType,
    required this.durationSeconds,
    this.name = 'demo.mp4',
  });

  final Uint8List bytes;
  final String mimeType;
  final double durationSeconds;
  final String name;
}
