import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/services/auth_service.dart';
import 'package:ophthalmology_clinical_record_system/services/security_settings_store.dart';
import 'package:ophthalmology_clinical_record_system/services/sms_otp_service.dart';
import 'package:ophthalmology_clinical_record_system/theme/app_theme.dart';
import 'package:ophthalmology_clinical_record_system/views/login_view.dart';
import 'package:ophthalmology_clinical_record_system/views/settings_view.dart';
import 'package:ophthalmology_clinical_record_system/widgets/session_lock_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_auth_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAuthBackend backend;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.instance.resetForTesting();
    SecuritySettingsStore.instance.reset();
    SmsOtpService.instance.clearOtp('+639175550192');
  });

  tearDown(() async {
    await AuthService.instance.resetForTesting();
    SecuritySettingsStore.instance.reset();
  });

  Future<void> attachBackend() async {
    backend = FakeAuthBackend({
      'admin@clinic.test': (password: 'Admin@123', role: UserRole.admin),
      'doctor@clinic.test': (password: 'Doctor@123', role: UserRole.physician),
    });
    await AuthService.instance.attach(backend);
  }

  group('SmsOtpService Unit Tests', () {
    test('masks phone numbers correctly for security display', () {
      expect(SmsOtpService.maskPhoneNumber('+639175550192'), '+63 ••• ••• 0192');
      expect(SmsOtpService.maskPhoneNumber('09175550192'), '091 ••• ••• 0192');
      expect(SmsOtpService.maskPhoneNumber('123'), '123');
    });

    test('generates, verifies, and expires 6-digit OTP codes', () async {
      final code = await SmsOtpService.instance.generateAndSendSmsOtp('+639175550192');
      expect(code.length, 6);
      expect(int.tryParse(code), isNotNull);

      // Wrong code fails
      final wrongResult = await SmsOtpService.instance.verifySmsOtp('+639175550192', '000000');
      expect(wrongResult, isFalse);

      // Correct code succeeds
      final correctResult = await SmsOtpService.instance.verifySmsOtp('+639175550192', code);
      expect(correctResult, isTrue);

      // Subsequent attempt fails because code was consumed
      final secondResult = await SmsOtpService.instance.verifySmsOtp('+639175550192', code);
      expect(secondResult, isFalse);
    });
  });

  group('SecuritySettingsStore Unit Tests', () {
    test('default settings and timeout mapping', () async {
      final store = SecuritySettingsStore.instance;
      expect(store.autoLockEnabled, isTrue);
      expect(store.autoLockDuration, '15 minutes');
      expect(store.timeoutDuration, const Duration(minutes: 15));
      expect(store.twoFactorEnabled, isFalse);
      expect(store.isLocked, isFalse);

      await store.updateAutoLock(enabled: true, duration: '5 minutes');
      expect(store.timeoutDuration, const Duration(minutes: 5));

      await store.updateAutoLock(enabled: true, duration: '10 minutes');
      expect(store.timeoutDuration, const Duration(minutes: 10));

      await store.updateAutoLock(enabled: true, duration: '30 minutes');
      expect(store.timeoutDuration, const Duration(minutes: 30));

      await store.updateAutoLock(enabled: true, duration: 'Never');
      expect(store.timeoutDuration, isNull);

      await store.updateAutoLock(enabled: false, duration: '15 minutes');
      expect(store.timeoutDuration, isNull);
    });

    test('lock and unlock with password verification', () async {
      await attachBackend();
      final store = SecuritySettingsStore.instance;
      await AuthService.instance.signIn('doctor@clinic.test', 'Doctor@123');

      store.lock();
      expect(store.isLocked, isTrue);

      // Unlock with wrong password fails
      final wrongUnlock = await store.unlockWithPassword('WrongPassword');
      expect(wrongUnlock, isFalse);
      expect(store.isLocked, isTrue);

      // Unlock with correct password succeeds
      final correctUnlock = await store.unlockWithPassword('Doctor@123');
      expect(correctUnlock, isTrue);
      expect(store.isLocked, isFalse);
    });

    test('serialization toMap and fromMap restores security properties', () {
      final store = SecuritySettingsStore.instance;
      store.fromMap({
        'autoLockEnabled': false,
        'autoLockDuration': '30 minutes',
        'twoFactorEnabled': true,
        'twoFactorPhoneNumber': '+639178889999',
      });

      expect(store.autoLockEnabled, isFalse);
      expect(store.autoLockDuration, '30 minutes');
      expect(store.twoFactorEnabled, isTrue);
      expect(store.twoFactorPhoneNumber, '+639178889999');

      final map = store.toMap();
      expect(map['autoLockEnabled'], isFalse);
      expect(map['autoLockDuration'], '30 minutes');
      expect(map['twoFactorEnabled'], isTrue);
      expect(map['twoFactorPhoneNumber'], '+639178889999');
    });
  });

  group('AuthService Change Password & 2FA Flow Tests', () {
    test('changePassword validates length and re-authenticates current password', () async {
      await attachBackend();
      await AuthService.instance.signIn('doctor@clinic.test', 'Doctor@123');

      // Short password throws AuthFailure
      await expectLater(
        AuthService.instance.changePassword(
          currentPassword: 'Doctor@123',
          newPassword: 'short',
        ),
        throwsA(isA<AuthFailure>().having((e) => e.message, 'message', contains('at least 6'))),
      );

      // Wrong current password throws AuthFailure
      await expectLater(
        AuthService.instance.changePassword(
          currentPassword: 'WrongOldPassword',
          newPassword: 'NewDoctorPass!1',
        ),
        throwsA(isA<AuthFailure>().having((e) => e.message, 'message', contains('Current password is incorrect'))),
      );

      // Correct current password succeeds
      await AuthService.instance.changePassword(
        currentPassword: 'Doctor@123',
        newPassword: 'NewDoctorPass!1',
      );

      // Verify sign in with new password
      await AuthService.instance.signOut();
      await AuthService.instance.signIn('doctor@clinic.test', 'NewDoctorPass!1');
      expect(AuthService.instance.isSignedIn, isTrue);
    });

    test('2FA gate blocks standard sign-in until OTP is verified', () async {
      await attachBackend();
      // Mark 2FA enabled on backend for doctor
      backend.twoFactorAccounts['doctor@clinic.test'] = true;
      backend.twoFactorPhoneNumbers['doctor@clinic.test'] = '+639175550192';

      await AuthService.instance.signIn('doctor@clinic.test', 'Doctor@123');

      expect(AuthService.instance.isSignedIn, isFalse);
      expect(AuthService.instance.is2faPending, isTrue);
      expect(AuthService.instance.masked2faPhone, contains('0192'));

      // Retrieve generated OTP and complete sign-in
      final otp = SmsOtpService.instance.lastGeneratedCode;
      expect(otp, isNotNull);

      // Wrong code fails
      await expectLater(
        AuthService.instance.complete2faSignIn('000000'),
        throwsA(isA<AuthFailure>()),
      );
      expect(AuthService.instance.isSignedIn, isFalse);

      // Valid code completes sign-in
      await AuthService.instance.complete2faSignIn(otp!);
      expect(AuthService.instance.isSignedIn, isTrue);
      expect(AuthService.instance.is2faPending, isFalse);
    });
  });

  group('SessionLockOverlay Widget Tests', () {
    testWidgets('SessionLockOverlay renders frosted blur and unlocks on correct password', (WidgetTester tester) async {
      await attachBackend();
      await AuthService.instance.signIn('doctor@clinic.test', 'Doctor@123');
      var unlocked = false;
      var signedOut = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SessionLockOverlay(
              onUnlock: (pass) async {
                final result = pass == 'Doctor@123';
                if (result) unlocked = true;
                return result;
              },
              onLogout: () => signedOut = true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Workstation Locked'), findsOneWidget);
      expect(find.text('Session paused due to inactivity to protect patient confidentiality.'), findsOneWidget);
      expect(find.text('doctor@clinic.test'), findsOneWidget);

      final passField = find.byType(TextField);
      expect(passField, findsOneWidget);

      // Enter wrong password
      await tester.enterText(passField, 'WrongPass');
      await tester.tap(find.text('Unlock Workstation'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(unlocked, isFalse);
      expect(find.text('Incorrect password. Please try again.'), findsOneWidget);

      // Enter correct password
      await tester.enterText(passField, 'Doctor@123');
      await tester.tap(find.text('Unlock Workstation'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(unlocked, isTrue);

      // Test sign out action
      final signOutBtn = find.text('Sign Out Instead');
      expect(signOutBtn, findsOneWidget);
      await tester.tap(signOutBtn);
      await tester.pump();
      expect(signedOut, isTrue);
    });
  });

  group('SettingsView Security Tab Widget Tests', () {
    testWidgets('Security tab renders Change Password and Session Security options', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await attachBackend();
      await AuthService.instance.signIn('doctor@clinic.test', 'Doctor@123');

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: SettingsView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to Security tab
      final securityTab = find.text('Security');
      expect(securityTab, findsOneWidget);
      await tester.tap(securityTab);
      await tester.pumpAndSettle();

      expect(find.text('Change Password'), findsOneWidget);
      expect(find.text('Session Security & Auto-Lock'), findsOneWidget);
      expect(find.text('Two-Factor Authentication (2FA)'), findsOneWidget);
      expect(find.text('Auto-Lock System'), findsOneWidget);
      expect(find.text('Inactivity Timeout:'), findsOneWidget);
    });

    testWidgets('Change Password validation rejects blank and mismatched passwords', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await attachBackend();
      await AuthService.instance.signIn('doctor@clinic.test', 'Doctor@123');

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: SettingsView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Security'));
      await tester.pumpAndSettle();

      // Tap update password without filling fields
      final updateBtn = find.text('Update Password');
      await tester.ensureVisible(updateBtn);
      await tester.tap(updateBtn);
      await tester.pump();

      expect(find.text('Please enter your current password.'), findsOneWidget);

      // Fill mismatched passwords
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'Doctor@123');
      await tester.enterText(textFields.at(1), 'NewPassword123');
      await tester.enterText(textFields.at(2), 'DifferentPassword123');

      await tester.tap(updateBtn);
      await tester.pump();

      expect(find.text('New password and confirmation do not match.'), findsOneWidget);
    });

    testWidgets('Successful password change triggers success modal and clears input fields', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await attachBackend();
      await AuthService.instance.signIn('doctor@clinic.test', 'Doctor@123');

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: SettingsView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Security'));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'Doctor@123');
      await tester.enterText(textFields.at(1), 'ValidNewPass123!');
      await tester.enterText(textFields.at(2), 'ValidNewPass123!');

      final updateBtn = find.text('Update Password');
      await tester.ensureVisible(updateBtn);
      await tester.tap(updateBtn);
      await tester.pumpAndSettle();

      // Verify success modal pops up
      expect(find.text('Password Updated'), findsOneWidget);
      expect(find.text('Your account password has been successfully updated in Firebase Authentication.'), findsOneWidget);

      // Verify fields are cleared
      expect(tester.widget<TextField>(textFields.at(0)).controller?.text, isEmpty);
      expect(tester.widget<TextField>(textFields.at(1)).controller?.text, isEmpty);
      expect(tester.widget<TextField>(textFields.at(2)).controller?.text, isEmpty);

      // Dismiss modal
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Password Updated'), findsNothing);
    });

    testWidgets('Password visibility toggle reveals and masks password fields independently', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await attachBackend();
      await AuthService.instance.signIn('doctor@clinic.test', 'Doctor@123');

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: SettingsView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Security'));
      await tester.pumpAndSettle();

      final toggleCurrent = find.byKey(const Key('toggle_current_password_visibility'));
      final toggleNew = find.byKey(const Key('toggle_new_password_visibility'));
      final toggleConfirm = find.byKey(const Key('toggle_confirm_password_visibility'));

      expect(toggleCurrent, findsOneWidget);
      expect(toggleNew, findsOneWidget);
      expect(toggleConfirm, findsOneWidget);

      final textFields = find.byType(TextField);
      expect(tester.widget<TextField>(textFields.at(0)).obscureText, isTrue);
      expect(tester.widget<TextField>(textFields.at(1)).obscureText, isTrue);
      expect(tester.widget<TextField>(textFields.at(2)).obscureText, isTrue);

      // Verify eye-off icons initially
      expect(find.byIcon(Icons.visibility_off_outlined), findsNWidgets(3));
      expect(find.byIcon(Icons.visibility_outlined), findsNothing);

      // Tap current password toggle -> reveals plain text
      await tester.tap(toggleCurrent);
      await tester.pump();

      expect(tester.widget<TextField>(textFields.at(0)).obscureText, isFalse);
      expect(tester.widget<TextField>(textFields.at(1)).obscureText, isTrue);
      expect(tester.widget<TextField>(textFields.at(2)).obscureText, isTrue);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off_outlined), findsNWidgets(2));

      // Tap current password toggle second time -> re-masks input
      await tester.tap(toggleCurrent);
      await tester.pump();

      expect(tester.widget<TextField>(textFields.at(0)).obscureText, isTrue);
      expect(tester.widget<TextField>(textFields.at(1)).obscureText, isTrue);
      expect(tester.widget<TextField>(textFields.at(2)).obscureText, isTrue);
      expect(find.byIcon(Icons.visibility_off_outlined), findsNWidgets(3));
      expect(find.byIcon(Icons.visibility_outlined), findsNothing);

      // Tap new password toggle
      await tester.tap(toggleNew);
      await tester.pump();

      expect(tester.widget<TextField>(textFields.at(0)).obscureText, isTrue);
      expect(tester.widget<TextField>(textFields.at(1)).obscureText, isFalse);
      expect(tester.widget<TextField>(textFields.at(2)).obscureText, isTrue);

      // Tap confirm password toggle
      await tester.tap(toggleConfirm);
      await tester.pump();

      expect(tester.widget<TextField>(textFields.at(0)).obscureText, isTrue);
      expect(tester.widget<TextField>(textFields.at(1)).obscureText, isFalse);
      expect(tester.widget<TextField>(textFields.at(2)).obscureText, isFalse);
    });

    testWidgets('Toggling 2FA opens SMS phone number enrollment modal and completes activation with valid code', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await attachBackend();
      await AuthService.instance.signIn('doctor@clinic.test', 'Doctor@123');

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: SettingsView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Security'));
      await tester.pumpAndSettle();

      // Find the 2FA switch (initially false)
      final twoFactorSwitch = find.byKey(const Key('two_factor_switch'));
      expect(twoFactorSwitch, findsOneWidget);
      expect(tester.widget<SwitchListTile>(twoFactorSwitch).value, isFalse);

      // Tap switch to initiate enrollment
      await tester.tap(twoFactorSwitch);
      await tester.pumpAndSettle();

      // Modal appears
      expect(find.text('Two-Factor Authentication'), findsAtLeastNWidgets(1));
      expect(find.text('Mobile Phone Number'), findsOneWidget);
      expect(find.text('Send Verification Code'), findsOneWidget);

      // Enter valid phone number and send OTP
      final phoneInput = find.byKey(const Key('two_factor_phone_field'));
      expect(phoneInput, findsOneWidget);
      await tester.enterText(phoneInput, '+639175550192');
      await tester.tap(find.text('Send Verification Code'));
      await tester.pumpAndSettle();

      // Step 2: Now asks for 6-digit code
      expect(find.text('Verify & Activate 2FA'), findsOneWidget);

      final code = SmsOtpService.instance.lastGeneratedCode;
      expect(code, isNotNull);

      // Enter valid 6-digit code into OTP fields
      for (var i = 0; i < 6; i++) {
        await tester.enterText(find.byKey(Key('two_factor_enroll_otp_$i')), code![i]);
      }
      await tester.pump();

      // Click "Verify & Activate 2FA"
      await tester.tap(find.byKey(const Key('verify_enrollment_sms_button')));
      await tester.pumpAndSettle();

      // Success modal is displayed
      expect(find.text('Two-Factor Authentication Enabled'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // Toggle switch in UI is now updated to true
      expect(tester.widget<SwitchListTile>(find.byKey(const Key('two_factor_switch'))).value, isTrue);
      expect(SecuritySettingsStore.instance.twoFactorEnabled, isTrue);
      expect(backend.twoFactorAccounts['doctor@clinic.test'], isTrue);

      // Verify subsequent login enforces 2FA challenge
      await AuthService.instance.signOut();
      expect(AuthService.instance.isSignedIn, isFalse);

      await AuthService.instance.signIn('doctor@clinic.test', 'Doctor@123');
      expect(AuthService.instance.isSignedIn, isFalse);
      expect(AuthService.instance.is2faPending, isTrue);
    });

    testWidgets('Cancelling 2FA enrollment cleanly aborts without altering toggle state', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await attachBackend();
      await AuthService.instance.signIn('doctor@clinic.test', 'Doctor@123');

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: SettingsView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Security'));
      await tester.pumpAndSettle();

      // 1. Cancel on Step 1
      final twoFactorSwitch = find.byKey(const Key('two_factor_switch'));
      expect(tester.widget<SwitchListTile>(twoFactorSwitch).value, isFalse);

      await tester.tap(twoFactorSwitch);
      await tester.pumpAndSettle();

      expect(find.text('Mobile Phone Number'), findsOneWidget);
      await tester.tap(find.byKey(const Key('two_factor_modal_cancel_button')));
      await tester.pumpAndSettle();

      // Switch remains unchanged (false)
      expect(tester.widget<SwitchListTile>(find.byKey(const Key('two_factor_switch'))).value, isFalse);
      expect(SecuritySettingsStore.instance.twoFactorEnabled, isFalse);

      // 2. Cancel on Step 2
      await tester.tap(find.byKey(const Key('two_factor_switch')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('two_factor_phone_field')), '+639175550192');
      await tester.tap(find.text('Send Verification Code'));
      await tester.pumpAndSettle();

      expect(find.text('Verify & Activate 2FA'), findsOneWidget);
      await tester.tap(find.byKey(const Key('two_factor_modal_cancel_button')));
      await tester.pumpAndSettle();

      // Switch remains unchanged (false)
      expect(tester.widget<SwitchListTile>(find.byKey(const Key('two_factor_switch'))).value, isFalse);
      expect(SecuritySettingsStore.instance.twoFactorEnabled, isFalse);
      expect(backend.twoFactorAccounts['doctor@clinic.test'], isNot(true));
    });

    testWidgets('2FA modal displays inline error for invalid verification code and allows resend', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await attachBackend();
      await AuthService.instance.signIn('doctor@clinic.test', 'Doctor@123');

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: SettingsView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Security'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('two_factor_switch')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('two_factor_phone_field')), '+639175550192');
      await tester.tap(find.text('Send Verification Code'));
      await tester.pumpAndSettle();

      expect(find.text('Verify & Activate 2FA'), findsOneWidget);

      // Enter wrong 6-digit code
      for (var i = 0; i < 6; i++) {
        await tester.enterText(find.byKey(Key('two_factor_enroll_otp_$i')), '0');
      }
      await tester.pump();

      await tester.tap(find.byKey(const Key('verify_enrollment_sms_button')));
      await tester.pumpAndSettle();

      // Error message is displayed inline
      expect(find.text('The verification code entered is incorrect. Please check the code sent to your phone and try again.'), findsOneWidget);
      expect(find.text('Verify & Activate 2FA'), findsOneWidget);

      // Switch remains false in background
      expect(SecuritySettingsStore.instance.twoFactorEnabled, isFalse);

      // Test Resend button
      final resendBtn = find.byKey(const Key('two_factor_modal_resend_button'));
      expect(resendBtn, findsOneWidget);
      await tester.tap(resendBtn);
      await tester.pumpAndSettle();

      expect(find.text('A new 6-digit code has been sent via SMS.'), findsOneWidget);

      final newCode = SmsOtpService.instance.lastGeneratedCode;
      expect(newCode, isNotNull);

      // Enter the new valid code
      for (var i = 0; i < 6; i++) {
        await tester.enterText(find.byKey(Key('two_factor_enroll_otp_$i')), newCode![i]);
      }
      await tester.pump();

      await tester.tap(find.byKey(const Key('verify_enrollment_sms_button')));
      await tester.pumpAndSettle();

      // Successfully enrolled
      expect(find.text('Two-Factor Authentication Enabled'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(find.byKey(const Key('two_factor_switch'))).value, isTrue);
      expect(SecuritySettingsStore.instance.twoFactorEnabled, isTrue);
    });
  });

  group('LoginView 2FA Pending View Widget Tests', () {
    testWidgets('Renders 2FA verification step and completes sign in', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await attachBackend();
      backend.twoFactorAccounts['doctor@clinic.test'] = true;
      backend.twoFactorPhoneNumbers['doctor@clinic.test'] = '+639175550192';

      var loginSuccessCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: LoginView(
              onLoginSuccess: () => loginSuccessCalled = true,
            ),
          ),
        ),
      );
      await tester.pump();

      final fields = find.byType(EditableText);
      await tester.enterText(fields.at(0), 'doctor@clinic.test');
      await tester.enterText(fields.at(1), 'Doctor@123');

      final signInBtn = find.text('Sign In to Workstation');
      await tester.ensureVisible(signInBtn);
      await tester.tap(signInBtn);
      await tester.pumpAndSettle();

      // Should now show 2FA screen
      expect(find.text('Two-Factor Authentication'), findsOneWidget);
      expect(find.byKey(const Key('two_factor_verification_view')), findsOneWidget);
      expect(find.byKey(const Key('two_factor_verify_button')), findsOneWidget);

      final otpCode = SmsOtpService.instance.lastGeneratedCode;
      expect(otpCode, isNotNull);

      // Enter OTP into 6 fields
      for (var i = 0; i < 6; i++) {
        final otpField = find.byKey(Key('two_factor_login_otp_$i'));
        expect(otpField, findsOneWidget);
        await tester.enterText(otpField, otpCode![i]);
      }

      await tester.tap(find.byKey(const Key('two_factor_verify_button')));
      await tester.pumpAndSettle();

      expect(AuthService.instance.isSignedIn, isTrue);
      expect(AuthService.instance.is2faPending, isFalse);
      expect(loginSuccessCalled, isTrue);
    });
  });
}
