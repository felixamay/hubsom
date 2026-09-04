import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/require_auth.dart';
import '../../core/providers/core_providers.dart';
import '../../core/services/product_demo_video_picker.dart';
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
  List<Product> _catalog = const [];
  final Set<String> _selected = {};
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.preselectedProductIds);
    _loadCatalog();
  }

  @override
  void dispose() {
    _caption.dispose();
    _sound.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    setState(() => _loading = true);
    try {
      final products =
          await ref.read(catalogRepositoryProvider).listProducts(limit: 80);
      if (!mounted) return;
      setState(() {
        _catalog = products;
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
          );
      if (!mounted) return;
      context.pushReplacement('/videos/${video.id}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add video')),
      body: _loading
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
                if (_catalog.isEmpty)
                  const Text('No products available to link yet.')
                else
                  ..._catalog.map((p) {
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
