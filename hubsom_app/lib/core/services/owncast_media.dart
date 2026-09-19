import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';

/// Owncast + Hubsom VPS media helpers.
///
/// Live video is ingested over RTMP and played as HLS. Shop videos are stored
/// as ordinary files under `/media` on the same VPS. The public base URL is
/// empty until the VPS is purchased and wired in.
class OwncastMedia {
  OwncastMedia._();

  static final Dio _http = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
      validateStatus: (s) => s != null && s < 500,
    ),
  );

  static String get baseUrl => AppConfig.owncastBaseUrl;

  static bool get isConfigured => AppConfig.owncastConfigured;

  /// Stock Owncast HLS playlist (one concurrent live on the default app).
  static String get defaultHlsUrl => '$baseUrl/hls/stream.m3u8';

  /// Per-show HLS playlist served by the VPS nginx-rtmp sidecar.
  static String hlsUrl(String streamId) {
    if (!isConfigured) return '';
    final id = streamId.trim();
    if (id.isEmpty) return defaultHlsUrl;
    return '$baseUrl/hls/$id/index.m3u8';
  }

  /// RTMP ingest for a Hubsom show. Stream key is the live stream id.
  static String get rtmpAppUrl {
    final override = AppConfig.owncastRtmpUrl.trim();
    if (override.isNotEmpty) return override;
    final host = _hostFromBase(baseUrl);
    if (host.isEmpty) return '';
    return 'rtmp://$host:1936/hubsom';
  }

  /// Default Owncast ingest (single-stream fallback).
  static String get owncastRtmpAppUrl {
    final host = _hostFromBase(baseUrl);
    if (host.isEmpty) return '';
    return 'rtmp://$host:1935/live';
  }

  static String streamKey(String streamId) => streamId.trim();

  static String videoUrl(String videoId) => '$baseUrl/media/$videoId.mp4';

  static String _hostFromBase(String url) {
    if (url.isEmpty) return '';
    try {
      return Uri.parse(url).host;
    } catch (_) {
      return url.replaceFirst(RegExp(r'^https?://'), '').split('/').first;
    }
  }

  /// True when nginx-rtmp (or Owncast) has published this show's playlist.
  static Future<bool> isHlsReady(String streamId) async {
    if (!isConfigured) return false;
    try {
      final res = await _http.get<dynamic>(
        hlsUrl(streamId),
        options: Options(
          responseType: ResponseType.plain,
          headers: const {'Accept': 'application/vnd.apple.mpegurl,*/*'},
        ),
      );
      if (res.statusCode != 200) return false;
      final body = '${res.data}';
      return body.contains('#EXTM3U');
    } catch (e) {
      if (kDebugMode) debugPrint('OwncastMedia.isHlsReady: $e');
      return false;
    }
  }

  static Future<bool> isOnline() async {
    if (!isConfigured) return false;
    try {
      final res = await _http.get<dynamic>('$baseUrl/api/status');
      final data = res.data;
      if (data is Map) return data['online'] == true;
      return res.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('OwncastMedia.isOnline: $e');
      return false;
    }
  }

  /// Upload a shop / product clip to the VPS `/media` store.
  static Future<String?> uploadVideo({
    required String videoId,
    required Uint8List bytes,
    String mimeType = 'video/mp4',
  }) async {
    if (!isConfigured || bytes.isEmpty || videoId.isEmpty) return null;
    final token = AppConfig.owncastMediaToken.trim();
    try {
      final res = await _http.post<dynamic>(
        '$baseUrl/media/upload',
        data: bytes,
        options: Options(
          headers: {
            'Content-Type': mimeType,
            'X-Hubsom-Video-Id': videoId,
            if (token.isNotEmpty) 'X-Hubsom-Media-Token': token,
          },
          receiveTimeout: const Duration(minutes: 3),
          sendTimeout: const Duration(minutes: 3),
        ),
      );
      final data = res.data;
      if (data is Map && '${data['url'] ?? ''}'.isNotEmpty) {
        return '${data['url']}';
      }
      if (res.statusCode == 200 || res.statusCode == 201) {
        return videoUrl(videoId);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('OwncastMedia.uploadVideo: $e');
    }
    return null;
  }
}
