import 'package:image_picker/image_picker.dart';

import 'product_photo.dart';

/// Mobile/desktop picker via image_picker.
Future<List<ProductPhoto>> pickProductPhotos({required int remaining}) async {
  if (remaining <= 0) return const [];

  final picker = ImagePicker();
  final files = <XFile>[];

  if (remaining == 1) {
    final one = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 72,
    );
    if (one != null) files.add(one);
  } else {
    files.addAll(
      await picker.pickMultiImage(
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 72,
        limit: remaining,
      ),
    );
  }

  final photos = <ProductPhoto>[];
  for (final file in files.take(remaining)) {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) continue;
    photos.add(
      ProductPhoto(
        bytes: bytes,
        mimeType: file.mimeType ?? 'image/jpeg',
        name: file.name,
      ),
    );
  }
  return photos;
}
