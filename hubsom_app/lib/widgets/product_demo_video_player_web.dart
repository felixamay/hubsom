import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/services/product_demo_blob_url.dart';
import '../core/services/product_demo_video_store.dart';
import '../core/theme/hubsom_colors.dart';

/// Web: play from local bytes (blob URL) and/or a real http(s) remote URL.
///
/// Desktop browsers block unmuted programmatic [play]. Autoplay always starts
/// muted (`setVolume(0)`). A user tap unmutes.
class ProductDemoVideoPlayer extends StatefulWidget {
  const ProductDemoVideoPlayer({
    super.key,
    required this.productId,
    this.remoteUrl,
    this.aspectRatio = 16 / 9,
    this.autoplay = false,
    this.expand = false,
    this.borderRadius = 14,
    this.showPlayOverlay = true,
  });

  final String productId;
  final String? remoteUrl;
  final double aspectRatio;
  final bool autoplay;
  final bool expand;
  final double borderRadius;
  final bool showPlayOverlay;

  @override
  State<ProductDemoVideoPlayer> createState() => _ProductDemoVideoPlayerState();
}

class _ProductDemoVideoPlayerState extends State<ProductDemoVideoPlayer> {
  VideoPlayerController? _controller;
  String? _ownedBlobUrl;
  bool _ready = false;
  bool _playing = false;
  bool _muted = true;
  String? _error;
  int _loadGen = 0;

  static bool _isPlayableRemote(String? url) {
    final u = (url ?? '').trim();
    return u.startsWith('http://') ||
        u.startsWith('https://') ||
        u.startsWith('blob:');
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void didUpdateWidget(covariant ProductDemoVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productId != widget.productId) {
      _bootstrap();
      return;
    }
    final oldRemote = _isPlayableRemote(oldWidget.remoteUrl)
        ? oldWidget.remoteUrl!.trim()
        : null;
    final newRemote =
        _isPlayableRemote(widget.remoteUrl) ? widget.remoteUrl!.trim() : null;
    if (oldRemote != newRemote && newRemote != null && !_ready) {
      _bootstrap();
      return;
    }
    if (oldWidget.autoplay != widget.autoplay) {
      _applyAutoplay();
    }
  }

  Future<void> _applyAutoplay() async {
    final c = _controller;
    if (c == null || !_ready || c.value.hasError) return;
    try {
      if (widget.autoplay) {
        await _playMuted(c);
      } else {
        // Pause only — seeking to zero on every swipe caused visible flicker.
        await c.pause();
      }
    } catch (_) {}
  }

  /// Programmatic play must be muted on web or the controller becomes erroneous.
  Future<void> _playMuted(VideoPlayerController c) async {
    if (c.value.hasError || !c.value.isInitialized) return;
    await c.setVolume(0);
    if (mounted) setState(() => _muted = true);
    await c.play();
  }

  Future<void> _bootstrap() async {
    final gen = ++_loadGen;
    await _disposeController();
    if (mounted) {
      setState(() {
        _ready = false;
        _playing = false;
        _muted = true;
        _error = null;
      });
    }

    final stored = await ProductDemoVideoStore.load(widget.productId);
    if (!mounted || gen != _loadGen) return;

    if (stored != null && stored.bytes.isNotEmpty) {
      final blobUrl = await createDemoVideoObjectUrl(
        bytes: stored.bytes,
        mimeType: stored.mimeType.isEmpty ? 'video/mp4' : stored.mimeType,
      );
      if (!mounted || gen != _loadGen) {
        revokeDemoVideoObjectUrl(blobUrl);
        return;
      }
      _ownedBlobUrl = blobUrl;
      await _attachController(
        VideoPlayerController.networkUrl(Uri.parse(blobUrl)),
        gen: gen,
      );
      return;
    }

    final remote = widget.remoteUrl?.trim();
    if (_isPlayableRemote(remote)) {
      await _attachController(
        VideoPlayerController.networkUrl(Uri.parse(remote!)),
        gen: gen,
      );
      return;
    }

    if (mounted && gen == _loadGen) {
      setState(() => _error = widget.expand ? null : 'No demo video');
    }
  }

