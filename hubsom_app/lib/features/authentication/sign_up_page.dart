import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/core_providers.dart';
import '../../core/repositories/auth_repository.dart';
import '../../widgets/hubsom_logo.dart';

class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _role = 'buyer';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String get _callback {
    final cb = GoRouterState.of(context).uri.queryParameters['callbackUrl'];
    if (cb != null && cb.startsWith('/') && !cb.startsWith('//')) return cb;
    return '/account';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authStateProvider.notifier).signUp(
            email: _email.text.trim(),
            password: _password.text,
            name: _name.text.trim(),
            role: _role,
          );
      if (mounted) context.go(_callback);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not create account');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const HubsomLogo(height: 48, showWordmark: true),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Name required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? 'Valid email required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    helperText: 'At least 8 characters',
                  ),
                  obscureText: true,
                  validator: (v) =>
                      (v == null || v.length < 8) ? 'Min 8 characters' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirm,
                  decoration: const InputDecoration(labelText: 'Confirm password'),
                  obscureText: true,
                  validator: (v) =>
                      v != _password.text ? 'Passwords do not match' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  items: const [
                    DropdownMenuItem(value: 'buyer', child: Text('Buyer')),
                    DropdownMenuItem(value: 'seller', child: Text('Seller')),
                    DropdownMenuItem(value: 'both', child: Text('Buyer & seller')),
                  ],
                  onChanged: (v) => setState(() => _role = v ?? 'buyer'),
                  decoration: const InputDecoration(labelText: 'Account type'),
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
                  child: Text(_busy ? 'Creating…' : 'Create secure account'),
                ),
                TextButton(
                  onPressed: () => context.go('/auth/sign-in'),
                  child: const Text('Already have an account? Sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
