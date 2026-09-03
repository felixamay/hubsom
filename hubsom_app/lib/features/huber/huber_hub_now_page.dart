import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../core/utils/money.dart';
import '../../models/huber.dart';

class HuberHubNowPage extends ConsumerStatefulWidget {
  const HuberHubNowPage({super.key});

  @override
  ConsumerState<HuberHubNowPage> createState() => _HuberHubNowPageState();
}

class _HuberHubNowPageState extends ConsumerState<HuberHubNowPage> {
  Timer? _ticker;
  int _ticks = 0;
  HuberProfile? _profile;
  List<HuberOffer> _offers = const [];
  String? _toast;
  bool _busy = false;

  HuberOffer? get _active => _offers.isEmpty ? null : _offers.first;

  @override
  void initState() {
    super.initState();
    _reload();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      _reload(silent: true);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _reload({bool silent = false}) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    final repo = ref.read(huberRepositoryProvider);
    _ticks++;
    if (!silent || _ticks % 5 == 0) await repo.refreshFromCloud();
    final profile = repo.profileFor(user);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _offers = profile == null || !profile.isOnline
          ? const []
          : repo.openOffers(profile);
    });
  }

  Future<void> _respond(bool accept) async {
    final offer = _active;
    final profile = _profile;
    if (offer == null || profile == null) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(huberRepositoryProvider);
      if (accept) {
        final delivery = await repo.acceptOffer(offer.id, profile);
        if (mounted) context.push('/huber/delivery/${delivery.id}');
      } else {
        await repo.declineOffer(offer.id, profile);
        setState(() => _toast = 'Declined — waiting for the next Hubsom offer');
      }
      await _reload();
    } catch (e) {
      setState(() => _toast = e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final online = _profile?.isOnline ?? false;
    final offer = _active;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Text(
          'Hub Now',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: HubsomColors.huberNavy,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          online
              ? 'Live Hubsom dispatch'
              : 'Go online to receive Hubsom delivery offers',
        ),
        if (_toast != null) ...[
          const SizedBox(height: 12),
          Material(
            color: HubsomColors.mint,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_toast!),
            ),
          ),
        ],
        const SizedBox(height: 20),
        if (!online)
          Center(
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: HubsomColors.huberNavy,
                minimumSize: const Size(160, 160),
                shape: const CircleBorder(),
              ),
              onPressed: () async {
                if (_profile == null) return;
                if (!_profile!.isVerified) {
                  context.push('/huber/verify');
                  return;
                }
                await ref.read(huberRepositoryProvider).setOnline(_profile!, true);
                await _reload();
              },
              child: const Text('Hub Now', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            ),
          )
        else if (offer == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: Text('Waiting for Hubsom orders…')),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.sellerName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${offer.secondsRemaining}s remaining',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: HubsomColors.live,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Chip(
                    label: const Text('Source: Hubsom marketplace'),
                    backgroundColor: HubsomColors.mint,
                  ),
                  const SizedBox(height: 12),
                  Text('Pickup · ${offer.pickupLabel}, ${offer.pickupCity}'),
                  Text('Customer · ${offer.recipientName}'),
                  Text('Drop-off · ${offer.dropoffLine1}, ${offer.dropoffCity}'),
                  Text('Packages · ${offer.itemCount} · ${offer.weightLbs.round()} lbs'),
                  Text('Payout · ${formatGhs(offer.offeredFeeGhs ?? 0)}'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy ? null : () => _respond(false),
                          child: const Text('Decline'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _busy ? null : () => _respond(true),
                          child: const Text('Accept'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
