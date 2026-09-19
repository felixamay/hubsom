import 'package:flutter/material.dart';

import '../core/theme/hubsom_colors.dart';
import 'owncast_rtmp_card.dart';

/// Mobile/desktop host stage: local presence + Owncast RTMP ingest card.
class LiveHostCamera extends StatelessWidget {
  const LiveHostCamera({
    super.key,
    required this.enabled,
    required this.micOn,
    this.hostName = 'Host',
    this.streamId,
  });

  final bool enabled;
  final bool micOn;
  final String hostName;
  final String? streamId;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0B1F17),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: HubsomColors.forest,
                child: Text(
                  hostName.isNotEmpty
                      ? hostName.substring(0, 1).toUpperCase()
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
                hostName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                enabled
                    ? (micOn
                        ? 'You are live · send RTMP from OBS / Larix'
                        : 'You are live · muted')
                    : 'Camera off · you are still live',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
          if (streamId != null && streamId!.isNotEmpty)
            Positioned(
              left: 12,
              right: 12,
              top: 12,
              child: OwncastRtmpCard(streamId: streamId!, compact: true),
            ),
        ],
      ),
    );
  }
}
