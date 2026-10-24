import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../core/services/owncast_media.dart';
import '../core/theme/hubsom_colors.dart';
import 'live_hls_helpers_web.dart';

/// Viewer stage: Owncast / nginx-rtmp HLS (Safari native, Chrome via hls.js).
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
  LiveHlsSession? _session;
  Timer? _poll;
  bool _ready = false;
  bool _connecting = true;
  bool _needsUnmute = true;
  String? _status;

  @override
  void initState() {
    super.initState();
    _viewType =
        'hubsom-live-viewer-${DateTime.now().microsecondsSinceEpoch}';
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
    _status = OwncastMedia.isConfigured
        ? 'Waiting for seller stream…'
        : 'Owncast VPS not connected';
    if (OwncastMedia.isConfigured) {
      _poll = Timer.periodic(const Duration(seconds: 2), (_) {
        unawaited(_tick());
      });
      unawaited(_tick());
    } else {
      _connecting = false;
    }
  }

  Future<void> _tick() async {
    if (!mounted || _ready || !OwncastMedia.isConfigured) return;
    final ready = await OwncastMedia.isHlsReady(widget.streamId);
    if (!mounted) return;
    if (!ready) {
      setState(() {
        _connecting = true;
        _status = 'Waiting for seller stream…';
      });
      return;
    }
    await _attachHls();
  }

  Future<void> _attachHls() async {
    final el = web.document.getElementById(_viewType);
    if (el == null || !el.isA<web.HTMLVideoElement>()) {
      if (mounted) {
        setState(() {
          _ready = true;
          _connecting = false;
          _status = null;
        });
      }
      return;
    }
    final video = el as web.HTMLVideoElement;
    _session?.dispose();
    try {
      _session = await attachLiveHls(
        video: video,
        url: OwncastMedia.hlsUrl(widget.streamId),
        muted: true,
      );
      if (!mounted) return;
      setState(() {
        _ready = true;
        _connecting = false;
        _status = null;
        _needsUnmute = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _connecting = true;
          _status = 'Reconnecting…';
        });
      }
    }
  }

  void _unmute() {
    final el = web.document.getElementById(_viewType);
    if (el != null && el.isA<web.HTMLVideoElement>()) {
      final video = el as web.HTMLVideoElement;
      video.muted = false;
      video.play().toDart;
    }
    if (mounted) setState(() => _needsUnmute = false);
  }

  @override
  void dispose() {
    _poll?.cancel();
    _session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        HtmlElementView(
          viewType: _viewType,
          onPlatformViewCreated: (_) {
            if (_ready) unawaited(_attachHls());
          },
        ),
        if (!_ready)
          _PresenceFallback(
            hostName: widget.hostName,
            pulse: widget.pulse,
            subtitle: _status ??
                (_connecting
                    ? 'Connecting to seller…'
                    : 'Waiting for seller video'),
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
        if (_ready && _needsUnmute)
          Positioned(
            right: 16,
            bottom: 24,
            child: TextButton.icon(
              onPressed: _unmute,
              style: TextButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.volume_up, size: 18),
              label: const Text('Tap for sound'),
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
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              if (OwncastMedia.isConfigured) ...[
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
            ],
          ),
        );
      },
    );
  }
}
