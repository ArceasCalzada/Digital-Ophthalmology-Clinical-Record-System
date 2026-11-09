import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/models/calendar_event.dart';
import 'package:ophthalmology_clinical_record_system/models/clinical_notification.dart';
import 'package:ophthalmology_clinical_record_system/models/patient.dart';
import 'package:ophthalmology_clinical_record_system/services/auth_service.dart';
import 'package:ophthalmology_clinical_record_system/services/offline_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Patient _makePatient({
  required String id,
  required String mrn,
  required String fullName,
  required String teamId,
  String gender = 'Female',
}) {
  return Patient(
    id: id,
    mrn: mrn,
    fullName: fullName,
    gender: gender,
    dateOfBirth: '1985-05-10',
    phone: '+63 917 555 1234',
    address: 'Metro Manila, Philippines',
    medicalHistory: const [],
    allergies: const [],
    encounters: const [],
    lastVisitDate: '2026-11-01',
    totalVisits: 1,
    teamId: teamId,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.instance.resetForTesting();
    PatientRepository.clearForTesting();
    CalendarEventRepository().disconnect();
    ClinicalNotificationRepository().disconnect();
    OfflineSyncService().stopAutoSyncTimer();
    OfflineSyncService().discardFailed();
  });

  tearDown(() {
    PatientRepository.clearForTesting();
    CalendarEventRepository().disconnect();
    ClinicalNotificationRepository().disconnect();
  });

  group('Cross-Account Data Isolation Tests', () {
    test('Patients are strictly isolated between different account holder teams', () {
      // Connect as Account Holder A (Team A)
      const teamA = 'team-alpha-001';
      PatientRepository.connect(teamA);

      final patientA1 = _makePatient(
        id: 'pat-a-1',
        mrn: 'MRN-A1',
        fullName: 'Alice Walker',
        gender: 'Female',
        teamId: teamA,
      );
      final patientA2 = _makePatient(
        id: 'pat-a-2',
        mrn: 'MRN-A2',
        fullName: 'Aaron Wright',
        gender: 'Male',
        teamId: teamA,
      );

      PatientRepository.addPatient(patientA1);
      PatientRepository.addPatient(patientA2);

      // Verify Account A sees both patients
      final patientsForA = PatientRepository.getAllPatients();
      expect(patientsForA.length, 2);
      expect(patientsForA.map((p) => p.id), containsAll(['pat-a-1', 'pat-a-2']));

      // Switch to Account Holder B (Team B)
      const teamB = 'team-beta-002';
      PatientRepository.connect(teamB);

      // Verify Account B sees ZERO patients from Team A
      final patientsForB = PatientRepository.getAllPatients();
      expect(patientsForB, isEmpty);

      // Add a patient for Account B
      final patientB1 = _makePatient(
        id: 'pat-b-1',
        mrn: 'MRN-B1',
        fullName: 'Bob Martinez',
        gender: 'Male',
        teamId: teamB,
      );
      PatientRepository.addPatient(patientB1);

      // Verify Account B sees only their own patient
      final updatedB = PatientRepository.getAllPatients();
      expect(updatedB.length, 1);
      expect(updatedB.first.id, 'pat-b-1');
      expect(updatedB.first.fullName, 'Bob Martinez');

      // Switch back to Account Holder A
      PatientRepository.connect(teamA);
      final reloadedA = PatientRepository.getAllPatients();
      expect(reloadedA.length, 2);
      expect(reloadedA.map((p) => p.id), containsAll(['pat-a-1', 'pat-a-2']));
      expect(reloadedA.any((p) => p.id == 'pat-b-1'), isFalse);
    });

    test('Connecting without a team does not leak other accounts data', () {
      const teamA = 'team-alpha-001';
      PatientRepository.connect(teamA);
      PatientRepository.addPatient(_makePatient(
        id: 'pat-a-secret',
        mrn: 'MRN-SEC',
        fullName: 'Confidential Patient',
        gender: 'Female',
        teamId: teamA,
      ));

      // Connect with null or empty team (unauthenticated or unready state)
      PatientRepository.connect('');
      final leaked = PatientRepository.getAllPatients();
      expect(leaked, isEmpty, reason: 'Empty team context must return zero patients');
    });

    test('Calendar events and notifications are strictly scoped to the active team', () {
      const teamA = 'team-alpha-001';
      const teamB = 'team-beta-002';

      final calRepo = CalendarEventRepository();
      calRepo.connect(teamA);
      calRepo.addEvent(CalendarEvent(
        id: 'event-a',
        patientName: 'Alice Walker',
        eventType: 'Consultation',
        location: 'Branch 1',
        dateTime: DateTime(2026, 11, 15, 10, 0),
        title: 'Review A',
        teamId: teamA,
      ));

      expect(calRepo.events.length, 1);
      expect(calRepo.events.first.id, 'event-a');

      // Switch to Team B
      calRepo.connect(teamB);
      expect(calRepo.events, isEmpty);

      final notifRepo = ClinicalNotificationRepository();
      notifRepo.connect(teamA);
      notifRepo.addNotification(ClinicalNotification(
        id: 'notif-a',
        title: 'Alert for Alpha',
        message: 'Follow-up due',
        category: 'Reminder',
        severity: NotificationSeverity.warning,
        timestamp: DateTime.now(),
        teamId: teamA,
      ));

      expect(notifRepo.notifications.length, 1);
      expect(notifRepo.notifications.first.id, 'notif-a');

      // Switch to Team B
      notifRepo.connect(teamB);
      expect(notifRepo.notifications, isEmpty);
    });
  });

  group('Sync Speed & Latency Tests', () {
    test('OfflineSyncService queues mutations and commits without meta/counters blockage', () async {
      final sync = OfflineSyncService();
      sync.setNetworkState(NetworkConnectivityState.offline);

      const teamA = 'team-alpha-001';
      PatientRepository.connect(teamA);

      final patient = _makePatient(
        id: 'pat-sync-speed',
        mrn: 'MRN-SPEED-1',
        fullName: 'Flash Gordon',
        gender: 'Male',
        teamId: teamA,
      );

      // Verify enqueueing a patient does not include global meta/counters mutation
      PatientRepository.addPatient(patient);

      expect(sync.pendingQueue, isNotEmpty);
      final mutation = sync.pendingQueue.firstWhere((m) => m.id == 'pat-sync-speed');
      final ops = mutation.resolveOps();

      // Ensure no op targets meta/counters
      expect(ops.any((op) => op.path.contains('meta/counters')), isFalse,
          reason: 'Global counters contention hotspot must be removed');
      expect(ops.any((op) => op.path == 'patients/pat-sync-speed'), isTrue);

      // Now set online and flush
      sync.setNetworkState(NetworkConnectivityState.online);
      await sync.syncNow();
      expect(sync.pendingCount, 0);
      expect(sync.failedMutations, isEmpty);
    });

    test('Chained consecutive mutations flush without 15s delays', () async {
      final sync = OfflineSyncService();
      sync.setNetworkState(NetworkConnectivityState.offline);

      // Enqueue first mutation
      sync.enqueueMutation(
        id: 'mut-1',
        entityType: 'Patient',
        action: 'CREATE',
        payload: {'id': 'mut-1', 'teamId': 'team-speed'},
      );

      // Enqueue second mutation while first may be processing
      sync.enqueueMutation(
        id: 'mut-2',
        entityType: 'Patient',
        action: 'CREATE',
        payload: {'id': 'mut-2', 'teamId': 'team-speed'},
      );

      expect(sync.pendingCount, 2);

      // When network restored, immediately flushes without waiting 15s
      sync.setNetworkState(NetworkConnectivityState.online);
      await sync.syncNow();

      // Both mutations should be flushed
      expect(sync.pendingCount, 0);
      expect(sync.failedMutations, isEmpty);
    });
  });
}
