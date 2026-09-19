import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/services/owncast_media.dart';
import '../core/theme/hubsom_colors.dart';

/// Native viewer stage: Owncast / nginx-rtmp HLS via video_player.
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
  VideoPlayerController? _controller;
  Timer? _poll;
  bool _ready = false;
  String _status = 'Waiting for seller stream…';

  @override
  void initState() {
    super.initState();
    if (!OwncastMedia.isConfigured) {
      _status = 'Owncast VPS not connected';
      return;
    }
    _poll = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_tick());
    });
    unawaited(_tick());
  }

  Future<void> _tick() async {
    if (!mounted || _ready) return;
    final ready = await OwncastMedia.isHlsReady(widget.streamId);
    if (!mounted || !ready) return;
    await _attach();
  }

  Future<void> _attach() async {
    final url = OwncastMedia.hlsUrl(widget.streamId);
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await controller.initialize();
      await controller.setLooping(false);
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _controller?.dispose();
      setState(() {
        _controller = controller;
        _ready = true;
        _status = '';
      });
      _poll?.cancel();
    } catch (_) {
      await controller.dispose();
      if (mounted) {
        setState(() => _status = 'Reconnecting…');
      }
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ready && _controller != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller!.value.size.width == 0
                  ? 16
                  : _controller!.value.size.width,
              height: _controller!.value.size.height == 0
                  ? 9
                  : _controller!.value.size.height,
              child: VideoPlayer(_controller!),
            ),
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

    return AnimatedBuilder(
      animation: widget.pulse,
      builder: (context, _) {
        final t = widget.pulse.value;
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
              CircleAvatar(
                radius: 48,
                backgroundColor: HubsomColors.forest,
                child: Text(
                  widget.hostName.isNotEmpty
                      ? widget.hostName[0].toUpperCase()
                      : 'H',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                widget.hostName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        );
      },
    );
  }
}
