import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../core/utils/money.dart';

class HuberEarningsPage extends ConsumerWidget {
  const HuberEarningsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final repo = ref.watch(huberRepositoryProvider);
    final profile = user == null ? null : repo.profileFor(user);
    final completed = profile == null ? const [] : repo.completed(profile);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Text(
          'Earnings',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: HubsomColors.huberNavy,
              ),
        ),
        const SizedBox(height: 4),
        const Text('Weight + distance pricing · never per product'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _stat(context, 'Today', formatGhs(profile?.todayEarningsGhs ?? 0))),
            const SizedBox(width: 12),
            Expanded(child: _stat(context, 'Completed', '${profile?.completedCount ?? 0}')),
          ],
        ),
        const SizedBox(height: 20),
        if (completed.isEmpty)
          const Text('No earnings yet. Complete deliveries to see totals here.')
        else
          ...completed.map(
            (d) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(d.customerName.isEmpty ? d.sellerName : d.customerName),
              subtitle: Text(d.dropoffAddress),
              trailing: Text(formatGhs(d.feeGhs), style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
      ],
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
        ],
      ),
    );
  }
}
