import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/models/clinical_notification.dart';
import 'package:ophthalmology_clinical_record_system/theme/app_theme.dart';
import 'package:ophthalmology_clinical_record_system/views/notification_center_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ClinicalNotificationRepository().clearForTesting();
  });

  tearDown(() {
    ClinicalNotificationRepository().clearForTesting();
  });

  Widget buildNotificationApp() {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: const Scaffold(
        body: NotificationCenterView(),
      ),
    );
  }

  group('Notifications Repository Deduplication & Placeholder Cleaning Tests', () {
    test('Repository starts with empty list by default (no uninvited hardcoded mocks)', () {
      final repo = ClinicalNotificationRepository();
      expect(repo.notifications, isEmpty);
      expect(repo.unreadCount, 0);
    });

    test('addNotification rejects dummy and empty placeholder notifications', () {
      final repo = ClinicalNotificationRepository();

      // Attempt to add empty placeholder
      repo.addNotification(ClinicalNotification(
        id: 'mock-dummy-1',
        title: '',
        message: '',
        category: 'Reminder',
        severity: NotificationSeverity.info,
        timestamp: DateTime.now(),
      ));

      // Attempt to add "Clinical Alert" placeholder with no message
      repo.addNotification(ClinicalNotification(
        id: 'mock-dummy-2',
        title: 'Clinical Alert',
        message: '',
        category: 'Reminder',
        severity: NotificationSeverity.info,
        timestamp: DateTime.now(),
      ));

      expect(repo.notifications, isEmpty);
    });

    test('addNotification deduplicates items with matching ID or content signature', () {
      final repo = ClinicalNotificationRepository();
      final now = DateTime.now();

      final alert1 = ClinicalNotification(
        id: 'real-notif-1',
        title: 'Elevated IOP OD: 32 mmHg',
        message: 'Patient Juan Dela Cruz requires emergency evaluation.',
        category: 'Urgent Alert',
        severity: NotificationSeverity.urgent,
        timestamp: now,
        patientName: 'Juan Dela Cruz',
        patientId: 'P-101',
      );

      final duplicateAlert1 = ClinicalNotification(
        id: 'real-notif-1',
        title: 'Elevated IOP OD: 32 mmHg',
        message: 'Patient Juan Dela Cruz requires emergency evaluation.',
        category: 'Urgent Alert',
        severity: NotificationSeverity.urgent,
        timestamp: now,
        patientName: 'Juan Dela Cruz',
        patientId: 'P-101',
      );

      final sameContentDiffId = ClinicalNotification(
        id: 'real-notif-diff-id',
        title: 'Elevated IOP OD: 32 mmHg',
        message: 'Patient Juan Dela Cruz requires emergency evaluation.',
        category: 'Urgent Alert',
        severity: NotificationSeverity.urgent,
        timestamp: now,
        patientName: 'Juan Dela Cruz',
        patientId: 'P-101',
      );

      repo.addNotification(alert1);
      expect(repo.notifications.length, 1);

      // Adding duplicate with same ID updates in place, does not duplicate
      repo.addNotification(duplicateAlert1);
      expect(repo.notifications.length, 1);

      // Adding identical alert with generated ID also updates in place
      repo.addNotification(sameContentDiffId);
      expect(repo.notifications.length, 1);
      expect(repo.notifications.first.title, 'Elevated IOP OD: 32 mmHg');
    });

    test('fromJson rejects empty title and message without synthesizing dummy Clinical Alert', () {
      final dummyJson = <String, dynamic>{
        'id': 'empty-doc-1',
        'title': '',
        'message': '',
        'category': 'Reminder',
      };
      final parsed = ClinicalNotification.fromJson(dummyJson);
      expect(parsed.isPlaceholderOrEmpty, isTrue);
      expect(parsed.title, isEmpty);
    });
  });

  group('NotificationCenterView UI & Empty State Tests', () {
    testWidgets('Renders clean empty state when notification queue is empty', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildNotificationApp());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('notifications_empty_state')), findsOneWidget);
      expect(find.text('All Caught Up!'), findsOneWidget);
      expect(find.text('No new alerts or pending reminders at this time.'), findsOneWidget);
      expect(find.text('0 alerts'), findsOneWidget);

      // Verify no placeholder cards are rendered
      expect(find.text('Clinical Alert'), findsNothing);
      expect(find.text('REMINDER'), findsNothing);
    });

    testWidgets('Renders filtered empty state when a filter category has no alerts', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repo = ClinicalNotificationRepository();
      repo.addNotification(
        ClinicalNotification(
          id: 'urgent-notif-1',
          title: 'Retinal Detachment Warning',
          message: 'Patient reports sudden flashes and floaters.',
          category: 'Urgent Alert',
          severity: NotificationSeverity.urgent,
          timestamp: DateTime.now(),
        ),
        enqueueSync: false,
      );

      await tester.pumpWidget(buildNotificationApp());
      await tester.pumpAndSettle();

      expect(find.text('1 alert'), findsOneWidget);
      expect(find.text('Retinal Detachment Warning'), findsOneWidget);

      // Tap "Refills" filter chip
      await tester.tap(find.text('Refills'));
      await tester.pumpAndSettle();

      // Now "Refills" should show empty state
      expect(find.byKey(const Key('notifications_empty_state')), findsOneWidget);
      expect(find.text('No Matching Alerts'), findsOneWidget);
      expect(find.text('There are no clinical alerts matching the "Refills" filter.'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('Renders live genuine notifications without duplicate cards or icons', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repo = ClinicalNotificationRepository();
      final now = DateTime.now();

      // Add two distinct genuine notifications
      repo.addNotification(
        ClinicalNotification(
          id: 'n-real-1',
          title: 'Post-Op Day 1 Review Due',
          message: 'Phacoemulsification post-op check for Eleanor Vance.',
          category: 'Reminder',
          severity: NotificationSeverity.warning,
          timestamp: now.subtract(const Duration(minutes: 5)),
          patientName: 'Eleanor Vance',
          patientId: 'MRN-10024',
        ),
        enqueueSync: false,
      );

      repo.addNotification(
        ClinicalNotification(
          id: 'n-real-2',
          title: 'Critical Corneal Abrasion',
          message: 'Seidel test positive OD. Urgent corneal specialist review needed.',
          category: 'Urgent Alert',
          severity: NotificationSeverity.urgent,
          timestamp: now.subtract(const Duration(minutes: 10)),
          patientName: 'Carlos Mendoza',
          patientId: 'MRN-10025',
        ),
        enqueueSync: false,
      );

      await tester.pumpWidget(buildNotificationApp());
      await tester.pumpAndSettle();

      expect(find.text('2 alerts'), findsOneWidget);
      expect(find.text('Post-Op Day 1 Review Due'), findsOneWidget);
      expect(find.text('Critical Corneal Abrasion'), findsOneWidget);
      expect(find.text('Eleanor Vance (MRN-10024)'), findsOneWidget);
      expect(find.text('Carlos Mendoza (MRN-10025)'), findsOneWidget);

      // Verify empty state is NOT present when notifications exist
      expect(find.byKey(const Key('notifications_empty_state')), findsNothing);

      await tester.pump(const Duration(seconds: 1));
    });
  });
}
