import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../core/services/live_webrtc_signal_store.dart';
import '../core/theme/hubsom_colors.dart';
import 'live_webrtc_helpers_web.dart';

/// Viewer stage: pulls the host camera/mic over WebRTC (Firestore signaling).
class LiveViewerVideo extends StatefulWidget {
  const LiveViewerVideo({
    super.key,
    required this.streamId,
    required this.viewerId,
    required this.hostName,
    required this.pulse,
  });

  final String streamId;
  final String viewerId;
  final String hostName;
  final AnimationController pulse;

  @override
  State<LiveViewerVideo> createState() => _LiveViewerVideoState();
}

class _LiveViewerVideoState extends State<LiveViewerVideo> {
  late final String _viewType;
  web.RTCPeerConnection? _pc;
  Timer? _poll;
  bool _ready = false;
  bool _connecting = true;
  String? _status;
  int _hostIceApplied = 0;
  bool _answerSent = false;
  String? _acceptedOfferSdp;
  final List<String> _localIce = [];
  bool _iceDirty = false;

  @override
  void initState() {
    super.initState();
    _viewType =
        'hubsom-live-viewer-${DateTime.now().microsecondsSinceEpoch}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int id) {
      final video = web.HTMLVideoElement()
        ..autoplay = true
        ..setAttribute('playsinline', 'true')
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..style.backgroundColor = '#0b1f17';
      video.id = _viewType;
      return video;
    });
    unawaited(_bootstrap());
    _poll = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_tick());
    });
  }

  Future<void> _bootstrap() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await LiveWebrtcSignalStore.upsert(
      LiveWebrtcSignal(
        id: LiveWebrtcSignal.docId(widget.streamId, widget.viewerId),
        streamId: widget.streamId,
        viewerId: widget.viewerId,
        state: 'waiting',
        updatedAt: now,
      ),
    );
    if (mounted) {
      setState(() {
        _connecting = true;
        _status = 'Connecting to seller…';
      });
    }
    await _tick();
  }

  Future<void> _tick() async {
    if (!mounted) return;
    try {
      final signal = await LiveWebrtcSignalStore.get(
        widget.streamId,
        widget.viewerId,
      );
      if (signal == null || signal.state == 'closed') {
        if (signal?.state == 'closed') {
          await _resetPeer(rejoin: true);
        }
        return;
      }

      if ((signal.offerSdp ?? '').isNotEmpty &&
          signal.offerSdp != _acceptedOfferSdp) {
        await _acceptOffer(signal);
        _acceptedOfferSdp = signal.offerSdp;
      }

      final pc = _pc;
      if (pc != null && signal.hostIce.length > _hostIceApplied) {
        await applyRemoteIce(
          pc,
          signal.hostIce,
          appliedCount: _hostIceApplied,
        );
        _hostIceApplied = signal.hostIce.length;
      }

      if (_iceDirty && _localIce.isNotEmpty) {
        _iceDirty = false;
        final latest = await LiveWebrtcSignalStore.get(
          widget.streamId,
          widget.viewerId,
        );
        if (latest != null && latest.state != 'closed') {
          await LiveWebrtcSignalStore.upsert(
            latest.copyWith(
              viewerIce: List<String>.from(_localIce),
              updatedAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );
        }
      }
    } catch (_) {
      // Keep polling; live room still works without video.
    }
  }

  Future<void> _acceptOffer(LiveWebrtcSignal signal) async {
    await _disposePc();
    final pc = web.RTCPeerConnection(liveRtcConfig());
    _pc = pc;
    _hostIceApplied = 0;
    _localIce.clear();
    _answerSent = false;
    _acceptedOfferSdp = null;

    pc.ontrack = ((web.Event event) {
      final te = event as web.RTCTrackEvent;
      final streams = te.streams.toDart;
      web.MediaStream? remote;
      if (streams.isNotEmpty) {
        remote = streams.first;
      } else {
        final stream = web.MediaStream();
        stream.addTrack(te.track);
        remote = stream;
      }
      _attach(remote);
      if (mounted) {
        setState(() {
          _ready = true;
          _connecting = false;
          _status = null;
        });
      }
    }).toJS;

    pc.onicecandidate = ((web.Event event) {
      final iceEvent = event as web.RTCPeerConnectionIceEvent;
      final c = iceEvent.candidate;
      if (c == null) return;
      final encoded = encodeIceCandidate(c);
      if (encoded.isEmpty) return;
      _localIce.add(encoded);
      _iceDirty = true;
    }).toJS;

    final offer = web.RTCSessionDescriptionInit(
      type: signal.offerType ?? 'offer',
      sdp: signal.offerSdp ?? '',
    );
    await pc.setRemoteDescription(offer).toDart;
    final answer = await pc.createAnswer().toDart;
    if (answer == null) return;
    await pc
        .setLocalDescription(
          web.RTCLocalSessionDescriptionInit(
            type: answer.type,
            sdp: answer.sdp,
          ),
        )
        .toDart;

    _answerSent = true;
    await LiveWebrtcSignalStore.upsert(
      signal.copyWith(
        state: 'answered',
        answerSdp: answer.sdp,
        answerType: answer.type,
        viewerIce: List<String>.from(_localIce),
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    if (mounted) {
      setState(() {
        _connecting = true;
        _status = 'Almost there…';
      });
    }
  }

  void _attach(web.MediaStream stream) {
    final el = web.document.getElementById(_viewType);
    if (el != null && el.isA<web.HTMLVideoElement>()) {
      final video = el as web.HTMLVideoElement;
      video.srcObject = stream;
      video.muted = false;
      video.play().toDart;
    }
  }

  Future<void> _disposePc() async {
    final pc = _pc;
    _pc = null;
    if (pc != null) {
      try {
        pc.close();
      } catch (_) {}
    }
  }

  Future<void> _resetPeer({required bool rejoin}) async {
    await _disposePc();
    _answerSent = false;
    _acceptedOfferSdp = null;
    _hostIceApplied = 0;
    _localIce.clear();
    _iceDirty = false;
    if (mounted) {
      setState(() {
        _ready = false;
        _connecting = true;
        _status = 'Reconnecting…';
      });
    }
    if (rejoin) {
      await LiveWebrtcSignalStore.upsert(
        LiveWebrtcSignal(
          id: LiveWebrtcSignal.docId(widget.streamId, widget.viewerId),
          streamId: widget.streamId,
          viewerId: widget.viewerId,
          state: 'waiting',
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    unawaited(_disposePc());
    unawaited(
      LiveWebrtcSignalStore.close(widget.streamId, widget.viewerId),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_ready)
          HtmlElementView(
            viewType: _viewType,
            onPlatformViewCreated: (_) {
              // Stream may already be attached via ontrack.
            },
          )
        else
          _PresenceFallback(
            hostName: widget.hostName,
            pulse: widget.pulse,
            subtitle: _status ??
                (_connecting ? 'Connecting to seller…' : 'Waiting for seller video'),
          ),
        if (_ready)
          Positioned(
            left: 16,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.hostName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PresenceFallback extends StatelessWidget {
  const _PresenceFallback({
    required this.hostName,
    required this.pulse,
    required this.subtitle,
  });

  final String hostName;
  final AnimationController pulse;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        final t = pulse.value;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(
                  const Color(0xFF0B1F17),
                  HubsomColors.forest,
                  t * 0.25,
                )!,
                const Color(0xFF12261C),
                Color.lerp(
                  HubsomColors.ink,
                  const Color(0xFF1A3A2A),
                  t * 0.3,
                )!,
              ],
            ),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: HubsomColors.forest,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color:
                          HubsomColors.live.withValues(alpha: 0.45 + t * 0.2),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  hostName.isNotEmpty ? hostName[0].toUpperCase() : 'H',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                hostName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 14),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
