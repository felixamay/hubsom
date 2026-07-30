import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/core_providers.dart';

class SellerGoLivePage extends ConsumerStatefulWidget {
  const SellerGoLivePage({super.key});
  @override
  ConsumerState<SellerGoLivePage> createState() => _SellerGoLivePageState();
}

class _SellerGoLivePageState extends ConsumerState<SellerGoLivePage> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  bool _auction = false;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Go live')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Stream title')),
          const SizedBox(height: 8),
          TextField(controller: _description, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Include live auction'),
            value: _auction,
            onChanged: (v) => setState(() => _auction = v),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : () async {
              setState(() => _busy = true);
              try {
                final stream = await ref.read(liveRepositoryProvider).createStream({
                  'title': _title.text.trim(),
                  'description': _description.text.trim(),
                  'status': 'live',
                  if (_auction) 'auction': true,
                });
                final agora = ref.read(agoraServiceProvider);
                final token = await agora.fetchToken(channelName: stream.channelName, uid: 1, role: 'host');
                if (token != null) {
                  await agora.joinAsHost(channelName: stream.channelName, token: token, uid: 1);
                }
                if (context.mounted) context.go('/live/${stream.id}');
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
            child: Text(_busy ? 'Starting…' : 'Start live stream'),
          ),
        ],
      ),
    );
  }
}
