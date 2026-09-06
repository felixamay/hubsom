import 'package:flutter/material.dart';

import '../../core/auth/afia_access.dart';
import '../../core/services/local_commerce_store.dart';
import '../../core/services/local_huber_store.dart';
import '../../core/services/local_promotion_store.dart';
import '../../core/services/local_purchase_offer_store.dart';
import '../../core/services/local_store.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../core/utils/money.dart';
import '../../models/user.dart';
import '../../widgets/hubsom_logo.dart';
import 'admin_offers_page.dart';
import 'afia_promotions_tab.dart';

class AfiaPortalPage extends StatefulWidget {
  const AfiaPortalPage({super.key});

  @override
  State<AfiaPortalPage> createState() => _AfiaPortalPageState();
}

class _AfiaPortalPageState extends State<AfiaPortalPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await AfiaAccess.unlock(
      email: _email.text.trim(),
      password: _password.text,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = ok ? null : 'Email or password is not valid for this portal.';
      if (ok) _password.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!AfiaAccess.isUnlocked()) {
      return _AfiaLoginPage(
        email: _email,
        password: _password,
        busy: _busy,
        error: _error,
        onUnlock: _unlock,
      );
    }
    return _AfiaShell(onLocked: () => setState(() {}));
  }
}

class _AfiaLoginPage extends StatelessWidget {
  const _AfiaLoginPage({
    required this.email,
    required this.password,
    required this.busy,
    required this.error,
    required this.onUnlock,
  });

  final TextEditingController email;
  final TextEditingController password;
  final bool busy;
  final String? error;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HubsomColors.forest,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const HubsomLogo(
                        height: 48,
                        showWordmark: true,
                        linkToHome: false,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Hubsom Admin',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: HubsomColors.forest,
                            ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Afia portal',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: email,
                        enabled: !busy,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.username],
                        decoration: const InputDecoration(labelText: 'Email'),
                        onSubmitted: (_) => onUnlock(),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: password,
                        obscureText: true,
                        enabled: !busy,
                        autofillHints: const [AutofillHints.password],
                        decoration: const InputDecoration(labelText: 'Password'),
                        onSubmitted: (_) => onUnlock(),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          error!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: busy ? null : onUnlock,
                        child: Text(busy ? 'Opening…' : 'Sign in'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AfiaShell extends StatelessWidget {
  const _AfiaShell({required this.onLocked});

  final VoidCallback onLocked;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Hubsom Admin'),
          actions: [
            TextButton(
              onPressed: () async {
                await AfiaAccess.lock();
                onLocked();
              },
              child: const Text('Lock'),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Promotions'),
              Tab(text: 'Offers'),
              Tab(text: 'Orders'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _OverviewTab(),
            AfiaPromotionsTab(),
            AdminOffersPage(embedded: true),
            _OrdersTab(),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab();

  static List<HubsomUser> _vaultUsers() {
    final users = <HubsomUser>[];
    for (final entry in LocalStore.loadCredentialVault().values) {
      if (entry is! Map) continue;
      final raw = entry['userJson'];
      if (raw is! Map) continue;
      try {
        users.add(HubsomUser.fromJson(Map<String, dynamic>.from(raw)));
      } catch (_) {}
    }
    return users;
  }

  @override
  Widget build(BuildContext context) {
    final products = LocalCommerceStore.listProducts();
    final sellers = LocalCommerceStore.listSellers();
    final lives = LocalCommerceStore.listStreams();
    final liveNow = lives.where((s) => s.isLive).length;
    final orders = LocalHuberStore.listOrders();
    final offers = LocalPurchaseOfferStore.all();
    final promos = LocalPromotionStore.all();
    final users = _vaultUsers();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _StatChip(label: 'Accounts', value: '${users.length}'),
            _StatChip(label: 'Stores', value: '${sellers.length}'),
            _StatChip(label: 'Products', value: '${products.length}'),
            _StatChip(label: 'Live now', value: '$liveNow'),
            _StatChip(label: 'Orders', value: '${orders.length}'),
            _StatChip(label: 'Offers', value: '${offers.length}'),
            _StatChip(label: 'Promos', value: '${promos.length}'),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Accounts',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        if (users.isEmpty)
          const Text('No saved accounts on this device')
        else
          for (final user in users.take(20))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(user.name),
              subtitle: Text(
                [
                  user.email,
                  user.role,
                  if (user.isHuber) 'rider',
                ].join(' · '),
              ),
            ),
        const SizedBox(height: 16),
        Text(
          'Live shows',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        if (lives.isEmpty)
          const Text('No live shows')
        else
          for (final stream in lives.take(12))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(stream.title),
              subtitle: Text('${stream.status} · ${stream.id}'),
            ),
      ],
    );
  }
}

class _OrdersTab extends StatelessWidget {
  const _OrdersTab();

  @override
  Widget build(BuildContext context) {
    final orders = LocalHuberStore.listOrders();
    if (orders.isEmpty) {
      return const Center(child: Text('No orders yet'));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final order = orders[i];
        final name = order.lines.isEmpty
            ? order.id
            : order.lines.map((l) => l.name).join(', ');
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            [
              order.id,
              order.status,
              formatGhs(order.subtotalGhs),
              if (order.buyerEmail != null && order.buyerEmail!.isNotEmpty)
                order.buyerEmail!,
            ].join(' · '),
          ),
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HubsomColors.mint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 20,
              color: HubsomColors.forest,
            ),
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
