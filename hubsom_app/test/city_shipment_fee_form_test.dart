import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hubsom_app/models/seller.dart';
import 'package:hubsom_app/widgets/shipment_zone_fee_fields.dart';

void main() {
  testWidgets('seller can pick cities around them and set an out-of-region fee',
      (tester) async {
    final inZone = TextEditingController();
    final outOfRegion = TextEditingController();
    final cities = <String>{};
    addTearDown(inZone.dispose);
    addTearDown(outOfRegion.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ShipmentZoneFeeFields(
              inZoneFee: inZone,
              outOfRegionFee: outOfRegion,
              selectedCities: cities,
              seller: const Seller(
                id: 's1',
                slug: 's1',
                name: 'Kumasi Store',
                city: 'Kumasi',
                region: 'Ashanti',
                bio: '',
                avatar: '',
                cover: '',
                latitude: 6.6885,
                longitude: -1.6244,
              ),
              onCitiesChanged: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('In-zone shipment fee (GHS)'), findsOneWidget);
    expect(find.text('Out of region shipment fee (GHS)'), findsOneWidget);
    expect(find.text('Cities around you'), findsOneWidget);

    final kumasiChip = find.byWidgetPredicate((w) {
      if (w is! FilterChip) return false;
      final label = w.label;
      return label is Text && (label.data ?? '').contains('Kumasi');
    });
    expect(kumasiChip, findsOneWidget);
    await tester.tap(kumasiChip);
    await tester.pump();
    expect(cities, contains('Kumasi'));
    expect(find.textContaining('In-zone: Kumasi'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'In-zone shipment fee (GHS)'),
      '15',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Out of region shipment fee (GHS)'),
      '42',
    );
    await tester.pump();
    expect(inZone.text, '15');
    expect(outOfRegion.text, '42');
  });
}
