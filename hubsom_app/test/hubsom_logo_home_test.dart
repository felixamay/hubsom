import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hubsom_app/widgets/hubsom_logo.dart';

void main() {
  testWidgets('HubsomLogo navigates to home on tap', (tester) async {
    final router = GoRouter(
      initialLocation: '/elsewhere',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const Text('Home')),
        GoRoute(
          path: '/elsewhere',
          builder: (_, __) => const Scaffold(
            body: Center(child: HubsomLogo(height: 32)),
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(find.text('Home'), findsNothing);

    await tester.tap(find.byType(HubsomLogo));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(router.state.uri.path, '/');
  });
}
