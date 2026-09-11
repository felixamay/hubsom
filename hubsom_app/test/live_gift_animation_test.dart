import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hubsom_app/models/live_gift.dart';
import 'package:hubsom_app/widgets/live_gift_burst.dart';

void main() {
  test('gift chat lines parse back to catalog gifts', () {
    expect(
      GiftCatalog.parseFromChat('sent a 🌹 Rose (1 pts)')?.id,
      'rose',
    );
    expect(
      GiftCatalog.parseFromChat('sent a 💎 Diamond (999 pts)')?.id,
      'diamond',
    );
    expect(GiftCatalog.parseFromChat('hello chat'), isNull);
    expect(GiftCatalog.parseFromChat('Bid 80 GHS'), isNull);
  });

  test('expensive gifts use heavier animation tiers', () {
    expect(GiftCatalog.byId('rose')!.fxTier, GiftFxTier.small);
    expect(GiftCatalog.byId('star')!.fxTier, GiftFxTier.medium);
    expect(GiftCatalog.byId('crown')!.fxTier, GiftFxTier.large);
    expect(GiftCatalog.byId('diamond')!.fxTier, GiftFxTier.mega);
    expect(
      GiftCatalog.byId('diamond')!.fxDuration.inMilliseconds,
      greaterThan(GiftCatalog.byId('rose')!.fxDuration.inMilliseconds),
    );
  });

  testWidgets('burst paints emoji, sender, and gift name', (tester) async {
    final gift = GiftCatalog.byId('crown')!;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveGiftBurst(
            gift: gift,
            senderName: 'Efua Fan',
            progress: 0.35,
          ),
        ),
      ),
    );

    expect(find.text('👑'), findsWidgets);
    expect(find.text('Efua Fan'), findsOneWidget);
    expect(find.textContaining('Crown'), findsOneWidget);
    expect(find.textContaining('100 pts'), findsOneWidget);
  });
}
