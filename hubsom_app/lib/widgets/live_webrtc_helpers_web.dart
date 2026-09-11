import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Shared STUN servers for Hubsom live WebRTC (no Agora App ID required).
web.RTCConfiguration liveRtcConfig() {
  return web.RTCConfiguration(
    iceServers: [
      web.RTCIceServer(urls: 'stun:stun.l.google.com:19302'.toJS),
      web.RTCIceServer(urls: 'stun:stun1.l.google.com:19302'.toJS),
    ].toJS,
  );
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

Future<void> applyRemoteIce(
  web.RTCPeerConnection pc,
  List<String> encoded, {
  required int appliedCount,
}) async {
  for (var i = appliedCount; i < encoded.length; i++) {
    final raw = encoded[i];
    if (raw.isEmpty) continue;
    try {
      await pc.addIceCandidate(decodeIceCandidate(raw)).toDart;
    } catch (_) {
      // Ignore stale / duplicate candidates.
    }
  }
}
