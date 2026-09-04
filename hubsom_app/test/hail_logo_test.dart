import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hubsom_app/widgets/hail_logo.dart';

void main() {
  testWidgets('HailLogo exposes Hail wordmark and paints mark', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: HailLogo(height: 36)),
        ),
      ),
    );
    expect(find.text('Hail'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
