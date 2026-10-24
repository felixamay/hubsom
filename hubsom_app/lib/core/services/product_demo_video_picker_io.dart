import 'package:image_picker/image_picker.dart';

import 'product_demo_video.dart';

/// Mobile/desktop gallery picker for a short product demo video.
Future<ProductDemoVideo?> pickProductDemoVideo({int maxSeconds = 15}) async {
  final picker = ImagePicker();
  final file = await picker.pickVideo(
    source: ImageSource.gallery,
    maxDuration: Duration(seconds: maxSeconds),
  );
  if (file == null) return null;

  final bytes = await file.readAsBytes();
  if (bytes.isEmpty) return null;
  if (bytes.lengthInBytes > 12 * 1024 * 1024) {
    throw StateError(
      'Video is too large. Use a clip under about 12MB (max $maxSeconds seconds).',
    );
  }

  // image_picker enforces maxDuration on supported platforms; treat as ≤ max.
  return ProductDemoVideo(
    bytes: bytes,
    mimeType: file.mimeType ?? 'video/mp4',
    durationSeconds: maxSeconds.toDouble(),
    name: file.name,
  );
}
