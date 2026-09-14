import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';
import '../services/local_store.dart';
import 'idle_session.dart';

/// Watches pointer/key activity and signs the user out after 30 idle minutes.
class IdleSessionGuard extends ConsumerStatefulWidget {
  const IdleSessionGuard({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<IdleSessionGuard> createState() => _IdleSessionGuardState();
}

class _IdleSessionGuardState extends ConsumerState<IdleSessionGuard>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_onKey);
    _timer = Timer.periodic(IdleSession.checkEvery, (_) {
      unawaited(_check());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_check());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKey);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_check(activity: true));
    }
  }

  bool _onKey(KeyEvent event) {
    if (event is KeyDownEvent) _onActivity();
    return false;
  }

  void _onActivity() {
    if (ref.read(authStateProvider).valueOrNull == null) return;
    unawaited(IdleSession.touch());
  }

  Future<void> _check({bool activity = false}) async {
    if (IdleSession.isExpired()) {
      await IdleSession.expireIfIdle();
      if (!mounted) return;
      ref.read(authStateProvider.notifier).forceSignedOut();
      return;
    }

    final signedIn = ref.read(authStateProvider).valueOrNull != null ||
        IdleSession.hasSession;
    if (!signedIn) return;

    // Resume or a session that predates idle tracking starts the 30-minute clock.
    if (activity || LocalStore.lastActivityMs == null) {
      await IdleSession.touch();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _onActivity(),
      onPointerSignal: (_) => _onActivity(),
      child: widget.child,
    );
  }
}
