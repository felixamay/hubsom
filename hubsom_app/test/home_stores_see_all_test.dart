import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hubsom_app/core/auth/auth_routes.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/providers/core_providers.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/features/home/home_page.dart';
import 'package:hubsom_app/features/stores/stores_list_page.dart';
import 'package:hubsom_app/models/seller.dart';

const _store = Seller(
  id: 's1',
  slug: 'osu-market',
  name: 'Osu Market',
  city: 'Accra',
  region: 'Greater Accra',
  bio: '',
  avatar: '',
  cover: '',
);

List<Override> _homeOverrides({List<Seller> sellers = const []}) {
  return [
    streamsProvider.overrideWith((ref) async => const []),
    productsProvider.overrideWith((ref, args) async => const []),
    promotionsProvider.overrideWith((ref, placement) async => const []),
    shopVideosProvider.overrideWith((ref) async => const []),
    sellersProvider.overrideWith((ref) async => sellers),
  ];
}

void main() {
  setUp(() {
    AppConfig.load();
    CloudStore.useNetwork = false;
  });

  testWidgets('Stores header puts See all on the top right', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: _homeOverrides(sellers: const [_store]),
        child: const MaterialApp(home: Scaffold(body: HomePage())),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Stores'), findsOneWidget);
    expect(find.text('Osu Market'), findsOneWidget);

    final storesPos = tester.getTopLeft(find.text('Stores'));
    final seeAllFinder = find.text('See all');
    expect(seeAllFinder, findsWidgets);

    var foundOnRight = false;
    for (var i = 0; i < tester.widgetList(seeAllFinder).length; i++) {
      final pos = tester.getTopLeft(seeAllFinder.at(i));
      if ((pos.dy - storesPos.dy).abs() < 24 && pos.dx > storesPos.dx) {
        foundOnRight = true;
        break;
      }
    }
    expect(
      foundOnRight,
      isTrue,
      reason: 'See all should sit on the top right of the Stores header',
    );
  });

  testWidgets('stores list shows every seller', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sellersProvider.overrideWith((ref) async => const [_store]),
        ],
        child: const MaterialApp(home: StoresListPage()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Stores'), findsWidgets);
    expect(find.text('Osu Market'), findsOneWidget);
    expect(find.text('Accra, Greater Accra'), findsOneWidget);
  });

  test('stores index is a public guest route', () {
    expect(AuthRoutes.isPublic('/stores'), isTrue);
    expect(AuthRoutes.isPublic('/stores/osu-market'), isTrue);
  });
}
