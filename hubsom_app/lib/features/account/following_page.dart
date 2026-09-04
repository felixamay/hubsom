import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final ids = user?.followingSellerIds ?? const <String>[];

    return Scaffold(
      appBar: AppBar(title: Text('Following accounts (${ids.length})')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ids.isEmpty
              ? const Center(child: Text('Not following any accounts yet'))
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
                  : ListView.builder(
                      itemCount: _sellers.length,
                      itemBuilder: (_, i) {
                        final s = _sellers[i];
                        final initial = s.name.isNotEmpty
                            ? s.name.substring(0, 1).toUpperCase()
                            : 'A';
                        return ListTile(
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
                          title: Text(s.name),
                          subtitle: Text(
                            '${s.city} · ${s.followers} followers',
                          ),
                          trailing: TextButton(
                            onPressed: () async {
                              await ref
                                  .read(catalogRepositoryProvider)
                                  .unfollowSeller(s.id);
                              await _load();
                            },
                            child: const Text('Unfollow'),
                          ),
                          onTap: () => context.push('/stores/${s.slug}'),
                        );
                      },
                    ),
    );
  }
}
