import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/core_providers.dart';
import '../../core/services/product_photo_compress.dart';
import '../../core/services/product_photo_picker.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../models/user.dart';
import '../../widgets/gps_pin_card.dart';
import '../../widgets/hubsom_image.dart';

class SellerStorePage extends ConsumerStatefulWidget {
  const SellerStorePage({super.key});
  @override
  ConsumerState<SellerStorePage> createState() => _SellerStorePageState();
}

class _SellerStorePageState extends ConsumerState<SellerStorePage> {
  final _name = TextEditingController();
  final _bio = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  String _region = AppConstants.defaultRegion;
  String _avatar = '';
  bool _storeReady = false;
  bool _busy = false;
  bool _picking = false;
  String? _error;
  String? _savedHint;
  GeoLocation? _gps;
  bool _gpsBusy = false;
  String? _gpsError;

  static const _maxStoredBytes = 450_000;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final store = await ref.read(sellerRepositoryProvider).myStore();
    if (store != null && mounted) {
      _name.text = store.name;
      _bio.text = store.bio;
      _address.text = store.address;
      _city.text = store.city;
      setState(() {
        _avatar = store.avatar;
        _region = store.region.trim().isEmpty
            ? AppConstants.defaultRegion
            : store.region.trim();
        _storeReady = true;
        if (store.latitude != null && store.longitude != null) {
          _gps = GeoLocation(
            latitude: store.latitude!,
            longitude: store.longitude!,
            source: 'saved',
          );
        }
      });
    } else if (mounted) {
      setState(() => _storeReady = true);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _address.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    if (_picking || _busy) return;
    setState(() {
      _picking = true;
      _error = null;
      _savedHint = null;
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
        _avatar = 'data:image/jpeg;base64,${base64Encode(compressed)}';
      });
    } catch (_) {
      setState(() => _error = 'Could not pick a profile photo. Try again.');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _useGps() async {
    setState(() {
      _gpsBusy = true;
      _gpsError = null;
    });
    try {
      final pin = await ref.read(locationServiceProvider).current();
      if (!mounted) return;
      setState(() => _gps = pin);
    } catch (e) {
      if (!mounted) return;
      setState(() => _gpsError = '$e');
    } finally {
      if (mounted) setState(() => _gpsBusy = false);
    }
  }

  Future<void> _save() async {
    if (_gps == null) {
      setState(() => _error = 'Allow store location so riders can navigate to pickup.');
      await _useGps();
      if (_gps == null) return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _savedHint = null;
    });
    try {
      await ref.read(sellerRepositoryProvider).updateStore({
        'name': _name.text.trim(),
        'address': _address.text.trim(),
        'city': _city.text.trim().isEmpty
            ? AppConstants.defaultCity
            : _city.text.trim(),
        'region': _region.trim().isEmpty
            ? AppConstants.defaultRegion
            : _region.trim(),
        'bio': _bio.text.trim(),
        'avatar': _avatar,
        if (_gps != null) 'latitude': _gps!.latitude,
        if (_gps != null) 'longitude': _gps!.longitude,
      });
      await ref.read(authStateProvider.notifier).refresh();
      if (!mounted) return;
      setState(() => _savedHint = 'Store profile saved — synced to account');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Store profile saved — photo synced to account'),
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
        : 'S';
    return Scaffold(
      appBar: AppBar(title: const Text('Store settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Store profile picture',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: HubsomColors.forest,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Same photo as your account profile — change either and both stay in sync. Shows on your store and Follow chip.',
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
                      backgroundColor: HubsomColors.forest,
                      child: _avatar.trim().isEmpty
                          ? Text(
                              initial,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                              ),
                            )
                          : ClipOval(
                              child: HubsomImage(
                                url: _avatar,
                                width: 112,
                                height: 112,
                                fit: BoxFit.cover,
                                placeholder: Container(
                                  width: 112,
                                  height: 112,
                                  color: HubsomColors.forest,
                                  alignment: Alignment.center,
                                  child: Text(
                                    initial,
                                    style: const TextStyle(
                                      color: Colors.white,
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
                          onTap: _busy || _picking ? null : _pickAvatar,
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
                  onPressed: _busy || _picking ? null : _pickAvatar,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(
                    _avatar.trim().isEmpty
                        ? 'Add profile picture'
                        : 'Change profile picture',
                  ),
                ),
                if (_avatar.trim().isNotEmpty)
                  TextButton(
                    onPressed: _busy || _picking
                        ? null
                        : () => setState(() => _avatar = ''),
                    child: const Text('Remove photo'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Store name'),
          ),
          const SizedBox(height: 20),
          Text(
            'Store location',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: HubsomColors.forest,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Shown on your public store and sent to Huber riders so they can navigate to pickup with GPS.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          GpsPinCard(
            title: 'Store GPS pin',
            subtitle:
                'Allow location so riders can navigate to your store on OpenStreetMap.',
            pin: _gps,
            busy: _gpsBusy,
            error: _gpsError,
            onUseLocation: _useGps,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _address,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Street / area',
              hintText: 'e.g. Osu Oxford Street',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _city,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'City / town',
              hintText: AppConstants.defaultCity,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: ValueKey('region-$_region-$_storeReady'),
            initialValue: _region,
            decoration: const InputDecoration(labelText: 'Region'),
            items: [
              for (final r in {
                ...AppConstants.ghanaRegions,
                if (_region.isNotEmpty) _region,
              })
                DropdownMenuItem(value: r, child: Text(r)),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _region = value);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bio,
            decoration: const InputDecoration(labelText: 'Bio'),
            maxLines: 4,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_savedHint != null) ...[
            const SizedBox(height: 12),
            Text(
              _savedHint!,
              style: const TextStyle(
                color: HubsomColors.forest,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy || _picking ? null : _save,
            child: Text(_busy ? 'Saving…' : 'Save store'),
          ),
        ],
      ),
    );
  }
}
