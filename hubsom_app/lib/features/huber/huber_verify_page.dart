import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/hubsom_colors.dart';

class HuberVerifyPage extends ConsumerStatefulWidget {
  const HuberVerifyPage({super.key});

  @override
  ConsumerState<HuberVerifyPage> createState() => _HuberVerifyPageState();
}

class _HuberVerifyPageState extends ConsumerState<HuberVerifyPage> {
  String _idType = 'GHANA_CARD';
  final _idNumber = TextEditingController();
  bool _confirm = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _idNumber.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    final profile = ref.read(huberRepositoryProvider).profileFor(user);
    if (profile == null) {
      setState(() => _error = 'Huber profile not found. Sign up as a Huber driver.');
      return;
    }
    if (!_confirm) {
      setState(() => _error = 'Confirm that this ID belongs to you');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(huberRepositoryProvider).verifyIdentity(
            driver: profile,
            idType: _idType,
            idNumber: _idNumber.text,
          );
      if (mounted) context.go('/huber');
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify identity')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Unlock Hub Now',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: HubsomColors.huberNavy,
                ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Same Hubsom account — confirm Ghana Card, passport, or driver’s license before going online. Ported from the Huber driver app.',
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: _idType,
            items: const [
              DropdownMenuItem(value: 'GHANA_CARD', child: Text('Ghana Card')),
              DropdownMenuItem(value: 'PASSPORT', child: Text('Passport')),
              DropdownMenuItem(value: 'DRIVERS_LICENSE', child: Text('Driver’s license')),
            ],
            onChanged: (v) => setState(() => _idType = v ?? 'GHANA_CARD'),
            decoration: const InputDecoration(labelText: 'ID type'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _idNumber,
            decoration: const InputDecoration(labelText: 'ID number'),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _confirm,
            onChanged: (v) => setState(() => _confirm = v ?? false),
            contentPadding: EdgeInsets.zero,
            title: const Text('I confirm this ID belongs to me'),
          ),
          if (_error != null)
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? 'Verifying…' : 'Submit verification'),
          ),
        ],
      ),
    );
  }
}
