import 'package:flutter/material.dart';

import '../../core/services/admin_controls_store.dart';
import '../../core/theme/hubsom_colors.dart';

class AdminControlsPage extends StatefulWidget {
  const AdminControlsPage({super.key});

  @override
  State<AdminControlsPage> createState() => _AdminControlsPageState();
}

class _AdminControlsPageState extends State<AdminControlsPage> {
  late AdminControls _controls;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controls = AdminControlsStore.current();
    AdminControlsStore.load().then((value) {
      if (mounted) setState(() => _controls = value);
    });
  }

  Future<void> _set(AdminControls next) async {
    setState(() {
      _controls = next;
      _busy = true;
    });
    await AdminControlsStore.save(next);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(
          'Platform controls',
          style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Turn Hubsom features on or off for everyone. Per-account switches live under Accounts.',
          style: text.bodyMedium?.copyWith(color: HubsomColors.ink.withValues(alpha: 0.7)),
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LinearProgressIndicator(),
          ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              _tile('New accounts', 'People can create a Hubsom account', _controls.signupsOpen, (v) => _set(_controls.copyWith(signupsOpen: v))),
              _tile('Shopping', 'Checkout and purchases', _controls.shoppingOpen, (v) => _set(_controls.copyWith(shoppingOpen: v))),
              _tile('Selling', 'Stores, listings, and seller tools', _controls.sellingOpen, (v) => _set(_controls.copyWith(sellingOpen: v))),
              _tile('Live', 'Go live and host shows', _controls.liveOpen, (v) => _set(_controls.copyWith(liveOpen: v))),
              _tile('Messages', 'Buyer and seller chat', _controls.chatOpen, (v) => _set(_controls.copyWith(chatOpen: v))),
              _tile('Wallet', 'Wallet, gifts, and points', _controls.walletOpen, (v) => _set(_controls.copyWith(walletOpen: v))),
              _tile('Hail Rider', 'Driver hub and deliveries', _controls.riderOpen, (v) => _set(_controls.copyWith(riderOpen: v))),
              _tile('Videos', 'Shop video uploads', _controls.videosOpen, (v) => _set(_controls.copyWith(videosOpen: v))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tile(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile.adaptive(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}
