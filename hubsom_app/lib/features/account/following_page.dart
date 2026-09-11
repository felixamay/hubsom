import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/require_auth.dart';
import '../../core/providers/core_providers.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../models/seller.dart';
import '../../widgets/hubsom_image.dart';

class FollowingPage extends ConsumerStatefulWidget {
  const FollowingPage({super.key});

  @override
  ConsumerState<FollowingPage> createState() => _FollowingPageState();
}

class _FollowingPageState extends ConsumerState<FollowingPage> {
  List<Seller> _sellers = const [];
  bool _loading = true;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final user = ref.read(authStateProvider).valueOrNull;
    final ids = user?.followingSellerIds ?? const <String>[];
    final catalog = ref.read(catalogRepositoryProvider);
    final loaded = <Seller>[];
    for (final id in ids) {
      final s = await catalog.getSeller(id);
      if (s != null) loaded.add(s);
    }
    if (!mounted) return;
    setState(() {
      _sellers = loaded;
      _loading = false;
    });
  }

  String _peerId(Seller s) =>
      (s.ownerUserId != null && s.ownerUserId!.isNotEmpty)
          ? s.ownerUserId!
          : s.id;

  Future<void> _message(Seller s) async {
    if (!ensureSignedIn(context, ref, message: 'Sign in to message')) return;
    await context.push('/messages/${_peerId(s)}');
  }

  Future<void> _toggleFollow(Seller s) async {
    if (!ensureSignedIn(context, ref, message: 'Sign in to follow')) return;
    setState(() => _busy.add(s.id));
    try {
      final catalog = ref.read(catalogRepositoryProvider);
      if (catalog.isFollowingSeller(s.id)) {
        await catalog.unfollowSeller(s.id);
      } else {
        await catalog.followSeller(s.id);
      }
      await _load();
    } finally {
      if (mounted) setState(() => _busy.remove(s.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final ids = user?.followingSellerIds ?? const <String>[];
    final catalog = ref.watch(catalogRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Following accounts (${ids.length})')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ids.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Not following any accounts yet. Follow sellers from their store, videos, or timeline — then message them here.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _sellers.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Following ${ids.length} account${ids.length == 1 ? '' : 's'}, but their stores are not loaded yet.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                      itemCount: _sellers.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final s = _sellers[i];
                        final initial = s.name.isNotEmpty
                            ? s.name.substring(0, 1).toUpperCase()
                            : 'A';
                        final busy = _busy.contains(s.id);
                        final following = catalog.isFollowingSeller(s.id);
                        return ListTile(
                          onTap: () => context.push('/stores/${s.slug}'),
                          leading: CircleAvatar(
                            backgroundColor: HubsomColors.forest,
                            child: s.avatar.trim().isEmpty
                                ? Text(
                                    initial,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  )
                                : ClipOval(
                                    child: HubsomImage(
                                      url: s.avatar,
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
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                          title: Text(
                            s.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${s.city} · ${catalog.sellerFollowerCount(s.id)} followers',
                          ),
                          trailing: Wrap(
                            spacing: 0,
                            children: [
                              IconButton(
                                tooltip: 'Message',
                                onPressed: () => _message(s),
                                icon: const Icon(Icons.chat_bubble_outline),
                              ),
                              IconButton(
                                tooltip: 'Visit store',
                                onPressed: () =>
                                    context.push('/stores/${s.slug}'),
                                icon: const Icon(Icons.storefront_outlined),
                              ),
                              TextButton(
                                onPressed: busy ? null : () => _toggleFollow(s),
                                child: Text(following ? 'Unfollow' : 'Follow'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
