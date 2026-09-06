import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/require_auth.dart';
import '../../core/providers/core_providers.dart';
import '../../core/services/product_demo_video_picker.dart';
import '../../core/services/product_photo_compress.dart';
import '../../core/services/product_photo_picker.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../models/product.dart';
import '../../widgets/hubsom_image.dart';

/// Add a short video independently (not a product listing), then link products.
class UploadVideoPage extends ConsumerStatefulWidget {
  const UploadVideoPage({super.key, this.preselectedProductIds = const []});
  final List<String> preselectedProductIds;

  @override
  ConsumerState<UploadVideoPage> createState() => _UploadVideoPageState();
}

class _UploadVideoPageState extends ConsumerState<UploadVideoPage> {
  final _caption = TextEditingController();
  final _sound = TextEditingController();
  Uint8List? _bytes;
  String _mime = 'video/mp4';
  Uint8List? _thumbBytes;
  final Set<String> _selected = {};
  bool _busy = false;
  bool _pickingThumb = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.preselectedProductIds);
  }

  @override
  void dispose() {
    _caption.dispose();
    _sound.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    setState(() => _error = null);
    try {
      final picked = await pickProductDemoVideo(maxSeconds: 15);
      if (picked == null) return;
      setState(() {
        _bytes = picked.bytes;
        _mime = picked.mimeType;
      });
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  Future<void> _publish() async {
    if (!ensureSignedIn(context, ref, message: 'Sign in to upload a video')) {
      return;
    }
    final bytes = _bytes;
    if (bytes == null || bytes.isEmpty) {
      setState(() => _error = 'Pick a short video first');
      return;
    }
    if (_thumbBytes == null || _thumbBytes!.isEmpty) {
      setState(() => _error = 'Upload a thumbnail from the video');
      return;
    }
    if (_selected.isEmpty) {
      setState(() => _error = 'Link at least one product');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final video = await ref.read(catalogRepositoryProvider).createShopVideo(
            bytes: bytes,
            mimeType: _mime,
            productIds: _selected.toList(),
            caption: _caption.text.trim(),
            soundTitle: _sound.text.trim(),
            thumbnailBytes: _thumbBytes,
          );
      ref.invalidate(shopVideosProvider);
      ref.invalidate(productsProvider((category: null, q: null)));
      if (!mounted) return;
      context.pushReplacement('/videos/${video.id}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickThumbnail() async {
    if (_pickingThumb) return;
    setState(() {
      _error = null;
      _pickingThumb = true;
    });
    try {
      final picked = await pickProductPhotos(remaining: 1);
      if (picked.isEmpty) return;
      final compressed = await compressProductPhoto(
        picked.first.bytes,
        maxSide: 720,
        quality: 74,
      );
      if (!mounted) return;
      if (compressed.isEmpty) {
        setState(() => _error = 'Could not read that photo. Try a JPEG or PNG.');
        return;
      }
      setState(() => _thumbBytes = compressed);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _pickingThumb = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(productsProvider((category: null, q: null)));
    final catalog = catalogAsync.when(
      data: (list) => list.whereType<Product>().toList(),
      loading: () => const <Product>[],
      error: (_, _) => const <Product>[],
    );
    final loadingCatalog = catalogAsync.isLoading && catalog.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Add video')),
      body: loadingCatalog
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HubsomColors.mint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'This is not Add product. You are posting a video clip. Link existing products so watchers open the product page.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pickVideo,
                  icon: const Icon(Icons.video_library_outlined),
                  label: Text(
                    _bytes == null ? 'Pick video (≤15s)' : 'Change video',
                  ),
                ),
                if (_bytes != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Video ready · ${(_bytes!.lengthInBytes / 1024).toStringAsFixed(0)} KB',
                    style: const TextStyle(
                      color: HubsomColors.forest,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  'Thumbnail',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Upload a still from the clip. This is what shoppers see on Home — not the product photo.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                if (_thumbBytes != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            _thumbBytes!,
                            width: 140,
                            height: 200,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: IconButton(
                            visualDensity: VisualDensity.compact,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black54,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _busy || _pickingThumb
                                ? null
                                : () => setState(() => _thumbBytes = null),
                            icon: const Icon(Icons.close, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_thumbBytes != null) const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy || _pickingThumb ? null : _pickThumbnail,
                  icon: _pickingThumb
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.image_outlined),
                  label: Text(
                    _pickingThumb
                        ? 'Preparing thumbnail…'
                        : _thumbBytes == null
                            ? 'Upload thumbnail'
                            : 'Change thumbnail',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _caption,
                  decoration: const InputDecoration(
                    labelText: 'Caption',
                    hintText: 'What are you showing?',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _sound,
                  decoration: const InputDecoration(
                    labelText: 'Sound / music',
                    hintText: 'Original sound - your name',
                    prefixIcon: Icon(Icons.music_note),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Link products (optional openings)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pick products this video should open. Create products separately with Add product.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                if (catalog.isEmpty)
                  const Text('No products available to link yet.')
                else
                  ...catalog.map((p) {
                    final selected = _selected.contains(p.id);
                    final thumb = p.images.isNotEmpty ? p.images.first : '';
                    return CheckboxListTile(
                      value: selected,
                      contentPadding: EdgeInsets.zero,
                      secondary: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: thumb.isEmpty
                            ? Container(
                                width: 44,
                                height: 44,
                                color: HubsomColors.mint,
                                child: const Icon(Icons.shopping_bag_outlined),
                              )
                            : HubsomImage(
                                url: thumb,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                              ),
                      ),
                      title: Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(p.category),
                      onChanged: _busy
                          ? null
                          : (v) {
                              setState(() {
                                if (v == true) {
                                  _selected.add(p.id);
                                } else {
                                  _selected.remove(p.id);
                                }
                              });
                            },
                    );
                  }),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _publish,
                  child: Text(_busy ? 'Publishing video…' : 'Publish video'),
                ),
              ],
            ),
    );
  }
}
