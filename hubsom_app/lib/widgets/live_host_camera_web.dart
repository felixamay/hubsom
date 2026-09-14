import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../core/services/live_webrtc_signal_store.dart';
import '../core/theme/hubsom_colors.dart';
import 'live_webrtc_helpers_web.dart';

/// Host camera preview + WebRTC publish so viewers can see the seller.
class LiveHostCamera extends StatefulWidget {
  const LiveHostCamera({
    super.key,
    required this.enabled,
    required this.micOn,
    this.hostName = 'Host',
    this.streamId,
  });

  final bool enabled;
  final bool micOn;
  final String hostName;
  final String? streamId;

  @override
  State<LiveHostCamera> createState() => _LiveHostCameraState();
}

class _LiveHostCameraState extends State<LiveHostCamera> {
  /// Drop a viewer that stopped checking in — a closed tab does not always get
  /// to run its cleanup, and dead peers keep eating the host's uplink.
  static const _viewerStaleAfter = Duration(seconds: 45);

  late final String _viewType;
  web.HTMLVideoElement? _videoEl; // direct ref avoids getElementById in shadow DOM
  web.MediaStream? _media;
  String? _error;
  bool _ready = false;
  Timer? _publishPoll;
  StreamSubscription<List<LiveWebrtcSignal>>? _watch;
  bool _ticking = false;
  final Map<String, _HostPeer> _peers = {};
  bool _pendingTick = false;

