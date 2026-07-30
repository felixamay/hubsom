import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'api_client.dart';

/// Agora live streaming — same provider as the existing Hubsom web app.
class AgoraService {
  AgoraService(this._api);

  final ApiClient _api;
  RtcEngine? _engine;
  bool joined = false;

  Future<String?> fetchToken({
    required String channelName,
    required int uid,
    String role = 'audience',
  }) async {
    try {
      final res = await _api.post<Map<String, dynamic>>(
        '/api/agora/token',
        data: {'channelName': channelName, 'uid': uid, 'role': role},
      );
      return res.data?['token'] as String?;
    } catch (e) {
      if (kDebugMode) debugPrint('Agora token error: $e');
      return null;
    }
  }

  Future<RtcEngine?> ensureEngine() async {
    if (kIsWeb) {
      // Web uses Agora Web SDK via platform views / JS interop in production.
      // Mobile/desktop engine is used on Android & iOS.
      return null;
    }
    if (_engine != null) return _engine;
    if (AppConfig.agoraAppId.isEmpty) return null;

    final engine = createAgoraRtcEngine();
    await engine.initialize(
      RtcEngineContext(
        appId: AppConfig.agoraAppId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ),
    );
    await engine.enableVideo();
    await engine.enableAudio();
    _engine = engine;
    return engine;
  }

  Future<void> joinAsAudience({
    required String channelName,
    required String token,
    int uid = 0,
  }) async {
    final engine = await ensureEngine();
    if (engine == null) return;
    await engine.setClientRole(role: ClientRoleType.clientRoleAudience);
    await engine.joinChannel(
      token: token,
      channelId: channelName,
      uid: uid,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleAudience,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ),
    );
    joined = true;
  }

  Future<void> joinAsHost({
    required String channelName,
    required String token,
    int uid = 0,
  }) async {
    final engine = await ensureEngine();
    if (engine == null) return;
    await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await engine.startPreview();
    await engine.joinChannel(
      token: token,
      channelId: channelName,
      uid: uid,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        publishCameraTrack: true,
        publishMicrophoneTrack: true,
      ),
    );
    joined = true;
  }

  Future<void> leave() async {
    final engine = _engine;
    if (engine == null) return;
    await engine.leaveChannel();
    joined = false;
  }

  Future<void> dispose() async {
    await leave();
    await _engine?.release();
    _engine = null;
  }
}
