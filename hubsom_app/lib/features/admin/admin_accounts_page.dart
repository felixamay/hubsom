import 'package:flutter/material.dart';

import '../../core/services/admin_account_store.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../models/user.dart';

class AdminAccountsPage extends StatefulWidget {
  const AdminAccountsPage({super.key});

  @override
  State<AdminAccountsPage> createState() => _AdminAccountsPageState();
}

class _AdminAccountsPageState extends State<AdminAccountsPage> {
  final _query = TextEditingController();
  List<AdminAccount> _accounts = const [];
  bool _loading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _accounts = AdminAccountStore.cached();
    _loading = _accounts.isEmpty;
    _refresh();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final rows = await AdminAccountStore.list();
    if (!mounted) return;
    setState(() {
      _accounts = rows;
      _loading = false;
    });
  }

  List<AdminAccount> get _visible {
    final q = _query.text.trim().toLowerCase();
    return _accounts.where((a) {
      if (_filter == 'suspended' && !a.user.suspended) return false;
      if (_filter == 'sellers' &&
          a.user.role != 'seller' &&
          a.user.role != 'both' &&
          a.user.role != 'admin') {
        return false;
      }
      if (q.isEmpty) return true;
      return a.user.name.toLowerCase().contains(q) ||
          a.email.contains(q) ||
          a.user.role.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'Hubsom accounts',
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Every account created on Hubsom. Edit, suspend, or delete — and control what each person can do.',
            style: text.bodyMedium?.copyWith(color: HubsomColors.ink.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _query,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Search name, email, or role',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final item in const [
                ('all', 'All'),
                ('sellers', 'Sellers'),
                ('suspended', 'Suspended'),
              ])
                FilterChip(
                  label: Text(item.$2),
                  selected: _filter == item.$1,
                  onSelected: (_) => setState(() => _filter = item.$1),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_visible.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Text('No Hubsom accounts match that search.'),
            )
          else
            for (final account in _visible) _AccountCard(account: account, onChanged: _refresh),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.account, required this.onChanged});

  final AdminAccount account;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final user = account.user;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: CircleAvatar(
          backgroundColor: HubsomColors.mint,
          foregroundColor: HubsomColors.forest,
          child: Text(
            user.name.isEmpty ? '?' : user.name.substring(0, 1).toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
          [
            user.email,
            user.role,
            if (user.suspended) 'suspended',
            if (account.isOwner) 'owner',
          ].join(' · '),
        ),
        trailing: user.suspended
            ? const Chip(label: Text('Suspended'), visualDensity: VisualDensity.compact)
            : const Icon(Icons.chevron_right_rounded),
        onTap: () async {
          await showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (_) => AdminAccountSheet(account: account),
          );
          await onChanged();
        },
      ),
    );
  }
}

class AdminAccountSheet extends StatefulWidget {
  const AdminAccountSheet({super.key, required this.account});

  final AdminAccount account;

  @override
  State<AdminAccountSheet> createState() => _AdminAccountSheetState();
}

class _AdminAccountSheetState extends State<AdminAccountSheet> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _city;
  late String _role;
  late bool _suspended;
  late UserFeatures _features;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = widget.account.user;
    _name = TextEditingController(text: user.name);
    _phone = TextEditingController(text: user.phone ?? '');
    _city = TextEditingController(text: user.city ?? '');
    _role = user.role;
    _suspended = user.suspended;
    _features = user.features;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _city.dispose();
    super.dispose();
  }

  HubsomUser get _draft => widget.account.user.copyWith(
        name: _name.text.trim().isEmpty ? widget.account.user.name : _name.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        city: _city.text.trim().isEmpty ? null : _city.text.trim(),
        role: _role,
        suspended: _suspended,
        features: _features,
      );

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AdminAccountStore.save(_draft);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e'.replaceFirst('Bad state: ', '');
      });
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this account?'),
        content: Text('Remove ${widget.account.email} from Hubsom. They will not be able to sign in.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await AdminAccountStore.delete(widget.account.email);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e'.replaceFirst('Bad state: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final owner = widget.account.isOwner;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              owner ? 'Afia owner' : 'Edit account',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(widget.account.email, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 10),
            TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone')),
            const SizedBox(height: 10),
            TextField(controller: _city, decoration: const InputDecoration(labelText: 'City')),
            const SizedBox(height: 10),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Role'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _role,
                  items: const [
                    DropdownMenuItem(value: 'buyer', child: Text('Buyer')),
                    DropdownMenuItem(value: 'seller', child: Text('Seller')),
                    DropdownMenuItem(value: 'both', child: Text('Buyer & seller')),
                    DropdownMenuItem(value: 'huber', child: Text('Hail Rider')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: owner ? null : (v) => setState(() => _role = v ?? _role),
                ),
              ),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Suspend account'),
              subtitle: const Text('Blocked from signing in and using Hubsom'),
              value: _suspended,
              onChanged: owner ? null : (v) => setState(() => _suspended = v),
            ),
            const SizedBox(height: 8),
            Text('User features', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            _feature('Shop & checkout', _features.canShop, (v) => _features = _features.copyWith(canShop: v)),
            _feature('Sell & store', _features.canSell, (v) => _features = _features.copyWith(canSell: v)),
            _feature('Go live', _features.canLive, (v) => _features = _features.copyWith(canLive: v)),
            _feature('Messages', _features.canChat, (v) => _features = _features.copyWith(canChat: v)),
            _feature('Wallet & gifts', _features.canWallet, (v) => _features = _features.copyWith(canWallet: v)),
            _feature('Hail Rider', _features.canRide, (v) => _features = _features.copyWith(canRide: v)),
            _feature('Upload videos', _features.canVideos, (v) => _features = _features.copyWith(canVideos: v)),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? 'Saving…' : 'Save account'),
            ),
            if (!owner)
              TextButton(
                onPressed: _busy ? null : _delete,
                child: const Text('Delete account'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _feature(String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      value: value,
      onChanged: (v) => setState(() => onChanged(v)),
    );
  }
}
