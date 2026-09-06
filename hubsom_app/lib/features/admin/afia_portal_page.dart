import 'package:flutter/material.dart';

import '../../core/auth/afia_access.dart';
import '../../core/constants/hubsom_commission.dart';
import '../../core/services/admin_account_store.dart';
import '../../core/services/admin_treasury_store.dart';
import '../../core/services/local_commerce_store.dart';
import '../../core/services/local_huber_store.dart';
import '../../core/services/local_promotion_store.dart';
import '../../core/services/local_purchase_offer_store.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../core/utils/money.dart';
import '../../models/seller_payout.dart';
import '../../widgets/hubsom_logo.dart';
import 'admin_accounts_page.dart';
import 'admin_controls_page.dart';
import 'admin_offers_page.dart';
import 'admin_payouts_page.dart';
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
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: HubsomColors.forest,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const HubsomLogo(height: 48, showWordmark: true, linkToHome: false),
                      const SizedBox(height: 20),
                      Text(
                        'Hubsom Admin',
                        textAlign: TextAlign.center,
                        style: text.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: HubsomColors.forest,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Afia console',
                        textAlign: TextAlign.center,
                        style: text.bodyMedium?.copyWith(
                          color: HubsomColors.ink.withValues(alpha: 0.65),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: email,
                        enabled: !busy,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email'),
                        onSubmitted: (_) => onUnlock(),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: password,
                        obscureText: true,
                        enabled: !busy,
                        decoration: const InputDecoration(labelText: 'Password'),
                        onSubmitted: (_) => onUnlock(),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
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

class _AfiaShell extends StatefulWidget {
  const _AfiaShell({required this.onLocked});

  final VoidCallback onLocked;

  @override
  State<_AfiaShell> createState() => _AfiaShellState();
}

class _AfiaShellState extends State<_AfiaShell> {
  int _index = 0;

  static const _destinations = <(IconData, String)>[
    (Icons.dashboard_rounded, 'Overview'),
    (Icons.people_alt_rounded, 'Accounts'),
    (Icons.payments_rounded, 'Payouts'),
    (Icons.toggle_on_rounded, 'Controls'),
    (Icons.campaign_rounded, 'Promotions'),
    (Icons.local_offer_rounded, 'Offers'),
    (Icons.receipt_long_rounded, 'Orders'),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 920;
    final pages = [
      const _OverviewTab(),
      const AdminAccountsPage(),
      const AdminPayoutsPage(),
      const AdminControlsPage(),
      const AfiaPromotionsTab(),
      const AdminOffersPage(embedded: true),
      const _OrdersTab(),
    ];

    final body = AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: KeyedSubtree(
        key: ValueKey(_index),
        child: pages[_index],
      ),
    );

    return Scaffold(
      backgroundColor: HubsomColors.mist,
      appBar: AppBar(
        title: const Text('Hubsom Admin'),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await AfiaAccess.logout();
              widget.onLocked();
            },
            icon: const Icon(Icons.logout),
            label: const Text('Log out'),
          ),
        ],
      ),
      body: wide
          ? Row(
              children: [
                NavigationRail(
                  extended: true,
                  minExtendedWidth: 188,
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  destinations: [
                    for (final item in _destinations)
                      NavigationRailDestination(
                        icon: Icon(item.$1),
                        label: Text(item.$2),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            )
          : body,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                for (final item in _destinations)
                  NavigationDestination(icon: Icon(item.$1), label: item.$2),
              ],
            ),
    );
  }
}

class _OverviewTab extends StatefulWidget {
  const _OverviewTab();

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  List<AdminAccount> _users = const [];
  TreasurySnapshot _treasury = const TreasurySnapshot();

  @override
  void initState() {
    super.initState();
    _users = AdminAccountStore.cached();
    _treasury = AdminTreasuryStore.snapshot();
    AdminAccountStore.list().then((rows) {
      if (mounted) setState(() => _users = rows);
    });
    AdminTreasuryStore.syncFromOrders().then((_) {
      if (mounted) {
        setState(() => _treasury = AdminTreasuryStore.snapshot());
      }
    });
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
    final users = _users;
    final text = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Text(
          'Overview',
          style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Live picture of Hubsom accounts, stores, and commerce. '
          'Product payments land on the admin receive account. '
          'Seller and user accounts withdraw after a '
          '${HubsomCommission.percentLabel} commission.',
          style: text.bodyMedium?.copyWith(color: HubsomColors.ink.withValues(alpha: 0.7)),
        ),
        const SizedBox(height: 16),
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
            _StatChip(label: 'Treasury', value: formatGhs(_treasury.collectedGhs)),
            _StatChip(label: 'To pay', value: formatGhs(_treasury.pendingPayoutsGhs)),
            _StatChip(label: 'Commission', value: formatGhs(_treasury.commissionGhs)),
          ],
        ),
        const SizedBox(height: 24),
        Text('Accounts', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (users.isEmpty)
          const Text('No Hubsom accounts yet')
        else
          for (final account in users.take(12))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(account.user.name),
              subtitle: Text(
                [
                  account.email,
                  account.user.role,
                  if (account.user.suspended) 'suspended',
                ].join(' · '),
              ),
            ),
        const SizedBox(height: 16),
        Text('Live shows', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
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
              if (order.buyerEmail != null && order.buyerEmail!.isNotEmpty) order.buyerEmail!,
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
      width: 112,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HubsomColors.forest.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 22,
              color: HubsomColors.forest,
            ),
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
