import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/core/services/local_commerce_store.dart';
import 'package:hubsom_app/core/services/local_store.dart';
import 'package:hubsom_app/models/live_reaction_kind.dart';
import 'package:hubsom_app/widgets/live_reaction_burst.dart';
import 'package:hubsom_app/widgets/live_reaction_tray.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reaction catalog includes fire and a full tray', () {
    expect(LiveReactionCatalog.kinds.length, greaterThanOrEqualTo(10));
    expect(LiveReactionCatalog.fire.emoji, '🔥');
    expect(LiveReactionCatalog.fire.fx, ReactionFx.fire);
    expect(LiveReactionCatalog.byEmoji('🔥').id, 'fire');
    expect(LiveReactionCatalog.byEmoji('❤️').id, 'heart');
    expect(LiveReactionCatalog.byId('party')?.fx, ReactionFx.burst);
    expect(
      LiveReactionCatalog.fire.duration.inMilliseconds,
      greaterThan(LiveReactionCatalog.byId('laugh')!.duration.inMilliseconds),
    );
  });

  testWidgets('fire burst paints FIRE and the flame', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveReactionBurst(
            kind: LiveReactionCatalog.fire,
            progress: 0.4,
            combo: 4,
          ),
        ),
      ),
    );
    expect(find.text('🔥'), findsWidgets);
    expect(find.text('FIRE'), findsOneWidget);
    expect(find.text('x4'), findsOneWidget);
  });

  testWidgets('reaction tray lists fire and other methods', (tester) async {
    LiveReactionKind? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveReactionTray(
            selectedId: 'fire',
            onPick: (k) => picked = k,
          ),
        ),
      ),
    );
    expect(find.text('Fire'), findsOneWidget);
    expect(find.text('Love'), findsOneWidget);
    expect(find.text('Party'), findsOneWidget);
    await tester.tap(find.text('Fire'));
    expect(picked?.id, 'fire');
  });

  test('sendReaction stores fire for other viewers', () async {
    AppConfig.load();
    CloudStore.useNetwork = false;
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('hubsom-fire-rx');
    Hive.init(dir.path);
    await LocalStore.init();

    final sent = await LocalCommerceStore.sendReaction(
      streamId: 'live-1',
      emoji: '🔥',
    );
    expect(sent.emoji, '🔥');
    final rows = LocalCommerceStore.recentReactions('live-1');
    expect(rows.any((r) => r.id == sent.id && r.emoji == '🔥'), isTrue);
  });
}
