import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../../models/stream.dart';

class SellerAnalyticsPage extends ConsumerWidget {
  const SellerAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streamsAsync = ref.watch(streamsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: streamsAsync.when(
        data: (streams) {
          final list = streams.cast<LiveStream>();
          if (list.isEmpty) return const Center(child: Text('No stream analytics yet'));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final s = list[i];
              return Card(
                child: ListTile(
                  title: Text(s.title),
                  subtitle: Text('Peak ${s.peakViewers} · Viewers ${s.viewerCount} · Latency ${s.latencyMs}ms'),
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
