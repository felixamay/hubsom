import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/core_providers.dart';
import '../../core/utils/money.dart';
import '../../models/stream.dart';

class AuctionsPage extends ConsumerWidget {
  const AuctionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streamsAsync = ref.watch(streamsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Live auctions')),
      body: streamsAsync.when(
        data: (streams) {
          final auctions = streams.cast<LiveStream>().where((s) => s.auction != null).toList();
          if (auctions.isEmpty) return const Center(child: Text('No auctions open right now'));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: auctions.length,
            itemBuilder: (_, i) {
              final s = auctions[i];
              final a = s.auction!;
              return Card(
                child: ListTile(
                  title: Text(s.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('Current ${formatGhs(a.currentBidGhs)} · ${a.status} · ${a.bidderCount} bidders'),
                  trailing: const Icon(Icons.gavel),
                  onTap: () => context.push('/live/${s.id}'),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}
