import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/services/video_frame_thumb.dart';
import '../models/shop_video.dart';
import 'hubsom_image.dart';

/// Still from the shop clip — never the linked product photo.
class ShopVideoPoster extends StatefulWidget {
  const ShopVideoPoster({
    super.key,
    required this.video,
  });

  final ShopVideo video;

  @override
  State<ShopVideoPoster> createState() => _ShopVideoPosterState();
}

class _ShopVideoPosterState extends State<ShopVideoPoster> {
  static final Map<String, Uint8List> _memoryFrames = {};

  Uint8List? _grabbed;
  bool _loading = false;

  String? get _storedThumb {
    final t = widget.video.videoPosterUrl;
    return t;
  }

  @override
  void initState() {
    super.initState();
    _grabbed = _memoryFrames[widget.video.id];
    if (_storedThumb == null && _grabbed == null) {
      _tryGrab();
    }
  }

  @override
  void didUpdateWidget(covariant ShopVideoPoster oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.id != widget.video.id ||
        oldWidget.video.thumbnailUrl != widget.video.thumbnailUrl) {
      _grabbed = _memoryFrames[widget.video.id];
      if (_storedThumb == null && _grabbed == null) {
        _tryGrab();
      } else if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _tryGrab() async {
    final url = widget.video.videoUrl?.trim() ?? '';
    if (!url.startsWith('http://') &&
        !url.startsWith('https://') &&
        !url.startsWith('blob:')) {
      return;
    }
    if (_loading) return;
    _loading = true;
    try {
      final frame = await captureShopVideoFrameFromUrl(url);
      if (frame == null || frame.isEmpty) return;
      _memoryFrames[widget.video.id] = frame;
      if (mounted) setState(() => _grabbed = frame);
    } catch (_) {
    } finally {
      _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final stored = _storedThumb;
    if (stored != null) {
      return HubsomImage(
        url: stored,
        fit: BoxFit.cover,
        placeholder: const ColoredBox(color: Colors.black),
      );
    }
    final grabbed = _grabbed;
    if (grabbed != null && grabbed.isNotEmpty) {
      return Image.memory(
        grabbed,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    }
    return const ColoredBox(color: Colors.black);
  }
}
