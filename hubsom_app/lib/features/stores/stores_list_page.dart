import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../models/seller.dart';
import '../../widgets/hubsom_image.dart';

class StoresListPage extends ConsumerWidget {
  const StoresListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sellersAsync = ref.watch(sellersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Stores')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: sellersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(child: Text('Could not load stores')),
            data: (sellers) {
              if (sellers.isEmpty) {
                return const Center(child: Text('No stores yet'));
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                itemCount: sellers.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) => _StoreTile(seller: sellers[i]),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StoreTile extends StatelessWidget {
  const _StoreTile({required this.seller});

  final Seller seller;

  @override
  Widget build(BuildContext context) {
    final initial = seller.name.isNotEmpty
        ? seller.name.substring(0, 1).toUpperCase()
        : 'S';
    return ListTile(
      onTap: () => context.push('/stores/${seller.slug}'),
      leading: CircleAvatar(
        backgroundColor: HubsomColors.mint,
        child: seller.avatar.trim().isEmpty
            ? Text(
                initial,
                style: const TextStyle(
                  color: HubsomColors.forest,
                  fontWeight: FontWeight.w800,
                ),
              )
            : ClipOval(
                child: HubsomImage(
                  url: seller.avatar,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  placeholder: Container(
                    width: 40,
                    height: 40,
                    color: HubsomColors.mint,
                    alignment: Alignment.center,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: HubsomColors.forest,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
      ),
      title: Text(
        seller.name,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(seller.displayLocation),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
