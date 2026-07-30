import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';

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
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authStateProvider).valueOrNull;
    if (user != null) {
      _name.text = user.name;
      _phone.text = user.phone ?? '';
      _bio.text = user.bio ?? '';
      _city.text = user.city ?? '';
    }
  }

  @override
  void dispose() {
    _name.dispose(); _phone.dispose(); _bio.dispose(); _city.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 8),
          TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone')),
          const SizedBox(height: 8),
          TextField(controller: _city, decoration: const InputDecoration(labelText: 'City')),
          const SizedBox(height: 8),
          TextField(controller: _bio, decoration: const InputDecoration(labelText: 'Bio'), maxLines: 3),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : () async {
              setState(() => _busy = true);
              await ref.read(authRepositoryProvider).updateProfile({
                'name': _name.text.trim(),
                'phone': _phone.text.trim(),
                'city': _city.text.trim(),
                'bio': _bio.text.trim(),
              });
              await ref.read(authStateProvider.notifier).refresh();
              if (mounted) setState(() => _busy = false);
            },
            child: Text(_busy ? 'Saving…' : 'Save'),
          ),
        ],
      ),
    );
  }
}
