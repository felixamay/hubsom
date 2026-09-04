import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/require_auth.dart';
import '../../core/providers/core_providers.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../models/seller.dart';
import '../../widgets/hubsom_image.dart';

class FollowersPage extends ConsumerStatefulWidget {
  const FollowersPage({super.key});

  @override
  ConsumerState<FollowersPage> createState() => _FollowersPageState();
}

class _FollowersPageState extends ConsumerState<FollowersPage> {
  final Map<String, Seller?> _stores = {};
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydrateStores());
  }

  Future<void> _hydrateStores() async {
    final catalog = ref.read(catalogRepositoryProvider);
    final followers = catalog.listMyFollowers();
    for (final f in followers) {
      final uid = '${f['userId']}';
      if (uid.isEmpty || _stores.containsKey(uid)) continue;
      final store = await catalog.getSellerByOwnerUserId(uid);
      if (!mounted) return;
      setState(() => _stores[uid] = store);
    }
  }

  Future<void> _message(String userId, String name) async {
    if (!ensureSignedIn(context, ref, message: 'Sign in to message')) return;
    if (userId.isEmpty) return;
    await context.push('/messages/$userId');
  }

  Future<void> _followBack(String userId) async {
    final store = _stores[userId];
    if (store == null) return;
    if (!ensureSignedIn(context, ref, message: 'Sign in to follow')) return;
    setState(() => _busy.add(userId));
    try {
      final catalog = ref.read(catalogRepositoryProvider);
      final following = catalog.isFollowingSeller(store.id);
      if (following) {
        await catalog.unfollowSeller(store.id);
      } else {
        await catalog.followSeller(store.id);
      }
      if (!mounted) return;
      setState(() {});
    } finally {
      if (mounted) setState(() => _busy.remove(userId));
    }
  }

  void _openPerson(String userId) {
    final store = _stores[userId];
    if (store != null) {
      context.push('/stores/${store.slug}');
      return;
    }
    _message(userId, '');
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogRepositoryProvider);
    final me = ref.watch(authStateProvider).valueOrNull;
    final followers = catalog.listMyFollowers();
    final count = catalog.myFollowerCount();

    return Scaffold(
      appBar: AppBar(title: Text('Followers ($count)')),
      body: followers.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No followers yet. When shoppers follow your store, they show up here — then you can message or follow them back.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
              itemCount: followers.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final f = followers[i];
                final userId = '${f['userId']}';
                final name = '${f['name'] ?? 'Hubsom user'}';
                final image = '${f['image'] ?? ''}';
                final email = '${f['email'] ?? ''}';
                final initial =
                    name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
                final store = _stores[userId];
                final isSelf = me?.id == userId;
                final followingStore = store != null &&
                    catalog.isFollowingSeller(store.id);
                final busy = _busy.contains(userId);

                return ListTile(
                  onTap: isSelf ? null : () => _openPerson(userId),
                  leading: CircleAvatar(
                    backgroundColor: HubsomColors.forest,
                    child: image.trim().isEmpty
                        ? Text(
                            initial,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        : ClipOval(
                            child: HubsomImage(
                              url: image,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              placeholder: Container(
                                width: 40,
                                height: 40,
                                color: HubsomColors.forest,
                                alignment: Alignment.center,
                                child: Text(
                                  initial,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    store != null
                        ? '${store.name} · ${catalog.sellerFollowerCount(store.id)} followers'
                        : (email.isNotEmpty ? email : 'Hubsom shopper'),
                  ),
                  isThreeLine: store != null,
                  trailing: isSelf
                      ? const Text('You', style: TextStyle(color: Colors.black45))
                      : Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: 'Message',
                              onPressed: () => _message(userId, name),
                              icon: const Icon(Icons.chat_bubble_outline),
                            ),
                            if (store != null)
                              TextButton(
                                onPressed: busy ? null : () => _followBack(userId),
                                child: Text(
                                  followingStore ? 'Following' : 'Follow back',
                                ),
                              ),
                          ],
                        ),
                );
              },
            ),
    );
  }
}
