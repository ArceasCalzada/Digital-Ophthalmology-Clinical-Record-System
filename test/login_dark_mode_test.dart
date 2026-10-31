import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/services/auth_service.dart';
import 'package:ophthalmology_clinical_record_system/services/offline_sync_service.dart';
import 'package:ophthalmology_clinical_record_system/theme/app_theme.dart';
import 'package:ophthalmology_clinical_record_system/views/login_view.dart';
import 'package:ophthalmology_clinical_record_system/widgets/required_text_form_field.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_auth_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.instance.resetForTesting();
    final backend = FakeAuthBackend({
      'test@clinic.example': (password: 'Pass123!', role: UserRole.physician),
    });
    await AuthService.instance.attach(backend);
  });

  tearDown(() async {
    OfflineSyncService().stopAutoSyncTimer();
    ThemeController.instance.setThemeMode(ThemeMode.light);
    await AuthService.instance.resetForTesting();
  });

  Widget buildLoginApp() {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeController.instance.themeMode,
          home: LoginView(onLoginSuccess: () {}),
        );
      },
    );
  }

  group('Login View Dark Mode Theme Tests', () {
    test('Theme preference persists in SharedPreferences and loads via ThemeController.instance.init()', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('docrs_appearance_preference', 'Dark');

      await ThemeController.instance.init();
      expect(ThemeController.instance.themeMode, equals(ThemeMode.dark));
      expect(ThemeController.instance.isDarkMode, isTrue);

      // Now save Light
      await ThemeController.instance.setThemeMode(ThemeMode.light);
      expect(prefs.getString('docrs_appearance_preference'), equals('Light'));

      // Switch back to Dark and verify save
      await ThemeController.instance.setThemeMode(ThemeMode.dark);
      expect(prefs.getString('docrs_appearance_preference'), equals('Dark'));
    });

    testWidgets('Login screen card and scaffold transition to dark mode colors when dark theme is active', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      ThemeController.instance.setThemeMode(ThemeMode.dark);
      await tester.pumpWidget(buildLoginApp());
      await tester.pumpAndSettle();

      // Verify Scaffold background
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, equals(const Color(0xFF0F172A)));

      // Verify Card container background and border
      final card = tester.widget<Card>(find.byType(Card));
      expect(card.color, equals(const Color(0xFF1E293B)));
      final shape = card.shape as RoundedRectangleBorder;
      expect(shape.side.color, equals(const Color(0xFF334155)));
    });

    testWidgets('Form inputs, labels, and placeholders have correct contrast in dark mode', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      ThemeController.instance.setThemeMode(ThemeMode.dark);
      await tester.pumpWidget(buildLoginApp());
      await tester.pumpAndSettle();

      // Check Email label color
      final emailLabel = tester.widget<Text>(find.text('Email Address'));
      expect(emailLabel.style?.color, equals(const Color(0xFFF8FAFC)));

      // Check Password label color
      final passwordLabel = tester.widget<Text>(find.text('Password'));
      expect(passwordLabel.style?.color, equals(const Color(0xFFF8FAFC)));

      // Check RequiredTextFormField input fields
      final formFields = tester.widgetList<RequiredTextFormField>(find.byType(RequiredTextFormField)).toList();
      expect(formFields.length, greaterThanOrEqualTo(2));

      // Email field
      final emailField = formFields[0];
      expect(emailField.style?.color, equals(const Color(0xFFF8FAFC)));
      expect(emailField.decoration.filled, isTrue);
      expect(emailField.decoration.fillColor, equals(const Color(0xFF0F172A)));
      expect(emailField.decoration.hintStyle?.color, equals(const Color(0xFF94A3B8)));

      // Password field
      final passwordField = formFields[1];
      expect(passwordField.style?.color, equals(const Color(0xFFF8FAFC)));
      expect(passwordField.decoration.filled, isTrue);
      expect(passwordField.decoration.fillColor, equals(const Color(0xFF0F172A)));
      expect(passwordField.decoration.hintStyle?.color, equals(const Color(0xFF94A3B8)));
    });

    testWidgets('Mode switcher tabs and compliance footer transition properly to dark mode', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      ThemeController.instance.setThemeMode(ThemeMode.dark);
      await tester.pumpWidget(buildLoginApp());
      await tester.pumpAndSettle();

      // Check active "Sign In" tab text color in dark mode
      final signInText = tester.widget<Text>(find.text('Sign In'));
      expect(signInText.style?.color, equals(const Color(0xFF60A5FA)));

      // Check inactive "Create Account" tab text color in dark mode
      final createAccountText = tester.widget<Text>(find.text('Create Account'));
      expect(createAccountText.style?.color, equals(const Color(0xFF94A3B8)));

      // Check compliance badge text
      final badgeText = tester.widget<Text>(find.text('Authorised clinic staff only'));
      expect(badgeText.style?.color, equals(const Color(0xFF94A3B8)));
    });

    testWidgets('Create Account registration tab reflects dark styling on inputs and role cards', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      ThemeController.instance.setThemeMode(ThemeMode.dark);
      await tester.pumpWidget(buildLoginApp());
      await tester.pumpAndSettle();

      // Tap Create Account
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      // Verify active role card text in dark mode
      final doctorRoleText = tester.widget<Text>(find.text('Doctor / Practice'));
      expect(doctorRoleText.style?.color, equals(const Color(0xFFF8FAFC)));

      // Verify fields in registration form
      final clinicEmailField = tester.widget<RequiredTextFormField>(find.byKey(const Key('signup-email-field')));
      expect(clinicEmailField.decoration.fillColor, equals(const Color(0xFF0F172A)));
      expect(clinicEmailField.style?.color, equals(const Color(0xFFF8FAFC)));
    });

    testWidgets('Toggling theme mode reactively updates the login screen immediately', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Start in Light Mode
      ThemeController.instance.setThemeMode(ThemeMode.light);
      await tester.pumpWidget(buildLoginApp());
      await tester.pumpAndSettle();

      Card card = tester.widget<Card>(find.byType(Card));
      expect(card.color, equals(Colors.white));

      // Switch to Dark Mode
      ThemeController.instance.setThemeMode(ThemeMode.dark);
      await tester.pumpAndSettle();

      card = tester.widget<Card>(find.byType(Card));
      expect(card.color, equals(const Color(0xFF1E293B)));

      // Switch back to Light Mode
      ThemeController.instance.setThemeMode(ThemeMode.light);
      await tester.pumpAndSettle();

      card = tester.widget<Card>(find.byType(Card));
      expect(card.color, equals(Colors.white));
    });

    testWidgets('Theme preference persists across user logout and LoginView displays dark card container', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.runAsync(() async {
        // Sign in user
        await AuthService.instance.signIn('test@clinic.example', 'Pass123!');
        expect(AuthService.instance.isSignedIn, isTrue);

        // User sets Dark Mode
        await ThemeController.instance.setThemeMode(ThemeMode.dark);

        // User logs out
        await AuthService.instance.signOut();
        expect(AuthService.instance.isSignedIn, isFalse);
      });

      // Build login screen wrapper
      await tester.pumpWidget(buildLoginApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify LoginView respects dark mode after logout
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, equals(const Color(0xFF0F172A)));

      final card = tester.widget<Card>(find.byType(Card));
      expect(card.color, equals(const Color(0xFF1E293B)));

      final shape = card.shape as RoundedRectangleBorder;
      expect(shape.side.color, equals(const Color(0xFF334155)));

      // Verify form fields in dark mode
      final emailField = tester.widget<RequiredTextFormField>(find.byType(RequiredTextFormField).first);
      expect(emailField.decoration.fillColor, equals(const Color(0xFF0F172A)));
      expect(emailField.style?.color, equals(const Color(0xFFF8FAFC)));
    });
  });
}
