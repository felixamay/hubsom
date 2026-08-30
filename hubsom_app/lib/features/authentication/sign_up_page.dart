import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_routes.dart';
import '../../core/providers/core_providers.dart';
import '../../core/repositories/auth_repository.dart';
import '../../models/huber.dart';
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
  final _phone = TextEditingController();
  final _city = TextEditingController(text: 'Accra');
  final _plate = TextEditingController();
  final _emergencyName = TextEditingController();
  final _emergencyPhone = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _role = 'buyer';
  String _vehicle = HuberVehicleType.motorcycle;
  bool _busy = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final requested = GoRouterState.of(context).uri.queryParameters['role'];
    if (requested != null &&
        const {'buyer', 'seller', 'both', 'huber', 'driver'}.contains(requested) &&
        _role == 'buyer') {
      _role = requested == 'driver' ? 'huber' : requested;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _phone.dispose();
    _city.dispose();
    _plate.dispose();
    _emergencyName.dispose();
    _emergencyPhone.dispose();
    super.dispose();
  }

  String get _callback {
    final cb = GoRouterState.of(context).uri.queryParameters['callbackUrl'];
    if (cb != null && cb.startsWith('/') && !cb.startsWith('//')) return cb;
    return AuthRoutes.isHuberRole(_role) ? '/huber' : '/account';
  }

  bool get _isHuber => AuthRoutes.isHuberRole(_role);

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
            huber: _isHuber
                ? HuberSignUpDetails(
                    phone: _phone.text.trim(),
                    city: _city.text.trim().isEmpty ? 'Accra' : _city.text.trim(),
                    vehicleType: _vehicle,
                    vehiclePlate: _plate.text.trim(),
                    emergencyContactName: _emergencyName.text.trim().isEmpty
                        ? null
                        : _emergencyName.text.trim(),
                    emergencyContactPhone: _emergencyPhone.text.trim().isEmpty
                        ? null
                        : _emergencyPhone.text.trim(),
                  )
                : null,
          );
      final user = ref.read(authStateProvider).valueOrNull;
      if (mounted) {
        context.go(
          AuthRoutes.homeForUser(
            user?.role ?? _role,
            callback: _callback,
            huberId: user?.huberId,
          ),
        );
      }
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
                const SizedBox(height: 12),
                Text(
                  _isHuber
                      ? 'Create a Huber driver account. It is stored in the Hubsom database so you can sign in on any device.'
                      : 'One Hubsom account for shopping, selling, and Huber driving. Saved in the Hubsom database — not only this browser.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
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
                    DropdownMenuItem(value: 'huber', child: Text('Huber driver')),
                  ],
                  onChanged: (v) => setState(() => _role = v ?? 'buyer'),
                  decoration: const InputDecoration(labelText: 'Account type'),
                ),
                if (_isHuber) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Huber driver details',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _phone,
                    decoration: const InputDecoration(labelText: 'Phone'),
                    keyboardType: TextInputType.phone,
                    validator: (v) =>
                        _isHuber && (v == null || v.trim().isEmpty)
                            ? 'Phone required for Huber'
                            : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _city,
                    decoration: const InputDecoration(labelText: 'City'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _vehicle,
                    items: [
                      for (final v in HuberVehicleType.values)
                        DropdownMenuItem(
                          value: v,
                          child: Text(HuberVehicleType.label(v)),
                        ),
                    ],
                    onChanged: (v) =>
                        setState(() => _vehicle = v ?? HuberVehicleType.motorcycle),
                    decoration: const InputDecoration(labelText: 'Vehicle'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _plate,
                    decoration: const InputDecoration(labelText: 'Vehicle plate (optional)'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emergencyName,
                    decoration: const InputDecoration(
                      labelText: 'Emergency contact name (optional)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emergencyPhone,
                    decoration: const InputDecoration(
                      labelText: 'Emergency contact phone (optional)',
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ],
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
                  onPressed: () => context.go(
                    '/auth/sign-in?callbackUrl=${Uri.encodeComponent(_callback)}',
                  ),
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
