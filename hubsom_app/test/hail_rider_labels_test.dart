import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hubsom_app/features/authentication/sign_in_page.dart';
import 'package:hubsom_app/features/authentication/sign_up_page.dart';

void main() {
  testWidgets('sign-in offers Hail Rider, not Huber', (tester) async {
    final router = GoRouter(
      initialLocation: '/auth/sign-in',
      routes: [
        GoRoute(
          path: '/auth/sign-in',
          builder: (_, __) => const SignInPage(),
        ),
        GoRoute(
          path: '/auth/sign-up',
          builder: (_, __) => const SignUpPage(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create Hail Rider account'), findsOneWidget);
    expect(find.textContaining('Huber'), findsNothing);
  });

  testWidgets('sign-up account type lists Hail Rider', (tester) async {
    final router = GoRouter(
      initialLocation: '/auth/sign-up',
      routes: [
        GoRoute(
          path: '/auth/sign-up',
          builder: (_, __) => const SignUpPage(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Buyer'));
    await tester.pumpAndSettle();

    expect(find.text('Hail Rider'), findsOneWidget);
    expect(find.textContaining('Huber'), findsNothing);
  });
}
