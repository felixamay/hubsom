import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../widgets/hubsom_image.dart';

class FollowersPage extends ConsumerWidget {
  const FollowersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogRepositoryProvider);
    final followers = catalog.listMyFollowers();
    final count = catalog.myFollowerCount();

    return Scaffold(
      appBar: AppBar(title: Text('Followers ($count)')),
      body: followers.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No followers yet. When shoppers follow your store, they show up here.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              itemCount: followers.length,
              itemBuilder: (_, i) {
                final f = followers[i];
                final name = '${f['name'] ?? 'Hubsom user'}';
                final image = '${f['image'] ?? ''}';
                final initial =
                    name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
                return ListTile(
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
                  title: Text(name),
                  subtitle: Text('${f['email'] ?? ''}'),
                );
              },
            ),
    );
  }
}
