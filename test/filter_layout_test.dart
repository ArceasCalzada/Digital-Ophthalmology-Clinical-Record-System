import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/theme/app_theme.dart';
import 'package:ophthalmology_clinical_record_system/views/calendar_page_view.dart';
import 'package:ophthalmology_clinical_record_system/views/notification_center_view.dart';
import 'package:ophthalmology_clinical_record_system/views/patients_screen.dart';
import 'package:ophthalmology_clinical_record_system/widgets/filter_pill.dart';

Future<void> pumpAt(WidgetTester tester, Size size, Widget page) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: page)));
  await tester.pumpAndSettle();
  // Offline-sync work started by other tests' seed data can leave a short timer.
  await tester.pump(const Duration(seconds: 1));
}

/// Every pill sits fully inside [maxRight] (the card / screen edge).
void expectPillsInside(WidgetTester tester, double maxRight) {
  for (final pill in tester.widgetList(find.byType(FilterPill))) {
    final rect = tester.getRect(find.byWidget(pill));
    expect(rect.right, lessThanOrEqualTo(maxRight), reason: 'a pill runs past its card');
  }
}

void main() {
  testWidgets('Patient quick filters are left-aligned and stay in the card, wide and narrow', (tester) async {
    await pumpAt(tester, const Size(1600, 900), PatientsScreen(onSelectPatient: (_) {}));
    final card = tester.getRect(find.ancestor(of: find.text('Quick Filters:'), matching: find.byType(Card)).first);
    expect(tester.getTopLeft(find.text('Quick Filters:')).dx - card.left, lessThan(40));
    expectPillsInside(tester, card.right);

    await pumpAt(tester, const Size(360, 800), PatientsScreen(onSelectPatient: (_) {}));
    expect(tester.takeException(), isNull);
    final narrowCard = tester.getRect(find.ancestor(of: find.text('Quick Filters:'), matching: find.byType(Card)).first);
    expectPillsInside(tester, narrowCard.right);
  });

  testWidgets('Calendar filters wrap inside their card on a narrow screen', (tester) async {
    await pumpAt(tester, const Size(360, 800), const CalendarPageView());
    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(FilterPill), findsWidgets);
    expectPillsInside(tester, 360);
    // Left-aligned: the label starts at the card's left edge, not centred.
    expect(tester.getTopLeft(find.text('Type Filter:')).dx, lessThan(60));
  });

  testWidgets('Notification filters wrap inside the screen on a narrow screen', (tester) async {
    await pumpAt(tester, const Size(320, 800), const NotificationCenterView());

    expect(tester.takeException(), isNull);
    expectPillsInside(tester, 320);
  });
}
