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

  group('handshake costs one write per hop', () {
    test('announcing also clears the previous negotiation', () {
      // A separate reset write would delay the host's offer by a round trip.
      final doc = LiveWebrtcSignalStore.announceDoc(
        streamId: 's1',
        viewerId: 'v1',
      );

      expect(doc['id'], 's1__v1');
      expect(doc['state'], 'waiting');
      expect(doc['answerSdp'], '');
      expect(doc['hostIce'], isEmpty);
      expect(doc['viewerIce'], isEmpty);
      expect(doc['viewerSeenAt'], isA<int>());
    });

    test('offering also clears the stale answer and candidates', () {
      final doc = LiveWebrtcSignalStore.offerDoc(
        streamId: 's1',
        viewerId: 'v1',
        offerSdp: 'v=0 fresh',
        offerType: 'offer',
      );

      expect(doc['state'], 'offered');
      expect(doc['offerSdp'], 'v=0 fresh');
      expect(doc['answerSdp'], '');
      expect(doc['answerType'], '');
      expect(doc['hostIce'], isEmpty);
      expect(doc['viewerIce'], isEmpty);
    });

    test('an offer doc round-trips into a signal the viewer can answer', () {
      final signal = LiveWebrtcSignal.fromJson(
        LiveWebrtcSignalStore.offerDoc(
          streamId: 's1',
          viewerId: 'v1',
          offerSdp: 'v=0 fresh',
          offerType: 'offer',
        ),
      );

      expect(signal.state, 'offered');
      expect(signal.offerSdp, 'v=0 fresh');
      expect((signal.answerSdp ?? '').isEmpty, isTrue);
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
