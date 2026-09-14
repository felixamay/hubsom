import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../core/services/live_webrtc_signal_store.dart';
import '../core/theme/hubsom_colors.dart';
import '../core/utils/browser_detect_web.dart';
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
  /// Give the host this long to answer before asking for a fresh offer.
  static const _connectTimeout = Duration(seconds: 20);
  static const _heartbeatEvery = Duration(seconds: 15);

  late final String _viewType;

  /// Direct reference to the <video> element.
  /// On Safari this element lives in document.body (not the shadow DOM).
  /// On other browsers it is returned from the HtmlElementView factory.
  web.HTMLVideoElement? _videoEl;

  web.RTCPeerConnection? _pc;
  web.MediaStream? _remote;
  web.MediaStream? _assembled;
  StreamSubscription<LiveWebrtcSignal?>? _watch;
  Timer? _poll;
  Timer? _upkeep;
  Timer? _attachRetry;
  Timer? _iceFlush;
  bool _ready = false;
  bool _muted = true;
  bool _handling = false;
  bool _answerPublished = false;
  bool _playBlocked = false;
  String? _status;
  int _hostIceApplied = 0;
  int _icePublished = 0;
  String? _acceptedOfferSdp;
  DateTime _attemptStartedAt = DateTime.now();
  DateTime _lastHeartbeat = DateTime.now();
  final List<String> _localIce = [];

  // ── Safari body-level video ──────────────────────────────────────────────
  // Flutter CanvasKit embeds HtmlElementView inside a shadow root. Safari
  // refuses to paint <video> elements in shadow roots regardless of CSS
  // compositing hints. On Safari we therefore create a second <video> element
  // directly in document.body *underneath* the Flutter view so it shows
  // through Flutter's transparent canvas while chat, buttons and the
  // tap-to-play overlay stay on top. The HtmlElementView slot becomes an
  // invisible placeholder that keeps the Flutter layout intact.
  web.HTMLVideoElement? _safariBodyEl;

  /// Connection diagnostics shown while no video frames are being painted.
  String? _diag;

  void _initSafariBodyVideo() {
    final v = web.HTMLVideoElement()
      ..muted = true
      ..setAttribute('playsinline', '')
      ..setAttribute('webkit-playsinline', '')
      ..setAttribute('autoplay', '')
      ..setAttribute('muted', '')
      ..style.setProperty('position', 'fixed')
      ..style.setProperty('top', '0')
      ..style.setProperty('left', '0')
      ..style.setProperty('width', '100%')
      ..style.setProperty('height', '100%')
      ..style.setProperty('object-fit', 'cover')
      ..style.setProperty('background-color', '#0b1f17')
      ..style.setProperty('display', 'none'); // hidden until stream arrives
    mountBehindFlutter(v);
    _safariBodyEl = v;
    _videoEl = v; // All WebRTC attachment code goes through _videoEl
  }

  @override
  void initState() {
    super.initState();
    _viewType = 'hubsom-live-viewer-${DateTime.now().microsecondsSinceEpoch}';

    if (isSafariBrowser()) {
      // Safari: video lives in document.body. HtmlElementView gets a
      // transparent <div> placeholder so Flutter's layout is unaffected.
      ui_web.platformViewRegistry.registerViewFactory(_viewType, (int id) {
        final div = web.document.createElement('div') as web.HTMLDivElement;
        div.style.width = '100%';
        div.style.height = '100%';
        return div;
      });
      _initSafariBodyVideo();
    } else {
      ui_web.platformViewRegistry.registerViewFactory(_viewType, (int id) {
        final video = web.HTMLVideoElement()
          ..autoplay = true
          ..muted = true
          ..setAttribute('playsinline', '')
          ..setAttribute('webkit-playsinline', '')
          ..setAttribute('autoplay', '')
          ..setAttribute('muted', '')
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = 'cover'
          ..style.backgroundColor = '#0b1f17'
          ..style.transform = 'translateZ(0)'
          ..style.setProperty('-webkit-transform', 'translateZ(0)')
          ..style.setProperty('will-change', 'transform')
          ..style.display = 'block';
        video.id = _viewType;
        _videoEl = video;
        return video;
      });
    }
    _muted = true;
    _status = 'Connecting to seller…';
    unawaited(_bootstrap());

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

  Future<void> _announce() async {
    _attemptStartedAt = DateTime.now();
    _lastHeartbeat = DateTime.now();
    try {
      await LiveWebrtcSignalStore.announceViewer(
        streamId: widget.streamId,
        viewerId: widget.viewerId,
      );
    } catch (_) {}
  }

  Future<void> _pollOnce() async {
    try {
      await _handle(
        await LiveWebrtcSignalStore.get(widget.streamId, widget.viewerId),
      );
    } catch (_) {}
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
    } finally {
      _handling = false;
    }
  }

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
      _refreshDiag();
    } catch (_) {}
  }

  /// Surfaces peer/video state so a blank stage can be reported precisely.
  /// Hidden automatically once real frames are painting.
  void _refreshDiag() {
    if (!mounted) return;
    final pc = _pc;
    final video = _videoEl;
    String? next;
    if (pc != null) {
      final painting = video != null && video.videoWidth > 0;
      if (!painting) {
        final size = video == null
            ? 'no element'
            : '${video.videoWidth}x${video.videoHeight} rs${video.readyState}'
                '${video.paused ? ' paused' : ''}';
        next = 'peer ${pc.connectionState} · ice ${pc.iceConnectionState} · '
            'video $size';
      }
    }
    if (next != _diag) setState(() => _diag = next);
  }

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
    _answerPublished = true;
    unawaited(_flushIce());
    if (mounted && !_ready) {
      setState(() => _status = 'Almost there…');
    }
  }

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
    final video = _videoEl;
    if (stream == null) return;
    if (video == null) {
      _attachRetry?.cancel();
      _attachRetry = Timer(const Duration(milliseconds: 120), () {
        if (mounted) _attach();
      });
      return;
    }

    // Make the Safari body-level element visible once we have a stream.
    final bodyEl = _safariBodyEl;
    if (bodyEl != null) {
      bodyEl.style.setProperty('display', 'block');
    }

    video.muted = true;
    video.setAttribute('playsinline', '');
    video.setAttribute('webkit-playsinline', '');
    if (video.srcObject != stream) {
      video.srcObject = stream;
    }
    video.play().toDart.then(
      (_) {
        if (mounted && _playBlocked) setState(() => _playBlocked = false);
        _syncMuteAffordance(video);
      },
      onError: (_) {
        if (mounted && !_playBlocked) setState(() => _playBlocked = true);
      },
    );
    _attachRetry?.cancel();
    _attachRetry = null;
    _syncMuteAffordance(video);
  }

  void _syncMuteAffordance(web.HTMLVideoElement video) {
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      if (video.muted != _muted) setState(() => _muted = video.muted);
    });
  }

  void _toggleSound() {
    final next = !_muted;
    setState(() => _muted = next);
    final video = _videoEl;
    final stream = _remote;
    if (video == null || stream == null) return;
    attachStreamToElement(video: video, stream: stream, muted: next);
  }

  /// Called from the native tap-to-play overlay.
  void _userPlay() {
    final video = _videoEl;
    final stream = _remote;
    if (video == null || stream == null) return;
    video.muted = false;
    video.play().toDart.then(
      (_) {
        if (mounted) setState(() { _playBlocked = false; _muted = false; });
      },
      onError: (_) {
        // Try muted as last resort.
        video.muted = true;
        video.play().toDart.then((_) {
          if (mounted) setState(() => _playBlocked = false);
        }, onError: (_) {});
      },
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
    _playBlocked = false; // reset so a fresh connect can re-evaluate
    _attachRetry?.cancel();
    _attachRetry = null;
    _iceFlush?.cancel();
    _iceFlush = null;
    // Hide the Safari body-level element while reconnecting.
    _safariBodyEl?.style.setProperty('display', 'none');
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
    _safariBodyEl?.remove();
    _safariBodyEl = null;
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
        // Always mounted: `ontrack` hands the stream to this element before
        // the connection is visible. On Safari this is a transparent <div>;
        // the real video is in document.body underneath the Flutter view.
        HtmlElementView(
          viewType: _viewType,
          onPlatformViewCreated: (_) {
            if (!isSafariBrowser()) _attach();
          },
        ),
        if (!_ready)
          _PresenceFallback(
            hostName: widget.hostName,
            pulse: widget.pulse,
            subtitle: _status ?? 'Connecting to seller…',
          ),
        if (_diag != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 72,
            child: IgnorePointer(
              child: Text(
                _diag!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                ),
              ),
            ),
          ),
        if (_ready && !_playBlocked)
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
        if (_ready && !_playBlocked)
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
        // Shown when the browser's autoplay policy blocks video.play().
        // Tapping calls play() inside a real user-gesture context (which
        // Safari always allows) and dismisses the overlay.
        if (_playBlocked)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _userPlay,
              child: Container(
                color: Colors.black.withValues(alpha: 0.55),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.play_circle_outline,
                      color: Colors.white,
                      size: 72,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Tap to watch',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.hostName,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
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
