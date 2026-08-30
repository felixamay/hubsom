import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../core/theme/hubsom_colors.dart';

/// Host camera preview via browser getUserMedia (Flutter web Agora is stubbed).
class LiveHostCamera extends StatefulWidget {
  const LiveHostCamera({
    super.key,
    required this.enabled,
    required this.micOn,
    this.hostName = 'Host',
  });

  final bool enabled;
  final bool micOn;
  final String hostName;

  @override
  State<LiveHostCamera> createState() => _LiveHostCameraState();
}

class _LiveHostCameraState extends State<LiveHostCamera> {
  late final String _viewType;
  web.MediaStream? _media;
  String? _error;
  bool _ready = false;

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
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Camera permission needed to appear on live';
          _ready = false;
        });
      }
    }
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
