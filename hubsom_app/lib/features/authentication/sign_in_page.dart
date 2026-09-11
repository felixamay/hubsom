import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_routes.dart';
import '../../core/providers/core_providers.dart';
import '../../core/repositories/auth_repository.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../widgets/hubsom_logo.dart';

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String get _callback {
    final cb = GoRouterState.of(context).uri.queryParameters['callbackUrl'];
    if (cb != null && cb.startsWith('/') && !cb.startsWith('//')) return cb;
    return '/account';
  }

  Future<void> _signInWithPasskey() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final email = _email.text.trim();
      await ref.read(authStateProvider.notifier).signInWithPasskey(
            email: email.isEmpty ? null : email,
          );
      final user = ref.read(authStateProvider).valueOrNull;
      if (mounted) {
        context.go(
          AuthRoutes.homeForUser(
            user?.role,
            callback: _callback,
            huberId: user?.huberId,
          ),
        );
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Passkey sign-in failed. Try again or use your password.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authStateProvider.notifier).signIn(
            _email.text.trim(),
            _password.text,
          );
      final user = ref.read(authStateProvider).valueOrNull;
      if (mounted) {
        context.go(
          AuthRoutes.homeForUser(
            user?.role,
            callback: _callback,
            huberId: user?.huberId,
          ),
        );
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Sign in failed. Check your email and password.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const HubsomLogo(height: 56, showWordmark: true),
                const SizedBox(height: 12),
                Text(
                  'Welcome back. Use a passkey or your email and password.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (ref.watch(passkeyBridgeProvider).isSupported) ...[
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _signInWithPasskey,
                    icon: const Icon(Icons.fingerprint),
                    label: Text(_busy ? 'Waiting for passkey…' : 'Sign in with passkey'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: HubsomColors.forest,
                      side: const BorderSide(color: HubsomColors.forest),
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('or use your password'),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  validator: (v) {
                    if (v == null || !v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  validator: (v) {
                    if (v == null || v.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    return null;
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(_busy ? 'Signing in…' : 'Sign in'),
                ),
                TextButton(
                  onPressed: () => context.push(
                    '/auth/sign-up?callbackUrl=${Uri.encodeComponent(_callback)}',
                  ),
                  child: const Text('Create account'),
                ),
                TextButton(
                  onPressed: () => context.push(
                    '/auth/sign-up?role=huber&callbackUrl=${Uri.encodeComponent('/huber')}',
                  ),
                  child: const Text('Create Hail Rider account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
