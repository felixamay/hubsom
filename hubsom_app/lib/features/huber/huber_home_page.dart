import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../core/utils/money.dart';
import '../../models/huber.dart';

class HuberHomePage extends ConsumerStatefulWidget {
  const HuberHomePage({super.key});

  @override
  ConsumerState<HuberHomePage> createState() => _HuberHomePageState();
}

class _HuberHomePageState extends ConsumerState<HuberHomePage> {
  HuberProfile? _profile;
  List<HuberOffer> _offers = const [];
  HuberDelivery? _active;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    final repo = ref.read(huberRepositoryProvider);
    await repo.refreshFromCloud();
    final profile = repo.profileFor(user);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _offers = profile == null ? const [] : repo.openOffers(profile);
      _active = profile == null ? null : repo.activeDelivery(profile);
    });
  }

  Future<void> _toggleOnline(bool next) async {
    final profile = _profile;
    if (profile == null) return;
    if (next && !profile.isVerified) {
      if (mounted) context.push('/huber/verify');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      double? lat;
      double? lng;
      if (next) {
        try {
          final pin = await ref.read(locationServiceProvider).current();
          lat = pin.latitude;
          lng = pin.longitude;
        } catch (e) {
          if (mounted) {
            setState(() => _error = '$e');
          }
        }
      }
      final updated = await ref.read(huberRepositoryProvider).setOnline(
            profile,
            next,
            latitude: lat,
            longitude: lng,
          );
      if (!mounted) return;
      setState(() => _profile = updated);
      if (next) context.go('/huber/hub');
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Bad state: ', ''));
      if ('$e'.contains('Verify')) {
        if (mounted) context.push('/huber/verify');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final online = profile?.isOnline ?? false;

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          Text(
            'Deliver Ghana',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: HubsomColors.huberNavy,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            profile == null
                ? 'Sign in as a Hail Rider to receive Hubsom offers.'
                : online
                    ? 'Online · Hubsom dispatch live'
                    : 'Offline',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Chip(
                avatar: Icon(
                  Icons.circle,
                  size: 10,
                  color: online ? HubsomColors.huberOnline : HubsomColors.huberOffline,
                ),
                label: Text(online ? 'Online' : 'Offline'),
                backgroundColor: online
                    ? HubsomColors.huberOnline.withValues(alpha: 0.12)
                    : HubsomColors.mist,
              ),
              const Spacer(),
              Text('Go online', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(width: 8),
              Switch.adaptive(
                value: online,
                onChanged: _busy ? null : _toggleOnline,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: SizedBox(
              width: 180,
              height: 180,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor:
                      online ? HubsomColors.huberNavy : HubsomColors.huberOffline,
                  shape: const CircleBorder(),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
                onPressed: () => _toggleOnline(true),
                child: const Text('Hub Now'),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _pill(
                  context,
                  'Today',
                  formatGhs(profile?.todayEarningsGhs ?? 0),
                  () => context.go('/huber/earnings'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _pill(
                  context,
                  'Wallet',
                  formatGhs(profile?.walletBalanceGhs ?? 0),
                  () => context.go('/huber/wallet'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Current work', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const Divider(),
          if (_active != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_active!.customerName.isEmpty ? 'Active delivery' : _active!.customerName),
              subtitle: Text(_active!.stepLabel),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/huber/delivery/${_active!.id}'),
            )
          else
            const Text('No active deliveries'),
          const SizedBox(height: 16),
          Text(
            'Pending offers (${_offers.length})',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const Divider(),
          if (_offers.isEmpty)
            const Text('No pending offers')
          else
            ..._offers.map(
              (o) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(o.recipientName.isEmpty ? o.sellerName : o.recipientName),
                subtitle: Text(
                  [
                    if (o.pickupDistanceLabel.isNotEmpty) o.pickupDistanceLabel,
                    o.dropoffCity,
                    formatGhs(o.offeredFeeGhs ?? 0),
                  ].join(' · '),
                ),
                onTap: () => context.go('/huber/hub'),
              ),
            ),
          const SizedBox(height: 16),
          Text('Performance', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _metric('Acceptance', '${((profile?.acceptanceRate ?? 0) * 100).round()}%'),
              _metric('Completed', '${profile?.completedCount ?? 0}'),
              _metric('Rating', (profile?.rating ?? 0) == 0 ? '—' : (profile!.rating).toStringAsFixed(1)),
            ],
          ),
          if (!(_profile?.isVerified ?? false)) ...[
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                leading: const Icon(Icons.verified_user_outlined, color: HubsomColors.huberNavy),
                title: const Text('Verify identity'),
                subtitle: const Text('Required before Hub Now'),
                onTap: () => context.push('/huber/verify'),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
    );
  }

  Widget _pill(BuildContext context, String label, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: HubsomColors.huberNavy.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
      ],
    );
  }
}
