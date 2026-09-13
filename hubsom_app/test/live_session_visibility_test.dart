import 'package:flutter_test/flutter_test.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/services/live_webrtc_signal_store.dart';
import 'package:hubsom_app/core/services/local_commerce_store.dart';
import 'package:hubsom_app/models/stream.dart';

LiveStream _stream({
  required String status,
  String? endedAt,
  int viewerCount = 0,
}) =>
    LiveStream(
      id: 's1',
      title: 'Ama live',
      description: '',
      sellerId: 'seller-1',
      status: status,
      channelName: 's1',
      cover: 'https://cdn/x.jpg',
      viewerCount: viewerCount,
      peakViewers: viewerCount,
      startedAt: '2026-09-13T10:00:00Z',
      endedAt: endedAt,
      productIds: const ['p1'],
      hosts: const [],
    );

LiveWebrtcSignal _signal() => LiveWebrtcSignal(
      id: LiveWebrtcSignal.docId('s1', 'v1'),
      streamId: 's1',
      viewerId: 'v1',
      state: 'offered',
      offerSdp: 'v=0 offer',
      offerType: 'offer',
      answerSdp: 'v=0 answer',
      answerType: 'answer',
      hostIce: const ['{"candidate":"host-a"}'],
      viewerIce: const ['{"candidate":"viewer-a"}'],
      updatedAt: 100,
      viewerSeenAt: 90,
    );

void main() {
  setUp(AppConfig.load);

  group('signaling writes stay on their own side', () {
    test('a host write cannot clobber the viewer answer or candidates', () {
      final host = _signal().toHostJson();

      // Merge-writing any of these would wipe what the viewer published.
      expect(host.containsKey('answerSdp'), isFalse);
      expect(host.containsKey('answerType'), isFalse);
      expect(host.containsKey('viewerIce'), isFalse);
      expect(host.containsKey('hostIce'), isFalse);

      expect(host['offerSdp'], 'v=0 offer');
      expect(host['state'], 'offered');
    });

    test('a viewer write cannot clobber the host offer or candidates', () {
      final viewer = _signal().toViewerJson();

      expect(viewer.containsKey('offerSdp'), isFalse);
      expect(viewer.containsKey('offerType'), isFalse);
      expect(viewer.containsKey('hostIce'), isFalse);
      expect(viewer.containsKey('viewerIce'), isFalse);

      expect(viewer['answerSdp'], 'v=0 answer');
      expect(viewer['state'], 'offered');
    });

    test('a viewer write always stamps the watching heartbeat', () {
      final before = DateTime.now().millisecondsSinceEpoch;
      final seen = _signal().toViewerJson()['viewerSeenAt'] as int;
      expect(seen, greaterThanOrEqualTo(before));
    });

    test('viewerSeenAt survives a JSON round trip', () {
      final copy = LiveWebrtcSignal.fromJson(_signal().toJson());
      expect(copy.viewerSeenAt, 90);
      expect(copy.updatedAt, 100);
    });

    test('a cleared SDP is written as empty, never dropped', () {
      // Omitting the field under merge semantics would leave the previous
      // negotiation's answer in place and the host would apply a stale answer.
      final fresh = LiveWebrtcSignal(
        id: LiveWebrtcSignal.docId('s1', 'v1'),
        streamId: 's1',
        viewerId: 'v1',
        state: 'offered',
        offerSdp: 'v=0 new offer',
        offerType: 'offer',
      ).toJson();

      expect(fresh['answerSdp'], '');
      expect(fresh['answerType'], '');
      expect(LiveWebrtcSignal.fromJson(fresh).answerSdp?.isEmpty, isTrue);
    });
  });

  group('live TURN configuration', () {
    test('a relay is configured, not STUN alone', () {
      // Carrier NAT on mobile data cannot be traversed with STUN only, so a
      // missing relay means viewers simply never receive the seller's video.
      expect(AppConfig.turnUrls.trim(), isNotEmpty);
      expect(AppConfig.turnUrls, contains('turn:'));
      expect(AppConfig.turnUsername, isNotEmpty);
      expect(AppConfig.turnCredential, isNotEmpty);
    });
  });

  group('stream status merge', () {
    test('a stale non-live copy is promoted when the cloud says live', () {
      final local = _stream(status: 'scheduled');
      final remote = _stream(status: 'live', viewerCount: 3);

      final merged = LocalCommerceStore.mergeStreams(local, remote);

      expect(merged.isLive, isTrue);
      expect(merged.viewerCount, 3);
    });

    test('a show ended on this device is not resurrected by a stale cloud doc',
        () {
      final local = _stream(status: 'ended', endedAt: '2026-09-13T11:00:00Z');
      final remote = _stream(status: 'live');

      final merged = LocalCommerceStore.mergeStreams(local, remote);

      expect(merged.isLive, isFalse);
      expect(merged.status, 'ended');
    });

    test('the cloud ending a live show still wins', () {
      final local = _stream(status: 'live');
      final remote = _stream(status: 'ended', endedAt: '2026-09-13T11:00:00Z');

      final merged = LocalCommerceStore.mergeStreams(local, remote);

      expect(merged.isLive, isFalse);
      expect(merged.endedAt, '2026-09-13T11:00:00Z');
    });
  });
}
