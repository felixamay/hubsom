import 'package:flutter/material.dart';

import '../core/theme/hubsom_colors.dart';

/// Mobile/desktop presence panel (full Agora video view can be wired later).
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
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: HubsomColors.forest,
            child: Text(
              hostName.isNotEmpty ? hostName.substring(0, 1).toUpperCase() : 'H',
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
                ? (micOn ? 'You are live' : 'You are live · muted')
                : 'Camera off · you are still live',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
