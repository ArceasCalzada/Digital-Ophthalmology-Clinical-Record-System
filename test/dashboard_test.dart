import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/models/calendar_event.dart';
import 'package:ophthalmology_clinical_record_system/models/patient.dart';
import 'package:ophthalmology_clinical_record_system/theme/app_theme.dart';
import 'package:ophthalmology_clinical_record_system/views/dashboard_screen.dart';

void main() {
  testWidgets('Dashboard renders greeting, queue, calendar and patient records', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: DashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Dr. Sigrid Robillos, MD'), findsOneWidget);
    expect(find.text('Schedules'), findsOneWidget);
    // Staff do not know patient IDs, so the search prompt does not ask for one.
    expect(find.text('Search patient by name or phone...'), findsOneWidget);
    expect(find.textContaining('MRN'), findsNothing);
    expect(find.text('Clinic Calendar'), findsNothing);
    expect(find.textContaining('Clinical Patient Records'), findsOneWidget);
  });

  testWidgets('Schedules lists today\'s calendar events, not tomorrow\'s', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Seed events evt-101..103 are today; evt-104/105 are tomorrow.
    expect(find.byKey(const Key('schedule_event_evt-101')), findsOneWidget);
    expect(find.byKey(const Key('schedule_event_evt-103')), findsOneWidget);
    expect(find.byKey(const Key('schedule_event_evt-104')), findsNothing);
    expect(find.text('Nothing scheduled for today'), findsNothing);
  });

  testWidgets('Mini calendar dots follow real events and update when one is added', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final repo = CalendarEventRepository();
    final now = DateTime.now();
    // A day in this month that has no seed event (seed events sit on today..today+2).
    final freeDay = [for (var d = 1; d <= 28; d++) d].firstWhere((d) => (d - now.day).abs() > 3);
    int dotCount() => find.byKey(const Key('dashboard_calendar_dot')).evaluate().length;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final before = dotCount();

    const id = 'test-dot-event';
    repo.addEvent(CalendarEvent(
      id: id,
      title: 'Dot test',
      eventType: 'Checkup',
      location: 'Davao',
      dateTime: DateTime(now.year, now.month, freeDay, 9),
      patientName: 'Test Patient',
    ));
    await tester.pumpAndSettle();
    final withEvent = dotCount();

    repo.deleteEvent(id);
    await tester.pumpAndSettle();
    final afterDelete = dotCount();

    // Each queued change starts a short offline-sync delay; let it finish.
    await tester.pump(const Duration(seconds: 1));

    expect(withEvent, before + 1);
    expect(afterDelete, before);
  });

  testWidgets('Clicking the calendar header opens the calendar with no date; clicking a day passes that date', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final calls = <DateTime?>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: DashboardScreen(onOpenCalendar: calls.add),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('dashboard_mini_calendar_header')));
    await tester.pump();
    expect(calls, [null]);

    final now = DateTime.now();
    await tester.tap(find.byKey(const Key('dashboard_calendar_day_15')));
    await tester.pump();
    expect(calls.last, DateTime(now.year, now.month, 15));
    expect(calls.length, 2);
  });

  testWidgets('Days with seed events (today) show a dot, and days are hoverable', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: DashboardScreen(onOpenCalendar: (_) {})),
      ),
    );
    await tester.pumpAndSettle();

    final today = DateTime.now().day;
    expect(
      find.descendant(
        of: find.byKey(Key('dashboard_calendar_day_$today')),
        matching: find.byKey(const Key('dashboard_calendar_dot')),
      ),
      findsOneWidget,
    );

    // Each day is an enabled InkWell with a hover tint, so it highlights under the mouse.
    final day = tester.widget<InkWell>(find.byKey(const Key('dashboard_calendar_day_15')));
    expect(day.onTap, isNotNull);
    expect(day.hoverColor, isNotNull);
  });

  test('formatRegistrationDate formats ISO timestamp to human readable clinical date & time', () {
    final formatted = formatRegistrationDate('2026-09-29T09:42:00.000');
    expect(formatted, contains('September 29, 2026'));
    expect(formatted, contains('9:42 AM'));
  });
}