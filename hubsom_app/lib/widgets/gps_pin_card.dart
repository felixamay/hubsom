import 'package:flutter/material.dart';

import '../core/theme/hubsom_colors.dart';
import '../models/user.dart';

/// Shared “allow GPS” card for sellers and buyers.
class GpsPinCard extends StatelessWidget {
  const GpsPinCard({
    super.key,
    required this.title,
    required this.pin,
    required this.busy,
    required this.onUseLocation,
    this.subtitle,
    this.address,
    this.error,
  });

  final String title;
  final String? subtitle;
  final String? address;
  final GeoLocation? pin;
  final bool busy;
  final VoidCallback onUseLocation;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final place = (address ?? '').trim();
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
          if ((subtitle ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
          ],
          if (place.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.place_outlined, color: HubsomColors.live),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    place,
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
            label: Text(pin == null ? 'Allow location' : 'Update location'),
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
