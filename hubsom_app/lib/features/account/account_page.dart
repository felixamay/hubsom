import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../core/utils/money.dart';
import '../../widgets/hubsom_image.dart';

class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    return auth.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Sign in to manage your Hubsom account'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => context.push('/auth/sign-in'),
            child: const Text('Sign in'),
          ),
          TextButton(
            onPressed: () => context.push('/auth/sign-up'),
            child: const Text('Create account'),
          ),
        ]),
      ),
      data: (user) {
        if (user == null) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Sign in to manage your Hubsom account'),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => context.push('/auth/sign-in'), child: const Text('Sign in')),
              TextButton(onPressed: () => context.push('/auth/sign-up'), child: const Text('Create account')),
            ]),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: HubsomColors.mint,
                child: (user.image ?? '').trim().isEmpty
                    ? Text(
                        user.name.isNotEmpty
                            ? user.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: HubsomColors.forest,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : ClipOval(
                        child: HubsomImage(
                          url: user.image!,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          placeholder: Container(
                            width: 40,
                            height: 40,
                            color: HubsomColors.mint,
                            alignment: Alignment.center,
                            child: Text(
                              user.name.isNotEmpty
                                  ? user.name[0].toUpperCase()
                                  : '?',
                            ),
                          ),
                        ),
                      ),
              ),
              title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${user.email}\nWallet ${formatGhs(user.walletBalanceGhs)}'),
              isThreeLine: true,
              onTap: () => context.push('/account/profile'),
            ),
            const Divider(),
            _link(context, Icons.person_outline, 'Profile', '/account/profile'),
            _link(context, Icons.favorite_border, 'Saved products', '/account/saved'),
            _link(context, Icons.dynamic_feed_outlined, 'Timeline', '/timeline'),
            _link(context, Icons.play_circle_outline, 'Watch videos', '/videos'),
            _link(context, Icons.movie_creation_outlined, 'Add video', '/videos/upload'),
            _link(context, Icons.people_outline, 'Following accounts', '/account/following'),
            _link(context, Icons.groups_outlined, 'Followers', '/account/followers'),
            _link(context, Icons.location_on_outlined, 'Addresses', '/account/addresses'),
            _link(context, Icons.account_balance_wallet_outlined, 'Wallet', '/wallet'),
            _link(context, Icons.notifications_outlined, 'Notifications', '/notifications'),
            _link(context, Icons.chat_bubble_outline, 'Messages', '/messages'),
            _link(context, Icons.settings_outlined, 'Settings', '/settings'),
            if (user.role == 'seller' || user.role == 'both' || user.role == 'admin')
              _link(context, Icons.dashboard_outlined, 'Seller hub', '/seller'),
            if (user.isHuber || user.role == 'admin')
              _link(context, Icons.two_wheeler_outlined, 'Huber driver hub', '/huber'),
            if (!user.isHuber && user.role != 'admin')
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.two_wheeler_outlined, color: HubsomColors.forest),
                title: const Text('Become a Huber driver'),
                subtitle: const Text('Use this same Hubsom account'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await ref.read(authStateProvider.notifier).enableHuber();
                  if (context.mounted) context.go('/huber/verify');
                },
              ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => ref.read(authStateProvider.notifier).signOut(),
              child: const Text('Sign out'),
            ),
          ],
        );
      },
    );
  }

  Widget _link(BuildContext context, IconData icon, String label, String path) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: HubsomColors.forest),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(path),
    );
  }
}
