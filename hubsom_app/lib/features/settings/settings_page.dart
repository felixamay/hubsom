import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/providers/core_providers.dart';
import '../../core/theme/hubsom_colors.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionLabel('Account'),
          ListTile(
            leading: const Icon(Icons.lock_outline, color: HubsomColors.forest),
            title: const Text('Change password'),
            subtitle: Text(
              user?.email ?? 'Update the password for this account',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/password'),
          ),
          ListTile(
            leading: const Icon(Icons.fingerprint, color: HubsomColors.forest),
            title: const Text('Passkeys'),
            subtitle: const Text(
              'Sign in with Face ID, Touch ID, or your device lock',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/passkeys'),
          ),
          const Divider(height: 32),
          const _SectionLabel('App'),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: HubsomColors.forest,
          fontSize: 12,
        ),
      ),
    );
  }
}
