import 'dart:typed_data';

/// A short shop / product clip (shop videos allow up to 2 minutes).
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
