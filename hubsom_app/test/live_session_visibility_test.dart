import 'package:flutter_test/flutter_test.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/services/live_viewer_identity.dart';
import 'package:hubsom_app/core/services/live_webrtc_signal_store.dart';
import 'package:hubsom_app/core/services/local_commerce_store.dart';
import 'package:hubsom_app/models/stream.dart';
import 'package:hubsom_app/models/user.dart';

LiveStream _stream({
  required String status,
  String? endedAt,
  int viewerCount = 0,
  List<StreamHost> hosts = const [],
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
      hosts: hosts,
    );

HubsomUser _user({required String id, String? sellerId}) => HubsomUser(
      id: id,
      email: '$id@example.com',
      name: 'Tester',
      role: sellerId == null ? 'buyer' : 'seller',
      sellerId: sellerId,
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

  group('the host is not part of their own audience', () {
    final stream = _stream(status: 'live');

    test('the seller running the show is recognised as the host', () {
      expect(
        LiveViewerIdentity.isHost(stream, _user(id: 'u1', sellerId: 'seller-1')),
        isTrue,
      );
    });

    test('a listed co-host is recognised as a host', () {
      final withHost = _stream(
        status: 'live',
        hosts: const [
          StreamHost(id: 'u-co', name: 'Kofi', role: 'host', avatar: ''),
        ],
      );
      expect(
        LiveViewerIdentity.isHost(withHost, _user(id: 'u-co')),
        isTrue,
      );
    });

    test('a shopper watching the show is not a host', () {
      expect(
        LiveViewerIdentity.isHost(stream, _user(id: 'u-shopper')),
        isFalse,
      );
    });

    test('a signed-out visitor is not a host', () {
      expect(LiveViewerIdentity.isHost(stream, null), isFalse);
    });

    test('an unrelated seller is not the host of this show', () {
      expect(
        LiveViewerIdentity.isHost(
          stream,
          _user(id: 'u-other', sellerId: 'seller-2'),
        ),
        isFalse,
      );
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

    test('the cloud live status is the one every browser shows', () {
      final local = _stream(status: 'ended', endedAt: '2026-09-13T11:00:00Z');
      final remote = _stream(status: 'live');

      final merged = LocalCommerceStore.mergeStreams(local, remote);

      expect(merged.isLive, isTrue);
    });

    test('the cloud ending a live show still wins', () {
      final local = _stream(status: 'live');
      final remote = _stream(status: 'ended', endedAt: '2026-09-13T11:00:00Z');

      final merged = LocalCommerceStore.mergeStreams(local, remote);

      expect(merged.isLive, isFalse);
      expect(merged.endedAt, '2026-09-13T11:00:00Z');
    });

    test('a corrected audience number can travel downwards', () {
      // Clamping to the larger of the two counts made the number monotonic, so
      // an inflated count could never be walked back.
      final local = _stream(status: 'live', viewerCount: 5);
      final remote = _stream(status: 'live', viewerCount: 4);

      final merged = LocalCommerceStore.mergeStreams(local, remote);

      expect(merged.viewerCount, 4);
    });

    test('the live bag on every browser is the cloud product list', () {
      final local = _stream(status: 'live').copyWith(productIds: const ['old']);
      final remote = _stream(status: 'live').copyWith(productIds: const ['new']);

      final merged = LocalCommerceStore.mergeStreams(local, remote);

      expect(merged.productIds, ['new']);
    });

    test('peak viewers stays a high-water mark', () {
      final local = _stream(status: 'live', viewerCount: 5);
      final remote = _stream(status: 'live', viewerCount: 2);

      final merged = LocalCommerceStore.mergeStreams(local, remote);

      expect(merged.viewerCount, 2);
      expect(merged.peakViewers, 5);
    });
  });
}
