import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/models/team.dart';
import 'package:ophthalmology_clinical_record_system/services/auth_service.dart';
import 'package:ophthalmology_clinical_record_system/services/profile_store.dart';
import 'package:ophthalmology_clinical_record_system/views/login_view.dart';
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

  testWidgets('Registration screen displays 4 distinct input fields for First, Middle, Last, and Suffix', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await switchToSignUp(tester);

    // Verify all 4 separate name input fields and their labels are present
    expect(find.text('First Name'), findsOneWidget);
    expect(find.text('Middle Name (Optional)'), findsOneWidget);
    expect(find.text('Last Name'), findsOneWidget);
    expect(find.text('Suffix (Optional)'), findsOneWidget);

    expect(find.byKey(const Key('signup-first-name-field')), findsOneWidget);
    expect(find.byKey(const Key('signup-middle-name-field')), findsOneWidget);
    expect(find.byKey(const Key('signup-last-name-field')), findsOneWidget);
    expect(find.byKey(const Key('signup-suffix-field')), findsOneWidget);

    // First Name and Last Name must be RequiredTextFormField
    final firstRequired = tester.widget<RequiredTextFormField>(find.byKey(const Key('signup-first-name-field')));
    expect(firstRequired, isNotNull);

    final lastRequired = tester.widget<RequiredTextFormField>(find.byKey(const Key('signup-last-name-field')));
    expect(lastRequired, isNotNull);
  });

  testWidgets('Validation requires First and Last Name before submission', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await switchToSignUp(tester);

    // Fill in only email and passwords, leaving First and Last names blank
    await tester.enterText(find.byKey(const Key('signup-email-field')), 'test@clinic.test');
    await tester.enterText(find.byKey(const Key('signup-password-field')), 'secret123');
    await tester.enterText(find.byKey(const Key('signup-confirm-password-field')), 'secret123');

    final submitBtn = find.byKey(const Key('register-submit-button'));
    await tester.ensureVisible(submitBtn);
    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    // Submission blocked
    expect(AuthService.instance.user, isNull);
    expect(loginSuccessCalled, isFalse);

    // Fill in only First Name, leaving Last Name empty
    await tester.enterText(find.byKey(const Key('signup-first-name-field')), 'Carlos');
    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    expect(AuthService.instance.user, isNull);
    expect(loginSuccessCalled, isFalse);

    // Fill in only Last Name, leaving First Name empty
    await tester.enterText(find.byKey(const Key('signup-first-name-field')), '');
    await tester.enterText(find.byKey(const Key('signup-last-name-field')), 'Santana');
    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    expect(AuthService.instance.user, isNull);
    expect(loginSuccessCalled, isFalse);
  });

  testWidgets('Submitting with only required First and Last names succeeds and leaves Middle and Suffix optional', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await switchToSignUp(tester);

    await tester.enterText(find.byKey(const Key('signup-first-name-field')), 'Carlos');
    await tester.enterText(find.byKey(const Key('signup-last-name-field')), 'Santana');
    await tester.enterText(find.byKey(const Key('signup-email-field')), 'carlos@clinic.test');
    await tester.enterText(find.byKey(const Key('signup-password-field')), 'secret123');
    await tester.enterText(find.byKey(const Key('signup-confirm-password-field')), 'secret123');

    final submitBtn = find.byKey(const Key('register-submit-button'));
    await tester.ensureVisible(submitBtn);
    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    final user = AuthService.instance.user;
    expect(user, isNotNull);
    expect(user!.firstName, 'Carlos');
    expect(user.lastName, 'Santana');
    expect(user.middleName, isNull);
    expect(user.suffix, isNull);
    expect(user.displayName, 'Carlos Santana');
  });

  testWidgets('Submitting with all 4 name fields concatenates displayName and stores individual components', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await switchToSignUp(tester);

    await tester.enterText(find.byKey(const Key('signup-first-name-field')), 'Juan');
    await tester.enterText(find.byKey(const Key('signup-middle-name-field')), 'Dela');
    await tester.enterText(find.byKey(const Key('signup-last-name-field')), 'Cruz');
    await tester.enterText(find.byKey(const Key('signup-suffix-field')), 'Jr.');
    await tester.enterText(find.byKey(const Key('signup-email-field')), 'juan.cruz@clinic.test');
    await tester.enterText(find.byKey(const Key('signup-password-field')), 'secret123');
    await tester.enterText(find.byKey(const Key('signup-confirm-password-field')), 'secret123');

    final submitBtn = find.byKey(const Key('register-submit-button'));
    await tester.ensureVisible(submitBtn);
    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    final user = AuthService.instance.user;
    expect(user, isNotNull);
    expect(user!.firstName, 'Juan');
    expect(user.middleName, 'Dela');
    expect(user.lastName, 'Cruz');
    expect(user.suffix, 'Jr.');
    expect(user.displayName, 'Juan Dela Cruz Jr.');

    // Verifies ProfileStore syncs and updates doctor title
    ProfileStore.instance.syncWithUser(user);
    expect(ProfileStore.instance.doctorName.text, 'Dr. Juan Dela Cruz Jr.');
    expect(ProfileStore.instance.firstName, 'Juan');
    expect(ProfileStore.instance.middleName, 'Dela');
    expect(ProfileStore.instance.lastName, 'Cruz');
    expect(ProfileStore.instance.suffix, 'Jr.');

    // Verifies TeamMember model mapping
    final member = TeamMember(
      uid: user.uid,
      email: user.email!,
      displayName: user.displayName!,
      firstName: user.firstName,
      middleName: user.middleName,
      lastName: user.lastName,
      suffix: user.suffix,
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
}
