import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/models/calendar_event.dart';
import 'package:ophthalmology_clinical_record_system/models/clinical_notification.dart';
import 'package:ophthalmology_clinical_record_system/views/main_layout.dart';
import 'package:ophthalmology_clinical_record_system/widgets/add_event_modal.dart';

void main() {
  group('CalendarEventRepository Unit Tests', () {
    test('Initial seed events loaded', () {
      final repo = CalendarEventRepository();
      expect(repo.events.isNotEmpty, isTrue);
    });

    test('Add new event increases count', () {
      final repo = CalendarEventRepository();
      final initialCount = repo.events.length;
      final newEvt = CalendarEvent(
        id: 'test-evt-99',
        title: 'Test Consultation',
        eventType: 'Consultation',
        location: 'Exam Room 1',
        dateTime: DateTime.now(),
        patientName: 'Test Patient',
      );

      repo.addEvent(newEvt);
      expect(repo.events.length, equals(initialCount + 1));
      expect(repo.events.firstWhere((e) => e.id == 'test-evt-99').title, equals('Test Consultation'));
    });

    test('Toggle event completed status', () {
      final repo = CalendarEventRepository();
      final evt = repo.events.first;
      final initialStatus = evt.isCompleted;

      repo.toggleEventStatus(evt.id);
      expect(evt.isCompleted, equals(!initialStatus));
    });
  });

  group('ClinicalNotificationRepository Unit Tests', () {
    test('Initial seed notifications loaded', () {
      final repo = ClinicalNotificationRepository();
      expect(repo.notifications.isNotEmpty, isTrue);
    });

    test('Mark notification as read updates unread count', () {
      final repo = ClinicalNotificationRepository();
      final initialUnread = repo.unreadCount;

      if (initialUnread > 0) {
        final unreadNotif = repo.notifications.firstWhere((n) => !n.isRead);
        repo.markAsRead(unreadNotif.id);
        expect(repo.unreadCount, equals(initialUnread - 1));
      }
    });

    test('Dismiss notification removes item', () {
      final repo = ClinicalNotificationRepository();
      final notif = repo.notifications.first;
      final initialCount = repo.notifications.length;

      repo.dismissNotification(notif.id);
      expect(repo.notifications.length, equals(initialCount - 1));
    });
  });

  group('Mobile UI Adaptation Widget Tests', () {
    testWidgets('Renders Bottom Navigation Bar on mobile screen (390x844)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: MainLayout(onLogout: () {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.text('Calendar'), findsOneWidget);
      expect(find.text('Agenda'), findsOneWidget);
      expect(find.text('Alerts'), findsOneWidget);
      expect(find.text('Records'), findsOneWidget);

      tester.view.resetPhysicalSize();
    });

    testWidgets('Add Event modal opens smoothly on mobile', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => AddEventModal.show(context),
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Add Clinical Event'), findsOneWidget);
      expect(find.text('Confirm & Save Event'), findsOneWidget);

      tester.view.resetPhysicalSize();
    });
  });
}
