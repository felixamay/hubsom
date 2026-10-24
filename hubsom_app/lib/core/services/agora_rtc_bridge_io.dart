import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';

/// Mobile/desktop Agora RTC bridge.
class AgoraRtcBridge {
  AgoraRtcBridge._();
  static final instance = AgoraRtcBridge._();

  RtcEngine? _engine;
  bool joined = false;

  Future<RtcEngine?> _ensureEngine() async {
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
    final engine = await _ensureEngine();
    if (engine == null) return;
    try {
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
    } catch (e) {
      if (kDebugMode) debugPrint('Agora audience join skipped: $e');
    }
  }

  Future<void> joinAsHost({
    required String channelName,
    required String token,
    int uid = 0,
  }) async {
    final engine = await _ensureEngine();
    if (engine == null) return;
    try {
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
    } catch (e) {
      if (kDebugMode) debugPrint('Agora host join skipped: $e');
    }
  }

  Future<void> leave() async {
    final engine = _engine;
    if (engine == null) return;
    try {
      await engine.leaveChannel();
    } catch (_) {}
    joined = false;
  }

  Future<void> dispose() async {
    await leave();
    await _engine?.release();
    _engine = null;
  }
}