  @override
  void initState() {
    super.initState();
    _viewType =
        'hubsom-live-cam-${DateTime.now().microsecondsSinceEpoch}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int id) {
      final video = web.HTMLVideoElement()
        ..autoplay = true
        ..setAttribute('playsinline', 'true')
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..style.backgroundColor = '#0b1f17';
      silenceElement(video);
      video.id = _viewType;
      _videoEl = video; // capture direct ref — CanvasKit shadow root hides it
      return video;
    });
    if (widget.enabled) {
      _start();
    }
  }

  @override
  void didUpdateWidget(covariant LiveHostCamera oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !oldWidget.enabled) {
      _start();
    } else if (!widget.enabled && oldWidget.enabled) {
      _stop();
      setState(() => _ready = false);
    }
    if (_media != null && widget.micOn != oldWidget.micOn) {
      final tracks = _media!.getAudioTracks().toDart;
      for (final t in tracks) {
        t.enabled = widget.micOn;
      }
    }
    if (widget.streamId != oldWidget.streamId) {
      _restartPublisher();
    }
  }

  Future<void> _start() async {
    try {
      final stream = await web.window.navigator.mediaDevices
          .getUserMedia(liveHostMediaConstraints())
          .toDart;
      _media = stream;
      if (!widget.micOn) {
        for (final t in stream.getAudioTracks().toDart) {
          t.enabled = false;
        }
      }
      if (!mounted) {
        _stopTracks(stream);
        return;
      }
      setState(() {
        _ready = true;
        _error = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _attach(stream));
      _restartPublisher();
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Camera permission needed to appear on live';
          _ready = false;
        });
      }
    }
  }

  void _restartPublisher() {
    _publishPoll?.cancel();
    _publishPoll = null;
    unawaited(_watch?.cancel());
    _watch = null;
    final streamId = widget.streamId;
    final media = _media;
    if (streamId == null ||
        streamId.isEmpty ||
        media == null ||
        !widget.enabled) {
      return;
    }
    // React the moment a viewer announces itself instead of up to a second
    // later — a poll interval on every negotiation hop is what made viewers
    // wait so long for the seller to appear.
    if (LiveWebrtcSignalStore.canWatch) {
      _watch = LiveWebrtcSignalStore.watchForStream(streamId).listen(
        (signals) => unawaited(_hostTick(streamId, media, signals: signals)),
      );
      // Slow safety net for pruning viewers that simply went quiet.
      _publishPoll = Timer.periodic(const Duration(seconds: 5), (_) {
        unawaited(_hostTick(streamId, media));
      });
    } else {
      _publishPoll = Timer.periodic(const Duration(seconds: 1), (_) {
        unawaited(_hostTick(streamId, media));
      });
    }
    unawaited(_hostTick(streamId, media));
  }

  Future<void> _hostTick(
    String streamId,
    web.MediaStream media, {
    List<LiveWebrtcSignal>? signals,
  }) async {
    if (!mounted) return;
    if (_ticking) {
      // A snapshot arrived while a tick was running. Re-run once it finishes
      // so the latest state is never silently dropped.
      _pendingTick = true;
      return;
    }
    _ticking = true;
    try {
      signals ??= await LiveWebrtcSignalStore.listForStream(streamId);
      final activeIds = <String>{};
      final now = DateTime.now().millisecondsSinceEpoch;

      for (final signal in signals) {
        if (signal.state == 'closed') {
          await _dropPeer(signal.viewerId);
          continue;
        }
        if (signal.viewerSeenAt > 0 &&
            now - signal.viewerSeenAt > _viewerStaleAfter.inMilliseconds) {
          await _dropPeer(signal.viewerId);
          continue;
        }
        activeIds.add(signal.viewerId);

        var peer = _peers[signal.viewerId];
        if (peer != null && signal.state == 'waiting') {
          // Viewer rejoined — renegotiate from a fresh offer.
          await _dropPeer(signal.viewerId);
          peer = null;
        }
        if (peer != null &&
            (isDeadPeerState(peer.pc.connectionState) ||
                isDeadPeerState(peer.pc.iceConnectionState))) {
          await _dropPeer(signal.viewerId);
          peer = null;
        }
        if (peer == null) {
          // Covers a viewer still marked 'answered' against a previous host
          // tab too: offering again immediately is a round trip cheaper than
          // bouncing it back to 'waiting' first.
          peer = await _createPeer(streamId, signal.viewerId, media);
          _peers[signal.viewerId] = peer;
          // The answer arrives on the next pushed snapshot.
          continue;
        }

        // Only trust an answer written against the offer this peer published,
        // otherwise a previous negotiation's answer can be applied to it.
        if (signal.offerSdp != peer.offerSdp) continue;

        if (!peer.answerApplied && (signal.answerSdp ?? '').isNotEmpty) {
          await peer.pc
              .setRemoteDescription(
                web.RTCSessionDescriptionInit(
                  type: signal.answerType?.isNotEmpty == true
                      ? signal.answerType!
                      : 'answer',
                  sdp: signal.answerSdp ?? '',
                ),
              )
              .toDart;
          peer.answerApplied = true;
        }

        // Candidates can only be added once the answer is in place.
        if (peer.answerApplied &&
            signal.viewerIce.length > peer.viewerIceApplied) {
          peer.viewerIceApplied = await applyRemoteIce(
            peer.pc,
            signal.viewerIce,
            appliedCount: peer.viewerIceApplied,
          );
        }

        await _flushIce(streamId, signal.viewerId, peer);
      }

      final gone = _peers.keys
          .where((id) => !activeIds.contains(id))
          .toList(growable: false);
      for (final id in gone) {
        await _dropPeer(id);
      }
    } catch (_) {
      // Host preview still works if signaling fails.
    } finally {
      _ticking = false;
      if (_pendingTick && mounted) {
        _pendingTick = false;
        unawaited(_hostTick(streamId, media));
      }
    }
  }

  Future<_HostPeer> _createPeer(
    String streamId,
    String viewerId,
    web.MediaStream media,
  ) async {
    final pc = web.RTCPeerConnection(liveRtcConfig());
    final peer = _HostPeer(pc: pc);

    for (final track in media.getTracks().toDart) {
      pc.addTrack(track, media);
    }

    pc.onicecandidate = ((web.Event event) {
      final iceEvent = event as web.RTCPeerConnectionIceEvent;
      final c = iceEvent.candidate;
      if (c == null) return;
      final encoded = encodeIceCandidate(c);
      if (encoded.isEmpty) return;
      peer.localIce.add(encoded);
      // Trickle straight away so the viewer can start checking paths while the
      // rest of the candidates are still being gathered.
      peer.iceFlush?.cancel();
      peer.iceFlush = Timer(const Duration(milliseconds: 60), () {
        unawaited(_flushIce(streamId, viewerId, peer));
      });
    }).toJS;

    final offer = await pc.createOffer().toDart;
    if (offer == null) {
      pc.close();
      throw StateError('Could not create WebRTC offer');
    }
    await pc
        .setLocalDescription(
          web.RTCLocalSessionDescriptionInit(
            type: offer.type,
            sdp: offer.sdp,
          ),
        )
        .toDart;

    // One write: advertise the offer and clear the previous negotiation's
    // answer and candidates, which would otherwise be matched against it.
    peer.offerSdp = offer.sdp;
    await LiveWebrtcSignalStore.publishOffer(
      streamId: streamId,
      viewerId: viewerId,
      offerSdp: offer.sdp,
      offerType: offer.type,
    );
    // Held back until now because the offer write resets both ICE lists.
    peer.offerPublished = true;
    unawaited(_flushIce(streamId, viewerId, peer));
    return peer;
  }

  Future<void> _flushIce(
    String streamId,
    String viewerId,
    _HostPeer peer,
  ) async {
    if (!peer.offerPublished || peer.localIce.length <= peer.icePublished) {
      return;
    }
    final pending = peer.localIce.sublist(peer.icePublished);
    peer.icePublished = peer.localIce.length;
    try {
      await LiveWebrtcSignalStore.appendIce(
        streamId: streamId,
        viewerId: viewerId,
        host: pending,
      );
    } catch (_) {
      peer.icePublished -= pending.length;
    }
  }

  Future<void> _dropPeer(String viewerId) async {
    final peer = _peers.remove(viewerId);
    if (peer == null) return;
    peer.iceFlush?.cancel();
    try {
      peer.pc.close();
    } catch (_) {}
  }

  void _attach(web.MediaStream stream) {
    final video = _videoEl;
    if (video == null) return;
    // Re-asserted on every attach: the preview must never be audible.
    silenceElement(video);
    video.srcObject = stream;
    video.play().toDart;
  }

  void _stopTracks(web.MediaStream stream) {
    for (final t in stream.getTracks().toDart) {
      t.stop();
    }
  }

  void _stop() {
    _publishPoll?.cancel();
    _publishPoll = null;
    unawaited(_watch?.cancel());
    _watch = null;
    for (final id in _peers.keys.toList(growable: false)) {
      unawaited(_dropPeer(id));
    }
    final streamId = widget.streamId;
    if (streamId != null && streamId.isNotEmpty) {
      unawaited(LiveWebrtcSignalStore.closeAllForStream(streamId));
    }
    final stream = _media;
    if (stream != null) {
      _stopTracks(stream);
      _media = null;
    }
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return _PresenceFallback(
        hostName: widget.hostName,
        subtitle: 'Camera off',
        icon: Icons.videocam_off,
      );
    }
    if (_error != null) {
      return _PresenceFallback(
        hostName: widget.hostName,
        subtitle: _error!,
        icon: Icons.videocam_off,
      );
    }
    if (!_ready) {
      return const ColoredBox(
        color: Color(0xFF0B1F17),
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        HtmlElementView(
          viewType: _viewType,
          onPlatformViewCreated: (_) {
            // _videoEl is already set by the factory; just attach any ready stream.
            final stream = _media;
            if (stream != null) _attach(stream);
          },
        ),
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
              'You · ${widget.hostName}',
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

class _HostPeer {
  _HostPeer({required this.pc});

  final web.RTCPeerConnection pc;
  final List<String> localIce = [];
  bool answerApplied = false;
  bool offerPublished = false;
  String? offerSdp;
  Timer? iceFlush;
  int viewerIceApplied = 0;
  int icePublished = 0;
}

class _PresenceFallback extends StatelessWidget {
  const _PresenceFallback({
    required this.hostName,
    required this.subtitle,
    required this.icon,
  });

  final String hostName;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0B1F17),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 42,
            backgroundColor: HubsomColors.forest,
            child: Text(
              hostName.isNotEmpty ? hostName.substring(0, 1).toUpperCase() : 'H',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            hostName,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white54, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
