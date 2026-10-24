import 'package:flutter_test/flutter_test.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/services/owncast_media.dart';
import 'package:hubsom_app/models/shop_video.dart';

void main() {
  setUp(() {
    AppConfig.load();
    AppConfig.owncastBaseUrlOverride = null;
    AppConfig.owncastRtmpUrlOverride = null;
    AppConfig.owncastMediaTokenOverride = null;
  });

  tearDown(() {
    AppConfig.owncastBaseUrlOverride = null;
    AppConfig.owncastRtmpUrlOverride = null;
    AppConfig.owncastMediaTokenOverride = null;
  });

  test('Owncast is disconnected until a VPS URL is set', () {
    expect(AppConfig.owncastConfigured, isFalse);
    expect(OwncastMedia.isConfigured, isFalse);
    expect(OwncastMedia.rtmpAppUrl, isEmpty);
    expect(OwncastMedia.hlsUrl('live-abc'), isEmpty);
  });

  test('hls, rtmp, and media URLs use the VPS host', () {
    AppConfig.owncastBaseUrlOverride = 'https://live.hubsom.test/';
    expect(OwncastMedia.isConfigured, isTrue);
    expect(
      OwncastMedia.hlsUrl('live-abc'),
      'https://live.hubsom.test/hls/live-abc/index.m3u8',
    );
    expect(OwncastMedia.defaultHlsUrl, 'https://live.hubsom.test/hls/stream.m3u8');
    expect(OwncastMedia.rtmpAppUrl, 'rtmp://live.hubsom.test:1936/hubsom');
    expect(OwncastMedia.owncastRtmpAppUrl, 'rtmp://live.hubsom.test:1935/live');
    expect(OwncastMedia.streamKey('live-abc'), 'live-abc');
    expect(
      OwncastMedia.videoUrl('vid-1'),
      'https://live.hubsom.test/media/vid-1.mp4',
    );
  });

  test('RTMP override wins over derived host:1936/hubsom', () {
    AppConfig.owncastBaseUrlOverride = 'https://live.hubsom.test';
    AppConfig.owncastRtmpUrlOverride = 'rtmp://ingest.hubsom.test:1936/hubsom';
    expect(OwncastMedia.rtmpAppUrl, 'rtmp://ingest.hubsom.test:1936/hubsom');
  });

  test('shop video JSON keeps a VPS media URL', () {
    const video = ShopVideo(
      id: 'vid-1',
      authorId: 'u1',
      authorName: 'Ama',
      caption: 'Clip',
      productIds: ['p1'],
      videoUrl: 'https://live.hubsom.test/media/vid-1.mp4',
      createdAt: '2026-09-19T00:00:00Z',
    );
    final copy = ShopVideo.fromJson(video.toJson());
    expect(copy.videoUrl, 'https://live.hubsom.test/media/vid-1.mp4');
  });
}
