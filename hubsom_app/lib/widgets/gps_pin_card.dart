import 'package:flutter/material.dart';

import '../core/theme/hubsom_colors.dart';
import '../models/user.dart';

/// Shared “allow GPS” card for sellers and buyers.
class GpsPinCard extends StatelessWidget {
  const GpsPinCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.pin,
    required this.busy,
    required this.onUseLocation,
    this.error,
  });

  final String title;
  final String subtitle;
  final GeoLocation? pin;
  final bool busy;
  final VoidCallback onUseLocation;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final loc = pin;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HubsomColors.mint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          if (loc != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.my_location, color: HubsomColors.live),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${loc.coordinateLabel}${loc.source == 'gps' ? ' · GPS' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: busy ? null : onUseLocation,
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
            label: Text(loc == null ? 'Allow location' : 'Update GPS pin'),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
