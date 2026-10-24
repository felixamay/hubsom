/// Web stub — agora_rtc_engine is not loaded on Flutter web (it blanks the page).
class AgoraRtcBridge {
  AgoraRtcBridge._();
  static final instance = AgoraRtcBridge._();

  bool joined = false;

  Future<void> joinAsAudience({
    required String channelName,
    required String token,
    int uid = 0,
  }) async {}

  Future<void> joinAsHost({
    required String channelName,
    required String token,
    int uid = 0,
  }) async {}

  Future<void> leave() async {
    joined = false;
  }

  Future<void> dispose() async {
    joined = false;
  }
}
