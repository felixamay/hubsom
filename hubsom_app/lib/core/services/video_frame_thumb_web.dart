import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Grab a JPEG still from in-memory clip bytes (a section of the video).
Future<Uint8List?> captureShopVideoFrame({
  required Uint8List bytes,
  required String mimeType,
}) async {
  if (bytes.length < 64) return null;
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType.isEmpty ? 'video/mp4' : mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  try {
    return await captureShopVideoFrameFromUrl(url);
  } finally {
    web.URL.revokeObjectURL(url);
  }
}

/// Seek ~10% into [url] and draw that frame to a JPEG.
Future<Uint8List?> captureShopVideoFrameFromUrl(String url) async {
  final src = url.trim();
  if (src.isEmpty) return null;
  final video = web.HTMLVideoElement()
    ..muted = true
    ..preload = 'auto'
    ..playsInline = true
    ..crossOrigin = 'anonymous'
    ..src = src;
  video.setAttribute('playsinline', 'true');
  video.setAttribute('crossorigin', 'anonymous');
  try {
    await _once(video, 'loadedmetadata').timeout(const Duration(seconds: 8));
    final duration = video.duration;
    final target = (!duration.isNaN && duration.isFinite && duration > 0)
        ? (duration * 0.12).clamp(0.12, 1.4)
        : 0.2;
    try {
      await video.play().toDart;
      video.pause();
    } catch (_) {}
    video.currentTime = target.toDouble();
    await _once(video, 'seeked').timeout(const Duration(seconds: 6));

    final rawW = video.videoWidth == 0 ? 360 : video.videoWidth;
    final rawH = video.videoHeight == 0 ? 640 : video.videoHeight;
    final scale = rawW > 480 ? 480 / rawW : 1.0;
    final w = (rawW * scale).round().clamp(1, 1280);
    final h = (rawH * scale).round().clamp(1, 1920);
    final canvas = web.HTMLCanvasElement()
      ..width = w
      ..height = h;
    canvas.context2D.drawImage(
      video,
      0,
      0,
      w.toDouble(),
      h.toDouble(),
    );
    final blob = await _canvasJpeg(canvas);
    if (blob == null || blob.size <= 0) return null;
    final buffer = await blob.arrayBuffer().toDart;
    final out = buffer.toDart.asUint8List();
    return out.isEmpty ? null : Uint8List.fromList(out);
  } catch (_) {
    return null;
  } finally {
    video.removeAttribute('src');
    video.load();
  }
}

Future<web.Blob?> _canvasJpeg(web.HTMLCanvasElement canvas) {
  final done = Completer<web.Blob?>();
  canvas.toBlob(
    (web.Blob blob) {
      if (!done.isCompleted) done.complete(blob);
    }.toJS,
    'image/jpeg',
    0.74.toJS,
  );
  return done.future.timeout(
    const Duration(seconds: 4),
    onTimeout: () => null,
  );
}

Future<void> _once(web.EventTarget target, String type) {
  final done = Completer<void>();
  late final JSFunction handler;
  handler = (web.Event _) {
    target.removeEventListener(type, handler);
    if (!done.isCompleted) done.complete();
  }.toJS;
  target.addEventListener(type, handler);
  return done.future;
}
