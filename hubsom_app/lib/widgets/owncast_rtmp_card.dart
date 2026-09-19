import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/services/owncast_media.dart';
import '../core/theme/hubsom_colors.dart';

/// Host overlay: Owncast / nginx-rtmp ingest URL + stream key.
class OwncastRtmpCard extends StatelessWidget {
  const OwncastRtmpCard({
    super.key,
    required this.streamId,
    this.compact = false,
  });

  final String streamId;
  final bool compact;

  Future<void> _copy(BuildContext context, String label, String value) async {
    if (value.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied $label')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!OwncastMedia.isConfigured) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: HubsomColors.gold.withValues(alpha: 0.55)),
        ),
        child: const Text(
          'Owncast VPS not connected yet. After you purchase the VPS, send the public URL and this show will stream over HLS.',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      );
    }

    final rtmp = OwncastMedia.rtmpAppUrl;
    final key = OwncastMedia.streamKey(streamId);
    final hls = OwncastMedia.hlsUrl(streamId);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Broadcast to Owncast',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            compact
                ? 'OBS / Larix → RTMP. Viewers watch HLS.'
                : 'Use OBS, Streamlabs, or Larix. Server is RTMP. Stream key is this live id.',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 8),
          _CopyRow(
            label: 'RTMP',
            value: rtmp,
            onCopy: () => _copy(context, 'RTMP URL', rtmp),
          ),
          _CopyRow(
            label: 'Key',
            value: key,
            onCopy: () => _copy(context, 'stream key', key),
          ),
          if (!compact)
            _CopyRow(
              label: 'HLS',
              value: hls,
              onCopy: () => _copy(context, 'HLS URL', hls),
            ),
        ],
      ),
    );
  }
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: 'Copy $label',
            onPressed: value.isEmpty ? null : onCopy,
            icon: const Icon(Icons.copy, color: Colors.white70, size: 16),
          ),
        ],
      ),
    );
  }
}
