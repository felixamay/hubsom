import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../models/stream.dart';
import '../../models/user.dart';
import 'local_store.dart';

/// Who a live viewer is, and whether this stream has already counted them.
///
/// The viewer count used to be a bare increment on every room entry, so a
/// seller stepping out to Home and back added a view each time, and the host
/// counted as part of their own audience. A join is deliberately remembered for
/// good rather than released on leaving: clearing it would race a fast
/// leave-then-rejoin and could drive the count below the real audience.
class LiveViewerIdentity {
  LiveViewerIdentity._();

  static const _peerKey = 'liveViewerPeerId';
  static const _countedKey = 'liveCountedViews';

  /// Remember at most this many joins. Enough to stop a viewer being counted
  /// twice for shows they are realistically still moving between.
  static const _maxRemembered = 60;

  static const _uuid = Uuid();

  /// Stable id for this viewer: their account when signed in, otherwise a
  /// per-device id. Also used as the WebRTC signaling peer id, so presence and
  /// the viewer count always refer to the same person.
  static String current({String? userId}) {
    final id = (userId ?? '').trim();
    if (id.isNotEmpty) return id;
    final existing = _read(_peerKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = 'v_${_uuid.v4()}';
    LocalStore.setString(_peerKey, generated);
    return generated;
  }

  /// The signed-in user straight from local storage.
  ///
  /// Needed because the auth provider reports null while it is still loading,
  /// and during that window a seller would be treated as a viewer of their own
  /// show — subscribing to their own audio, which is heard as a loud echo.
  static HubsomUser? localUser() {
    try {
      final raw = LocalStore.userJson;
      if (raw == null || raw.isEmpty) return null;
      return HubsomUser.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  /// True when this person is running the show rather than watching it.
  static bool isHost(LiveStream stream, HubsomUser? user) {
    if (user == null) return false;
    final sellerId = (user.sellerId ?? '').trim();
    if (sellerId.isNotEmpty && sellerId == stream.sellerId) return true;
    return stream.hosts.any((h) => h.id == user.id);
  }

  static String _token(String streamId, String viewerId) =>
      '$streamId|$viewerId';

  /// Whether [viewerId] has already been counted towards [streamId].
  static bool alreadyCounted(String streamId, String viewerId) =>
      _counted().contains(_token(streamId, viewerId));

  static Future<void> markCounted(String streamId, String viewerId) async {
    final token = _token(streamId, viewerId);
    final list = _counted()..remove(token);
    list.add(token);
    while (list.length > _maxRemembered) {
      list.removeAt(0);
    }
    await _write(list);
  }

  static List<String> _counted() {
    final raw = _read(_countedKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.map((e) => '$e').where((e) => e.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _write(List<String> list) async {
    try {
      await LocalStore.setString(_countedKey, jsonEncode(list));
    } catch (_) {
      // Losing the record only risks counting a view twice.
    }
  }

  static String? _read(String key) {
    try {
      return LocalStore.getString(key);
    } catch (_) {
      // LocalStore may not be initialised yet (tests, early startup).
      return null;
    }
  }
}
