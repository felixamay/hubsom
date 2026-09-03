import 'package:flutter/material.dart';

import '../core/theme/hubsom_colors.dart';

/// Non-web viewer stage (presence only; native Agora path can replace later).
class LiveViewerVideo extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        final t = pulse.value;
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
                  hostName.isNotEmpty ? hostName[0].toUpperCase() : 'H',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                hostName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Live',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        );
      },
    );
  }
}
