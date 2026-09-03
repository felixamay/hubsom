import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/hubsom_colors.dart';
import '../models/promotion.dart';

class PromoBanner extends StatelessWidget {
  const PromoBanner({super.key, required this.promotions});

  final List<Promotion> promotions;

  @override
  Widget build(BuildContext context) {
    if (promotions.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 140,
      child: PageView.builder(
        itemCount: promotions.length,
        controller: PageController(viewportFraction: 0.92),
        itemBuilder: (context, i) {
          final p = promotions[i];
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: InkWell(
              onTap: p.href != null ? () => context.push(p.href!) : null,
              borderRadius: BorderRadius.circular(14),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (p.imageUrl != null && p.imageUrl!.startsWith('http'))
                      CachedNetworkImage(imageUrl: p.imageUrl!, fit: BoxFit.cover)
                    else
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [HubsomColors.forest, HubsomColors.blue],
                          ),
                        ),
                      ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.65),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            p.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                          if (p.subtitle != null)
                            Text(
                              p.subtitle!,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
