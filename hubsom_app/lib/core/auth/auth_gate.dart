import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/core_providers.dart';
import '../theme/hubsom_colors.dart';
import '../../widgets/hubsom_logo.dart';

/// Wraps a screen that must only render for signed-in users.
class AuthGate extends ConsumerWidget {
  const AuthGate({
    super.key,
    required this.child,
    this.requireSeller = false,
    this.requireHuber = false,
    this.message = 'Sign in to continue',
  });

  final Widget child;
  final bool requireSeller;
  final bool requireHuber;
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);

    return auth.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      // Treat restore failures as signed-out — never dump Dio/HTML.
      error: (_, __) => _LockedScaffold(
        title: 'Sign in required',
        message: message,
        primaryLabel: 'Sign in',
        onPrimary: () {
          final here = GoRouterState.of(context).uri.toString();
          context.go(
            '/auth/sign-in?callbackUrl=${Uri.encodeComponent(here)}',
          );
        },
        secondaryLabel: 'Create account',
        onSecondary: () => context.go('/auth/sign-up'),
      ),
      data: (user) {
        if (user == null) {
          return _LockedScaffold(
            title: 'Sign in required',
            message: message,
            primaryLabel: 'Sign in',
            onPrimary: () {
              final here = GoRouterState.of(context).uri.toString();
              context.go(
                '/auth/sign-in?callbackUrl=${Uri.encodeComponent(here)}',
              );
            },
            secondaryLabel: 'Create account',
            onSecondary: () => context.go('/auth/sign-up'),
          );
        }

        if (requireSeller &&
            user.role != 'seller' &&
            user.role != 'both' &&
            user.role != 'admin') {
          return _LockedScaffold(
            title: 'Seller access required',
            message:
                'This area is for Hubsom sellers. Update your account role or open a store.',
            primaryLabel: 'Account',
            onPrimary: () => context.go('/account'),
            secondaryLabel: 'Home',
            onSecondary: () => context.go('/'),
          );
        }

        if (requireHuber && !user.isHuber && user.role != 'admin') {
          return _LockedScaffold(
            title: 'Hail Rider access required',
            message:
                'This area is for Hail Riders. Create a Hail Rider account to receive Hubsom delivery offers.',
            primaryLabel: 'Create Hail Rider account',
            onPrimary: () => context.go('/auth/sign-up?role=huber&callbackUrl=%2Fhuber'),
            secondaryLabel: 'Account',
            onSecondary: () => context.go('/account'),
          );
        }

        return child;
      },
    );
  }
}

class _LockedScaffold extends StatelessWidget {
  const _LockedScaffold({
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.onSecondary,
  });

  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String secondaryLabel;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const HubsomLogo(height: 56, showWordmark: true),
                const SizedBox(height: 24),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: HubsomColors.forest,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(onPressed: onPrimary, child: Text(primaryLabel)),
                ),
                TextButton(onPressed: onSecondary, child: Text(secondaryLabel)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
