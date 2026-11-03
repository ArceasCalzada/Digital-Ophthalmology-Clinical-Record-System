import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/models/audit_log.dart';
import 'package:ophthalmology_clinical_record_system/models/patient.dart';
import 'package:ophthalmology_clinical_record_system/models/prescription.dart';
import 'package:ophthalmology_clinical_record_system/models/team.dart';
import 'package:ophthalmology_clinical_record_system/services/audit_service.dart';
import 'package:ophthalmology_clinical_record_system/services/team_service.dart';
import 'package:ophthalmology_clinical_record_system/theme/app_theme.dart';
import 'package:ophthalmology_clinical_record_system/views/audit_logs_view.dart';
import 'package:ophthalmology_clinical_record_system/views/settings_view.dart';
import 'package:ophthalmology_clinical_record_system/widgets/filter_pill.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuditLog Model Serialization & Helpers', () {
    test('AuditLog serializes to JSON and parses from JSON correctly', () {
      final now = DateTime(2026, 11, 3, 14, 30);
      final log = AuditLog(
        id: 'audit-test-1',
        teamId: 'team-test-branch',
        timestamp: now,
        userId: 'u-123',
        userEmail: 'doctor@docrs.app',
        userName: 'Dr. Jane Doe',
        userRole: 'owner',
        actionType: AuditActionType.patientCreate,
        actionCategory: AuditActionCategory.patientRecords,
        resourceType: 'Patient',
        resourceId: 'p-456',
        resourceName: 'Maria Santos',
        details: 'Created new patient record (MRN: MRN-100)',
        metadata: {'platform': 'macOS', 'ip': '127.0.0.1'},
      );

      final json = log.toJson();
      expect(json['id'], 'audit-test-1');
      expect(json['teamId'], 'team-test-branch');
      expect(json['userEmail'], 'doctor@docrs.app');
      expect(json['actionType'], AuditActionType.patientCreate);
      expect(json['actionCategory'], AuditActionCategory.patientRecords);
      expect(json['resourceId'], 'p-456');

      final deserialized = AuditLog.fromJson(json);
      expect(deserialized.id, log.id);
      expect(deserialized.teamId, log.teamId);
      expect(deserialized.userEmail, log.userEmail);
      expect(deserialized.actionType, log.actionType);
      expect(deserialized.resourceName, 'Maria Santos');
      expect(deserialized.actionLabel, 'Patient Created');
      expect(deserialized.formattedTimestamp, contains('Nov 3, 2026'));
      expect(deserialized.relativeTime, isNotEmpty);
      expect(deserialized.categoryColor, const Color(0xFF2563EB));
      expect(deserialized.actionIcon, Icons.person_add_rounded);
    });
  });

  group('Automatic Audit Logging Engine Tests', () {
    setUp(() async {
      PatientRepository.clearForTesting();
      AuditService.instance.clearForTesting();
      await TeamService.instance.load('owner-uid', userEmail: 'owner@docrs.app', displayName: 'Dr. Owner');
      TeamService.instance.setActiveRoleForTesting(TeamRole.owner);
    });

    test('Patient creation and patient modification generate audit log entries', () async {
      final patient = Patient(
        id: 'pat-audit-1',
        mrn: 'MRN-AUDIT-1',
        fullName: 'Antonio Luna',
        dateOfBirth: '1975-10-29',
        gender: 'Male',
        phone: '09171112222',
        address: 'Davao City',
        occupation: 'General',
        phicNumber: '',
        notes: '',
        medicalHistory: const [],
        allergies: const [],
        previousDiagnoses: const [],
        previousPrescriptions: const [],
        prescriptions: const [],
        encounters: const [],
        lastVisitDate: '2026-11-01',
        totalVisits: 1,
      );

      // 1. Create Patient
      PatientRepository.addPatient(patient);

      final logsAfterCreate = AuditService.instance.memoryLogs;
      expect(logsAfterCreate.any((l) =>
          l.actionType == AuditActionType.patientCreate &&
          l.resourceId == 'pat-audit-1'), isTrue);

      // 2. Edit Patient
      final updatedPatient = patient.copyWith(address: 'Tagum City');
      PatientRepository.addPatient(updatedPatient);

      final logsAfterEdit = AuditService.instance.memoryLogs;
      expect(logsAfterEdit.any((l) =>
          l.actionType == AuditActionType.patientEdit &&
          l.resourceId == 'pat-audit-1'), isTrue);
    });

    test('Prescription creation automatically records an audit log entry', () async {
      final patient = Patient(
        id: 'pat-audit-rx',
        mrn: 'MRN-AUDIT-RX',
        fullName: 'Gabriela Silang',
        dateOfBirth: '1980-03-15',
        gender: 'Female',
        phone: '09183334444',
        address: 'Davao City',
        occupation: 'Leader',
        phicNumber: '',
        notes: '',
        medicalHistory: const [],
        allergies: const [],
        previousDiagnoses: const [],
        previousPrescriptions: const [],
        prescriptions: const [],
        encounters: const [],
        lastVisitDate: '2026-11-01',
        totalVisits: 1,
      );
      PatientRepository.addPatient(patient);

      final rx = Prescription(
        id: 'rx-audit-1',
        patientId: 'pat-audit-rx',
        encounterId: 'enc-1',
        doctorName: 'Dr. Owner',
        date: '2026-11-03',
        notes: 'Instill 1 drop twice daily',
        items: [
          PrescriptionItem(
            id: 'item-1',
            medicationName: 'Latanoprost',
            strength: '0.005%',
            dosage: '1 drop',
            frequency: 'Every evening',
            duration: '30 days',
            instructions: 'Left eye',
          ),
        ],
      );

      PatientRepository.addPrescription('pat-audit-rx', rx);

      final logs = AuditService.instance.memoryLogs;
      expect(logs.any((l) =>
          l.actionType == AuditActionType.prescriptionCreate &&
          l.resourceId == 'rx-audit-1'), isTrue);
    });

    test('Staff role update and member removal automatically record audit log entries', () async {
      TeamService.instance.addMemberForTesting(
        TeamMember(
          uid: 'member-uid-99',
          email: 'staff@docrs.app',
          displayName: 'Nurse Staff',
          role: TeamRole.viewer,
          joinedAt: DateTime.now().toIso8601String(),
        ),
      );

      await TeamService.instance.updateMemberRole('member-uid-99', TeamRole.editor);

      final logsAfterRole = AuditService.instance.memoryLogs;
      expect(logsAfterRole.any((l) =>
          l.actionType == AuditActionType.memberRoleUpdate &&
          l.resourceId == 'member-uid-99'), isTrue);

      await TeamService.instance.removeMember('member-uid-99');
      final logsAfterRemove = AuditService.instance.memoryLogs;
      expect(logsAfterRemove.any((l) =>
          l.actionType == AuditActionType.memberRemove &&
          l.resourceId == 'member-uid-99'), isTrue);
    });

    test('Team workspace archiving and restoring record audit log entries', () async {
      final service = TeamService.instance;
      final team2 = await service.createTeam('Secondary Clinic');
      await service.switchTo(service.teams.first.id);

      await service.archiveTeam(team2.id);
      expect(AuditService.instance.memoryLogs.any((l) =>
          l.actionType == AuditActionType.teamArchive &&
          l.resourceId == team2.id), isTrue);

      await service.restoreTeam(team2.id);
      expect(AuditService.instance.memoryLogs.any((l) =>
          l.actionType == AuditActionType.teamRestore &&
          l.resourceId == team2.id), isTrue);
    });
  });

  group('Owner-Only Security Access & View Restriction Tests', () {
    setUp(() async {
      AuditService.instance.clearForTesting();
    });

    testWidgets('Non-owner role (Assistant) cannot view audit trail and sees Access Restricted screen', (tester) async {
      await TeamService.instance.load('assistant-uid', userEmail: 'assistant@docrs.app');
      TeamService.instance.setActiveRoleForTesting(TeamRole.assistant);

      expect(AuditService.instance.canAccessAuditLogs, isFalse);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const AuditLogsView(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Audit Logs Restricted'), findsOneWidget);
      expect(find.textContaining('Access to the clinical audit trail is strictly restricted to the Clinic Owner role'), findsOneWidget);
      expect(find.text('Audit Records'), findsNothing);
    });

    testWidgets('Owner role can access AuditLogsView and review records', (tester) async {
      await TeamService.instance.load('owner-uid', userEmail: 'owner@docrs.app');
      TeamService.instance.setActiveRoleForTesting(TeamRole.owner);

      expect(AuditService.instance.canAccessAuditLogs, isTrue);

      // Seed audit log
      await AuditService.instance.log(
        actionType: AuditActionType.patientEdit,
        actionCategory: AuditActionCategory.patientRecords,
        resourceType: 'Patient',
        resourceId: 'p-test-secure',
        resourceName: 'Emilio Aguinaldo',
        details: 'Updated visual acuity and slit lamp exam',
        teamId: TeamService.instance.activeTeam?.id,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const AuditLogsView(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Clinic Audit Trail & Activity Logs'), findsOneWidget);
      expect(find.text('SECURE MEDICAL AUDIT TRAIL'), findsOneWidget);
      expect(find.text('IMMUTABLE'), findsOneWidget);
      expect(find.text('Audit Records'), findsOneWidget);
      expect(find.text('Updated visual acuity and slit lamp exam'), findsOneWidget);
    });

    testWidgets('SettingsView displays Audit Logs tab only for Clinic Owner', (tester) async {
      // 1. Assistant does not see Audit Logs navigation item
      await TeamService.instance.load('asst-1', userEmail: 'assistant@docrs.app');
      TeamService.instance.setActiveRoleForTesting(TeamRole.assistant);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: SettingsView()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Audit Logs'), findsNothing);

      // 2. Owner sees Audit Logs tab in Settings
      await TeamService.instance.load('owner-1', userEmail: 'owner@docrs.app');
      TeamService.instance.setActiveRoleForTesting(TeamRole.owner);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: SettingsView()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Audit Logs'), findsWidgets);
    });
  });

  group('Audit Logs Search, Filtering, and Pagination UI Tests', () {
    setUp(() async {
      AuditService.instance.clearForTesting();
      await TeamService.instance.load('owner-uid', userEmail: 'owner@docrs.app');
      TeamService.instance.setActiveRoleForTesting(TeamRole.owner);

      final teamId = TeamService.instance.activeTeam?.id ?? 'c-default-team';

      // Seed multiple logs across categories
      await AuditService.instance.log(
        actionType: AuditActionType.patientCreate,
        actionCategory: AuditActionCategory.patientRecords,
        resourceType: 'Patient',
        resourceId: 'pat-1',
        resourceName: 'Jose Rizal',
        details: 'Initial consultation record created',
        teamId: teamId,
      );

      await AuditService.instance.log(
        actionType: AuditActionType.prescriptionPrint,
        actionCategory: AuditActionCategory.prescriptions,
        resourceType: 'Prescription',
        resourceId: 'rx-2',
        resourceName: 'Jose Rizal',
        details: 'Printed prescription for Moxifloxacin drops',
        teamId: teamId,
      );

      await AuditService.instance.log(
        actionType: AuditActionType.memberApprove,
        actionCategory: AuditActionCategory.teamManagement,
        resourceType: 'TeamMember',
        resourceId: 'staff-3',
        resourceName: 'Nurse Teresa',
        details: 'Approved nurse account for clinic branch',
        teamId: teamId,
      );
    });

    testWidgets('Filtering by Category updates displayed logs', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const AuditLogsView(),
        ),
      );
      await tester.pumpAndSettle();

      // All 3 logs initially visible
      expect(find.text('Initial consultation record created'), findsOneWidget);
      expect(find.text('Printed prescription for Moxifloxacin drops'), findsOneWidget);
      expect(find.text('Approved nurse account for clinic branch'), findsOneWidget);

      // Tap Prescriptions filter
      final rxPill = find.widgetWithText(FilterPill, 'Prescriptions');
      await tester.ensureVisible(rxPill);
      await tester.tap(rxPill);
      await tester.pumpAndSettle();

      expect(find.text('Printed prescription for Moxifloxacin drops'), findsOneWidget);
      expect(find.text('Initial consultation record created'), findsNothing);
      expect(find.text('Approved nurse account for clinic branch'), findsNothing);

      // Tap All Categories
      final allPill = find.widgetWithText(FilterPill, 'All Categories');
      await tester.ensureVisible(allPill);
      await tester.tap(allPill);
      await tester.pumpAndSettle();

      expect(find.text('Initial consultation record created'), findsOneWidget);
      expect(find.text('Printed prescription for Moxifloxacin drops'), findsOneWidget);
      expect(find.text('Approved nurse account for clinic branch'), findsOneWidget);
    });

    testWidgets('Search input filters logs by keyword', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const AuditLogsView(),
        ),
      );
      await tester.pumpAndSettle();

      final searchInput = find.byKey(const Key('audit_search_input'));
      expect(searchInput, findsOneWidget);

      // Enter search term "Moxifloxacin"
      await tester.enterText(searchInput, 'Moxifloxacin');
      await tester.pumpAndSettle();

      expect(find.text('Printed prescription for Moxifloxacin drops'), findsOneWidget);
      expect(find.text('Initial consultation record created'), findsNothing);
      expect(find.text('Approved nurse account for clinic branch'), findsNothing);
    });
  });
}
