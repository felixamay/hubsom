import 'package:flutter/material.dart';

import '../core/services/ghana_places.dart';
import '../core/theme/hubsom_colors.dart';
import '../models/seller.dart';

/// Seller picks nearby cities plus in-zone / out-of-region shipment fees.
class ShipmentZoneFeeFields extends StatefulWidget {
  const ShipmentZoneFeeFields({
    super.key,
    required this.inZoneFee,
    required this.outOfRegionFee,
    required this.selectedCities,
    this.seller,
    this.enabled = true,
    required this.onCitiesChanged,
  });

  final TextEditingController inZoneFee;
  final TextEditingController outOfRegionFee;
  final Set<String> selectedCities;
  final Seller? seller;
  final bool enabled;
  final VoidCallback onCitiesChanged;

  @override
  State<ShipmentZoneFeeFields> createState() => _ShipmentZoneFeeFieldsState();
}

class _ShipmentZoneFeeFieldsState extends State<ShipmentZoneFeeFields> {
  bool _showAllCities = false;

  String? _feeValidator(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return null;
    final n = double.tryParse(raw);
    if (n == null || n < 0) return 'Enter 0 or a valid shipment fee';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final seller = widget.seller;
    final ranked = GhanaPlaces.rankedFrom(
      latitude: seller?.latitude,
      longitude: seller?.longitude,
      city: seller?.city,
    );
    final nearby = ranked.where((e) => e.km <= 80).toList();
    final around = nearby.isNotEmpty ? nearby : ranked.take(8).toList();
    final aroundNames = around.map((e) => e.city).toSet();
    final more = ranked.where((e) => !aroundNames.contains(e.city)).toList();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Shipment fees',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: HubsomColors.forest,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Pick any cities around you for the in-zone fee. Buyers outside those cities pay the out-of-region fee — both are sent to the customer after they purchase.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        Text(
          around.any((e) => e.km.isFinite)
              ? 'Cities around you'
              : 'Cities you ship in-zone',
          style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final place in around)
              FilterChip(
                label: Text(
                  place.km.isFinite && place.km < 1000
                      ? '${place.city} · ${GhanaPlaces.formatDistanceKm(place.km)}'
                      : place.city,
                ),
                selected: widget.selectedCities.contains(place.city),
                onSelected: widget.enabled
                    ? (v) {
                        if (v) {
                          widget.selectedCities.add(place.city);
                        } else {
                          widget.selectedCities.remove(place.city);
                        }
                        widget.onCitiesChanged();
                        setState(() {});
                      }
                    : null,
              ),
          ],
        ),
        if (more.isNotEmpty) ...[
          TextButton(
            onPressed: widget.enabled
                ? () => setState(() => _showAllCities = !_showAllCities)
                : null,
            child: Text(
              _showAllCities
                  ? 'Hide other cities'
                  : 'Select any other city (${more.length})',
            ),
          ),
          if (_showAllCities)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final place in more)
                  FilterChip(
                    label: Text(place.city),
                    selected: widget.selectedCities.contains(place.city),
                    onSelected: widget.enabled
                        ? (v) {
                            if (v) {
                              widget.selectedCities.add(place.city);
                            } else {
                              widget.selectedCities.remove(place.city);
                            }
                            widget.onCitiesChanged();
                            setState(() {});
                          }
                        : null,
                  ),
              ],
            ),
        ],
        if (widget.selectedCities.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'In-zone: ${widget.selectedCities.join(', ')}',
            style: theme.textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 10),
        TextFormField(
          controller: widget.inZoneFee,
          enabled: widget.enabled,
          decoration: const InputDecoration(
            labelText: 'In-zone shipment fee (GHS)',
            helperText: 'Charged when the buyer’s GPS is in a city you selected.',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: _feeValidator,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.outOfRegionFee,
          enabled: widget.enabled,
          decoration: const InputDecoration(
            labelText: 'Out of region shipment fee (GHS)',
            helperText:
                'Charged when the buyer is outside your selected cities. Sent on the order after purchase.',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: _feeValidator,
        ),
      ],
    );
  }
}
