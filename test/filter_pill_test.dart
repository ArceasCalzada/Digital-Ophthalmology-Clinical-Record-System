import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/widgets/filter_pill.dart';

void main() {
  testWidgets('FilterPill shows no check mark and only fires when a different pill is chosen', (tester) async {
    var taps = 0;
    Widget pill({required bool selected}) => MaterialApp(
          home: Scaffold(
            body: FilterPill(label: 'Glaucoma', selected: selected, onSelected: () => taps++),
          ),
        );

    await tester.pumpWidget(pill(selected: true));
    expect(find.byIcon(Icons.check), findsNothing);
    await tester.tap(find.text('Glaucoma'));
    await tester.pumpAndSettle();
    expect(taps, 0, reason: 'tapping the pill that is already chosen changes nothing');

    await tester.pumpWidget(pill(selected: false));
    await tester.tap(find.text('Glaucoma'));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });
}
