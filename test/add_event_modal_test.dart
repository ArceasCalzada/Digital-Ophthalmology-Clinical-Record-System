import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/models/calendar_event.dart';
import 'package:ophthalmology_clinical_record_system/models/patient.dart';
import 'package:ophthalmology_clinical_record_system/services/reminder_settings_store.dart';
import 'package:ophthalmology_clinical_record_system/theme/app_theme.dart';
import 'package:ophthalmology_clinical_record_system/views/calendar_page_view.dart';
import 'package:ophthalmology_clinical_record_system/widgets/add_event_modal.dart';
import 'helpers/shake_finders.dart';

Future<void> openModal(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => AddEventModal.show(context, initialDate: DateTime(2030, 3, 4)),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('only the date and time fields keep an icon; type and location start as None', (tester) async {
    await openModal(tester);

    expect(find.byIcon(Icons.calendar_today_rounded), findsOneWidget);
    expect(find.byIcon(Icons.access_time_rounded), findsOneWidget);
    for (final removed in [
      Icons.calendar_month_rounded,
      Icons.event_note,
      Icons.person_rounded,
      Icons.event_rounded,
      Icons.location_on_rounded,
      Icons.notifications_active_rounded,
    ]) {
      expect(find.byIcon(removed), findsNothing, reason: '$removed should be gone');
    }

    // Event type and location are not assumed.
    expect(find.text('None'), findsNWidgets(2));
    expect(find.text('Checkup'), findsNothing);
    expect(find.text('Davao'), findsNothing);
  });

  testWidgets('title and date & time are marked required with a red asterisk', (tester) async {
    await openModal(tester);

    for (final label in ['Event Title', 'Schedule Date & Time']) {
      final rich = tester.widget<RichText>(find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText() == '$label *',
      ));
      // Find the asterisk span wherever the label nests it.
      TextSpan? star;
      rich.text.visitChildren((span) {
        if (span is TextSpan && span.text == ' *') star = span;
        return true;
      });
      expect(star, isNotNull, reason: '"$label" needs an asterisk');
      expect(star!.style!.color, const Color(0xFFDC2626));
    }
    // Optional fields have no asterisk.
    expect(find.textContaining('Location *'), findsNothing);
    expect(find.textContaining('Event Type *'), findsNothing);
  });

  testWidgets('a title is required, but event type and location may stay empty', (tester) async {
    final repo = CalendarEventRepository();
    await openModal(tester);
    final before = repo.events.length;

    final titleField = find.byType(TextFormField).first;
    expect(shakeOffset(tester, titleField), 0);
    await tester.tap(find.text('Confirm & Save Event'));
    await letShakeStart(tester);
    expect(shakeOffset(tester, titleField), isNot(0), reason: 'the empty title shakes');
    expect(find.text('Enter an event title'), findsNothing, reason: 'no message, just the shake');
    await tester.pumpAndSettle();
    expect(shakeOffset(tester, titleField), 0, reason: 'and settles again');
    expect(repo.events.length, before, reason: 'nothing is saved without a title');

    await tester.enterText(find.byType(TextFormField).first, 'Lens follow-up');
    await tester.tap(find.text('Confirm & Save Event'));
    await tester.pumpAndSettle();

    expect(repo.events.length, before + 1);
    final saved = repo.events.last;
    expect(saved.title, 'Lens follow-up');
    expect(saved.eventType, isEmpty);
    expect(saved.location, isEmpty);
    expect(saved.dateTime.year, 2030);
  });

  testWidgets('an event without a type or location renders cleanly in the agenda and master schedule', (tester) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    CalendarEventRepository().addEvent(CalendarEvent(
      id: 'evt-untyped',
      title: 'Untyped walk-in',
      eventType: '',
      location: '',
      dateTime: DateTime.now(),
      patientName: 'Walk-in Patient',
    ));

    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: CalendarPageView())));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Untyped walk-in'), findsWidgets);
    // No empty "()" is left behind in the master schedule line.
    expect(find.textContaining('Walk-in Patient ()'), findsNothing);
    expect(find.textContaining('Walk-in Patient'), findsWidgets);

    // addEvent queues a cloud sync behind a short timer; let it run before the test ends.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('patient, type and location are dropdowns under their field, not pop-ups', (tester) async {
    await openModal(tester);
    final dialogsBefore = find.byType(Dialog).evaluate().length;

    // Location: the list opens right below the field and choosing an entry fills it in.
    final locationField = tester.getRect(find.ancestor(of: find.text('None').last, matching: find.byType(InkWell)).first);
    await tester.tap(find.text('None').last);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog).evaluate().length, dialogsBefore, reason: 'no pop-up opened');
    expect(tester.getTopLeft(find.text('Bukidnon')).dy, greaterThanOrEqualTo(locationField.bottom));
    await tester.tap(find.text('Bukidnon'));
    await tester.pumpAndSettle();
    expect(find.text('Bukidnon'), findsOneWidget);

  });

  testWidgets('the form no longer asks for a reminder; a new event takes the one set in Settings', (tester) async {
    final settings = ReminderSettingsStore.instance;
    final repo = CalendarEventRepository();
    addTearDown(settings.resetForTest);

    settings.minutesBefore = 60;
    await openModal(tester);
    expect(find.text('Notification Reminder Alert'), findsNothing);
    expect(find.textContaining('minutes before'), findsNothing);
    expect(find.text('1 hour before'), findsNothing);

    await tester.enterText(find.byType(TextFormField).first, 'Reminder default');
    await tester.tap(find.text('Confirm & Save Event'));
    await tester.pumpAndSettle();
    expect(repo.events.last.title, 'Reminder default');
    expect(repo.events.last.reminderMinutes, 60);

    // addEvent queues a cloud sync behind a short timer; let it run before the test ends.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the patient dropdown has a search box that narrows the list', (tester) async {
    Patient patient(String id, String name) => Patient(
          id: id,
          mrn: 'PT-$id',
          fullName: name,
          dateOfBirth: '1980-01-01',
          gender: 'Female',
          phone: '+63 900 000 0000',
          address: 'Davao',
          medicalHistory: const [],
          allergies: const [],
          encounters: const [],
          lastVisitDate: '2026-01-01',
          totalVisits: 1,
        );
    PatientRepository.addPatient(patient('100001', 'Alma Cruz'));
    PatientRepository.addPatient(patient('100002', 'Bruno Reyes'));
    addTearDown(PatientRepository.disconnect);

    await openModal(tester);
    // A new event starts with the newest patient chosen; open the list from that field.
    await tester.tap(find.text('Bruno Reyes (PT-100002)'));
    await tester.pumpAndSettle();
    expect(find.text('Alma Cruz'), findsOneWidget);
    expect(find.text('Bruno Reyes'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Search patient by name...'), 'alm');
    await tester.pumpAndSettle();
    expect(find.text('Bruno Reyes'), findsNothing);
    expect(find.text('Alma Cruz'), findsOneWidget);

    await tester.tap(find.text('Alma Cruz'));
    await tester.pumpAndSettle();
    expect(find.text('Alma Cruz (PT-100001)'), findsOneWidget, reason: 'the chosen patient is shown in the field');
    await tester.pump(const Duration(seconds: 1)); // addPatient queues a sync behind a short timer
  });
}
