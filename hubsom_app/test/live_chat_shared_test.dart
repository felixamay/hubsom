import 'package:flutter_test/flutter_test.dart';
import 'package:hubsom_app/core/services/live_chat_store.dart';
import 'package:hubsom_app/models/stream.dart';

ChatMessage _msg(
  String id, {
  String text = 'hello',
  String at = '2026-09-13T10:00:00.000Z',
  String userId = 'u1',
  bool moderated = false,
}) =>
    ChatMessage(
      id: id,
      streamId: 's1',
      userId: userId,
      displayName: 'Ama',
      text: text,
      createdAt: at,
      moderated: moderated,
    );

void main() {
  group('a live message reaches the whole room', () {
    test('the stored doc is addressable per stream and keeps its own id', () {
      final row = LiveChatStore.docId('s1', 'msg-abc');
      expect(row, 's1__msg-abc');
    });

    test('chat is ordered newest first so the room reads correctly', () {
      final ordered = LiveChatStore.sortNewestFirst([
        _msg('m1', at: '2026-09-13T10:00:00.000Z'),
        _msg('m3', at: '2026-09-13T10:00:02.000Z'),
        _msg('m2', at: '2026-09-13T10:00:01.000Z'),
      ]);

      expect(ordered.map((m) => m.id).toList(), ['m3', 'm2', 'm1']);
    });

    test('two messages in the same millisecond keep a stable order', () {
      const sameInstant = '2026-09-13T10:00:00.000Z';
      final first = LiveChatStore.sortNewestFirst([
        _msg('m-a', at: sameInstant),
        _msg('m-b', at: sameInstant),
      ]);
      final second = LiveChatStore.sortNewestFirst([
        _msg('m-b', at: sameInstant),
        _msg('m-a', at: sameInstant),
      ]);

      expect(first.map((m) => m.id).toList(), second.map((m) => m.id).toList());
    });
  });

  group('merging this device with the room', () {
    test("another viewer's message shows up alongside my own", () {
      final mine = [_msg('mine', text: 'is it still available?')];
      final theirs = [
        _msg('theirs', text: 'I will take two', userId: 'u2'),
      ];

      final merged = LiveChatStore.merge(mine, theirs);

      expect(merged.map((m) => m.id), containsAll(['mine', 'theirs']));
      expect(merged.length, 2);
    });

    test('my own message is not duplicated when it comes back from the cloud',
        () {
      final mine = [_msg('mine')];
      final echoed = [_msg('mine')];

      expect(LiveChatStore.merge(mine, echoed).length, 1);
    });

    test('a locally moderated message is not un-hidden by a stale cloud copy',
        () {
      final mine = [_msg('m1', moderated: true)];
      final stale = [_msg('m1')];

      final merged = LiveChatStore.merge(mine, stale);

      expect(merged.single.moderated, isTrue);
    });

    test('the cloud can still moderate a message this device has plain', () {
      final mine = [_msg('m1')];
      final fromCloud = [_msg('m1', moderated: true)];

      expect(LiveChatStore.merge(mine, fromCloud).single.moderated, isTrue);
    });

    test('a long-running show does not grow without bound', () {
      final many = [
        for (var i = 0; i < LiveChatStore.maxMessages + 40; i++)
          _msg(
            'm$i',
            at: DateTime.utc(2026, 9, 13, 10, 0, i).toIso8601String(),
          ),
      ];

      expect(
        LiveChatStore.merge(const [], many).length,
        LiveChatStore.maxMessages,
      );
    });

    test('trimming keeps the newest messages, not the oldest', () {
      final many = [
        for (var i = 0; i < LiveChatStore.maxMessages + 5; i++)
          _msg(
            'm$i',
            at: DateTime.utc(2026, 9, 13, 10, 0, i).toIso8601String(),
          ),
      ];

      final merged = LiveChatStore.merge(const [], many);

      expect(merged.first.id, 'm${LiveChatStore.maxMessages + 4}');
    });

    test('empty input on either side is handled', () {
      expect(LiveChatStore.merge(const [], const []), isEmpty);
      expect(LiveChatStore.merge([_msg('m1')], const []).length, 1);
      expect(LiveChatStore.merge(const [], [_msg('m1')]).length, 1);
    });
  });
}
