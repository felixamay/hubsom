import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

@JS('Hls')
extension type _Hls._(JSObject _) implements JSObject {
  external factory _Hls();
  external static bool isSupported();
  external void loadSource(String url);
  external void attachMedia(web.HTMLMediaElement media);
  external void destroy();
}

/// HLS session for a live viewer <video> element (Safari native, else hls.js).
class LiveHlsSession {
  LiveHlsSession._({required this.video, _Hls? hls}) : _hls = hls;

  final web.HTMLVideoElement video;
  final _Hls? _hls;

  void dispose() {
    try {
      _hls?.destroy();
    } catch (_) {}
    try {
      video.removeAttribute('src');
      video.load();
    } catch (_) {}
  }
}

bool _nativeHls(web.HTMLVideoElement video) {
  final type = video.canPlayType('application/vnd.apple.mpegurl');
  return type == 'probably' || type == 'maybe';
}

Future<void> ensureHlsJsLoaded() async {
  try {
    if (_Hls.isSupported()) return;
  } catch (_) {}

  final existing = web.document.querySelector('script[data-hubsom-hls]');
  if (existing != null) {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return;
  }

  final ready = Completer<void>();
  final script = web.HTMLScriptElement()
    ..src = 'https://cdn.jsdelivr.net/npm/hls.js@1.5.20/dist/hls.min.js'
    ..async = true;
  script.setAttribute('data-hubsom-hls', '1');
  script.onload = (web.Event _) {
    if (!ready.isCompleted) ready.complete();
  }.toJS;
  script.onerror = (web.Event _) {
    if (!ready.isCompleted) {
      ready.completeError(StateError('Could not load hls.js'));
    }
  }.toJS;
  web.document.head?.append(script);
  await ready.future;
}

Future<LiveHlsSession> attachLiveHls({
  required web.HTMLVideoElement video,
  required String url,
  bool muted = true,
}) async {
  video.muted = muted;
  video.autoplay = true;
  video.setAttribute('playsinline', 'true');
  video.controls = false;

  if (_nativeHls(video)) {
    video.src = url;
    unawaited(video.play().toDart);
    return LiveHlsSession._(video: video);
  }

  await ensureHlsJsLoaded();
  if (_Hls.isSupported()) {
    final hls = _Hls()
      ..loadSource(url)
      ..attachMedia(video);
    unawaited(video.play().toDart);
    return LiveHlsSession._(video: video, hls: hls);
  }

  video.src = url;
  unawaited(video.play().toDart);
  return LiveHlsSession._(video: video);
}
