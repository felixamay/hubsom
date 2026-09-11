import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hubsom_app/core/theme/hubsom_theme.dart';
import 'package:hubsom_app/features/shell/main_shell.dart';
import 'package:hubsom_app/widgets/hubsom_logo.dart';
import 'package:hubsom_app/widgets/hubsom_phone_app_bar.dart';

Future<void> _pumpHeader(
  WidgetTester tester, {
  required double width,
  required bool signedIn,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 932));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      theme: HubsomTheme.light(),
      home: Scaffold(
        appBar: HubsomPhoneAppBar(
          width: width,
          signedIn: signedIn,
          cartCount: signedIn ? 2 : 0,
          unreadMessages: signedIn ? 1 : 0,
          unreadNotifications: signedIn ? 3 : 0,
          menuEntries: const [],
          onSearch: () {},
          onLive: () {},
          onNotifications: () {},
          onMessages: () {},
          onCart: () {},
          onMenuSelected: (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  test('large phones keep extra header icons in the menu', () {
    expect(MainShell.inlineHeaderExtras(390), isFalse);
    expect(MainShell.inlineHeaderExtras(430), isFalse);
    expect(HubsomPhoneAppBar.inlineExtras(480), isFalse);
    expect(MainShell.inlineHeaderExtras(520), isTrue);
    expect(MainShell.inlineHeaderExtras(768), isTrue);
  });

  for (final width in [390.0, 414.0, 430.0, 480.0]) {
    testWidgets('search stays clear of the logo at ${width.toInt()}px',
        (tester) async {
      await _pumpHeader(tester, width: width, signedIn: true);
      expect(find.text('Hubsom'), findsOneWidget);
      expect(find.byTooltip('Live'), findsNothing);

      final logo = tester.getRect(find.byType(HubsomLogo));
      final search = tester.getRect(find.byTooltip('Search'));
      expect(logo.right, lessThanOrEqualTo(search.left + 0.5));
    });
  }

  testWidgets('tablet width keeps extras and still separates logo from search',
      (tester) async {
    await _pumpHeader(tester, width: 768, signedIn: true);
    expect(find.byTooltip('Search'), findsOneWidget);
    expect(find.byTooltip('Live'), findsOneWidget);
    expect(find.byTooltip('Notifications'), findsOneWidget);
    expect(find.byTooltip('Messages'), findsOneWidget);

    final logo = tester.getRect(find.byType(HubsomLogo));
    final search = tester.getRect(find.byTooltip('Search'));
    expect(logo.right, lessThanOrEqualTo(search.left + 0.5));
  });
}
