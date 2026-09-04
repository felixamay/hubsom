import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/services/product_demo_blob_url.dart';
import '../core/services/product_demo_video_store.dart';
import '../core/theme/hubsom_colors.dart';

class ProductDemoVideoPlayer extends StatefulWidget {
  const ProductDemoVideoPlayer({
    super.key,
    required this.productId,
    this.remoteUrl,
    this.aspectRatio = 16 / 9,
    this.expand = false,
    this.autoplay = false,
    this.borderRadius = 12,
  });

  final String productId;
  final String? remoteUrl;
  final double aspectRatio;

  /// Fill the parent (carousel stage) instead of intrinsic aspect ratio.
  final bool expand;
  final bool autoplay;
  final double borderRadius;

  @override
  State<ProductDemoVideoPlayer> createState() => _ProductDemoVideoPlayerState();
}

class _ProductDemoVideoPlayerState extends State<ProductDemoVideoPlayer> {
  VideoPlayerController? _controller;
  String? _ownedUrl;
  String? _error;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ProductDemoVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productId != widget.productId ||
        oldWidget.remoteUrl != widget.remoteUrl) {
      _controller?.dispose();
      final url = _ownedUrl;
      if (url != null) {
        revokeDemoVideoObjectUrl(url);
        _ownedUrl = null;
      }
      _controller = null;
      _ready = false;
      _error = null;
      _load();
      return;
    }
    final c = _controller;
    if (c != null && oldWidget.autoplay != widget.autoplay) {
      if (widget.autoplay) {
        c.play();
      } else {
        c.pause();
      }
    }
  }

  Future<void> _load() async {
    try {
      late final VideoPlayerController controller;
      final remote = widget.remoteUrl?.trim();
      if (remote != null &&
          remote.isNotEmpty &&
          (remote.startsWith('http://') ||
              remote.startsWith('https://') ||
              remote.startsWith('blob:') ||
              remote.startsWith('data:'))) {
        controller = VideoPlayerController.networkUrl(Uri.parse(remote));
      } else {
        final stored = await ProductDemoVideoStore.load(widget.productId);
        if (stored == null) {
          if (mounted) setState(() => _error = 'No demo video');
          return;
        }
        final url = await createDemoVideoObjectUrl(
          bytes: stored.bytes,
          mimeType: stored.mimeType,
        );
        _ownedUrl = url;
        controller = VideoPlayerController.networkUrl(Uri.parse(url));
      }

      await controller.initialize();
      controller.setLooping(true);
      controller.addListener(() {
        if (mounted) setState(() {});
      });
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _ready = true;
      });
      if (widget.autoplay) {
        await controller.play();
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not play demo video');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    final url = _ownedUrl;
    if (url != null) {
      revokeDemoVideoObjectUrl(url);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _DemoVideoScaffold(
        error: _error,
        ready: _ready,
        controller: _controller,
        fallbackAspectRatio: widget.aspectRatio,
        expand: widget.expand,
        borderRadius: widget.borderRadius,
      );
}

class _DemoVideoScaffold extends StatelessWidget {
  const _DemoVideoScaffold({
    required this.error,
    required this.ready,
    required this.controller,
    required this.fallbackAspectRatio,
    required this.expand,
    required this.borderRadius,
  });

  final String? error;
  final bool ready;
  final VideoPlayerController? controller;
  final double fallbackAspectRatio;
  final bool expand;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Container(
        height: expand ? null : 160,
        alignment: Alignment.center,
        color: Colors.black,
        child: Text(error!, style: const TextStyle(color: Colors.white70)),
      );
    }
    if (!ready || controller == null) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(
            color: expand ? Colors.white : HubsomColors.forest,
          ),
        ),
      );
    }
    final c = controller!;
    void toggle() {
      if (c.value.isPlaying) {
        c.pause();
      } else {
        c.play();
      }
    }

    final video = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: toggle,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          ColoredBox(
            color: Colors.black,
            child: expand
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: c.value.size.width == 0 ? 16 : c.value.size.width,
                      height:
                          c.value.size.height == 0 ? 9 : c.value.size.height,
                      child: VideoPlayer(c),
                    ),
                  )
                : VideoPlayer(c),
          ),
          // Expand/feed: show play affordance only when paused (video itself is the UI).
          if (!c.value.isPlaying || !expand)
            Icon(
              c.value.isPlaying
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_filled,
              size: 56,
              color: Colors.white,
            ),
        ],
      ),
    );

    if (expand) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: video,
      );
    }

    return AspectRatio(
      aspectRatio:
          c.value.aspectRatio == 0 ? fallbackAspectRatio : c.value.aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: video,
      ),
    );
  }
}
