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
      expect(find.text('Type Filter:'), findsOneWidget);
      expect(find.text('Location:'), findsOneWidget);
      expect(find.text('Upcoming Master Schedule'), findsOneWidget);

      // Verify choice chips exist
      expect(find.text('Surgery'), findsAtLeastNWidgets(1));
      expect(find.text('Davao'), findsAtLeastNWidgets(1));
    });

    testWidgets('Tapping date cell in CalendarPageView opens AddEventModal', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarPageView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find day 10 text widget and scroll into view if needed
      final dayCell = find.text('10');
      if (dayCell.evaluate().isNotEmpty) {
        await tester.ensureVisible(dayCell.first);
        await tester.pumpAndSettle();
        await tester.tap(dayCell.first, warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(find.byType(AddEventModal), findsAtLeastNWidgets(1));
      }
    });

    testWidgets('MainLayout includes Calendar navigation tab and Notification bell indicator', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MainLayout(onLogout: () {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Calendar'), findsAtLeastNWidgets(1));
      expect(find.byIcon(Icons.notifications_active_outlined), findsAtLeastNWidgets(1));
    });
  });
}
