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
  late final String _viewType;
  web.MediaStream? _media;
  String? _error;
  bool _ready = false;
  Timer? _publishPoll;
  final Map<String, _HostPeer> _peers = {};

  @override
  void initState() {
    super.initState();
    _viewType =
        'hubsom-live-cam-${DateTime.now().microsecondsSinceEpoch}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int id) {
      final video = web.HTMLVideoElement()
        ..autoplay = true
        ..muted = true
        ..setAttribute('playsinline', 'true')
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..style.backgroundColor = '#0b1f17';
      video.id = _viewType;
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
      final stream =
          await web.window.navigator.mediaDevices
              .getUserMedia(
                web.MediaStreamConstraints(
                  video: true.toJS,
                  audio: true.toJS,
                ),
              )
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
    final streamId = widget.streamId;
    final media = _media;
    if (streamId == null ||
        streamId.isEmpty ||
        media == null ||
        !widget.enabled) {
      return;
    }
    _publishPoll = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_hostTick(streamId, media));
    });
    unawaited(_hostTick(streamId, media));
  }

  Future<void> _hostTick(String streamId, web.MediaStream media) async {
    if (!mounted) return;
    try {
      final signals = await LiveWebrtcSignalStore.listForStream(streamId);
      final activeIds = <String>{};

      for (final signal in signals) {
        if (signal.state == 'closed') {
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
        if (peer == null) {
          if ((signal.answerSdp ?? '').isNotEmpty &&
              signal.state == 'answered') {
            // Stale session from a previous host tab — ask viewer to rejoin.
            await LiveWebrtcSignalStore.upsert(
              LiveWebrtcSignal(
                id: signal.id,
                streamId: streamId,
                viewerId: signal.viewerId,
                state: 'waiting',
                updatedAt: DateTime.now().millisecondsSinceEpoch,
              ),
            );
            continue;
          }
          peer = await _createPeer(streamId, signal.viewerId, media);
          _peers[signal.viewerId] = peer;
        }

        if (!peer.answerApplied && (signal.answerSdp ?? '').isNotEmpty) {
          await peer.pc
              .setRemoteDescription(
                web.RTCSessionDescriptionInit(
                  type: signal.answerType ?? 'answer',
                  sdp: signal.answerSdp ?? '',
                ),
              )
              .toDart;
          peer.answerApplied = true;
        }

        if (signal.viewerIce.length > peer.viewerIceApplied) {
          await applyRemoteIce(
            peer.pc,
            signal.viewerIce,
            appliedCount: peer.viewerIceApplied,
          );
          peer.viewerIceApplied = signal.viewerIce.length;
        }

        if (peer.iceDirty && peer.localIce.isNotEmpty) {
          peer.iceDirty = false;
          final latest = await LiveWebrtcSignalStore.get(
            streamId,
            signal.viewerId,
          );
          if (latest != null && latest.state != 'closed') {
            await LiveWebrtcSignalStore.upsert(
              latest.copyWith(
                hostIce: List<String>.from(peer.localIce),
                updatedAt: DateTime.now().millisecondsSinceEpoch,
              ),
            );
          }
        }
      }

      final stale = _peers.keys
          .where((id) => !activeIds.contains(id))
          .toList(growable: false);
      for (final id in stale) {
        await _dropPeer(id);
      }
    } catch (_) {
      // Host preview still works if signaling fails.
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
      peer.iceDirty = true;
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

    await LiveWebrtcSignalStore.upsert(
      LiveWebrtcSignal(
        id: LiveWebrtcSignal.docId(streamId, viewerId),
        streamId: streamId,
        viewerId: viewerId,
        state: 'offered',
        offerSdp: offer.sdp,
        offerType: offer.type,
        hostIce: List<String>.from(peer.localIce),
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    return peer;
  }

  Future<void> _dropPeer(String viewerId) async {
    final peer = _peers.remove(viewerId);
    if (peer == null) return;
    try {
      peer.pc.close();
    } catch (_) {}
  }

  void _attach(web.MediaStream stream) {
    final el = web.document.getElementById(_viewType);
    if (el != null && el.isA<web.HTMLVideoElement>()) {
      final video = el as web.HTMLVideoElement;
      video.srcObject = stream;
      video.play().toDart;
    }
  }

  void _stopTracks(web.MediaStream stream) {
    for (final t in stream.getTracks().toDart) {
      t.stop();
    }
  }

  void _stop() {
    _publishPoll?.cancel();
    _publishPoll = null;
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
            final stream = _media;
            if (stream != null) {
              Future<void>.delayed(const Duration(milliseconds: 50), () {
                _attach(stream);
              });
            }
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
  bool iceDirty = false;
  bool answerApplied = false;
  int viewerIceApplied = 0;
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
