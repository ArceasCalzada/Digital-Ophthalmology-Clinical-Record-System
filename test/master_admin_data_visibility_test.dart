import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/models/calendar_event.dart';
import 'package:ophthalmology_clinical_record_system/models/clinical_notification.dart';
import 'package:ophthalmology_clinical_record_system/models/patient.dart';
import 'package:ophthalmology_clinical_record_system/models/team.dart';
import 'package:ophthalmology_clinical_record_system/services/team_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Master Admin (admin.docrs@gmail.com) Data Visibility Tests', () {
    setUp(() async {
      PatientRepository.clearForTesting();
    });

    test('Master admin gets owner privileges and cannot be treated as assistant', () async {
      await TeamService.instance.load('admin-uid', userEmail: 'admin.docrs@gmail.com', displayName: 'Admin User');

      expect(TeamService.instance.isMasterAdmin, isTrue);
      expect(TeamService.instance.isAssistant, isFalse);
      expect(TeamService.instance.activeRole, equals(TeamRole.owner));
      expect(TeamService.instance.canViewPatients, isTrue);
      expect(TeamService.instance.canEditPatients, isTrue);
      expect(TeamService.instance.canSeeVisits, isTrue);
      expect(TeamService.instance.canWriteVisits, isTrue);
      expect(TeamService.instance.canManageMembers, isTrue);
    });

    test('PatientRepository exposes all clinic patients to Master Admin regardless of team ID', () async {
      await TeamService.instance.load('admin-uid', userEmail: 'admin.docrs@gmail.com');

      final patientA = Patient(
        id: 'p-clinic-a',
        mrn: 'MRN-A',
        fullName: 'Juan Dela Cruz',
        dateOfBirth: '1980-01-01',
        gender: 'Male',
        phone: '09123456789',
        address: 'Davao City',
        occupation: 'Farmer',
        phicNumber: '',
        notes: '',
        medicalHistory: const [],
        allergies: const [],
        previousDiagnoses: const [],
        previousPrescriptions: const [],
        prescriptions: const [],
        encounters: const [],
        teamId: 'team-branch-alpha',
        lastVisitDate: '2026-10-01',
        totalVisits: 2,
      );

      final patientB = Patient(
        id: 'p-clinic-b',
        mrn: 'MRN-B',
        fullName: 'Maria Mercedes',
        dateOfBirth: '1990-05-12',
        gender: 'Female',
        phone: '09987654321',
        address: 'Tagum City',
        occupation: 'Teacher',
        phicNumber: '',
        notes: '',
        medicalHistory: const [],
        allergies: const [],
        previousDiagnoses: const [],
        previousPrescriptions: const [],
        prescriptions: const [],
        encounters: const [],
        teamId: 'team-branch-beta',
        lastVisitDate: '2026-10-15',
        totalVisits: 1,
      );

      PatientRepository.addPatient(patientA);
      PatientRepository.addPatient(patientB);

      // Connect to team 'team-other' which has no patients of its own
      PatientRepository.connect('team-other');

      final allPatients = PatientRepository.getAllPatients();
      expect(allPatients.length, equals(2));
      expect(allPatients.any((p) => p.id == 'p-clinic-a'), isTrue);
      expect(allPatients.any((p) => p.id == 'p-clinic-b'), isTrue);
    });

    test('CalendarEventRepository and ClinicalNotificationRepository expose data to Master Admin', () async {
      await TeamService.instance.load('admin-uid', userEmail: 'admin.docrs@gmail.com');

      final calRepo = CalendarEventRepository();
      calRepo.connect('some-empty-team');

      final event = CalendarEvent(
        id: 'event-x-1',
        teamId: 'team-x',
        title: 'Cataract Surgery',
        eventType: 'Surgery',
        location: 'Main OR',
        dateTime: DateTime.now().add(const Duration(days: 1)),
        patientName: 'Pedro Penduko',
      );
      calRepo.addEvent(event);
      expect(calRepo.events.any((e) => e.id == 'event-x-1'), isTrue);

      final notifRepo = ClinicalNotificationRepository();
      notifRepo.connect('some-empty-team');
      final notif = ClinicalNotification(
        id: 'notif-x-1',
        title: 'Critical Alert',
        message: 'High IOP',
        teamId: 'team-y',
        category: 'UrgentAlert',
        severity: NotificationSeverity.urgent,
        timestamp: DateTime.now(),
      );
      notifRepo.addNotification(notif);
      expect(notifRepo.notifications.any((n) => n.id == 'notif-x-1'), isTrue);
    });
  });
}
