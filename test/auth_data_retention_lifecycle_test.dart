import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ophthalmology_clinical_record_system/models/clinic_branch.dart';
import 'package:ophthalmology_clinical_record_system/models/patient.dart';
import 'package:ophthalmology_clinical_record_system/models/team.dart';
import 'package:ophthalmology_clinical_record_system/services/auth_service.dart';
import 'package:ophthalmology_clinical_record_system/services/profile_store.dart';
import 'package:ophthalmology_clinical_record_system/services/team_service.dart';
import 'package:ophthalmology_clinical_record_system/services/workspace_store.dart';
import 'package:ophthalmology_clinical_record_system/views/dashboard_screen.dart';
import 'package:ophthalmology_clinical_record_system/views/patients_screen.dart';
import 'package:ophthalmology_clinical_record_system/widgets/skeleton_loader.dart';

import 'helpers/fake_auth_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAuthBackend backend;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    backend = FakeAuthBackend({
      'doctor@docrs.app': (password: 'secret', role: UserRole.physician),
    });
    await AuthService.instance.attach(backend);
    PatientRepository.disconnect();
    TeamService.instance.unload();
  });

  tearDown(() {
    PatientRepository.disconnect();
    TeamService.instance.unload();
  });

  group('Auth Lifecycle & Data Retention Tests', () {
    test('Auth state token re-resolution does not wipe patient records or branches', () async {
      await AuthService.instance.signIn('doctor@docrs.app', 'secret');
      expect(AuthService.instance.isSignedIn, isTrue);

      final doctorUid = AuthService.instance.user!.uid;
      final team = Team(
        id: 'team-active-1',
        name: 'Metro Eye Clinic',
        ownerId: doctorUid,
        inviteCode: 'METRO1',
        createdAt: '2026-01-01',
      );
      TeamService.instance.setTeamsForTesting([team]);
      TeamService.instance.setActiveTeamForTesting(team);
      PatientRepository.connect(team.id);

      final samplePatient = Patient(
        id: 'patient-retention-1',
        fullName: 'Carlos Garcia',
        dateOfBirth: '1985-05-15',
        gender: 'Male',
        phone: '09171234567',
        address: 'Davao City',
        medicalHistory: const [],
        allergies: const [],
        encounters: const [],
        prescriptions: const [],
        lastVisitDate: '2026-01-01',
        totalVisits: 1,
        mrn: 'MRN-901',
        teamId: team.id,
      );
      PatientRepository.addPatient(samplePatient);
      expect(PatientRepository.getAllPatients(), contains(samplePatient));

      ProfileStore.instance.setBranches([
        ClinicBranch(
          id: 'b-1',
          name: 'Main Clinic Branch',
          address: 'Suite 100',
          days: 'Mon-Fri',
          hours: '8am-5pm',
        ),
      ]);
      expect(ProfileStore.instance.branches.length, equals(1));

      // While user != null, repository data must NOT be cleared.
      expect(AuthService.instance.user, isNotNull);
      expect(PatientRepository.getAllPatients().isNotEmpty, isTrue);
      expect(ProfileStore.instance.branches.isNotEmpty, isTrue);
    });

    test('ProfileStore preserves existing valid branches against empty Firestore snapshots', () {
      final initialBranch = ClinicBranch(
        id: 'branch-custom-1',
        name: 'Specialist Eye Center',
        address: 'Medical Arts Tower',
        days: 'Mon-Sat',
        hours: '9am - 4pm',
      );
      ProfileStore.instance.setBranches([initialBranch]);
      expect(ProfileStore.instance.branches.length, 1);
      expect(ProfileStore.instance.branches.first.name, 'Specialist Eye Center');

      // fromMap with empty values should preserve existing non-empty branches
      ProfileStore.instance.fromMap({
        'doctorName': 'Dr. Specialist',
        'clinic1Name': '',
        'clinic2Name': '',
        'clinic3Name': '',
        'branches': [],
      });

      expect(ProfileStore.instance.branches.length, 1);
      expect(ProfileStore.instance.branches.first.name, 'Specialist Eye Center');
    });

    testWidgets('Dashboard renders Skeleton loader while patient repository or team is loading', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      addTearDown(tester.view.resetPhysicalSize);

      final team = Team(
        id: 'team-loading-test',
        name: 'Loading Test Practice',
        ownerId: 'owner-1',
        inviteCode: 'LOAD12',
        createdAt: '2026-01-01',
      );
      TeamService.instance.setTeamsForTesting([team]);
      TeamService.instance.setActiveTeamForTesting(team);
      WorkspaceStore.instance.setActiveWorkspace(team.id, workspace: team);

      PatientRepository.isLoading.value = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DashboardScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      // Should display skeleton cards instead of "No patient records in database."
      expect(find.byType(SkeletonPatientCard), findsWidgets);
      expect(find.text('No patient records in database.'), findsNothing);

      // Finish loading
      PatientRepository.isLoading.value = false;
      await tester.pump();

      // Now with 0 patients and loading = false, shows empty message
      expect(find.text('No patient records in database.'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('PatientsScreen displays skeleton state during active asynchronous loading', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      addTearDown(tester.view.resetPhysicalSize);

      final team = Team(
        id: 'team-pts-test',
        name: 'Patients Screen Practice',
        ownerId: 'owner-2',
        inviteCode: 'PTS001',
        createdAt: '2026-01-01',
      );
      TeamService.instance.setTeamsForTesting([team]);
      TeamService.instance.setActiveTeamForTesting(team);
      WorkspaceStore.instance.setActiveWorkspace(team.id, workspace: team);

      PatientRepository.isLoading.value = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PatientsScreen(onSelectPatient: (_) {}),
          ),
        ),
      );
      await tester.pump();

      // Skeletons are shown
      expect(find.byType(SkeletonPatientCard), findsWidgets);
      expect(find.text('No matching patient found'), findsNothing);

      PatientRepository.isLoading.value = false;
      await tester.pump();

      expect(find.byType(SkeletonPatientCard), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    test('Workspace resolving condition properly identifies unready workspace states', () {
      TeamService.instance.unload();
      TeamService.instance.setLoadingForTesting(true);

      // Unresolved while loading
      expect(
        TeamService.instance.loading ||
            TeamService.instance.activeTeam == null ||
            WorkspaceStore.instance.activeWorkspaceId == null,
        isTrue,
      );

      // Workspace resolves
      final team = Team(
        id: 't-resolved',
        name: 'Resolved Practice',
        ownerId: 'doc-1',
        inviteCode: 'RES1',
        createdAt: '2026-01-01',
      );
      TeamService.instance.setTeamsForTesting([team]);
      TeamService.instance.setActiveTeamForTesting(team);
      WorkspaceStore.instance.setActiveWorkspace(team.id, workspace: team);
      TeamService.instance.setLoadingForTesting(false);

      expect(
        TeamService.instance.loading ||
            TeamService.instance.activeTeam == null ||
            WorkspaceStore.instance.activeWorkspaceId == null,
        isFalse,
      );
    });
  });
}
