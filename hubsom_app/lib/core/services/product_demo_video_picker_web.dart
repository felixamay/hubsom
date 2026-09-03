import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'product_demo_video.dart';

/// Browser file picker for a short product demo video.
Future<ProductDemoVideo?> pickProductDemoVideo({int maxSeconds = 15}) async {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'video/mp4,video/webm,video/quicktime,video/*';
  input.style.display = 'none';
  web.document.body?.append(input);

  final completer = Completer<ProductDemoVideo?>();

  void finish(ProductDemoVideo? video) {
    input.remove();
    if (!completer.isCompleted) completer.complete(video);
  }

  input.addEventListener(
    'change',
    (web.Event _) {
      () async {
        try {
          final files = input.files;
          if (files == null || files.length == 0) {
            finish(null);
            return;
          }
          final file = files.item(0);
          if (file == null) {
            finish(null);
            return;
          }
          final type = file.type.toLowerCase();
          if (type.isNotEmpty && !type.startsWith('video/')) {
            finish(null);
            return;
          }
          if (file.size > 12 * 1024 * 1024) {
            throw StateError(
              'Video is too large. Use a clip under about 12MB (max $maxSeconds seconds).',
            );
          }

          final duration = await _readDurationSeconds(file);
          if (duration <= 0) {
            throw StateError('Could not read that video. Try MP4 or WebM.');
          }
          if (duration > maxSeconds + 0.25) {
            throw StateError(
              'Video must be $maxSeconds seconds or shorter (yours is ${duration.toStringAsFixed(1)}s).',
            );
          }

          final buffer = await file.arrayBuffer().toDart;
          final bytes = buffer.toDart.asUint8List();
          if (bytes.isEmpty) {
            finish(null);
            return;
          }
          finish(
            ProductDemoVideo(
              bytes: Uint8List.fromList(bytes),
              mimeType: type.isEmpty ? 'video/mp4' : type,
              durationSeconds: duration,
              name: file.name,
            ),
          );
        } catch (e) {
          if (!completer.isCompleted) {
            completer.completeError(e);
          }
          input.remove();
        }
      }();
    }.toJS,
  );

  input.addEventListener(
    'cancel',
    (web.Event _) {
      finish(null);
    }.toJS,
  );

  Future<void>.delayed(const Duration(minutes: 2), () {
    if (!completer.isCompleted) finish(null);
  });

  input.click();
  return completer.future;
}

Future<double> _readDurationSeconds(web.File file) async {
  final url = web.URL.createObjectURL(file);
  final video = web.HTMLVideoElement()
    ..preload = 'metadata'
    ..src = url;

  final done = Completer<double>();
  void cleanup() {
    try {
      web.URL.revokeObjectURL(url);
    } catch (_) {}
  }

  video.addEventListener(
    'loadedmetadata',
    (web.Event _) {
      if (!done.isCompleted) {
        final d = video.duration;
        done.complete(d.isFinite ? d : 0);
      }
      cleanup();
    }.toJS,
  );
  video.addEventListener(
    'error',
    (web.Event _) {
      if (!done.isCompleted) done.complete(0);
      cleanup();
    }.toJS,
  );

  return done.future.timeout(
    const Duration(seconds: 12),
    onTimeout: () {
      cleanup();
      return 0;
    },
  );
}
