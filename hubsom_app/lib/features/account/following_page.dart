import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/core_providers.dart';

class FollowingPage extends ConsumerWidget {
  const FollowingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final ids = user?.followingSellerIds ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('Following')),
      body: FutureBuilder(
        future: ref.read(catalogRepositoryProvider).listSellers(),
        builder: (context, snap) {
          final sellers = (snap.data ?? []).where((s) => ids.contains(s.id)).toList();
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          if (sellers.isEmpty) return const Center(child: Text('Not following any sellers yet'));
          return ListView.builder(
            itemCount: sellers.length,
            itemBuilder: (_, i) {
              final s = sellers[i];
              return ListTile(
                title: Text(s.name),
                subtitle: Text('${s.city} · ${s.followers} followers'),
                onTap: () => context.push('/stores/${s.slug}'),
              );
            },
          );
        },
      ),
    );
  }
}
