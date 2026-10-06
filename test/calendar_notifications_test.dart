import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/models/calendar_event.dart';
import 'package:ophthalmology_clinical_record_system/models/clinical_notification.dart';
import 'package:ophthalmology_clinical_record_system/views/calendar_page_view.dart';
import 'package:ophthalmology_clinical_record_system/views/main_layout.dart';
import 'package:ophthalmology_clinical_record_system/widgets/add_event_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Calendar & Notification System Integration Tests', () {
    late CalendarEventRepository eventRepo;
    late ClinicalNotificationRepository notifRepo;

    setUp(() {
      eventRepo = CalendarEventRepository();
      notifRepo = ClinicalNotificationRepository();
    });

    test('CalendarEventRepository stores and filters events correctly', () {
      final initialCount = eventRepo.events.length;
      expect(initialCount, greaterThan(0));

      final surgeryEvents = eventRepo.getFilteredEvents(typeFilter: 'Surgery');
      expect(surgeryEvents.every((e) => e.eventType == 'Surgery'), isTrue);

      final davaoEvents = eventRepo.getFilteredEvents(locationFilter: 'Davao');
      expect(davaoEvents.every((e) => e.location == 'Davao'), isTrue);

      final newEvt = CalendarEvent(
        id: 'test-evt-999',
        title: 'Emergency Retinal Detachment Laser',
        eventType: 'Emergency',
        location: 'OR Suite 3',
        dateTime: DateTime.now().add(const Duration(hours: 2)),
        patientName: 'Test Patient',
        reminderMinutes: 15,
      );

      eventRepo.addEvent(newEvt);
      expect(eventRepo.events.length, equals(initialCount + 1));

      final emergencyEvents = eventRepo.getFilteredEvents(typeFilter: 'Emergency');
      expect(emergencyEvents.any((e) => e.id == 'test-evt-999'), isTrue);
    });

    test('ClinicalNotificationRepository tracks unread count and read state', () {
      final initialUnread = notifRepo.unreadCount;
      expect(initialUnread, greaterThanOrEqualTo(0));

      final newNotif = ClinicalNotification(
        id: 'test-notif-999',
        title: 'Critical Surgery Reminder',
        message: 'Phacoemulsification pre-op in 15 minutes',
        category: 'Urgent Alert',
        severity: NotificationSeverity.urgent,
        timestamp: DateTime.now(),
      );

      notifRepo.addNotification(newNotif);
      expect(notifRepo.unreadCount, equals(initialUnread + 1));

      notifRepo.markAsRead('test-notif-999');
      expect(notifRepo.unreadCount, equals(initialUnread));
    });

    testWidgets('CalendarPageView renders month grid, filter chips, and agenda list', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarPageView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Clinical Calendar & Scheduling'), findsOneWidget);

      // Filters start collapsed; opening the section reveals the chips.
      expect(find.text('Type Filter:'), findsNothing);
      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();
      expect(find.text('Type Filter:'), findsOneWidget);
      expect(find.text('Location:'), findsOneWidget);
      expect(find.text('Upcoming Master Schedule'), findsOneWidget);

      // Verify choice chips exist
      expect(find.text('Surgery'), findsAtLeastNWidgets(1));
      expect(find.text('Davao'), findsAtLeastNWidgets(1));
    });

    testWidgets('Tapping a date cell selects it and shows its agenda instead of opening the form', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarPageView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final day = DateTime.now().day == 10 ? '11' : '10';
      final dayCell = find.text(day);
      await tester.ensureVisible(dayCell.first);
      await tester.pumpAndSettle();
      await tester.tap(dayCell.first, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byType(AddEventModal), findsNothing);
      expect(find.textContaining('Agenda for'), findsOneWidget);
    });

    testWidgets('Tapping an agenda event card opens the form pre-filled for editing', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarPageView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Seed data puts events on today, which is the selected day when the page opens.
      // The whole card is the edit button (there is no separate pencil). Matching InkWells
      // with this title, in page order: month-grid day cell, agenda card, master-schedule row.
      expect(find.byTooltip('Edit event'), findsNothing);
      final rows = find.widgetWithText(InkWell, 'Glaucoma Follow-up & IOP Check');
      await tester.tap(rows.at(rows.evaluate().length - 2));
      await tester.pumpAndSettle();

      expect(find.byType(AddEventModal), findsOneWidget);
      expect(find.text('Edit Clinical Event'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
    });

    testWidgets('Tapping a master schedule row opens it for editing, and it has no select circle', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarPageView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
      expect(find.byIcon(Icons.check_circle), findsNothing);

      // The master schedule is the last section, so its row is the last matching InkWell.
      await tester.tap(find.widgetWithText(InkWell, 'Glaucoma Follow-up & IOP Check').last);
      await tester.pumpAndSettle();

      expect(find.text('Edit Clinical Event'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
    });

    testWidgets('Grayed-out days from a neighbouring month are shown and switch the month when tapped', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarPageView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      const months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];

      // Find a month that has leading days (not starting on a Sunday), then tap the
      // last day of the previous month, which is the first cell of the grid.
      var shown = DateTime(DateTime.now().year, DateTime.now().month, 1);
      while (shown.weekday % 7 == 0) {
        await tester.tap(find.byTooltip('Next Month'));
        await tester.pumpAndSettle();
        shown = DateTime(shown.year, shown.month + 1, 1);
      }
      expect(find.text('${months[shown.month - 1]} ${shown.year}'), findsOneWidget);

      final previous = DateTime(shown.year, shown.month, 0);
      await tester.tap(find.text('${previous.day}').first);
      await tester.pumpAndSettle();

      expect(find.text('${months[previous.month - 1]} ${previous.year}'), findsOneWidget);
      expect(find.text('${months[shown.month - 1]} ${shown.year}'), findsNothing);
    });

    testWidgets('MainLayout includes Calendar navigation tab and Notification bell indicator', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: MainLayout(onLogout: () {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Calendar'), findsAtLeastNWidgets(1));
      expect(find.byIcon(Icons.notifications_active_outlined), findsAtLeastNWidgets(1));
      // The bell badge is the only unread indicator; there is no "N NEW" pill.
      expect(find.textContaining(' NEW'), findsNothing);
    });

    testWidgets('Agenda and master schedule have no count pills, and switching days animates to the new agenda', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarPageView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Total:'), findsNothing);
      expect(find.textContaining(' Events'), findsNothing);

      // Day 15 appears once in the month grid (neighbouring-month cells are ≤12 or ≥24).
      final agendaTitle = find.textContaining('Agenda for');
      final before = tester.widget<Text>(agendaTitle).data;
      await tester.tap(find.text('15').first);
      await tester.pump(const Duration(milliseconds: 100));
      // Mid-transition the outgoing and incoming agendas are both on screen.
      expect(agendaTitle, findsNWidgets(2));
      await tester.pumpAndSettle();

      expect(agendaTitle, findsOneWidget);
      expect(tester.widget<Text>(agendaTitle).data, isNot(before));
      expect(find.textContaining('No appointments or surgeries'), findsNothing);
    });
  });
}
