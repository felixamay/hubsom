import 'dart:io';

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
    this.showPlayOverlay = true,
  });

  final String productId;
  final String? remoteUrl;
  final double aspectRatio;
  final bool expand;
  final bool autoplay;
  final double borderRadius;

  /// When false, hide the centered play/pause affordance (e.g. home thumbnails).
  final bool showPlayOverlay;

  @override
  State<ProductDemoVideoPlayer> createState() => _ProductDemoVideoPlayerState();
}

class _ProductDemoVideoPlayerState extends State<ProductDemoVideoPlayer> {
  VideoPlayerController? _controller;
  String? _ownedPath;
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
      final path = _ownedPath;
      if (path != null) {
        revokeDemoVideoObjectUrl(path);
        _ownedPath = null;
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
          (remote.startsWith('http://') || remote.startsWith('https://'))) {
        controller = VideoPlayerController.networkUrl(Uri.parse(remote));
      } else {
        final stored = await ProductDemoVideoStore.load(widget.productId);
        if (stored == null) {
          if (mounted) setState(() => _error = 'No demo video');
          return;
        }
        final path = await createDemoVideoObjectUrl(
          bytes: stored.bytes,
          mimeType: stored.mimeType,
        );
        _ownedPath = path;
        controller = VideoPlayerController.file(File(path));
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
    final path = _ownedPath;
    if (path != null) {
      revokeDemoVideoObjectUrl(path);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Container(
        height: widget.expand ? null : 160,
        alignment: Alignment.center,
        color: Colors.black,
        child: Text(_error!, style: const TextStyle(color: Colors.white70)),
      );
    }
    if (!_ready || _controller == null) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(
            color: widget.expand ? Colors.white : HubsomColors.forest,
          ),
        ),
      );
    }
    final c = _controller!;
    void toggle() {
      setState(() {
        if (c.value.isPlaying) {
          c.pause();
        } else {
          c.play();
        }
      });
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
            child: widget.expand
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
          if (widget.showPlayOverlay &&
              (!c.value.isPlaying || !widget.expand))
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

    if (widget.expand) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: video,
      );
    }

    return AspectRatio(
      aspectRatio: c.value.aspectRatio == 0
          ? widget.aspectRatio
          : c.value.aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: video,
      ),
    );
  }
}
