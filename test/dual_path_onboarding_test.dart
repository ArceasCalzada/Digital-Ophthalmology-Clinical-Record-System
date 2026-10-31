import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/models/team.dart';
import 'package:ophthalmology_clinical_record_system/services/auth_service.dart';
import 'package:ophthalmology_clinical_record_system/services/profile_store.dart';
import 'package:ophthalmology_clinical_record_system/services/team_service.dart';
import 'package:ophthalmology_clinical_record_system/views/login_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_auth_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAuthBackend backend;
  bool loginSuccessCalled = false;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.instance.resetForTesting();
    loginSuccessCalled = false;
    backend = FakeAuthBackend({
      'admin@clinic.test': (password: 'correct-horse', role: UserRole.admin),
      'doc@clinic.test': (password: 'battery-staple', role: UserRole.physician),
      'front@clinic.test': (password: 'desk-pass-1', role: UserRole.staff),
      'unapproved.physician@clinic.test': (password: 'doctorpass', role: null),
    });
    await AuthService.instance.attach(backend);
    ProfileStore.instance.reset();
  });

  tearDown(() async {
    await AuthService.instance.resetForTesting();
  });

  Widget buildLoginApp() {
    return MaterialApp(
      home: Scaffold(
        body: LoginView(
          onLoginSuccess: () {
            loginSuccessCalled = true;
          },
        ),
      ),
    );
  }

  group('Dual-Path Onboarding & Physician Auto-Provisioning Tests', () {
    test('Independent Physician registration automatically provisions active workspace and Owner privileges', () async {
      await AuthService.instance.signUp(
        'a.calzada.534429@umindanao.edu.ph',
        'doctorpass123',
        'Dr. Arceas Calzada',
        requestedRole: 'physician',
      );

      // Verify immediate active privileges with zero approval delays
      expect(AuthService.instance.isSignedIn, isTrue);
      expect(AuthService.instance.role, UserRole.physician);
      expect(AuthService.instance.isPendingApproval, isFalse);
      expect(AuthService.instance.isPendingRole, isFalse);
      expect(AuthService.instance.canWriteClinical, isTrue);

      // Verify active practice team provisioning
      final activeTeam = TeamService.instance.activeTeam;
      expect(activeTeam, isNotNull);
      expect(activeTeam!.name, contains('Eye Clinic'));
      expect(TeamService.instance.activeRole, TeamRole.owner);

      // Verify clinical doctor profile defaults
      expect(ProfileStore.instance.doctorName.text, 'Dr. Arceas Calzada');
      expect(ProfileStore.instance.specialization.text, 'General Ophthalmology');
    });

    test('Staff registration with invite code is routed to pending approval queue and blocks clinical access', () async {
      await AuthService.instance.signUp(
        'assistant.maria@clinic.test',
        'assistantpass123',
        'Maria Santos',
        requestedRole: 'assistant',
        inviteCode: 'MED-789',
      );

      // Verify staff account is held in pending approval state
      expect(AuthService.instance.isSignedIn, isFalse);
      expect(AuthService.instance.isPendingApproval, isTrue);
      expect(AuthService.instance.isPendingRole, isTrue);
      expect(AuthService.instance.canWriteClinical, isFalse);
      expect(AuthService.instance.pendingInviteCode, 'MED-789');
    });

    testWidgets('Independent Physician sign-up UI selects Physician by default and displays Create Physician Practice', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildLoginApp());
      await tester.pump();

      // Switch to sign-up tab
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      // Verify Intent Selector pills exist
      expect(find.byKey(const Key('signup-intent-physician')), findsOneWidget);
      expect(find.byKey(const Key('signup-intent-assistant')), findsOneWidget);

      // Verify default is Physician mode
      expect(find.text('Create Physician Practice'), findsOneWidget);
      expect(find.textContaining('Independent practice: instant workspace provisioning'), findsOneWidget);
      expect(find.byKey(const Key('signup-invite-code-field')), findsNothing);

      // Switch to Staff mode
      await tester.tap(find.byKey(const Key('signup-intent-assistant')));
      await tester.pumpAndSettle();

      // Verify invite code is displayed in Staff mode
      expect(find.text('Request Clinic Access'), findsOneWidget);
      expect(find.byKey(const Key('signup-invite-code-field')), findsOneWidget);
      expect(find.textContaining('Staff registration requires a clinic invite code'), findsOneWidget);

      // Switch back to Physician mode
      await tester.tap(find.byKey(const Key('signup-intent-physician')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('signup-invite-code-field')), findsNothing);
      expect(find.text('Create Physician Practice'), findsOneWidget);
    });

    testWidgets('Signing up as Physician in UI automatically provisions workspace and completes login', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildLoginApp());
      await tester.pump();

      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('signup-email-field')), 'dr.auto@clinic.test');
      await tester.enterText(find.byKey(const Key('signup-password-field')), 'secure123');
      await tester.enterText(find.byKey(const Key('signup-confirm-password-field')), 'secure123');

      final submitBtn = find.byKey(const Key('register-submit-button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      // Physician sign up automatically activates and calls onLoginSuccess
      expect(AuthService.instance.isSignedIn, isTrue);
      expect(AuthService.instance.role, UserRole.physician);
      expect(loginSuccessCalled, isTrue);
      expect(find.byKey(const Key('pending-approval-holding-card')), findsNothing);
    });

    test('Unapproved physician account routes to Onboarding Wizard without approval wall deadlock', () async {
      // Sign in unapproved physician account (no invite code submitted)
      await AuthService.instance.signIn('unapproved.physician@clinic.test', 'doctorpass');
      expect(AuthService.instance.isPendingRole, isTrue);
      expect(AuthService.instance.isPendingApproval, isFalse);
      expect(AuthService.instance.needsOnboarding, isTrue);
      expect(AuthService.instance.hasSubmittedJoinRequest, isFalse);

      // Verify that this state routes to the Onboarding Wizard (not approval lock)
      final auth = AuthService.instance;
      expect(auth.needsOnboarding || auth.hasSubmittedJoinRequest, isTrue);
      expect(auth.isPendingApproval, isFalse);
    });

    test('Staff account with pending join request displays Waiting for Administrator Approval state', () async {
      // Staff member signs up with invite code
      await AuthService.instance.signUp(
        'staff.pending@clinic.test',
        'staffpass123',
        'Staff Elena',
        requestedRole: 'assistant',
        inviteCode: 'CLINIC-99',
      );
      expect(AuthService.instance.isPendingRole, isTrue);
      expect(AuthService.instance.isPendingApproval, isTrue);
      expect(AuthService.instance.hasSubmittedJoinRequest, isTrue);
      expect(AuthService.instance.pendingInviteCode, 'CLINIC-99');

      // Verify approval wall state
      final auth = AuthService.instance;
      expect(auth.needsOnboarding, isFalse);
      expect(auth.isPendingApproval, isTrue);
    });

    test('Doctor a.calzada.534429@umindanao.edu.ph can activate practice workspace directly', () async {
      backend.accounts['a.calzada.534429@umindanao.edu.ph'] = (password: 'docpass123', role: null);

      await AuthService.instance.signIn('a.calzada.534429@umindanao.edu.ph', 'docpass123');
      expect(AuthService.instance.isPendingApproval, isFalse);

      // Auto-provision practice workspace for doctor
      await AuthService.instance.autoProvisionPhysicianWorkspace(
        AuthService.instance.user!,
        clinicName: 'Calzada Eye Specialty Practice',
      );

      expect(AuthService.instance.isSignedIn, isTrue);
      expect(AuthService.instance.role, UserRole.physician);
      expect(AuthService.instance.canWriteClinical, isTrue);
      expect(TeamService.instance.activeTeam?.name, 'Calzada Eye Specialty Practice');
      expect(TeamService.instance.activeRole, TeamRole.owner);
    });
  });
}
