import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/theme/app_theme.dart';
import 'package:ophthalmology_clinical_record_system/views/calendar_page_view.dart';

void main() {
  testWidgets('Calendar page opens on initialDate when given one', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final date = DateTime.now().add(const Duration(days: 40));
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: CalendarPageView(initialDate: date))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Agenda for ${formatScheduleDate(date, long: true)}'), findsOneWidget);
  });
}
