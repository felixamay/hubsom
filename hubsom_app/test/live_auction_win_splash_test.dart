import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hubsom_app/core/utils/money.dart';
import 'package:hubsom_app/widgets/live_auction_win_splash.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('winner splash copy names the bidder and the bid', () {
    expect(
      LiveAuctionWinSplash.headline(
        winnerName: 'Kojo Bidder',
        isYou: false,
      ),
      'Kojo Bidder won!',
    );
    expect(
      LiveAuctionWinSplash.headline(winnerName: 'Kojo Bidder', isYou: true),
      'You won!',
    );
    expect(
      LiveAuctionWinSplash.chatLine(
        winnerName: 'Kojo Bidder',
        productName: 'Kente scarf',
        amountGhs: 180,
      ),
      '🏆 Kojo Bidder won Kente scarf — 180 GHS',
    );
  });

  testWidgets('splash paints winner, product, and amount', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LiveAuctionWinSplash(
            winnerName: 'Kojo Bidder',
            amountGhs: 180,
            productName: 'Kente scarf',
            progress: 0.4,
          ),
        ),
      ),
    );

    expect(find.text('SOLD'), findsOneWidget);
    expect(find.text('Kojo Bidder won!'), findsOneWidget);
    expect(find.text('Kente scarf'), findsOneWidget);
    expect(find.text(formatGhs(180)), findsOneWidget);
    expect(find.text('🏆'), findsWidgets);
  });

  testWidgets('winning bidder sees You won', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LiveAuctionWinSplash(
            winnerName: 'Kojo Bidder',
            amountGhs: 150,
            productName: 'Kente scarf',
            isYou: true,
            progress: 0.5,
          ),
        ),
      ),
    );
    expect(find.text('You won!'), findsOneWidget);
    expect(find.text('The host will confirm your order'), findsOneWidget);
  });
}
