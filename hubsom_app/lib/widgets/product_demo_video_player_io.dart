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
  });

  final String productId;
  final String? remoteUrl;
  final double aspectRatio;

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
        height: 160,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: HubsomColors.mist,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(_error!),
      );
    }
    if (!_ready || _controller == null) {
      return const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final c = _controller!;
    return AspectRatio(
      aspectRatio: c.value.aspectRatio == 0
          ? widget.aspectRatio
          : c.value.aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ColoredBox(color: Colors.black, child: VideoPlayer(c)),
            IconButton(
              iconSize: 56,
              color: Colors.white,
              onPressed: () {
                setState(() {
                  if (c.value.isPlaying) {
                    c.pause();
                  } else {
                    c.play();
                  }
                });
              },
              icon: Icon(
                c.value.isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
