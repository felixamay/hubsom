import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(title: const Text('API base URL'), subtitle: Text(AppConfig.apiBaseUrl)),
          ListTile(title: const Text('Firebase'), subtitle: Text(AppConfig.firebaseEnabled ? 'Enabled' : 'Optional / disabled')),
          ListTile(title: const Text('Agora'), subtitle: Text(AppConfig.agoraAppId.isEmpty ? 'Not configured' : 'Configured')),
          const ListTile(
            title: Text('Maps'),
            subtitle: Text(
              'flutter_map · OpenStreetMap · rider GPS navigation to seller store and buyer',
            ),
          ),
          SwitchListTile(
            title: const Text('Push notifications'),
            value: true,
            onChanged: (_) {},
          ),
        ],
      ),
    );
  }
}
