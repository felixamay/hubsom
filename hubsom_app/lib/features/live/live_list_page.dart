import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../models/stream.dart';

class LiveListPage extends ConsumerWidget {
  const LiveListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streamsAsync = ref.watch(streamsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live shopping'),
        actions: [
          TextButton(onPressed: () => context.push('/seller/go-live'), child: const Text('Go live')),
        ],
      ),
      body: streamsAsync.when(
        data: (streams) {
          final list = streams.cast<LiveStream>();
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('No live shows yet'),
                    const SizedBox(height: 8),
                    const Text(
                      'Sellers can start a show from Seller hub → Go live.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => context.push('/seller/go-live'),
                      child: const Text('Go live'),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final s = list[i];
              return ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: HubsomColors.forest.withValues(alpha: 0.1))),
                leading: CircleAvatar(
                  backgroundColor: s.isLive ? HubsomColors.live : HubsomColors.mint,
                  child: Icon(s.isLive ? Icons.videocam : Icons.replay, color: Colors.white),
                ),
                title: Text(s.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${s.status.toUpperCase()} · ${s.viewerCount} viewers'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/live/${s.id}'),
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
