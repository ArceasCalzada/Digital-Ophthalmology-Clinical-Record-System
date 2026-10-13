import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ophthalmology_clinical_record_system/models/calendar_event.dart';
import 'package:ophthalmology_clinical_record_system/models/clinical_notification.dart';
import 'package:ophthalmology_clinical_record_system/models/patient.dart';
import 'package:ophthalmology_clinical_record_system/services/team_service.dart';
import 'package:ophthalmology_clinical_record_system/services/workspace_store.dart';
import 'package:ophthalmology_clinical_record_system/theme/app_theme.dart';
import 'package:ophthalmology_clinical_record_system/views/dashboard_screen.dart';
import 'package:ophthalmology_clinical_record_system/views/notification_center_view.dart';
import 'package:ophthalmology_clinical_record_system/views/calendar_page_view.dart';

Patient _createPatient({
  required String id,
  required String mrn,
  required String fullName,
  required String teamId,
}) {
  return Patient(
    id: id,
    mrn: mrn,
    fullName: fullName,
    dateOfBirth: '1985-01-01',
    gender: 'Female',
    phone: '09123456789',
    address: 'City',
    medicalHistory: const [],
    allergies: const [],
    encounters: const [],
    lastVisitDate: '2026-10-13',
    totalVisits: 1,
    teamId: teamId,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TeamService.instance.load('test-switching-admin', userEmail: 'admin@eyecenter.ph', displayName: 'Admin Dr');
  });

  group('WorkspaceStore & Global State Management Tests', () {
    test('WorkspaceStore broadcasts active workspace ID and syncs with TeamService', () async {
      final teamService = TeamService.instance;
      final eyeCenter = await teamService.createTeam('Eye Center');
      final generalClinic = await teamService.createTeam('General Eye Clinic');

      final store = WorkspaceStore.instance;
      expect(store.activeWorkspaceId, generalClinic.id);
      expect(teamService.activeWorkspaceId, generalClinic.id);

      bool notified = false;
      store.addListener(() {
        notified = true;
      });

      await store.switchWorkspace(eyeCenter.id);
      expect(notified, isTrue);
      expect(store.activeWorkspaceId, eyeCenter.id);
      expect(store.activeWorkspace?.name, 'Eye Center');
      expect(teamService.activeTeam?.id, eyeCenter.id);
    });

    testWidgets('WorkspaceScope exposes activeWorkspaceId via context extension', (tester) async {
      final teamService = TeamService.instance;
      final eyeCenter = await teamService.createTeam('Eye Center Workspace');
      await teamService.switchTo(eyeCenter.id);

      String? foundWorkspaceId;

      await tester.pumpWidget(
        WorkspaceScope(
          store: WorkspaceStore.instance,
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                foundWorkspaceId = context.activeWorkspaceId;
                return Text('Active: $foundWorkspaceId');
              },
            ),
          ),
        ),
      );
      await tester.pump();

      expect(foundWorkspaceId, eyeCenter.id);
      expect(find.text('Active: ${eyeCenter.id}'), findsOneWidget);
    });
  });

  group('Momentary Cache Clear & Repository Scoping Tests', () {
    test('Team switch momentarily clears repository cache to prevent stale data bleeding', () async {
      final teamService = TeamService.instance;
      final clinicA = await teamService.createTeam('Clinic Alpha');
      final clinicB = await teamService.createTeam('Clinic Beta');

      await teamService.switchTo(clinicA.id);

      // Add data to Clinic Alpha
      final patientA = _createPatient(
        id: 'pat-alpha-1',
        mrn: 'MRN-A1',
        fullName: 'Alpha Patient',
        teamId: clinicA.id,
      );
      PatientRepository.addPatient(patientA);

      final eventA = CalendarEvent(
        id: 'evt-alpha-1',
        title: 'Alpha Cataract Consult',
        eventType: 'Consultation',
        location: 'Alpha Room',
        dateTime: DateTime.now(),
        patientName: 'Alpha Patient',
        teamId: clinicA.id,
      );
      CalendarEventRepository().addEvent(eventA);

      final notifA = ClinicalNotification(
        id: 'notif-alpha-1',
        title: 'Alpha Alert',
        message: 'Alert for Alpha',
        category: 'Urgent Alert',
        severity: NotificationSeverity.urgent,
        timestamp: DateTime.now(),
        teamId: clinicA.id,
      );
      ClinicalNotificationRepository().addNotification(notifA);

      expect(PatientRepository.getAllPatients().map((p) => p.id), contains('pat-alpha-1'));
      expect(CalendarEventRepository().events.map((e) => e.id), contains('evt-alpha-1'));
      expect(ClinicalNotificationRepository().notifications.map((n) => n.id), contains('notif-alpha-1'));

      // Switch to Clinic Beta
      await teamService.switchTo(clinicB.id);

      // Clinic Beta has no records yet - Alpha data must not bleed over
      expect(PatientRepository.getAllPatients(), isEmpty);
      expect(CalendarEventRepository().events, isEmpty);
      expect(ClinicalNotificationRepository().notifications, isEmpty);

      // Switch back to Clinic Alpha - Alpha data restored immediately
      await teamService.switchTo(clinicA.id);
      expect(PatientRepository.getAllPatients().map((p) => p.id), contains('pat-alpha-1'));
      expect(CalendarEventRepository().events.map((e) => e.id), contains('evt-alpha-1'));
      expect(ClinicalNotificationRepository().notifications.map((n) => n.id), contains('notif-alpha-1'));
    });
  });

  group('Calendar Oct 16 Surgery & Upcoming Event Tests', () {
    testWidgets('Calendar displays Oct 16 Surgery only when parent workspace is active', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final teamService = TeamService.instance;
      final eyeCenter = await teamService.createTeam('Eye Center');
      final otherClinic = await teamService.createTeam('Other Clinic');

      // Schedule Oct 16 Surgery for Eye Center
      final oct16 = DateTime(2026, 10, 16, 14, 0);
      final surgeryEvent = CalendarEvent(
        id: 'evt-oct16-surgery',
        title: 'Oct 16 Phacoemulsification Surgery',
        eventType: 'Surgery',
        location: 'OR Suite 1',
        dateTime: oct16,
        patientName: 'Ramon Dela Cruz',
        patientId: 'P-EYE-100',
        teamId: eyeCenter.id,
      );
      CalendarEventRepository().addEvent(surgeryEvent);

      // 1. Activate Other Clinic
      await teamService.switchTo(otherClinic.id);

      await tester.pumpWidget(
        WorkspaceScope(
          store: WorkspaceStore.instance,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: CalendarPageView(initialDate: oct16),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Surgery should NOT be visible for Other Clinic
      expect(find.text('Oct 16 Phacoemulsification Surgery'), findsNothing);

      // 2. Switch to Eye Center
      await teamService.switchTo(eyeCenter.id);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Surgery MUST now be visible
      expect(find.text('Oct 16 Phacoemulsification Surgery'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Ramon Dela Cruz'), findsAtLeastNWidgets(1));
    });
  });

  group('Dashboard Schedules & Clinical Patient Records Workspace Binding Tests', () {
    testWidgets('Dashboard updates Schedules and Patient Records without false empty states', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final teamService = TeamService.instance;
      final eyeCenter = await teamService.createTeam('Eye Center');
      final generalClinic = await teamService.createTeam('General Clinic');

      final today = DateTime.now();

      // Eye Center Patient & Today Schedule
      final eyeCenterPatient = _createPatient(
        id: 'pat-eye-1',
        mrn: 'MRN-EYE-001',
        fullName: 'Maria Santos',
        teamId: eyeCenter.id,
      );
      PatientRepository.addPatient(eyeCenterPatient);

      final eyeCenterSchedule = CalendarEvent(
        id: 'evt-eye-today',
        title: 'Cataract Pre-Op Assessment',
        eventType: 'Checkup',
        location: 'Exam Room 1',
        dateTime: DateTime(today.year, today.month, today.day, 10, 0),
        patientName: 'Maria Santos',
        teamId: eyeCenter.id,
      );
      CalendarEventRepository().addEvent(eyeCenterSchedule);

      // General Clinic Patient & Today Schedule
      final generalPatient = _createPatient(
        id: 'pat-gen-1',
        mrn: 'MRN-GEN-002',
        fullName: 'Juan Luna',
        teamId: generalClinic.id,
      );
      PatientRepository.addPatient(generalPatient);

      final generalSchedule = CalendarEvent(
        id: 'evt-gen-today',
        title: 'Routine Vision Screening',
        eventType: 'Checkup',
        location: 'Room B',
        dateTime: DateTime(today.year, today.month, today.day, 11, 30),
        patientName: 'Juan Luna',
        teamId: generalClinic.id,
      );
      CalendarEventRepository().addEvent(generalSchedule);

      // Start with General Clinic
      await teamService.switchTo(generalClinic.id);

      await tester.pumpWidget(
        WorkspaceScope(
          store: WorkspaceStore.instance,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: DashboardScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // General clinic records should be shown; Eye Center records should NOT be shown
      expect(find.text('Juan Luna'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Routine Vision Screening'), findsOneWidget);
      expect(find.text('Maria Santos'), findsNothing);
      expect(find.textContaining('Cataract Pre-Op Assessment'), findsNothing);
      expect(find.text('No patient records in database.'), findsNothing);
      expect(find.text('Nothing scheduled for today'), findsNothing);

      // Switch to Eye Center
      await teamService.switchTo(eyeCenter.id);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Eye Center records should now be shown; General Clinic records removed
      expect(find.text('Maria Santos'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Cataract Pre-Op Assessment'), findsOneWidget);
      expect(find.text('Juan Luna'), findsNothing);
      expect(find.textContaining('Routine Vision Screening'), findsNothing);
      expect(find.text('No patient records in database.'), findsNothing);
      expect(find.text('Nothing scheduled for today'), findsNothing);
    });
  });

  group('Notifications Modal Workspace Isolation Tests', () {
    testWidgets('Notification modal strictly displays alerts for the active workspace', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final teamService = TeamService.instance;
      final eyeCenter = await teamService.createTeam('Eye Center Alerts');
      final otherTeam = await teamService.createTeam('Other Alerts Team');

      final alertEyeCenter = ClinicalNotification(
        id: 'notif-eye-1',
        title: 'Post-Op Infection Alert',
        message: 'Patient requires urgent follow-up for Eye Center.',
        category: 'Urgent Alert',
        severity: NotificationSeverity.urgent,
        timestamp: DateTime.now(),
        teamId: eyeCenter.id,
      );
      ClinicalNotificationRepository().addNotification(alertEyeCenter);

      final alertOther = ClinicalNotification(
        id: 'notif-other-1',
        title: 'Medication Refill Request',
        message: 'Standard refill request for Other Team.',
        category: 'Refills',
        severity: NotificationSeverity.info,
        timestamp: DateTime.now(),
        teamId: otherTeam.id,
      );
      ClinicalNotificationRepository().addNotification(alertOther);

      // Start on Other Team
      await teamService.switchTo(otherTeam.id);

      await tester.pumpWidget(
        WorkspaceScope(
          store: WorkspaceStore.instance,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: NotificationCenterView(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Should show Other Team's alert only
      expect(find.text('Medication Refill Request'), findsOneWidget);
      expect(find.text('Post-Op Infection Alert'), findsNothing);

      // Switch to Eye Center
      await teamService.switchTo(eyeCenter.id);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Should show Eye Center's alert only
      expect(find.text('Post-Op Infection Alert'), findsOneWidget);
      expect(find.text('Medication Refill Request'), findsNothing);
    });
  });
}
