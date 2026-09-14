import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../config/firebase_options.dart';
import 'local_store.dart';

/// Is there a real Google Cloud Storage bucket behind this Firebase project?
///
/// Firebase Storage has to be turned on in the console before the bucket
/// exists; until then every upload fails after a long retry, which is what
/// used to stall Publish. Probing once and caching the answer lets the app
/// skip Storage entirely while it is missing, and start using it the moment
/// the owner enables it — no new build required.
abstract final class CloudStorageStatus {
  static const _readyKey = 'cloudStorageReady';
  static const _checkedKey = 'cloudStorageCheckedAt';

  /// A missing bucket is rechecked this often so enabling Storage is picked
  /// up by an already-installed app.
  static const _missingRecheck = Duration(minutes: 30);

  static final Dio _http = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      validateStatus: (_) => true,
    ),
  );

  static bool? _cached;
  static Future<bool>? _inFlight;

  /// The bucket the app reads and writes. A `HUBSOM_STORAGE_BUCKET` define
  /// wins, so a bucket created by hand can be used without touching
  /// firebase_options.
  static String get bucket {
    String configured;
    try {
      configured = AppConfig.storageBucket.trim();
    } catch (_) {
      // AppConfig.load() has not run yet.
      configured = '';
    }
    if (configured.isNotEmpty) {
      return configured.replaceFirst(RegExp(r'^gs://'), '');
    }
    return DefaultFirebaseOptions.web.storageBucket ?? '';
  }

  /// True when [bucket] is not the project's default Firebase bucket, so the
  /// Storage SDK has to be pointed at it explicitly.
  static bool get isCustomBucket {
    final fallback = DefaultFirebaseOptions.web.storageBucket ?? '';
    return bucket.isNotEmpty && bucket != fallback;
  }

  /// Last known answer without touching the network. False until the first
  /// probe resolves, so callers that cannot await still behave safely.
  static bool get knownAvailable => _cached ?? _rememberedReady;

  /// LocalStore is `late`-initialised in `main`; widget tests and any call
  /// before init must not throw.
  static bool get _rememberedReady {
    try {
      return LocalStore.getBool(_readyKey, fallback: false);
    } catch (_) {
      return false;
    }
  }

  static Future<void> _remember(bool ready) async {
    try {
      await LocalStore.setBool(_readyKey, ready);
      await LocalStore.setString(
        _checkedKey,
        DateTime.now().toUtc().toIso8601String(),
      );
    } catch (_) {}
  }

  /// Test seam: pretend Storage is or is not there.
  @visibleForTesting
  static set debugOverride(bool? value) {
    _cached = value;
    _inFlight = null;
  }

  static Future<bool> ensureAvailable() {
    final cached = _cached;
    if (cached == true) return Future.value(true);

    if (bucket.isEmpty) return Future.value(false);

    // A previous "yes" is permanent — buckets are not un-created.
    if (_rememberedReady) {
      _cached = true;
      return Future.value(true);
    }
    if (cached == false && !_missingRecheckDue) return Future.value(false);

    return _inFlight ??= _probe().whenComplete(() => _inFlight = null);
  }

  static bool get _missingRecheckDue {
    String? raw;
    try {
      raw = LocalStore.getString(_checkedKey);
    } catch (_) {
      return true;
    }
    if (raw == null || raw.isEmpty) return true;
    final at = DateTime.tryParse(raw);
    if (at == null) return true;
    return DateTime.now().toUtc().difference(at) > _missingRecheck;
  }

  /// The object-list endpoint answers 404 only when the bucket itself is
  /// absent. A live bucket answers 200, or 403 when rules deny listing —
  /// both mean uploads can proceed.
  static Future<bool> _probe() async {
    try {
      final res = await _http.get<dynamic>(
        'https://firebasestorage.googleapis.com/v0/b/$bucket/o',
        queryParameters: const {'maxResults': 1},
      );
      final code = res.statusCode ?? 0;
      if (code == 0) return _cached ?? false;
      final ready = code != 404;
      _cached = ready;
      await _remember(ready);
      if (kDebugMode) {
        debugPrint('CloudStorageStatus: bucket $bucket ready=$ready ($code)');
      }
      return ready;
    } catch (e) {
      // Offline or blocked: do not cache a wrong "missing" answer.
      if (kDebugMode) debugPrint('CloudStorageStatus probe failed: $e');
      return _cached ?? false;
    }
  }
}
