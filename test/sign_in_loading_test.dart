import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/services/auth_service.dart';
import 'package:ophthalmology_clinical_record_system/views/login_view.dart';
import 'package:ophthalmology_clinical_record_system/widgets/required_text_form_field.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_auth_backend.dart';

class ControllableAuthBackend extends FakeAuthBackend {
  Completer<void>? pendingSignIn;

  ControllableAuthBackend(super.accounts);

  @override
  Future<AuthUser> signIn(String email, String password, {required bool remember}) async {
    if (pendingSignIn != null) {
      await pendingSignIn!.future;
    }
    return super.signIn(email, password, remember: remember);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ControllableAuthBackend backend;
  bool loginSuccessCalled = false;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.instance.resetForTesting();
    loginSuccessCalled = false;
    backend = ControllableAuthBackend({
      'doctor@clinic.test': (password: 'ValidPassword123!', role: UserRole.physician),
    });
    await AuthService.instance.attach(backend);
  });

  tearDown(() async {
    await AuthService.instance.resetForTesting();
  });

  Widget buildTestLoginView() {
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

  testWidgets('Sign in button displays loading spinner and disables inputs during authentication', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildTestLoginView());
    await tester.pump();

    // Verify initial idle state
    expect(find.text('Sign In to Workstation'), findsOneWidget);
    expect(find.byKey(const Key('sign-in-loading-spinner')), findsNothing);

    final initialFields = tester.widgetList<RequiredTextFormField>(find.byType(RequiredTextFormField)).toList();
    expect(initialFields[0].enabled, isTrue);
    expect(initialFields[1].enabled, isTrue);

    // Enter credentials
    final editableFields = find.byType(EditableText);
    await tester.enterText(editableFields.at(0), 'doctor@clinic.test');
    await tester.enterText(editableFields.at(1), 'ValidPassword123!');

    // Hold the signIn future open
    backend.pendingSignIn = Completer<void>();

    final signInButtonFinder = find.widgetWithText(ElevatedButton, 'Sign In to Workstation');
    await tester.ensureVisible(signInButtonFinder);
    await tester.tap(signInButtonFinder);
    await tester.pump();

    // 1. Loading spinner is displayed on the button
    expect(find.byKey(const Key('sign-in-loading-spinner')), findsOneWidget);
    expect(find.text('Sign In to Workstation'), findsNothing);

    // 2. Button is disabled to prevent duplicate submissions
    final elevatedBtn = tester.widget<ElevatedButton>(find.byType(ElevatedButton).first);
    expect(elevatedBtn.onPressed, isNull);

    // 3. Form inputs are disabled during processing
    final requiredFields = tester.widgetList<RequiredTextFormField>(find.byType(RequiredTextFormField)).toList();
    expect(requiredFields[0].enabled, isFalse);
    expect(requiredFields[1].enabled, isFalse);

    final textFormFields = tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
    expect(textFormFields[0].enabled, isFalse);
    expect(textFormFields[1].enabled, isFalse);

    // Complete the authentication request
    await tester.runAsync(() async {
      backend.pendingSignIn!.complete();
      await Future.delayed(const Duration(milliseconds: 20));
    });

    await tester.pump();

    // 4. Displays transition view before dashboard
    expect(find.byKey(const Key('login-transition-view')), findsOneWidget);
    expect(find.text('Authenticating Session...'), findsOneWidget);
    expect(loginSuccessCalled, isFalse);

    // Wait for the brief transition delay (300ms)
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    // 5. Successfully transitions and triggers onLoginSuccess
    expect(loginSuccessCalled, isTrue);
  });

  testWidgets('Authentication failure stops loading, re-enables inputs, and displays error', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildTestLoginView());
    await tester.pump();

    final editableFields = find.byType(EditableText);
    await tester.enterText(editableFields.at(0), 'doctor@clinic.test');
    await tester.enterText(editableFields.at(1), 'WrongPassword!');

    backend.pendingSignIn = Completer<void>();

    final signInButtonFinder = find.widgetWithText(ElevatedButton, 'Sign In to Workstation');
    await tester.tap(signInButtonFinder);
    await tester.pump();

    // While processing: spinner is visible, inputs are disabled
    expect(find.byKey(const Key('sign-in-loading-spinner')), findsOneWidget);
    expect(tester.widget<RequiredTextFormField>(find.byType(RequiredTextFormField).first).enabled, isFalse);

    // Fail the authentication with AuthFailure
    backend.pendingSignIn!.completeError(const AuthFailure('Incorrect credentials or expired clinic token.'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // After failure:
    // 1. Loading spinner stops and sign-in text returns
    expect(find.byKey(const Key('sign-in-loading-spinner')), findsNothing);
    expect(find.text('Sign In to Workstation'), findsOneWidget);

    // 2. Inputs are re-enabled
    final requiredFields = tester.widgetList<RequiredTextFormField>(find.byType(RequiredTextFormField)).toList();
    expect(requiredFields[0].enabled, isTrue);
    expect(requiredFields[1].enabled, isTrue);

    final textFormFields = tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
    expect(textFormFields[0].enabled, isTrue);
    expect(textFormFields[1].enabled, isTrue);

    // 3. Error message is displayed clearly
    expect(find.text('Incorrect credentials or expired clinic token.'), findsOneWidget);

    // 4. Button is re-enabled for another attempt
    final elevatedBtn = tester.widget<ElevatedButton>(find.byType(ElevatedButton).first);
    expect(elevatedBtn.onPressed, isNotNull);
    expect(loginSuccessCalled, isFalse);
  });
}
