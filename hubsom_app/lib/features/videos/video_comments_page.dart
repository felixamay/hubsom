import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/require_auth.dart';
import '../../core/providers/core_providers.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../models/product_social.dart';
import '../../models/shop_video.dart';
import '../../widgets/hubsom_image.dart';

/// Dedicated comments screen for a shop video.
class VideoCommentsPage extends ConsumerStatefulWidget {
  const VideoCommentsPage({super.key, required this.videoId});
  final String videoId;

  @override
  ConsumerState<VideoCommentsPage> createState() => _VideoCommentsPageState();
}

class _VideoCommentsPageState extends ConsumerState<VideoCommentsPage> {
  ShopVideo? _video;
  List<ProductComment> _comments = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  final _commentCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final catalog = ref.read(catalogRepositoryProvider);
      final video = await catalog.getShopVideo(widget.videoId);
      final comments = video == null
          ? const <ProductComment>[]
          : await catalog.listVideoComments(video.id);
      if (!mounted) return;
      setState(() {
        _video = video;
        _comments = comments;
        _loading = false;
        if (video == null) _error = 'Video not found';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _submit() async {
    if (!ensureSignedIn(context, ref, message: 'Sign in to comment')) return;
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _busy = true);
    try {
      final comment = await ref
          .read(catalogRepositoryProvider)
          .addVideoComment(widget.videoId, text);
      _commentCtrl.clear();
      if (!mounted) return;
      setState(() {
        _comments = [comment, ..._comments];
        _busy = false;
      });
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final video = _video;
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        foregroundColor: Colors.white,
        title: Text(
          _loading
              ? 'Comments'
              : '${_comments.length} comment${_comments.length == 1 ? '' : 's'}',
        ),
        actions: [
          if (video != null)
            TextButton(
              onPressed: () => context.push('/videos/${video.id}'),
              child: const Text('Video', style: TextStyle(color: Colors.white70)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                  ),
                if (video != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: HubsomColors.forest,
                          backgroundImage: (video.authorImage ?? '').isNotEmpty
                              ? null
                              : null,
                          child: (video.authorImage ?? '').isNotEmpty
                              ? ClipOval(
                                  child: HubsomImage(
                                    url: video.authorImage!,
                                    width: 32,
                                    height: 32,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Text(
                                  video.authorName.isNotEmpty
                                      ? video.authorName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            video.caption.trim().isEmpty
                                ? '@${video.authorName}'
                                : video.caption,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 1, color: Colors.white12),
                Expanded(
                  child: _comments.isEmpty
                      ? const Center(
                          child: Text(
                            'Be the first to comment',
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : ListView.separated(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          itemCount: _comments.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 14),
                          itemBuilder: (_, i) {
                            final c = _comments[i];
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: HubsomColors.forest,
                                  child: Text(
                                    c.userName.isNotEmpty
                                        ? c.userName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.userName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        c.text,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentCtrl,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Add comment...',
                              hintStyle:
                                  const TextStyle(color: Colors.white38),
                              filled: true,
                              fillColor: Colors.white10,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            onSubmitted: (_) => _submit(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _busy ? null : _submit,
                          style: IconButton.styleFrom(
                            backgroundColor: HubsomColors.gold,
                            foregroundColor: Colors.black,
                          ),
                          icon: _busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
