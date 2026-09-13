import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/core_providers.dart';
import '../../core/services/shop_video_upload_progress.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../models/shop_video.dart';
import '../../widgets/shop_video_poster.dart';

class SellerVideosPage extends ConsumerStatefulWidget {
  const SellerVideosPage({super.key});

  @override
  ConsumerState<SellerVideosPage> createState() => _SellerVideosPageState();
}

class _SellerVideosPageState extends ConsumerState<SellerVideosPage> {
  List<ShopVideo> _videos = const [];
  bool _loading = true;
  String? _error;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ref.read(catalogRepositoryProvider).myShopVideos();
      if (!mounted) return;
      setState(() {
        _videos = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _confirmDelete(ShopVideo video) async {
    final caption = video.caption.trim();
    final label = caption.isEmpty ? 'this video' : '“$caption”';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete video?'),
        content: Text(
          '$label will be removed from Home, Timeline, and the video feed. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busyId = video.id);
    try {
      await ref.read(catalogRepositoryProvider).deleteShopVideo(video.id);
      ref.invalidate(shopVideosProvider);
      if (!mounted) return;
      setState(() {
        _videos = _videos.where((v) => v.id != video.id).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  String _postedLabel(ShopVideo video) {
    final raw = video.createdAt.trim();
    if (raw.length >= 10) return 'Posted ${raw.substring(0, 10)}';
    return 'Shop clip';
  }

  /// Upload state for one clip. Publish saves locally and uploads in the
  /// background, so this is what tells a seller the clip is still going up.
  Widget? _uploadStatus(ShopVideo video, double? progress) {
    if (progress != null) {
      final percent = (progress * 100).clamp(0, 100).toStringAsFixed(0);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress == 0 ? null : progress,
              minHeight: 4,
              backgroundColor: HubsomColors.mint,
              color: HubsomColors.forest,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Uploading to cloud · $percent%',
            style: const TextStyle(
              color: HubsomColors.forest,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      );
    }
    if (video.hasPublishedMedia) return null;
    return const Padding(
      padding: EdgeInsets.only(top: 6),
      child: Text(
        'Saved on this device · waiting to upload',
        style: TextStyle(
          color: Colors.orange,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My videos'),
        actions: [
          IconButton(
            tooltip: 'Add video',
            onPressed: () async {
              await context.push('/videos/upload');
              if (mounted) _load();
            },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/videos/upload');
          if (mounted) _load();
        },
        icon: const Icon(Icons.movie_creation_outlined),
        label: const Text('Add video'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _videos.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.movie_creation_outlined,
                              size: 48,
                              color: HubsomColors.forest,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No videos yet',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Upload a short clip and link products so shoppers can watch and buy.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: () => context.push('/videos/upload'),
                              child: const Text('Add video'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        itemCount: _videos.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final video = _videos[i];
                          final busy = _busyId == video.id;
                          final caption = video.caption.trim();
                          return ValueListenableBuilder<Map<String, double>>(
                            valueListenable: ShopVideoUploadProgress.active,
                            builder: (context, uploads, _) {
                              final status = _uploadStatus(
                                video,
                                uploads[video.id],
                              );
                              return Material(
                                color: HubsomColors.mist,
                                borderRadius: BorderRadius.circular(14),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () =>
                                      context.push('/videos/${video.id}'),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: SizedBox(
                                            width: 72,
                                            height: 96,
                                            child:
                                                ShopVideoPoster(video: video),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                caption.isEmpty
                                                    ? 'Shop video'
                                                    : caption,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _postedLabel(video),
                                                style: TextStyle(
                                                  color: HubsomColors.ink
                                                      .withValues(alpha: 0.72),
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              if (video
                                                  .productIds.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${video.productIds.length} linked product${video.productIds.length == 1 ? '' : 's'}',
                                                  style: const TextStyle(
                                                    color: HubsomColors.forest,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                              if (status != null) status,
                                            ],
                                          ),
                                        ),
                                        if (busy)
                                          const SizedBox(
                                            width: 28,
                                            height: 28,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        else
                                          PopupMenuButton<String>(
                                            onSelected: (value) async {
                                              if (value == 'watch') {
                                                context.push(
                                                  '/videos/${video.id}',
                                                );
                                              } else if (value == 'delete') {
                                                await _confirmDelete(video);
                                              }
                                            },
                                            itemBuilder: (_) => const [
                                              PopupMenuItem(
                                                value: 'watch',
                                                child: Text('Watch'),
                                              ),
                                              PopupMenuItem(
                                                value: 'delete',
                                                child: Text('Delete video'),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
    );
  }
}
