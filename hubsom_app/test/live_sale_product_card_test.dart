import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hubsom_app/models/product.dart';
import 'package:hubsom_app/models/stream.dart';
import 'package:hubsom_app/widgets/live_sale_product_card.dart';

Product _product() => const Product(
      id: 'p1',
      slug: 'kente',
      name: 'Kente scarf',
      description: 'Handwoven',
      category: 'fashion',
      priceGhs: 120,
      images: const [],
      sellerId: 's1',
      stock: 4,
    );

LiveAuction _auction({
  required String status,
  required DateTime endsAt,
  String? highestBidder,
}) =>
    LiveAuction(
      id: 'a1',
      productId: 'p1',
      startingBidGhs: 40,
      currentBidGhs: 40,
      minIncrementGhs: 2,
      endsAt: endsAt.toUtc().toIso8601String(),
      status: status,
      highestBidder: highestBidder,
    );

LiveStream _stream({LiveAuction? auction, String? pinned = 'p1'}) => LiveStream(
      id: 'live-1',
      title: 'Sunday live',
      description: '',
      sellerId: 's1',
      status: 'live',
      channelName: 'live-1',
      cover: '',
      pinnedProductId: pinned,
      auction: auction,
    );

void main() {
  test('fixed-price pin is not an active auction', () {
    final live = _stream();
    expect(live.hasActiveAuction, isFalse);
    expect(live.isLiveAuction, isFalse);
  });

  test('open auction stays active', () {
    final live = _stream(
      auction: _auction(
        status: 'open',
        endsAt: DateTime.now().add(const Duration(seconds: 20)),
      ),
    );
    expect(live.hasActiveAuction, isTrue);
    expect(live.isLiveAuction, isTrue);
  });

  test('sold leftover auction yields to the sale card', () {
    final live = _stream(
      auction: _auction(
        status: 'sold',
        endsAt: DateTime.now().subtract(const Duration(seconds: 5)),
        highestBidder: 'Kojo',
      ),
    );
    expect(live.hasActiveAuction, isFalse);
  });

  testWidgets('sale product card is tappable', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveSaleProductCard(
            product: _product(),
            offeredQty: 3,
            isHost: false,
            onOpenProduct: () => opened = true,
            onBuy: () {},
            onDismiss: () {},
          ),
        ),
      ),
    );

    expect(find.text('Kente scarf'), findsOneWidget);
    expect(find.text('3 for sale · Huber shipping'), findsOneWidget);
    expect(find.text('Buy'), findsOneWidget);

    await tester.tap(find.text('Kente scarf'));
    await tester.pump();
    expect(opened, isTrue);
  });
}
