import 'package:flutter_test/flutter_test.dart';

import 'package:hubsom_app/core/services/live_webrtc_signal_store.dart';

void main() {
  test('LiveWebrtcSignal round-trips JSON for offer/answer/ICE', () {
    final signal = LiveWebrtcSignal(
      id: LiveWebrtcSignal.docId('stream1', 'viewer9'),
      streamId: 'stream1',
      viewerId: 'viewer9',
      state: 'answered',
      offerSdp: 'v=0 offer',
      offerType: 'offer',
      answerSdp: 'v=0 answer',
      answerType: 'answer',
      hostIce: const ['{"candidate":"a"}'],
      viewerIce: const ['{"candidate":"b"}'],
      updatedAt: 42,
    );

    final copy = LiveWebrtcSignal.fromJson(signal.toJson());
    expect(copy.id, 'stream1__viewer9');
    expect(copy.state, 'answered');
    expect(copy.offerSdp, 'v=0 offer');
    expect(copy.answerSdp, 'v=0 answer');
    expect(copy.hostIce, ['{"candidate":"a"}']);
    expect(copy.viewerIce, ['{"candidate":"b"}']);
    expect(copy.updatedAt, 42);
  });

  test('docId is stable for stream+viewer', () {
    expect(
      LiveWebrtcSignal.docId('abc', 'u1'),
      'abc__u1',
    );
  });
}
