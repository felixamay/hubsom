import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../models/stream.dart';
import '../../widgets/hubsom_image.dart';

/// Live shopping directory — Watch live shows currently-on-air shows only.
class LiveListPage extends ConsumerWidget {
  const LiveListPage({super.key, this.liveOnly = true});

  /// When true (default for Watch live), hide ended / scheduled shows.
  final bool liveOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streamsAsync = ref.watch(streamsProvider);
    final signedIn = ref.watch(authStateProvider).valueOrNull != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(liveOnly ? 'Watch live' : 'Live shopping'),
        actions: [
          if (signedIn)
            TextButton(
              onPressed: () => context.push('/seller/go-live'),
              child: const Text('Go live'),
            ),
        ],
      ),
      body: streamsAsync.when(
        data: (streams) {
          final all = streams.whereType<LiveStream>().toList();
          final live = all.where((s) => s.isLive).toList();
          final ended = all.where((s) => !s.isLive).toList();

          if (liveOnly) {
            if (live.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.live_tv_outlined,
                        size: 48,
                        color: HubsomColors.forest.withValues(alpha: 0.45),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No one is live right now',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        signedIn
                            ? 'Check back soon, or go live from Seller hub.'
                            : 'Check back soon for a live show.',
                        textAlign: TextAlign.center,
                      ),
                      if (signedIn) ...[
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => context.push('/seller/go-live'),
                          child: const Text('Go live'),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(streamsProvider),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: live.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _LiveTile(stream: live[i]),
              ),
            );
          }

          if (all.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('No live shows yet'),
                    const SizedBox(height: 8),
                    Text(
                      signedIn
                          ? 'Sellers can start a show from Seller hub → Go live.'
                          : 'Check back soon for a live show.',
                      textAlign: TextAlign.center,
                    ),
                    if (signedIn) ...[
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => context.push('/seller/go-live'),
                        child: const Text('Go live'),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(streamsProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (live.isNotEmpty) ...[
                  Text(
                    'Live now',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 10),
                  ...live.map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _LiveTile(stream: s),
                      )),
                ],
                if (ended.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Ended',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: HubsomColors.ink.withValues(alpha: 0.55),
                        ),
                  ),
                  const SizedBox(height: 10),
                  ...ended.map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _LiveTile(stream: s),
                      )),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}

class _LiveTile extends StatelessWidget {
  const _LiveTile({required this.stream});
  final LiveStream stream;

  @override
  Widget build(BuildContext context) {
    final live = stream.isLive;
    final cover = stream.cover.trim().isNotEmpty ? stream.cover : null;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: HubsomColors.forest.withValues(alpha: 0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/live/${stream.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (cover != null)
                    HubsomImage(
                      url: cover,
                      fit: BoxFit.cover,
                      placeholder: ColoredBox(
                        color: live ? HubsomColors.live : HubsomColors.mint,
                        child: Icon(
                          live ? Icons.videocam : Icons.replay,
                          color: live ? Colors.white : HubsomColors.forest,
                        ),
                      ),
                    )
                  else
                    ColoredBox(
                      color: live ? HubsomColors.live : HubsomColors.mint,
                      child: Icon(
                        live ? Icons.videocam : Icons.replay,
                        color: live ? Colors.white : HubsomColors.forest,
                        size: 40,
                      ),
                    ),
                  Positioned(
                    left: 10,
                    top: 10,
                    child: live
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            color: HubsomColors.live,
                            child: const Text(
                              'LIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            ListTile(
              title: Text(
                stream.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                live
                    ? '${stream.viewerCount} watching'
                    : 'ENDED · ${stream.viewerCount} viewers',
              ),
              trailing: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }
}
