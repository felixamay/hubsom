import 'product_demo_video.dart';
import 'product_demo_video_picker_io.dart'
    if (dart.library.js_interop) 'product_demo_video_picker_web.dart' as impl;

export 'product_demo_video.dart';

/// Pick one product demo video, max [maxSeconds] long.
Future<ProductDemoVideo?> pickProductDemoVideo({int maxSeconds = 15}) =>
    impl.pickProductDemoVideo(maxSeconds: maxSeconds);
