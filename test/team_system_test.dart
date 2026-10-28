import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ophthalmology_clinical_record_system/models/calendar_event.dart';
import 'package:ophthalmology_clinical_record_system/models/team.dart';
import 'package:ophthalmology_clinical_record_system/models/patient.dart';
import 'package:ophthalmology_clinical_record_system/models/encounter.dart';
import 'package:ophthalmology_clinical_record_system/models/prescription.dart';
import 'package:ophthalmology_clinical_record_system/models/eye_exam.dart';
import 'package:ophthalmology_clinical_record_system/services/auth_service.dart';
import 'package:ophthalmology_clinical_record_system/services/team_service.dart';
import 'package:ophthalmology_clinical_record_system/views/teams_view.dart';
import 'helpers/fake_auth_backend.dart';

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

    test('TeamRole parses legacy strings gracefully and handles case sensitivity', () {
      expect(TeamRole.parse('owner'), TeamRole.owner);
      expect(TeamRole.parse('Owner'), TeamRole.owner);
      expect(TeamRole.parse('leader'), TeamRole.owner);
      expect(TeamRole.parse('admin'), TeamRole.owner);
      expect(TeamRole.parse('Admin'), TeamRole.owner);
      expect(TeamRole.parse('editor'), TeamRole.editor);
      expect(TeamRole.parse('Editor'), TeamRole.editor);
      expect(TeamRole.parse('physician'), TeamRole.editor);
      expect(TeamRole.parse('Physician'), TeamRole.editor);
      expect(TeamRole.parse('doctor'), TeamRole.editor);
      expect(TeamRole.parse('assistant'), TeamRole.assistant);
      expect(TeamRole.parse('staff'), TeamRole.assistant);
      expect(TeamRole.parse('viewer'), TeamRole.viewer);
      expect(TeamRole.parse('Viewer'), TeamRole.viewer);
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

    test('TeamMember converts to/from JSON with requestedRole and requestedWorkspaceId', () {
      const member = TeamMember(
        uid: 'u-101',
        email: 'staff@clinic.com',
        displayName: 'Staff Jane',
        role: TeamRole.viewer,
        joinedAt: '2026-10-01T12:00:00.000',
        status: 'pending',
        requestedRole: 'assistant',
        requestedWorkspaceId: 'ws-456',
        workspaceId: 'ws-456',
      );

      final json = member.toJson();
      expect(json['requestedRole'], 'assistant');
      expect(json['requestedWorkspaceId'], 'ws-456');
      expect(json['workspaceId'], 'ws-456');

      final reconstructed = TeamMember.fromJson(json);
      expect(reconstructed.requestedRole, 'assistant');
      expect(reconstructed.requestedWorkspaceId, 'ws-456');
      expect(reconstructed.workspaceId, 'ws-456');
      expect(reconstructed.isPending, isTrue);
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

  group('Pending Approvals Workflow Tests', () {
    test('TeamMember detects pending status correctly from JSON', () {
      final m1 = TeamMember.fromJson({
        'uid': 'p-1',
        'email': 'newuser@clinic.com',
        'displayName': 'Dr. Pending',
        'status': 'pending',
      });
      expect(m1.isPending, isTrue);

      final m2 = TeamMember.fromJson({
        'uid': 'p-2',
        'email': 'unapproved@clinic.com',
        'displayName': 'Staff Pending',
        'isApproved': false,
      });
      expect(m2.isPending, isTrue);

      final m3 = TeamMember.fromJson({
        'uid': 'a-1',
        'email': 'active@clinic.com',
        'displayName': 'Active Doctor',
        'role': 'editor',
        'status': 'active',
      });
      expect(m3.isPending, isFalse);
      expect(m3.role, TeamRole.editor);
    });

    test('TeamService approves pending member and updates active team members', () async {
      final service = TeamService.instance;
      await service.load('owner-uid', userEmail: 'owner@docrs.app', displayName: 'Dr. Owner');

      const pendingUser = TeamMember(
        uid: 'user-pending-1',
        email: 'applicant@clinic.com',
        displayName: 'Applicant Doctor',
        role: TeamRole.viewer,
        joinedAt: '2026-10-06T12:00:00.000',
        status: 'pending',
      );

      service.addPendingMemberForTesting(pendingUser);
      expect(service.pendingMembers.length, 1);
      expect(service.pendingMembers.first.uid, 'user-pending-1');

      // Approve as Editor
      await service.approvePendingMember('user-pending-1', TeamRole.editor);

      expect(service.pendingMembers.isEmpty, isTrue);
      expect(service.members.any((m) => m.uid == 'user-pending-1'), isTrue);

      final approved = service.members.firstWhere((m) => m.uid == 'user-pending-1');
      expect(approved.role, TeamRole.editor);
      expect(approved.status, 'active');
      expect(approved.isPending, isFalse);
    });

    test('TeamService approves pending member with specified targetWorkspaceId', () async {
      SharedPreferences.setMockInitialValues({});
      final service = TeamService.instance;
      await service.load('owner-uid', userEmail: 'owner@docrs.app', displayName: 'Dr. Owner');

      final teamA = await service.createTeam('Branch Alpha');
      final teamB = await service.createTeam('Branch Beta');

      final applicant = TeamMember(
        uid: 'user-multi-ws-1',
        email: 'applicant@branchb.ph',
        displayName: 'Branch Assistant',
        role: TeamRole.viewer,
        joinedAt: '2026-10-19T10:00:00.000',
        status: 'pending',
        requestedRole: 'assistant',
        requestedWorkspaceId: teamA.id,
      );
      service.addPendingMemberForTesting(applicant);

      // Admin approves and assigns member to Branch Beta
      await service.approvePendingMember(
        'user-multi-ws-1',
        TeamRole.assistant,
        targetWorkspaceId: teamB.id,
      );

      // Verify member is removed from pending
      expect(service.pendingMembers.any((m) => m.uid == 'user-multi-ws-1'), isFalse);
    });

    test('TeamService rejects pending member request', () async {
      final service = TeamService.instance;
      await service.load('owner-uid', userEmail: 'owner@docrs.app', displayName: 'Dr. Owner');

      const unauth = TeamMember(
        uid: 'unauth-user',
        email: 'hacker@unknown.com',
        displayName: 'Unknown User',
        role: TeamRole.viewer,
        joinedAt: '2026-10-06T12:00:00.000',
        status: 'pending',
      );

      service.addPendingMemberForTesting(unauth);
      expect(service.pendingMembers.any((m) => m.uid == 'unauth-user'), isTrue);

      // Reject access request
      await service.rejectPendingMember('unauth-user');

      expect(service.pendingMembers.any((m) => m.uid == 'unauth-user'), isFalse);
      expect(service.members.any((m) => m.uid == 'unauth-user'), isFalse);
    });

    test('Joining a team via invite code writes pending approval record with requestedRole', () async {
      SharedPreferences.setMockInitialValues({});
      final service = TeamService.instance;
      await service.load('owner-uid', userEmail: 'owner@docrs.app', displayName: 'Dr. Owner');

      final team = await service.createTeam('Cornea Specialty Clinic');
      final code = team.inviteCode;

      // New assistant loads service
      await service.load('assistant-uid', userEmail: 'assistant@cornea.ph', displayName: 'Staff Anna');
      final joinedTeam = await service.joinWithCode(code, requestedRole: 'assistant');

      expect(joinedTeam.id, team.id);
      expect(service.pendingMembers.any((m) => m.uid == 'assistant-uid'), isTrue);
      final pendingRecord = service.pendingMembers.firstWhere((m) => m.uid == 'assistant-uid');
      expect(pendingRecord.status, 'pending');
      expect(pendingRecord.isPending, isTrue);
      expect(pendingRecord.requestedRole, 'assistant');
      expect(pendingRecord.requestedWorkspaceId, team.id);
      expect(pendingRecord.email, 'assistant@cornea.ph');
    });

    test('Newly registered pending user joins team via invite code and resolves identity', () async {
      SharedPreferences.setMockInitialValues({});
      final service = TeamService.instance;
      await service.load('owner-uid', userEmail: 'owner@docrs.app', displayName: 'Dr. Owner');

      final team = await service.createTeam('Ophthalmology Associates');
      final code = team.inviteCode;

      // Simulate a freshly signed-up assistant whose role is pending (TeamService.load not yet called)
      service.unload();
      final fakeBackend = FakeAuthBackend({});
      await AuthService.instance.attach(fakeBackend);
      await fakeBackend.signUp('assistant@oa.ph', 'password123', 'Assistant Maria', requestedRole: 'assistant');

      final joinedTeam = await service.joinWithCode(code, requestedRole: 'assistant');

      expect(joinedTeam.id, team.id);
      expect(service.pendingMembers.any((m) => m.email == 'assistant@oa.ph'), isTrue);
      final pendingRecord = service.pendingMembers.firstWhere((m) => m.email == 'assistant@oa.ph');
      expect(pendingRecord.uid, 'uid-assistant@oa.ph');
      expect(pendingRecord.status, 'pending');
      expect(pendingRecord.isPending, isTrue);
      expect(pendingRecord.requestedRole, 'assistant');
      expect(pendingRecord.displayName, 'Assistant Maria');
      expect(pendingRecord.requestedWorkspaceId, team.id);
    });

    test('streamPendingMembers broadcasts updates when pending members change', () async {
      SharedPreferences.setMockInitialValues({});
      final service = TeamService.instance;
      await service.load('owner-uid', userEmail: 'owner@docrs.app', displayName: 'Dr. Owner');

      final activeId = service.activeTeam?.id;
      final stream = service.streamPendingMembers(activeId);

      const applicant = TeamMember(
        uid: 'user-stream-1',
        email: 'stream.applicant@clinic.ph',
        displayName: 'Stream Applicant',
        role: TeamRole.viewer,
        joinedAt: '2026-10-19T10:00:00.000',
        status: 'pending',
      );

      final expectation = expectLater(
        stream,
        emitsInOrder([
          isEmpty,
          predicate<List<TeamMember>>((list) => list.length == 1 && list.first.uid == 'user-stream-1'),
        ]),
      );

      await pumpEventQueue();
      service.addPendingMemberForTesting(applicant);
      await expectation;
    });

    testWidgets('TeamsView renders Pending Approvals section with requestedRole badge and preselects role', (tester) async {
      final service = TeamService.instance;
      await service.load('owner-uid', userEmail: 'owner@docrs.app', displayName: 'Dr. Owner');

      const pendingMember = TeamMember(
        uid: 'user-widget-1',
        email: 'dr.new@clinic.com',
        displayName: 'Dr. New Registrant',
        role: TeamRole.viewer,
        joinedAt: '2026-10-06T10:00:00.000',
        status: 'pending',
        requestedRole: 'assistant',
      );
      service.addPendingMemberForTesting(pendingMember);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TeamsView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Pending Approvals (1)'), findsOneWidget);
      expect(find.text('Dr. New Registrant'), findsOneWidget);
      expect(find.text('dr.new@clinic.com'), findsOneWidget);
      expect(find.text('Requested: ASSISTANT'), findsOneWidget);
      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);

      // Tap Approve button
      await tester.ensureVisible(find.text('Approve'));
      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();

      // Check success modal
      expect(find.text('User Approved Successfully'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(service.pendingMembers.isEmpty, isTrue);
      expect(service.members.any((m) => m.uid == 'user-widget-1'), isTrue);
      final approved = service.members.firstWhere((m) => m.uid == 'user-widget-1');
      expect(approved.role, TeamRole.assistant);
    });

    testWidgets('Pending Approvals updates dynamically in real-time when new request arrives', (tester) async {
      final service = TeamService.instance;
      await service.load('owner-uid', userEmail: 'owner@docrs.app', displayName: 'Dr. Owner');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TeamsView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially no pending approvals
      expect(find.textContaining('No pending approval requests'), findsOneWidget);

      // New pending request arrives in real-time
      const dynamicApplicant = TeamMember(
        uid: 'user-realtime-99',
        email: 'nurse.joy@clinic.ph',
        displayName: 'Nurse Joy',
        role: TeamRole.viewer,
        joinedAt: '2026-10-19T10:00:00.000',
        status: 'pending',
      );
      service.addPendingMemberForTesting(dynamicApplicant);
      await tester.pump();

      // Dynamically displayed without full refresh
      expect(find.text('Nurse Joy'), findsOneWidget);
      expect(find.text('nurse.joy@clinic.ph'), findsOneWidget);
      expect(find.textContaining('Pending Approvals (1)'), findsOneWidget);
    });

    test('admin.docrs@gmail.com streams pending approvals across all owned teams and approves assistant', () async {
      SharedPreferences.setMockInitialValues({});
      final service = TeamService.instance;
      await service.load('admin-uid', userEmail: 'admin.docrs@gmail.com', displayName: 'Admin Owner');

      final team1 = service.teams.first;
      final team2 = await service.createTeam('Second Clinic Branch');

      // Pending assistant on team1
      final assistant1 = TeamMember(
        uid: 'asst-1',
        email: 'assistant1@clinic.ph',
        displayName: 'Assistant 1',
        role: TeamRole.viewer,
        joinedAt: '2026-10-21T10:00:00.000',
        status: 'pending',
        requestedRole: 'assistant',
        requestedWorkspaceId: team1.id,
      );

      // Pending assistant on team2
      final assistant2 = TeamMember(
        uid: 'asst-2',
        email: 'assistant2@clinic.ph',
        displayName: 'Assistant 2',
        role: TeamRole.viewer,
        joinedAt: '2026-10-21T10:00:00.000',
        status: 'pending',
        requestedRole: 'assistant',
        requestedWorkspaceId: team2.id,
      );

      service.addPendingMemberForTesting(assistant1);
      service.addPendingMemberForTesting(assistant2);

      // Stream pending members as admin
      final stream = service.streamPendingMembers();
      final currentList = await stream.first;

      // Admin receives pending members from all owned teams
      expect(currentList.any((m) => m.uid == 'asst-1'), isTrue);
      expect(currentList.any((m) => m.uid == 'asst-2'), isTrue);

      // Approve assistant2 into team2
      await service.approvePendingMember(
        'asst-2',
        TeamRole.assistant,
        targetWorkspaceId: team2.id,
      );

      // Verify assistant2 is no longer pending
      expect(service.pendingMembers.any((m) => m.uid == 'asst-2'), isFalse);
    });

    test('Newly registered unassigned user without invite code appears in pending approvals and can be assigned to workspace', () async {
      SharedPreferences.setMockInitialValues({});
      final service = TeamService.instance;
      await service.load('admin-uid', userEmail: 'admin.docrs@gmail.com', displayName: 'Admin Owner');

      final eyeCenter = await service.createTeam('Eye Center');
      await service.createTeam('Lasik Clinic');

      // Newly registered user with no workspace assigned (unassigned registration)
      final newRegisteredUser = TeamMember(
        uid: 'user-newly-registered-123',
        email: 'calzada.arceas@gmail.com',
        displayName: 'Arceas Calzada',
        role: TeamRole.viewer,
        joinedAt: '2026-10-23T15:10:00.000',
        status: 'pending',
        requestedRole: 'assistant',
        requestedWorkspaceId: null, // Unassigned
      );

      service.addPendingMemberForTesting(newRegisteredUser);

      // Verify unassigned user is included in pendingMembers and streamPendingMembers
      expect(service.pendingMembers.any((m) => m.email == 'calzada.arceas@gmail.com'), isTrue);

      final streamList = await service.streamPendingMembers(eyeCenter.id).first;
      expect(streamList.any((m) => m.email == 'calzada.arceas@gmail.com'), isTrue);
      final pendingItem = streamList.firstWhere((m) => m.email == 'calzada.arceas@gmail.com');
      expect(pendingItem.requestedRole, 'assistant');
      expect(pendingItem.requestedWorkspaceId, isNull);

      // Admin reviews unassigned account, assigns to Eye Center workspace with assistant role
      await service.approvePendingMember(
        'user-newly-registered-123',
        TeamRole.assistant,
        targetWorkspaceId: eyeCenter.id,
      );

      // Verify removed from pending
      expect(service.pendingMembers.any((m) => m.email == 'calzada.arceas@gmail.com'), isFalse);

      // Verify added as active member
      expect(service.members.any((m) => m.email == 'calzada.arceas@gmail.com' && m.role == TeamRole.assistant), isTrue);
    });

    test('Switching active team reconnects CalendarEventRepository to target workspace teamId', () async {
      SharedPreferences.setMockInitialValues({});
      final service = TeamService.instance;
      await service.load('owner-uid', userEmail: 'owner@docrs.app', displayName: 'Dr. Owner');

      final team1 = await service.createTeam('Clinic Team Alpha');
      final team2 = await service.createTeam('Clinic Team Beta');

      final repo = CalendarEventRepository();
      repo.addEvent(CalendarEvent(
        id: 'evt-alpha',
        teamId: team1.id,
        title: 'Team Alpha Surgery',
        eventType: 'Surgery',
        location: 'Alpha Room',
        dateTime: DateTime.now(),
        patientName: 'Alpha Patient',
      ));

      repo.addEvent(CalendarEvent(
        id: 'evt-beta',
        teamId: team2.id,
        title: 'Team Beta Checkup',
        eventType: 'Checkup',
        location: 'Beta Room',
        dateTime: DateTime.now(),
        patientName: 'Beta Patient',
      ));

      // Switch to Team Alpha
      await service.switchTo(team1.id);
      expect(repo.events.any((e) => e.id == 'evt-alpha'), isTrue);
      expect(repo.events.any((e) => e.id == 'evt-beta'), isFalse);

      // Switch to Team Beta
      await service.switchTo(team2.id);
      expect(repo.events.any((e) => e.id == 'evt-beta'), isTrue);
      expect(repo.events.any((e) => e.id == 'evt-alpha'), isFalse);
    });

    test('Master administrator admin.docrs@gmail.com can archive and restore owned clinic teams', () async {
      SharedPreferences.setMockInitialValues({});
      final service = TeamService.instance;
      await service.load('master-admin-uid', userEmail: 'admin.docrs@gmail.com', displayName: 'Master Admin');

      final team1 = await service.createTeam('Clinic Alpha');
      final team2 = await service.createTeam('Clinic Beta');

      // Active is currently team2. Archiving inactive team1 should succeed
      expect(service.canManageTeam(team1), isTrue);
      await service.archiveTeam(team1.id);

      expect(service.archivedTeams.any((t) => t.id == team1.id), isTrue);
      final archivedTeam = service.archivedTeams.firstWhere((t) => t.id == team1.id);
      expect(archivedTeam.isArchived, isTrue);

      // Restore team1
      await service.restoreTeam(team1.id);
      final restoredTeam = service.teams.firstWhere((t) => t.id == team1.id);
      expect(restoredTeam.isArchived, isFalse);
    });

    test('Assistant submits join request with invite code into pending queue without error', () async {
      SharedPreferences.setMockInitialValues({});
      final service = TeamService.instance;
      await service.load('clinic-owner-uid', userEmail: 'doctor@clinic.ph', displayName: 'Dr. Clinic Owner');

      final clinicTeam = await service.createTeam('St. Luke Eye Clinic');
      final invite = clinicTeam.inviteCode;

      // New assistant registers and submits join request
      service.unload();
      final fakeBackend = FakeAuthBackend({});
      await AuthService.instance.attach(fakeBackend);
      await fakeBackend.signUp('alex@clinic.ph', 'password123', 'Alex Assistant', requestedRole: 'assistant');

      final resultTeam = await service.joinWithCode(invite, requestedRole: 'assistant');

      expect(resultTeam.id, clinicTeam.id);
      expect(service.pendingMembers.any((m) => m.email == 'alex@clinic.ph'), isTrue);
      final req = service.pendingMembers.firstWhere((m) => m.email == 'alex@clinic.ph');
      expect(req.uid, 'uid-alex@clinic.ph');
      expect(req.status, 'pending');
      expect(req.isPending, isTrue);
      expect(req.requestedRole, 'assistant');
    });
  });
}
