import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/services/local_store.dart';
import '../../core/theme/hubsom_colors.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final TextEditingController _owncastUrl;
  late final TextEditingController _owncastRtmp;
  late final TextEditingController _owncastToken;
  bool _saving = false;
  String? _savedNote;

  @override
  void initState() {
    super.initState();
    _owncastUrl = TextEditingController(text: AppConfig.owncastBaseUrl);
    _owncastRtmp = TextEditingController(text: AppConfig.owncastRtmpUrl);
    _owncastToken = TextEditingController(text: AppConfig.owncastMediaToken);
  }

  @override
  void dispose() {
    _owncastUrl.dispose();
    _owncastRtmp.dispose();
    _owncastToken.dispose();
    super.dispose();
  }

  Future<void> _saveOwncast() async {
    setState(() {
      _saving = true;
      _savedNote = null;
    });
    final url = _owncastUrl.text.trim();
    final rtmp = _owncastRtmp.text.trim();
    final token = _owncastToken.text.trim();
    await LocalStore.setString('owncastBaseUrl', url.isEmpty ? null : url);
    await LocalStore.setString('owncastRtmpUrl', rtmp.isEmpty ? null : rtmp);
    await LocalStore.setString(
      'owncastMediaToken',
      token.isEmpty ? null : token,
    );
    AppConfig.owncastBaseUrlOverride = url.isEmpty ? null : url;
    AppConfig.owncastRtmpUrlOverride = rtmp.isEmpty ? null : rtmp;
    AppConfig.owncastMediaTokenOverride = token.isEmpty ? null : token;
    if (!mounted) return;
    setState(() {
      _saving = false;
      _savedNote = url.isEmpty
          ? 'Owncast URL cleared. Live stays offline until a VPS is connected.'
          : 'Owncast VPS saved. Live HLS and video uploads will use this host.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final owncastReady = AppConfig.owncastConfigured;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('API base URL'),
            subtitle: Text(AppConfig.apiBaseUrl),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Firebase'),
            subtitle: Text(
              AppConfig.firebaseEnabled ? 'Enabled' : 'Optional / disabled',
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Agora'),
            subtitle: Text(
              AppConfig.agoraAppId.isEmpty
                  ? 'Unused — live uses Owncast HLS'
                  : 'Configured (unused for live)',
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Maps'),
            subtitle: const Text(
              'flutter_map · OpenStreetMap · ORS / OSRM / GraphHopper',
            ),
          ),
          const Divider(height: 32),
          Text(
            'Owncast live + video VPS',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: HubsomColors.forest,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            owncastReady
                ? 'Connected. Hosts publish RTMP; viewers play HLS; shop clips upload to /media.'
                : 'Not connected. Buy a VPS, install deploy/owncast, then paste the public HTTPS URL here (or send it to be baked into the build).',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _owncastUrl,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Owncast public URL',
              hintText: 'https://live.your-vps.com',
              helperText: 'Leave empty until the VPS is ready',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _owncastRtmp,
            decoration: const InputDecoration(
              labelText: 'RTMP ingest override (optional)',
              hintText: 'rtmp://live.your-vps.com:1936/hubsom',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _owncastToken,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Media upload token (optional)',
              helperText: 'Must match HUBSOM_MEDIA_TOKEN on the VPS',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : _saveOwncast,
            child: Text(_saving ? 'Saving…' : 'Save Owncast VPS'),
          ),
          if (_savedNote != null) ...[
            const SizedBox(height: 8),
            Text(
              _savedNote!,
              style: const TextStyle(
                color: HubsomColors.forest,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Push notifications'),
            value: true,
            onChanged: (_) {},
          ),
        ],
      ),
    );
  }
}
