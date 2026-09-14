import 'package:flutter/foundation.dart';

import '../services/local_store.dart';

/// Signs Hubsom user accounts out after [timeout] with no interaction.
///
/// Last activity is stored on device so a closed tab or killed app still
/// expires the session. Pointer, key, and scroll events refresh the stamp.
abstract final class IdleSession {
  static const Duration timeout = Duration(minutes: 30);
  static const Duration persistThrottle = Duration(seconds: 15);
  static const Duration checkEvery = Duration(seconds: 15);

  /// Overridable in tests.
  static DateTime Function() clock = DateTime.now;

  static bool _clearing = false;

  @visibleForTesting
  static void resetForTest() {
    clock = DateTime.now;
    _clearing = false;
  }

  static bool get hasSession {
    final token = LocalStore.sessionToken;
    return token != null && token.isNotEmpty && LocalStore.userJson != null;
  }

  static bool isExpired([DateTime? at]) {
    if (!hasSession) return false;
    final last = LocalStore.lastActivityMs;
    if (last == null) return false;
    final when = at ?? clock();
    return when.difference(DateTime.fromMillisecondsSinceEpoch(last)) >=
        timeout;
  }

  static Future<void> touch({bool force = false}) async {
    if (!hasSession && !force) return;
    final t = clock().millisecondsSinceEpoch;
    final last = LocalStore.lastActivityMs;
    if (!force &&
        last != null &&
        t - last < persistThrottle.inMilliseconds) {
      return;
    }
    await LocalStore.setLastActivityMs(t);
  }

  /// Drop a stale session from device storage.
  static Future<bool> expireIfIdle() async {
    if (!isExpired()) return false;
    if (_clearing) return true;
    _clearing = true;
    try {
      await LocalStore.clearSession();
      return true;
    } finally {
      _clearing = false;
    }
  }
}
