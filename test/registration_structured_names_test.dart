import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/models/team.dart';
import 'package:ophthalmology_clinical_record_system/services/auth_service.dart';
import 'package:ophthalmology_clinical_record_system/services/profile_store.dart';
import 'package:ophthalmology_clinical_record_system/services/team_service.dart';
import 'package:ophthalmology_clinical_record_system/views/login_view.dart';
import 'package:ophthalmology_clinical_record_system/views/onboarding_wizard_view.dart';
import 'package:ophthalmology_clinical_record_system/widgets/required_text_form_field.dart';
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
    backend = FakeAuthBackend({});
    await AuthService.instance.attach(backend);
    ProfileStore.instance.reset();
  });

  tearDown(() async {
    await AuthService.instance.resetForTesting();
  });

  Widget buildLoginView() {
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

  Future<void> switchToSignUp(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1000));
    await tester.pumpWidget(buildLoginView());
    await tester.pump();

    final createAccountTab = find.text('Create Account');
    await tester.tap(createAccountTab);
    await tester.pumpAndSettle();
  }

  group('Lightweight Sign-Up & Wizard Routing Tests', () {
    testWidgets('Initial public sign-up form is streamlined to email and passwords only', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await switchToSignUp(tester);

      // Verify streamlined fields exist on the initial public sign-up form
      expect(find.byKey(const Key('signup-email-field')), findsOneWidget);
      expect(find.byKey(const Key('signup-password-field')), findsOneWidget);
      expect(find.byKey(const Key('signup-confirm-password-field')), findsOneWidget);
      expect(find.byKey(const Key('register-submit-button')), findsOneWidget);

      // Verify complex role/name fields have been removed from the public sign-up form
      expect(find.byKey(const Key('signup-first-name-field')), findsNothing);
      expect(find.byKey(const Key('signup-last-name-field')), findsNothing);
      expect(find.byKey(const Key('signup-role-dropdown')), findsNothing);
      expect(find.byKey(const Key('signup-clinic-name-field')), findsNothing);
    });

    testWidgets('Registering immediately transitions new user into OnboardingWizardView', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await switchToSignUp(tester);

      await tester.enterText(find.byKey(const Key('signup-email-field')), 'dr.new@clinic.test');
      await tester.enterText(find.byKey(const Key('signup-password-field')), 'secret123');
      await tester.enterText(find.byKey(const Key('signup-confirm-password-field')), 'secret123');

      final submitBtn = find.byKey(const Key('register-submit-button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Successfully signed in and routed to OnboardingWizardView
      expect(AuthService.instance.user, isNotNull);
      expect(AuthService.instance.isSignedIn, isFalse);
      expect(AuthService.instance.needsOnboarding, isTrue);
      expect(find.byType(OnboardingWizardView), findsOneWidget);
      expect(find.text('Welcome to Your Clinical Setup'), findsOneWidget);
      expect(find.text('Legal Identity'), findsOneWidget);
      expect(find.text('Practice Path'), findsOneWidget);
    });
  });

  group('Onboarding Wizard Step 1: Structured Names & Validation', () {
    testWidgets('Step 1 displays 4 distinct input fields for First, Middle, Last, and Suffix', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await switchToSignUp(tester);

      await tester.enterText(find.byKey(const Key('signup-email-field')), 'user@clinic.test');
      await tester.enterText(find.byKey(const Key('signup-password-field')), 'secret123');
      await tester.enterText(find.byKey(const Key('signup-confirm-password-field')), 'secret123');
      await tester.tap(find.byKey(const Key('register-submit-button')));
      await tester.pumpAndSettle();

      // Verify all 4 separate name input fields and their labels
      expect(find.text('First Name'), findsOneWidget);
      expect(find.text('Middle Name (Optional)'), findsOneWidget);
      expect(find.text('Last Name'), findsOneWidget);
      expect(find.text('Suffix (Optional)'), findsOneWidget);

      expect(find.byKey(const Key('wizard-first-name-field')), findsOneWidget);
      expect(find.byKey(const Key('wizard-middle-name-field')), findsOneWidget);
      expect(find.byKey(const Key('wizard-last-name-field')), findsOneWidget);
      expect(find.byKey(const Key('wizard-suffix-field')), findsOneWidget);

      // First Name and Last Name must be RequiredTextFormField
      final firstRequired = tester.widget<RequiredTextFormField>(find.byKey(const Key('wizard-first-name-field')));
      expect(firstRequired, isNotNull);

      final lastRequired = tester.widget<RequiredTextFormField>(find.byKey(const Key('wizard-last-name-field')));
      expect(lastRequired, isNotNull);
    });

    testWidgets('Validation requires First and Last Name before continuing to Step 2', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await switchToSignUp(tester);

      await tester.enterText(find.byKey(const Key('signup-email-field')), 'user@clinic.test');
      await tester.enterText(find.byKey(const Key('signup-password-field')), 'secret123');
      await tester.enterText(find.byKey(const Key('signup-confirm-password-field')), 'secret123');
      await tester.tap(find.byKey(const Key('register-submit-button')));
      await tester.pumpAndSettle();

      final continueBtn = find.byKey(const Key('wizard-step1-continue-button'));
      await tester.tap(continueBtn);
      await tester.pumpAndSettle();

      // Blocked on Step 1: Still on Legal Identity
      expect(find.text('Select Your Practice Path'), findsNothing);
      expect(find.text('Legal Identity'), findsOneWidget);

      // Fill in only First Name, leaving Last Name empty
      await tester.enterText(find.byKey(const Key('wizard-first-name-field')), 'Carlos');
      await tester.tap(continueBtn);
      await tester.pumpAndSettle();

      expect(find.text('Select Your Practice Path'), findsNothing);

      // Now fill in Last Name and continue
      await tester.enterText(find.byKey(const Key('wizard-last-name-field')), 'Santana');
      await tester.tap(continueBtn);
      await tester.pumpAndSettle();

      // Successfully advanced to Step 2
      expect(find.text('Select Your Practice Path'), findsOneWidget);
    });
  });

  group('Onboarding Wizard Branching Paths Tests', () {
    testWidgets('Doctor Path: Provisions practice workspace with zero approval delays', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await switchToSignUp(tester);

      // Step 0: Register
      await tester.enterText(find.byKey(const Key('signup-email-field')), 'dr.rodriguez@clinic.test');
      await tester.enterText(find.byKey(const Key('signup-password-field')), 'secret123');
      await tester.enterText(find.byKey(const Key('signup-confirm-password-field')), 'secret123');
      await tester.tap(find.byKey(const Key('register-submit-button')));
      await tester.pumpAndSettle();

      // Step 1: Structured Names
      await tester.enterText(find.byKey(const Key('wizard-first-name-field')), 'Maria');
      await tester.enterText(find.byKey(const Key('wizard-middle-name-field')), 'Santos');
      await tester.enterText(find.byKey(const Key('wizard-last-name-field')), 'Rodriguez');
      await tester.enterText(find.byKey(const Key('wizard-suffix-field')), 'MD');
      await tester.tap(find.byKey(const Key('wizard-step1-continue-button')));
      await tester.pumpAndSettle();

      // Step 2: Practice Path Selection -> Select New Practice
      expect(find.text('Select Your Practice Path'), findsOneWidget);
      expect(find.text('Open a New Clinic Practice'), findsOneWidget);
      expect(find.text('Join an Existing Clinic'), findsOneWidget);

      await tester.tap(find.byKey(const Key('wizard-path-new-practice')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wizard-step2-continue-button')));
      await tester.pumpAndSettle();

      // Step 3A: Practice Configuration
      expect(find.text("Configure Dr. Maria Santos Rodriguez MD's Practice"), findsOneWidget);
      await tester.enterText(find.byKey(const Key('wizard-clinic-name-field')), 'Metro Vision Center');
      await tester.enterText(find.byKey(const Key('wizard-specialty-field')), 'Vitreoretinal Surgery');
      await tester.enterText(find.byKey(const Key('wizard-clinic-address-field')), 'Suite 501 Medical Arts, QC');
      await tester.enterText(find.byKey(const Key('wizard-license-field')), 'PRC-009988');
      await tester.enterText(find.byKey(const Key('wizard-ptr-field')), 'PTR-776655');

      await tester.tap(find.byKey(const Key('wizard-create-practice-submit-button')));
      await tester.pumpAndSettle();

      // Verification of Zero-Delay Doctor Activation
      final user = AuthService.instance.user;
      expect(user, isNotNull);
      expect(AuthService.instance.role, UserRole.physician);
      expect(user!.displayName, 'Dr. Maria Santos Rodriguez MD');
      expect(user.firstName, 'Maria');
      expect(user.middleName, 'Santos');
      expect(user.lastName, 'Rodriguez');
      expect(user.suffix, 'MD');

      expect(AuthService.instance.needsOnboarding, isFalse);
      expect(AuthService.instance.hasSubmittedJoinRequest, isFalse);
      expect(loginSuccessCalled, isTrue);

      // Verifies ProfileStore and TeamService
      expect(ProfileStore.instance.doctorName.text, 'Dr. Maria Santos Rodriguez MD');
      expect(ProfileStore.instance.license.text, 'PRC-009988');
      expect(ProfileStore.instance.ptrNo.text, 'PTR-776655');
      expect(ProfileStore.instance.specialization.text, 'Vitreoretinal Surgery');

      final activeTeam = TeamService.instance.activeTeam;
      expect(activeTeam, isNotNull);
      expect(activeTeam!.name, 'Metro Vision Center');
      expect(TeamService.instance.activeRole, TeamRole.owner);
    });

    testWidgets('Assistant Path: Validates 6-character invite code and routes to pending approval queue', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // First create a team so we have a valid invite code
      final doctorTeam = await TeamService.instance.createTeam('Capitol Eye Clinic');
      final validCode = doctorTeam.inviteCode;

      await switchToSignUp(tester);

      // Step 0: Register Staff
      await tester.enterText(find.byKey(const Key('signup-email-field')), 'staff.elena@clinic.test');
      await tester.enterText(find.byKey(const Key('signup-password-field')), 'secret123');
      await tester.enterText(find.byKey(const Key('signup-confirm-password-field')), 'secret123');
      await tester.tap(find.byKey(const Key('register-submit-button')));
      await tester.pumpAndSettle();

      // Step 1: Structured Names
      await tester.enterText(find.byKey(const Key('wizard-first-name-field')), 'Elena');
      await tester.enterText(find.byKey(const Key('wizard-last-name-field')), 'Bautista');
      await tester.tap(find.byKey(const Key('wizard-step1-continue-button')));
      await tester.pumpAndSettle();

      // Step 2: Practice Path Selection -> Select Join Clinic
      await tester.tap(find.byKey(const Key('wizard-path-join-clinic')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wizard-step2-continue-button')));
      await tester.pumpAndSettle();

      // Step 3B: Join Clinic Invite Code Entry
      expect(find.text('Join Your Clinic Team'), findsOneWidget);

      // Test invalid code
      await tester.enterText(find.byKey(const Key('wizard-invite-code-field')), 'INVALID');
      await tester.tap(find.byKey(const Key('wizard-join-clinic-submit-button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('No team found'), findsOneWidget);
      expect(AuthService.instance.hasSubmittedJoinRequest, isFalse);

      // Test valid code
      await tester.enterText(find.byKey(const Key('wizard-invite-code-field')), validCode);
      await tester.tap(find.byKey(const Key('wizard-join-clinic-submit-button')));
      await tester.pumpAndSettle();

      // Verification of Pending Queue State
      expect(AuthService.instance.hasSubmittedJoinRequest, isTrue);
      expect(AuthService.instance.needsOnboarding, isFalse);
      expect(AuthService.instance.pendingWorkspaceName, 'Capitol Eye Clinic');
      expect(AuthService.instance.pendingInviteCode, validCode);

      // Screen updates to pending approval UI
      expect(find.byKey(const Key('wizard-pending-approval-view')), findsOneWidget);
      expect(find.text('Join Request Submitted'), findsOneWidget);
      expect(find.text('Capitol Eye Clinic'), findsOneWidget);
      expect(find.text('Elena Bautista'), findsOneWidget);
      expect(find.byKey(const Key('wizard-check-status-button')), findsOneWidget);
      expect(find.byKey(const Key('wizard-change-code-button')), findsOneWidget);

      // Tapping "Enter a Different Invite Code" resets the join request
      await tester.tap(find.byKey(const Key('wizard-change-code-button')));
      await tester.pumpAndSettle();

      expect(AuthService.instance.hasSubmittedJoinRequest, isFalse);
      expect(find.byKey(const Key('wizard-invite-code-field')), findsOneWidget);
    });
  });

  group('TeamMember Structured Name Serialization Tests', () {
    test('TeamMember correctly parses and serializes structured name components', () {
      final member = TeamMember(
        uid: 'user-001',
        email: 'doctor@clinic.test',
        displayName: 'Juan Dela Cruz Jr.',
        firstName: 'Juan',
        middleName: 'Dela',
        lastName: 'Cruz',
        suffix: 'Jr.',
        role: TeamRole.assistant,
        joinedAt: DateTime.now().toIso8601String(),
      );

      expect(member.firstName, 'Juan');
      expect(member.middleName, 'Dela');
      expect(member.lastName, 'Cruz');
      expect(member.suffix, 'Jr.');
      expect(member.displayName, 'Juan Dela Cruz Jr.');

      final json = member.toJson();
      expect(json['firstName'], 'Juan');
      expect(json['middleName'], 'Dela');
      expect(json['lastName'], 'Cruz');
      expect(json['suffix'], 'Jr.');
      expect(json['displayName'], 'Juan Dela Cruz Jr.');

      final deserialized = TeamMember.fromJson(json);
      expect(deserialized.firstName, 'Juan');
      expect(deserialized.middleName, 'Dela');
      expect(deserialized.lastName, 'Cruz');
      expect(deserialized.suffix, 'Jr.');
      expect(deserialized.displayName, 'Juan Dela Cruz Jr.');
    });
  });
}
