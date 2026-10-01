import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/models/team.dart';
import 'package:ophthalmology_clinical_record_system/models/patient.dart';
import 'package:ophthalmology_clinical_record_system/models/encounter.dart';
import 'package:ophthalmology_clinical_record_system/models/prescription.dart';
import 'package:ophthalmology_clinical_record_system/models/eye_exam.dart';
import 'package:ophthalmology_clinical_record_system/services/team_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TeamRole Permission Matrix Tests', () {
    test('Owner role has full permissions', () {
      const role = TeamRole.owner;
      expect(role.canViewPatients, isTrue);
      expect(role.canEditPatients, isTrue);
      expect(role.canSeeVisits, isTrue);
      expect(role.canWriteVisits, isTrue);
      expect(role.canManageMembers, isTrue);
      expect(role.canDeleteOrTransfer, isTrue);
    });

    test('Editor role can view/edit patients and write visits but cannot manage members', () {
      const role = TeamRole.editor;
      expect(role.canViewPatients, isTrue);
      expect(role.canEditPatients, isTrue);
      expect(role.canSeeVisits, isTrue);
      expect(role.canWriteVisits, isTrue);
      expect(role.canManageMembers, isFalse);
      expect(role.canDeleteOrTransfer, isFalse);
    });

    test('Assistant role can view/edit patients ONLY (no visits or prescriptions access)', () {
      const role = TeamRole.assistant;
      expect(role.canViewPatients, isTrue);
      expect(role.canEditPatients, isTrue);
      expect(role.canSeeVisits, isFalse);
      expect(role.canWriteVisits, isFalse);
      expect(role.canManageMembers, isFalse);
    });

    test('Viewer role has read-only access to patients and visits', () {
      const role = TeamRole.viewer;
      expect(role.canViewPatients, isTrue);
      expect(role.canEditPatients, isFalse);
      expect(role.canSeeVisits, isTrue);
      expect(role.canWriteVisits, isFalse);
      expect(role.canManageMembers, isFalse);
    });

    test('TeamRole parses legacy strings gracefully', () {
      expect(TeamRole.parse('owner'), TeamRole.owner);
      expect(TeamRole.parse('leader'), TeamRole.owner);
      expect(TeamRole.parse('editor'), TeamRole.editor);
      expect(TeamRole.parse('assistant'), TeamRole.assistant);
      expect(TeamRole.parse('viewer'), TeamRole.viewer);
      expect(TeamRole.parse('member'), TeamRole.viewer);
      expect(TeamRole.parse(null), TeamRole.viewer);
    });
  });

  group('Team & Member Serialization Tests', () {
    test('Team converts to/from JSON correctly', () {
      const team = Team(
        id: 't-123',
        name: 'Metro Eye Clinic',
        ownerId: 'u-456',
        inviteCode: 'DOC-8921',
        createdAt: '2026-10-01T12:00:00.000',
        patientCount: 15,
      );

      final json = team.toJson();
      expect(json['id'], 't-123');
      expect(json['name'], 'Metro Eye Clinic');
      expect(json['inviteCode'], 'DOC-8921');

      final reconstructed = Team.fromJson(json);
      expect(reconstructed.id, team.id);
      expect(reconstructed.name, team.name);
      expect(reconstructed.ownerId, team.ownerId);
      expect(reconstructed.inviteCode, team.inviteCode);
      expect(reconstructed.patientCount, 15);
    });

    test('TeamMember converts to/from JSON correctly', () {
      const member = TeamMember(
        uid: 'u-789',
        email: 'assistant@clinic.com',
        displayName: 'Maria Santos',
        role: TeamRole.assistant,
        joinedAt: '2026-10-01T12:00:00.000',
      );

      final json = member.toJson();
      expect(json['uid'], 'u-789');
      expect(json['role'], 'assistant');

      final reconstructed = TeamMember.fromJson(json);
      expect(reconstructed.uid, member.uid);
      expect(reconstructed.email, member.email);
      expect(reconstructed.displayName, member.displayName);
      expect(reconstructed.role, TeamRole.assistant);
    });
  });

  group('Model Team Isolation Stamping Tests', () {
    test('Patient includes and parses teamId', () {
      final patient = Patient(
        id: 'pat-100',
        mrn: 'MRN-100',
        fullName: 'Juan Dela Cruz',
        dateOfBirth: '1980-05-10',
        gender: 'Male',
        phone: '+63 917 123 4567',
        address: 'Manila',
        medicalHistory: const [],
        allergies: const [],
        encounters: const [],
        teamId: 't-team-a',
        lastVisitDate: '2026-10-01',
        totalVisits: 1,
      );

      final firestoreData = patient.toFirestore();
      expect(firestoreData['teamId'], 't-team-a');

      final parsed = Patient.fromJson(firestoreData);
      expect(parsed.teamId, 't-team-a');
    });

    test('Encounter includes and parses teamId', () {
      final encounter = Encounter(
        id: 'enc-1',
        patientId: 'pat-100',
        date: '2026-10-01',
        chiefComplaint: 'Red eye',
        examOD: EyeExamData(acuity: VisualAcuity(), refraction: Refraction()),
        examOS: EyeExamData(acuity: VisualAcuity(), refraction: Refraction()),
        diagnosis: 'Conjunctivitis',
        treatmentPlan: 'Antibiotic drops',
        teamId: 't-team-b',
      );

      final firestoreData = encounter.toFirestore();
      expect(firestoreData['teamId'], 't-team-b');

      final parsed = Encounter.fromJson(firestoreData);
      expect(parsed.teamId, 't-team-b');
    });

    test('Prescription includes and parses teamId', () {
      final rx = Prescription(
        id: 'rx-1',
        patientId: 'pat-100',
        encounterId: 'enc-1',
        doctorName: 'Dr. Robillos',
        date: '2026-10-01',
        items: const [],
        teamId: 't-team-c',
      );

      final json = rx.toJson();
      expect(json['teamId'], 't-team-c');

      final parsed = Prescription.fromJson(json);
      expect(parsed.teamId, 't-team-c');
    });
  });

  group('TeamService Logic & Fallback Tests', () {
    test('TeamService initializes fallback default team in unit test environment', () async {
      final service = TeamService.instance;
      await service.load('user-101', userEmail: 'doctor@docrs.app', displayName: 'Dr. Clara');

      expect(service.teams.isNotEmpty, isTrue);
      expect(service.activeTeam, isNotNull);
      expect(service.activeRole, TeamRole.owner);
      expect(service.canManageMembers, isTrue);
      expect(service.canViewPatients, isTrue);
      expect(service.canWriteVisits, isTrue);
    });

    test('Team creation adds team and sets as active workspace', () async {
      final service = TeamService.instance;
      final created = await service.createTeam('Davao Ophthalmology Clinic');

      expect(created.name, 'Davao Ophthalmology Clinic');
      expect(created.inviteCode.startsWith('DOC-'), isTrue);
      expect(service.activeTeam?.id, created.id);
      expect(service.activeRole, TeamRole.owner);
    });

    test('Multiple teams can be loaded, displayed, and switched seamlessly', () async {
      final service = TeamService.instance;
      final team1 = await service.createTeam('Primary Clinic Team');
      final team2 = await service.createTeam('Testing 2 Eye Clinic Center 2');

      expect(service.teams.length, greaterThanOrEqualTo(2));
      expect(service.teams.any((t) => t.name == 'Primary Clinic Team'), isTrue);
      expect(service.teams.any((t) => t.name == 'Testing 2 Eye Clinic Center 2'), isTrue);

      await service.switchTo(team1.id);
      expect(service.activeTeam?.id, team1.id);

      await service.switchTo(team2.id);
      expect(service.activeTeam?.id, team2.id);
    });

    test('Patient Directory scopes records to active team and isolates data on switch', () async {
      final service = TeamService.instance;
      final teamA = await service.createTeam('Clinic Alpha');
      final teamB = await service.createTeam('Clinic Beta');

      // Switch to Team A and add patient
      await service.switchTo(teamA.id);
      PatientRepository.addPatient(Patient(
        id: 'pat-alpha-1',
        mrn: 'PT-ALPHA',
        fullName: 'Alpha Patient',
        dateOfBirth: '1990-01-01',
        gender: 'Male',
        phone: '123',
        address: 'Alpha St',
        medicalHistory: const [],
        allergies: const [],
        encounters: const [],
        teamId: teamA.id,
        lastVisitDate: '2026-10-01',
        totalVisits: 1,
      ));

      expect(PatientRepository.getAllPatients().any((p) => p.id == 'pat-alpha-1'), isTrue);

      // Switch to Team B
      await service.switchTo(teamB.id);

      // Add patient for Team B
      PatientRepository.addPatient(Patient(
        id: 'pat-beta-1',
        mrn: 'PT-BETA',
        fullName: 'Beta Patient',
        dateOfBirth: '1992-02-02',
        gender: 'Female',
        phone: '456',
        address: 'Beta St',
        medicalHistory: const [],
        allergies: const [],
        encounters: const [],
        teamId: teamB.id,
        lastVisitDate: '2026-10-01',
        totalVisits: 1,
      ));

      final teamBPatients = PatientRepository.getAllPatients();
      expect(teamBPatients.any((p) => p.id == 'pat-beta-1'), isTrue);
      expect(teamBPatients.any((p) => p.id == 'pat-alpha-1'), isFalse);

      // Switch back to Team A
      await service.switchTo(teamA.id);
      final teamAPatients = PatientRepository.getAllPatients();
      expect(teamAPatients.any((p) => p.id == 'pat-alpha-1'), isTrue);
      expect(teamAPatients.any((p) => p.id == 'pat-beta-1'), isFalse);
    });
  });
}
