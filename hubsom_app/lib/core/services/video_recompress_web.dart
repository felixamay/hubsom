import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'product_demo_video.dart';

/// Re-encode a clip at ~800 kbps so Ghana-speed links can start in seconds.
Future<ProductDemoVideo?> recompressShopVideoForSlowNetwork({
  required Uint8List bytes,
  required String mimeType,
}) async {
  if (bytes.length < 400 * 1024) return null;
  try {
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: mimeType.isEmpty ? 'video/mp4' : mimeType),
    );
    final url = web.URL.createObjectURL(blob);
    final video = web.HTMLVideoElement()
      ..muted = true
      ..preload = 'auto'
      ..playsInline = true
      ..src = url;
    video.setAttribute('playsinline', 'true');

    await _once(video, 'loadedmetadata').timeout(const Duration(seconds: 8));
    if (video.duration.isNaN || video.duration <= 0) {
      web.URL.revokeObjectURL(url);
      return null;
    }

    await video.play().toDart;
    final stream = video.captureStream();
    final mime = _recorderMime();
    if (mime == null) {
      video.pause();
      web.URL.revokeObjectURL(url);
      return null;
    }

    final recorder = web.MediaRecorder(
      stream,
      web.MediaRecorderOptions(
        mimeType: mime,
        videoBitsPerSecond: 800000,
        audioBitsPerSecond: 48000,
      ),
    );
    final chunks = <web.Blob>[];
    final done = Completer<void>();
    recorder.addEventListener(
      'dataavailable',
      (web.Event event) {
        final e = event as web.BlobEvent;
        if (e.data.size > 0) chunks.add(e.data);
      }.toJS,
    );
    recorder.addEventListener(
      'stop',
      (web.Event _) {
        if (!done.isCompleted) done.complete();
      }.toJS,
    );
    recorder.addEventListener(
      'error',
      (web.Event _) {
        if (!done.isCompleted) {
          done.completeError(StateError('MediaRecorder failed'));
        }
      }.toJS,
    );

    recorder.start();
    await video.play().toDart;
    await _once(video, 'ended').timeout(
      Duration(milliseconds: ((video.duration + 1) * 1000).round()),
    );
    if (recorder.state == 'recording') recorder.stop();
    await done.future.timeout(const Duration(seconds: 8));
    video.pause();
    web.URL.revokeObjectURL(url);
    if (chunks.isEmpty) return null;

    final outBlob = web.Blob(chunks.toJS, web.BlobPropertyBag(type: mime));
    final buffer = await outBlob.arrayBuffer().toDart;
    final out = buffer.toDart.asUint8List();
    if (out.isEmpty || out.length >= bytes.length) return null;
    return ProductDemoVideo(
      bytes: Uint8List.fromList(out),
      mimeType: mime.split(';').first,
      durationSeconds: video.duration,
    );
  } catch (_) {
    return null;
  }
}

String? _recorderMime() {
  const candidates = <String>[
    'video/mp4',
    'video/webm;codecs=vp8,opus',
    'video/webm;codecs=vp8',
    'video/webm',
  ];
  for (final mime in candidates) {
    try {
      if (web.MediaRecorder.isTypeSupported(mime)) return mime;
    } catch (_) {}
  }
  return null;
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
