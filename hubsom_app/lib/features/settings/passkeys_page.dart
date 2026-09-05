import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/passkey_models.dart';
import '../../core/providers/core_providers.dart';
import '../../core/repositories/auth_repository.dart';
import '../../core/theme/hubsom_colors.dart';

class PasskeysPage extends ConsumerStatefulWidget {
  const PasskeysPage({super.key});

  @override
  ConsumerState<PasskeysPage> createState() => _PasskeysPageState();
}

class _PasskeysPageState extends ConsumerState<PasskeysPage> {
  bool _busy = false;
  String? _error;

  Future<void> _add() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authStateProvider.notifier).registerPasskey();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passkey saved. You can sign in without typing a password.')),
        );
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not add a passkey on this device.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(PasskeyRecord key) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authStateProvider.notifier).removePasskey(key.id);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not remove that passkey.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(authStateProvider);
    final repo = ref.watch(authRepositoryProvider);
    final keys = repo.listPasskeys();
    final supported = repo.passkeysSupported;
    return Scaffold(
      appBar: AppBar(title: const Text('Passkeys')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          Text(
            'Sign in with Face ID, Touch ID, Windows Hello, or your device lock — no password to remember.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          if (!supported)
            const Card(
              child: ListTile(
                leading: Icon(Icons.info_outline, color: HubsomColors.forest),
                title: Text('Passkeys need a supported browser'),
                subtitle: Text(
                  'Open Hubsom on a phone or computer that offers Face ID, Touch ID, or Windows Hello.',
                ),
              ),
            ),
          if (keys.isEmpty)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('No passkeys yet'),
              subtitle: Text('Add one after you sign in on this device.'),
            )
          else
            for (final key in keys)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.fingerprint, color: HubsomColors.forest),
                  title: Text(key.label),
                  subtitle: Text(
                    key.createdAt.isEmpty
                        ? key.email
                        : 'Added ${key.createdAt.split('T').first}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Remove passkey',
                    onPressed: _busy ? null : () => _remove(key),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy || !supported ? null : _add,
            style: FilledButton.styleFrom(backgroundColor: HubsomColors.forest),
            icon: const Icon(Icons.add),
            label: Text(_busy ? 'Waiting…' : 'Add a passkey'),
          ),
        ],
      ),
    );
  }
}
