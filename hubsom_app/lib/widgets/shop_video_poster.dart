import 'package:flutter/material.dart';

import '../core/services/shop_video_poster_url.dart';
import '../models/shop_video.dart';
import 'hubsom_image.dart';

/// Still from the shop clip — never the linked product photo.
///
/// Uses the stored JPEG only. Do not stream the clip here; Home shows up to
/// 12 cards and downloading each video just for a poster hangs slow links.
class ShopVideoPoster extends StatelessWidget {
  const ShopVideoPoster({
    super.key,
    required this.video,
  });

  final ShopVideo video;

  @override
  Widget build(BuildContext context) {
    final stored = ShopVideoPosterUrl.resolve(video);
    if (stored != null) {
      return HubsomImage(
        url: stored,
        fit: BoxFit.cover,
        placeholder: const ColoredBox(color: Colors.black),
      );
    }
    return const ColoredBox(color: Colors.black);
  }
}
