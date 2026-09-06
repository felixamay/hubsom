import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hubsom_app/core/theme/hubsom_theme.dart';
import 'package:hubsom_app/features/shell/main_shell.dart';
import 'package:hubsom_app/widgets/hubsom_logo.dart';

void main() {
  test('large phones keep extra header icons in the menu', () {
    expect(MainShell.inlineHeaderExtras(390), isFalse);
    expect(MainShell.inlineHeaderExtras(430), isFalse);
    expect(MainShell.inlineHeaderExtras(520), isTrue);
    expect(MainShell.inlineHeaderExtras(768), isTrue);
  });

  testWidgets('search does not cover the logo on a large phone', (tester) async {
    const width = 430.0;
    await tester.binding.setSurfaceSize(const Size(width, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: HubsomTheme.light(),
        home: Scaffold(
          appBar: AppBar(
            titleSpacing: 8,
            title: MainShell.phoneTitle(width: width),
            actions: [
              IconButton(
                tooltip: 'Search',
                visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                onPressed: () {},
                icon: const Icon(Icons.search),
              ),
              IconButton(
                tooltip: 'Cart',
                visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                onPressed: () {},
                icon: const Icon(Icons.shopping_bag_outlined),
              ),
              IconButton(
                tooltip: 'Menu',
                onPressed: () {},
                icon: const Icon(Icons.menu),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(HubsomLogo), findsOneWidget);
    expect(find.text('Hubsom'), findsOneWidget);
    expect(find.byTooltip('Search'), findsOneWidget);

    final logo = tester.getRect(find.byType(HubsomLogo));
    final search = tester.getRect(find.byTooltip('Search'));
    expect(logo.right, lessThanOrEqualTo(search.left + 0.5));
    expect(find.byTooltip('Live'), findsNothing);
  });
}
