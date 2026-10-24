import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../../core/services/product_photo_compress.dart';
import '../../core/services/product_photo_picker.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../widgets/hubsom_image.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});
  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _bio = TextEditingController();
  final _city = TextEditingController();
  String _image = '';
  bool _busy = false;
  bool _picking = false;
  String? _error;

  static const _maxStoredBytes = 450_000;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authStateProvider).valueOrNull;
    if (user != null) {
      _name.text = user.name;
      _phone.text = user.phone ?? '';
      _bio.text = user.bio ?? '';
      _city.text = user.city ?? '';
      _image = user.image ?? '';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _bio.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_picking || _busy) return;
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final picked = await pickProductPhotos(remaining: 1);
      if (picked.isEmpty) return;
      final compressed = await compressProductPhoto(
        picked.first.bytes,
        maxSide: 640,
        quality: 78,
      );
      if (compressed.isEmpty) {
        setState(() => _error = 'Could not use that photo. Try another JPG/PNG.');
        return;
      }
      if (compressed.lengthInBytes > _maxStoredBytes) {
        setState(
          () => _error =
              'Photo is still too large after compress. Try a clearer, smaller shot.',
        );
        return;
      }
      setState(() {
        _image = 'data:image/jpeg;base64,${base64Encode(compressed)}';
      });
    } catch (_) {
      setState(() => _error = 'Could not pick a profile photo. Try again.');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).updateProfile({
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'city': _city.text.trim(),
        'bio': _bio.text.trim(),
        'image': _image,
      });
      await ref.read(authStateProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved — photo syncs with your store'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = _name.text.trim().isNotEmpty
        ? _name.text.trim().substring(0, 1).toUpperCase()
        : '?';
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Profile picture',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: HubsomColors.forest,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Same photo as your seller store — change either and both stay in sync.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          Center(
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 56,
                      backgroundColor: HubsomColors.mint,
                      child: _image.trim().isEmpty
                          ? Text(
                              initial,
                              style: const TextStyle(
                                color: HubsomColors.forest,
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                              ),
                            )
                          : ClipOval(
                              child: HubsomImage(
                                url: _image,
                                width: 112,
                                height: 112,
                                fit: BoxFit.cover,
                                placeholder: Container(
                                  width: 112,
                                  height: 112,
                                  color: HubsomColors.mint,
                                  alignment: Alignment.center,
                                  child: Text(
                                    initial,
                                    style: const TextStyle(
                                      color: HubsomColors.forest,
                                      fontSize: 40,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Material(
                        color: HubsomColors.gold,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _busy || _picking ? null : _pickPhoto,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: _picking
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.camera_alt,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _busy || _picking ? null : _pickPhoto,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(
                    _image.trim().isEmpty
                        ? 'Add profile picture'
                        : 'Change profile picture',
                  ),
                ),
                if (_image.trim().isNotEmpty)
                  TextButton(
                    onPressed: _busy || _picking
                        ? null
                        : () => setState(() => _image = ''),
                    child: const Text('Remove photo'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _phone,
            decoration: const InputDecoration(labelText: 'Phone'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _city,
            decoration: const InputDecoration(labelText: 'City'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _bio,
            decoration: const InputDecoration(labelText: 'Bio'),
            maxLines: 3,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy || _picking ? null : _save,
            child: Text(_busy ? 'Saving…' : 'Save'),
          ),
        ],
      ),
    );
  }
}
