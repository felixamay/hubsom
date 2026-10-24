import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../widgets/hubsom_image.dart';

class FollowingPage extends ConsumerWidget {
  const FollowingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final ids = user?.followingSellerIds ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('Following accounts')),
      body: FutureBuilder(
        future: ref.read(catalogRepositoryProvider).listSellers(),
        builder: (context, snap) {
          final sellers =
              (snap.data ?? []).where((s) => ids.contains(s.id)).toList();
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (sellers.isEmpty) {
            return const Center(
              child: Text('Not following any accounts yet'),
            );
          }
          return ListView.builder(
            itemCount: sellers.length,
            itemBuilder: (_, i) {
              final s = sellers[i];
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
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                ),
                title: Text(s.name),
                subtitle: Text('${s.city} · ${s.followers} followers'),
                trailing: TextButton(
                  onPressed: () async {
                    await ref
                        .read(catalogRepositoryProvider)
                        .unfollowSeller(s.id);
                    ref.invalidate(authStateProvider);
                  },
                  child: const Text('Unfollow'),
                ),
                onTap: () => context.push('/stores/${s.slug}'),
              );
            },
          );
        },
      ),
    );
  }
}
