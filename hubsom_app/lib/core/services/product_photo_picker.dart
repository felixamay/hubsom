import 'product_photo.dart';
import 'product_photo_picker_io.dart'
    if (dart.library.js_interop) 'product_photo_picker_web.dart' as impl;

export 'product_photo.dart';

Future<List<ProductPhoto>> pickProductPhotos({required int remaining}) =>
    impl.pickProductPhotos(remaining: remaining);
