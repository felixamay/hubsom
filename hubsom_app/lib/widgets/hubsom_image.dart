import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Renders http(s) images and `data:` URLs (local product uploads).
class HubsomImage extends StatelessWidget {
  const HubsomImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
  });

  final String? url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    final src = url?.trim() ?? '';
    if (src.isEmpty) {
      return placeholder ??
          Container(
            width: width,
            height: height,
            color: Colors.black12,
            alignment: Alignment.center,
            child: const Icon(Icons.image_not_supported_outlined),
          );
    }

    if (src.startsWith('data:image')) {
      try {
        final b64 = src.split(',').last;
        final bytes = base64Decode(b64);
        return Image.memory(
          bytes,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (_, __, ___) =>
              placeholder ?? const ColoredBox(color: Colors.black12),
        );
      } catch (_) {
        return placeholder ?? const ColoredBox(color: Colors.black12);
      }
    }

    return CachedNetworkImage(
      imageUrl: src,
      fit: fit,
      width: width,
      height: height,
      placeholder: (_, __) =>
          placeholder ?? const Center(child: CircularProgressIndicator()),
      errorWidget: (_, __, ___) =>
          placeholder ?? const ColoredBox(color: Colors.black12),
    );
  }
}
