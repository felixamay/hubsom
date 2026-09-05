import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/providers/core_providers.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/features/home/home_page.dart';
import 'package:hubsom_app/models/stream.dart';

LiveStream _live({
  required String id,
  required String title,
  required int viewers,
  String cover = '',
}) {
  return LiveStream(
    id: id,
    title: title,
    description: '',
    sellerId: 'seller-1',
    status: 'live',
    channelName: 'hubsom-$id',
    cover: cover,
    viewerCount: viewers,
    hosts: const [
      StreamHost(id: 'h1', name: 'Ama Host', role: 'host', avatar: ''),
    ],
  );
}

List<Override> _homeOverrides({List<LiveStream> lives = const []}) {
  return [
    streamsProvider.overrideWith((ref) async => lives),
    productsProvider.overrideWith((ref, args) async => const []),
    promotionsProvider.overrideWith((ref, placement) async => const []),
    shopVideosProvider.overrideWith((ref) async => const []),
    sellersProvider.overrideWith((ref) async => const []),
  ];
}

void main() {
  setUp(() {
    AppConfig.load();
    CloudStore.useNetwork = false;
  });

  testWidgets('Live now sits before Categories and shows viewer counts', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _homeOverrides(
          lives: [
            _live(id: 'live-1', title: 'Sunday bargains', viewers: 42),
            _live(id: 'live-2', title: 'Night market', viewers: 7),
          ],
        ),
        child: const MaterialApp(home: Scaffold(body: HomePage())),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Live now'), findsOneWidget);
    expect(find.text('Categories'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Live now')).dy,
      lessThan(tester.getTopLeft(find.text('Categories')).dy),
    );
    expect(find.text('Sunday bargains'), findsOneWidget);
    expect(find.text('42 watching'), findsOneWidget);
    expect(find.text('Night market'), findsOneWidget);
    expect(find.text('7 watching'), findsOneWidget);
    expect(find.text('LIVE'), findsWidgets);
  });

  testWidgets('Live now section stays above Categories when empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _homeOverrides(),
        child: const MaterialApp(home: Scaffold(body: HomePage())),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Live now'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Live now')).dy,
      lessThan(tester.getTopLeft(find.text('Categories')).dy),
    );
    expect(find.textContaining('No one is live right now'), findsOneWidget);
  });
}
