import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'api_client.dart';
import 'api_response.dart';
import 'agora_rtc_bridge_io.dart'
    if (dart.library.html) 'agora_rtc_bridge_web.dart';

/// Agora live streaming — same provider as the existing Hubsom web app.
/// On Flutter web the RTC engine is stubbed so the live room never white-screens.
class AgoraService {
  AgoraService(this._api);

  final ApiClient _api;
  final _bridge = AgoraRtcBridge.instance;

  bool get joined => _bridge.joined;

  Future<String?> fetchToken({
    required String channelName,
    required int uid,
    String role = 'subscriber',
  }) async {
    try {
      final res = await _api.post(
        '/api/agora/token',
        data: {'channelName': channelName, 'uid': uid, 'role': role},
      );
      return ApiResponse.asMap(res.data)?['token'] as String?;
    } catch (e) {
      if (kDebugMode) debugPrint('Agora token error: $e');
      return null;
    }
  }

  Future<void> joinAsAudience({
    required String channelName,
    required String token,
    int uid = 0,
  }) =>
      _bridge.joinAsAudience(
        channelName: channelName,
        token: token,
        uid: uid,
      );

  Future<void> joinAsHost({
    required String channelName,
    required String token,
    int uid = 0,
  }) =>
      _bridge.joinAsHost(
        channelName: channelName,
        token: token,
        uid: uid,
      );

  Future<void> leave() => _bridge.leave();

  Future<void> dispose() => _bridge.dispose();

  bool get configured => AppConfig.agoraAppId.isNotEmpty;
}
