import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../core/config/app_config.dart';

/// ICE configuration for Hubsom live WebRTC (no Agora App ID required).
///
/// STUN only discovers a public address; it cannot get packets through
/// carrier-grade NAT, which is what most Ghanaian mobile data sits behind. A
/// TURN relay is therefore required for a viewer to see the seller at all on
/// those networks, so it is always included.
web.RTCConfiguration liveRtcConfig() {
  final servers = <web.RTCIceServer>[
    web.RTCIceServer(urls: 'stun:stun.l.google.com:19302'.toJS),
    web.RTCIceServer(urls: 'stun:stun1.l.google.com:19302'.toJS),
  ];

  final turnUrls = AppConfig.turnUrls
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
  if (turnUrls.isNotEmpty) {
    servers.add(
      web.RTCIceServer(
        urls: turnUrls.map((e) => e.toJS).toList().toJS,
        username: AppConfig.turnUsername,
        credential: AppConfig.turnCredential,
      ),
    );
  }

  return web.RTCConfiguration(
    iceServers: servers.toJS,
    // Pool a candidate ahead of the offer so the first connect is quicker.
    iceCandidatePoolSize: 4,
  );
}

/// Camera and mic capture for the host.
///
/// Asking for bare `audio: true` leaves echo handling to whatever the browser
/// defaults to, which is how a seller ends up broadcasting a loud echo of their
/// own speakers. These processing flags are requested explicitly instead.
web.MediaStreamConstraints liveHostMediaConstraints() {
  return web.MediaStreamConstraints(
    video: web.MediaTrackConstraints(
      width: web.ConstrainULongRange(ideal: 1280),
      height: web.ConstrainULongRange(ideal: 720),
      frameRate: web.ConstrainDoubleRange(ideal: 30),
      facingMode: 'user'.toJS,
    ) as JSAny,
    audio: web.MediaTrackConstraints(
      echoCancellation: true.toJS,
      noiseSuppression: true.toJS,
      autoGainControl: true.toJS,
    ) as JSAny,
  );
}

/// Make an element that must never play sound genuinely silent.
///
/// A host preview that plays the captured mic back through the speakers feeds
/// straight into the mic again, which is the loudest kind of echo. `muted`
/// alone has been unset by re-attach paths before, so volume is pinned too.
void silenceElement(web.HTMLVideoElement video) {
  video.muted = true;
  video.volume = 0;
  video.setAttribute('muted', 'true');
}

String encodeIceCandidate(web.RTCIceCandidate candidate) {
  return jsonEncode({
    'candidate': candidate.candidate,
    'sdpMid': candidate.sdpMid,
    'sdpMLineIndex': candidate.sdpMLineIndex,
  });
}

web.RTCIceCandidateInit decodeIceCandidate(String raw) {
  final map = jsonDecode(raw);
  if (map is! Map) {
    return web.RTCIceCandidateInit(candidate: '');
  }
  final m = Map<String, dynamic>.from(map);
  return web.RTCIceCandidateInit(
    candidate: '${m['candidate'] ?? ''}',
    sdpMid: m['sdpMid']?.toString(),
    sdpMLineIndex: m['sdpMLineIndex'] is int
        ? m['sdpMLineIndex'] as int
        : int.tryParse('${m['sdpMLineIndex'] ?? ''}'),
  );
}

/// Apply every remote candidate we have not already fed to [pc].
///
/// Returns how many entries of [encoded] are now applied, so a caller never
/// re-adds one and never skips one it failed to add earlier.
Future<int> applyRemoteIce(
  web.RTCPeerConnection pc,
  List<String> encoded, {
  required int appliedCount,
}) async {
  var applied = appliedCount;
  for (var i = appliedCount; i < encoded.length; i++) {
    final raw = encoded[i];
    applied = i + 1;
    if (raw.isEmpty) continue;
    try {
      await pc.addIceCandidate(decodeIceCandidate(raw)).toDart;
    } catch (_) {
      // Ignore stale / duplicate candidates.
    }
  }
  return applied;
}

/// True when the peer connection has given up and needs a fresh negotiation.
bool isDeadPeerState(String? state) =>
    state == 'failed' || state == 'closed' || state == 'disconnected';

/// Attach [stream] to [video].
///
/// Returns immediately — the caller is responsible for ensuring the element
/// is in the DOM before calling (retry via onPlatformViewCreated or a short
/// timer if needed).
void attachStreamToElement({
  required web.HTMLVideoElement video,
  required web.MediaStream stream,
  bool muted = false,
}) {
  // Re-assert playsinline so Safari never opens full-screen unexpectedly.
  video.setAttribute('playsinline', '');
  video.setAttribute('webkit-playsinline', '');
  if (video.srcObject != stream) {
    video.srcObject = stream;
  }
  video.muted = muted;
  video.play().toDart.then(
    (_) {},
    onError: (_) {
      // Autoplay with sound was refused; fall back to muted playback.
      video.muted = true;
      video.play().toDart.then((_) {}, onError: (_) {});
    },
  );
}

/// Attach [stream] to the <video> element created for [viewType].
///
/// The element only exists once Flutter has mounted the platform view, so
/// callers retry until it appears rather than dropping the stream on the floor.
///
/// PREFER [attachStreamToElement] when a direct element reference is available
/// (CanvasKit renders platform views inside a shadow root that
/// [web.document.getElementById] cannot reach).
bool attachStreamToView({
  required String viewType,
  required web.MediaStream stream,
  bool muted = false,
}) {
  final el = web.document.getElementById(viewType);
  if (el == null || !el.isA<web.HTMLVideoElement>()) return false;
  attachStreamToElement(video: el as web.HTMLVideoElement, stream: stream, muted: muted);
  return true;
}