  Future<void> _attachController(
    VideoPlayerController controller, {
    required int gen,
  }) async {
    try {
      await controller.initialize();
      if (!mounted || gen != _loadGen) {
        await controller.dispose();
        return;
      }
      await controller.setLooping(true);
      // Start muted so a later autoplay play() is allowed by the browser.
      await controller.setVolume(0);
      controller.addListener(_onControllerTick);
      _controller = controller;
      setState(() {
        _ready = true;
        _playing = controller.value.isPlaying;
        _muted = true;
        _error = null;
      });
      if (widget.autoplay) {
        await _playMuted(controller);
      }
    } catch (_) {
      try {
        await controller.dispose();
      } catch (_) {}
      if (mounted && gen == _loadGen) {
        setState(
          () => _error = widget.expand ? null : 'Could not play demo video',
        );
      }
    }
  }

  /// Only rebuild on play/pause — never on every frame (that caused timeline flicker).
  void _onControllerTick() {
    final c = _controller;
    if (c == null || !mounted) return;
    if (c.value.hasError) return;
    final playing = c.value.isPlaying;
    if (playing != _playing) {
      setState(() => _playing = playing);
    }
  }

  Future<void> _onTapToggle() async {
    final c = _controller;
    if (c == null || !_ready || c.value.hasError) return;
    try {
      if (c.value.isPlaying) {
        await c.pause();
      } else {
        // User gesture: unmute + play is allowed.
        await c.setVolume(1.0);
        if (mounted) setState(() => _muted = false);
        await c.play();
      }
    } catch (_) {}
  }

  Future<void> _disposeController() async {
    final c = _controller;
    _controller = null;
    if (c != null) {
      c.removeListener(_onControllerTick);
      await c.dispose();
    }
    final blob = _ownedBlobUrl;
    _ownedBlobUrl = null;
    if (blob != null) {
      revokeDemoVideoObjectUrl(blob);
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _DemoVideoScaffold(
        error: _error,
        ready: _ready,
        controller: _controller,
        playing: _playing,
        muted: _muted,
        fallbackAspectRatio: widget.aspectRatio,
        expand: widget.expand,
        borderRadius: widget.borderRadius,
        showPlayOverlay: widget.showPlayOverlay,
        onToggle: _onTapToggle,
      );
}

class _DemoVideoScaffold extends StatelessWidget {
  const _DemoVideoScaffold({
    required this.error,
    required this.ready,
    required this.controller,
    required this.playing,
    required this.muted,
    required this.fallbackAspectRatio,
    required this.expand,
    required this.borderRadius,
    required this.showPlayOverlay,
    required this.onToggle,
  });

  final String? error;
  final bool ready;
  final VideoPlayerController? controller;
  final bool playing;
  final bool muted;
  final double fallbackAspectRatio;
  final bool expand;
  final double borderRadius;
  final bool showPlayOverlay;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return ColoredBox(
        color: Colors.black,
        child: expand
            ? const SizedBox.expand()
            : SizedBox(
                height: 160,
                child: Center(
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ),
      );
    }
    if (!ready || controller == null || controller!.value.hasError) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(
            color: expand ? Colors.white54 : HubsomColors.forest,
            strokeWidth: expand ? 2 : 3,
          ),
        ),
      );
    }
    final c = controller!;

    final video = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          ColoredBox(
            color: Colors.black,
            child: expand
                ? FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: c.value.size.width == 0 ? 16 : c.value.size.width,
                      height:
                          c.value.size.height == 0 ? 9 : c.value.size.height,
                      child: VideoPlayer(c),
                    ),
                  )
                : VideoPlayer(c),
          ),
          if (expand && muted && playing)
            const Positioned(
              right: 12,
              top: 12,
              child: IgnorePointer(
                child: Icon(
                  Icons.volume_off,
                  color: Colors.white70,
                  size: 22,
                ),
              ),
            ),
          if (showPlayOverlay && (!playing || !expand))
            Icon(
              playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
              size: 56,
              color: Colors.white,
            ),
        ],
      ),
    );

    if (expand) return video;
    final ratio = c.value.aspectRatio == 0
        ? fallbackAspectRatio
        : c.value.aspectRatio;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: AspectRatio(aspectRatio: ratio, child: video),
    );
  }
}
