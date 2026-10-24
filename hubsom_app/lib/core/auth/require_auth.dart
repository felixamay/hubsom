import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/core_providers.dart';

/// Returns true if signed in; otherwise navigates to sign-in and returns false.
bool ensureSignedIn(BuildContext context, WidgetRef ref, {String? message}) {
  final user = ref.read(authStateProvider).valueOrNull;
  if (user != null) return true;
  final here = GoRouterState.of(context).uri.toString();
  if (message != null && message.isNotEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
  context.push('/auth/sign-in?callbackUrl=${Uri.encodeComponent(here)}');
  return false;
}
