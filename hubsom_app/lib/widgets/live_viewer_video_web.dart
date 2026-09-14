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
  /// Give the host this long to answer before asking for a fresh offer. Covers
  /// a host tab that reloaded and no longer knows about this viewer.
  static const _connectTimeout = Duration(seconds: 20);

  /// How often to tell the host we are still watching. Must stay well inside
  /// the host's stale-viewer window.
  static const _heartbeatEvery = Duration(seconds: 15);

  late final String _viewType;
  web.RTCPeerConnection? _pc;
  web.MediaStream? _remote;

  /// Fallback stream for browsers whose track events carry no stream.
  web.MediaStream? _assembled;
  StreamSubscription<LiveWebrtcSignal?>? _watch;
  Timer? _poll;
  Timer? _upkeep;
  Timer? _attachRetry;
  Timer? _iceFlush;
  bool _ready = false;
  bool _muted = false;
  bool _handling = false;
  bool _answerPublished = false;
  String? _status;
  int _hostIceApplied = 0;
  int _icePublished = 0;
  String? _acceptedOfferSdp;
  DateTime _attemptStartedAt = DateTime.now();
  DateTime _lastHeartbeat = DateTime.now();
  final List<String> _localIce = [];

  @override
  void initState() {
    super.initState();
    _viewType = 'hubsom-live-viewer-${DateTime.now().microsecondsSinceEpoch}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int id) {
      final video = web.HTMLVideoElement()
        ..autoplay = true
        ..muted = true // Autoplay policies on Safari/Chrome require muted to
        //   start; the viewer unmutes via the sound button.
        ..setAttribute('playsinline', '')
        ..setAttribute('webkit-playsinline', '')
        ..setAttribute('autoplay', '')
        ..setAttribute('muted', '')
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..style.backgroundColor = '#0b1f17';
      video.id = _viewType;
      return video;
    });
    _muted = true; // Match the element's initial muted state.
    _status = 'Connecting to seller…';
    unawaited(_bootstrap());

    // Listeners deliver the host's offer as soon as it is written. Polling is
    // only a fallback for when Firestore cannot push, and can be slow because
    // it is no longer on the critical path.
    if (LiveWebrtcSignalStore.canWatch) {
      _watch = LiveWebrtcSignalStore.watchOne(
        widget.streamId,
        widget.viewerId,
      ).listen((signal) => unawaited(_handle(signal)));
    } else {
      _poll = Timer.periodic(const Duration(seconds: 1), (_) {
        unawaited(_pollOnce());
      });
    }

    _upkeep = Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(_upkeepTick());
    });
  }

  Future<void> _bootstrap() async {
    await _announce();
    if (!LiveWebrtcSignalStore.canWatch) await _pollOnce();
  }

  /// Tell the host a viewer is here and wants an offer.
  Future<void> _announce() async {
    _attemptStartedAt = DateTime.now();
    _lastHeartbeat = DateTime.now();
    try {
      await LiveWebrtcSignalStore.announceViewer(
        streamId: widget.streamId,
        viewerId: widget.viewerId,
      );
    } catch (_) {
      // Upkeep retries.
    }
  }

  Future<void> _pollOnce() async {
    try {
      await _handle(
        await LiveWebrtcSignalStore.get(widget.streamId, widget.viewerId),
      );
    } catch (_) {
      // Keep going; live room still works without video.
    }
  }

  Future<void> _handle(LiveWebrtcSignal? signal) async {
    if (!mounted || _handling) return;
    _handling = true;
    try {
      if (signal == null) {
        await _announce();
        return;
      }
      if (signal.state == 'closed') {
        await _resetPeer(rejoin: true);
        return;
      }

      if ((signal.offerSdp ?? '').isNotEmpty &&
          signal.offerSdp != _acceptedOfferSdp) {
        await _acceptOffer(signal);
      }

      final pc = _pc;
      if (pc != null && signal.hostIce.length > _hostIceApplied) {
        _hostIceApplied = await applyRemoteIce(
          pc,
          signal.hostIce,
          appliedCount: _hostIceApplied,
        );
      }
    } catch (_) {
      // Upkeep recovers.
    } finally {
      _handling = false;
    }
  }

  /// Heartbeat, stall detection and dead-connection recovery. None of this is
  /// on the path to first frame, so it runs on a slow timer.
  Future<void> _upkeepTick() async {
    if (!mounted) return;
    try {
      final pc = _pc;
      if (pc != null &&
          (isDeadPeerState(pc.connectionState) ||
              isDeadPeerState(pc.iceConnectionState))) {
        await _resetPeer(rejoin: true);
        return;
      }

      if (DateTime.now().difference(_lastHeartbeat) > _heartbeatEvery) {
        _lastHeartbeat = DateTime.now();
        await LiveWebrtcSignalStore.viewerHeartbeat(
          streamId: widget.streamId,
          viewerId: widget.viewerId,
        );
      }

      if (!_ready &&
          DateTime.now().difference(_attemptStartedAt) > _connectTimeout) {
        await _resetPeer(rejoin: true);
      }
    } catch (_) {
      // Try again next tick.
    }
  }

  /// Send candidates as they are gathered rather than on a tick boundary.
  ///
  /// A short debounce batches the burst that arrives right after the answer
  /// into one write without holding the first candidate back.
  void _scheduleIceFlush() {
    if (!_answerPublished) return;
    _iceFlush?.cancel();
    _iceFlush = Timer(const Duration(milliseconds: 60), () {
      unawaited(_flushIce());
    });
  }

  Future<void> _flushIce() async {
    if (!_answerPublished || _localIce.length <= _icePublished) return;
    final pending = _localIce.sublist(_icePublished);
    _icePublished = _localIce.length;
    try {
      await LiveWebrtcSignalStore.appendIce(
        streamId: widget.streamId,
        viewerId: widget.viewerId,
        viewer: pending,
      );
    } catch (_) {
      // Re-send on the next gathered candidate.
      _icePublished -= pending.length;
    }
  }

  Future<void> _acceptOffer(LiveWebrtcSignal signal) async {
    await _disposePc();
    final pc = web.RTCPeerConnection(liveRtcConfig());
    _pc = pc;
    _hostIceApplied = 0;
    _icePublished = 0;
    _localIce.clear();
    _acceptedOfferSdp = null;
    _answerPublished = false;
    _assembled = null;
    _attemptStartedAt = DateTime.now();

    pc.ontrack = ((web.Event event) {
      final te = event as web.RTCTrackEvent;
      final streams = te.streams.toDart;
      if (streams.isNotEmpty) {
        _showRemote(streams.first);
        return;
      }
      // Some browsers report no stream on the event. Collect the tracks into
      // one stream rather than letting the video track replace the audio one.
      final assembled = _assembled ??= web.MediaStream();
      assembled.addTrack(te.track);
      _showRemote(assembled);
    }).toJS;

    pc.onicecandidate = ((web.Event event) {
      final iceEvent = event as web.RTCPeerConnectionIceEvent;
      final c = iceEvent.candidate;
      if (c == null) return;
      final encoded = encodeIceCandidate(c);
      if (encoded.isEmpty) return;
      _localIce.add(encoded);
      _scheduleIceFlush();
    }).toJS;

    await pc
        .setRemoteDescription(
          web.RTCSessionDescriptionInit(
            type: signal.offerType?.isNotEmpty == true
                ? signal.offerType!
                : 'offer',
            sdp: signal.offerSdp ?? '',
          ),
        )
        .toDart;
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

    _acceptedOfferSdp = signal.offerSdp;
    await LiveWebrtcSignalStore.upsertViewerSide(
      LiveWebrtcSignal(
        id: signal.id,
        streamId: signal.streamId,
        viewerId: signal.viewerId,
        state: 'answered',
        answerSdp: answer.sdp,
        answerType: answer.type,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    // Candidates were held back until now: the host's offer write resets both
    // ICE lists, so anything sent earlier would have been wiped.
    _answerPublished = true;
    unawaited(_flushIce());
    if (mounted && !_ready) {
      setState(() => _status = 'Almost there…');
    }
  }

  /// Remember the stream *and* keep trying to hand it to the <video> element.
  void _showRemote(web.MediaStream stream) {
    _remote = stream;
    if (mounted && !_ready) {
      setState(() {
        _ready = true;
        _status = null;
      });
    }
    _attach();
  }

  void _attach() {
    final stream = _remote;
    if (stream == null) return;
    final attached = attachStreamToView(
      viewType: _viewType,
      stream: stream,
      muted: _muted,
    );
    if (attached) {
      _attachRetry?.cancel();
      _attachRetry = null;
      _syncMuteAffordance();
      return;
    }
    // The platform view may not be in the DOM yet — keep trying briefly.
    _attachRetry?.cancel();
    _attachRetry = Timer(const Duration(milliseconds: 120), () {
      if (mounted) _attach();
    });
  }

  void _syncMuteAffordance() {
    final el = web.document.getElementById(_viewType);
    if (el == null || !el.isA<web.HTMLVideoElement>()) return;
    final video = el as web.HTMLVideoElement;
    // Autoplay policies mute the element when sound was not allowed; reflect
    // that in the control instead of silently playing with no audio.
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      if (video.muted != _muted) setState(() => _muted = video.muted);
    });
  }

  void _toggleSound() {
    final next = !_muted;
    setState(() => _muted = next);
    final stream = _remote;
    if (stream == null) return;
    attachStreamToView(
      viewType: _viewType,
      stream: stream,
      muted: next,
    );
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
    _acceptedOfferSdp = null;
    _answerPublished = false;
    _hostIceApplied = 0;
    _icePublished = 0;
    _localIce.clear();
    _remote = null;
    _assembled = null;
    _attachRetry?.cancel();
    _attachRetry = null;
    _iceFlush?.cancel();
    _iceFlush = null;
    if (mounted) {
      setState(() {
        _ready = false;
        _status = 'Reconnecting…';
      });
    }
    if (rejoin) await _announce();
  }

  @override
  void dispose() {
    unawaited(_watch?.cancel());
    _poll?.cancel();
    _upkeep?.cancel();
    _attachRetry?.cancel();
    _iceFlush?.cancel();
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
        // Always mounted: `ontrack` can only hand the stream to an element that
        // already exists, so the video surface cannot wait on a connection.
        HtmlElementView(
          viewType: _viewType,
          onPlatformViewCreated: (_) => _attach(),
        ),
        if (!_ready)
          _PresenceFallback(
            hostName: widget.hostName,
            pulse: widget.pulse,
            subtitle: _status ?? 'Connecting to seller…',
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
        // Always offered once video is up: browsers often start muted, and a
        // viewer sitting near the seller needs to be able to kill the audio.
        if (_ready)
          Positioned(
            right: 16,
            bottom: 24,
            child: TextButton.icon(
              onPressed: _toggleSound,
              style: TextButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
              ),
              icon: Icon(
                _muted ? Icons.volume_off : Icons.volume_up,
                size: 18,
              ),
              label: Text(_muted ? 'Tap for sound' : 'Mute'),
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
