import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/main.dart';
import 'package:ophthalmology_clinical_record_system/services/auth_service.dart';
import 'package:ophthalmology_clinical_record_system/services/clinic_store.dart';
import 'package:ophthalmology_clinical_record_system/services/offline_sync_service.dart';
import 'package:ophthalmology_clinical_record_system/services/profile_store.dart';
import 'package:ophthalmology_clinical_record_system/theme/app_theme.dart';
import 'package:ophthalmology_clinical_record_system/views/main_layout.dart';
import 'package:ophthalmology_clinical_record_system/widgets/logout_confirmation_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_auth_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAuthBackend backend;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.instance.resetForTesting();
    ClinicStore.instance.resetForTesting();
    ProfileStore.instance.reset();
  });

  tearDown(() async {
    await AuthService.instance.resetForTesting();
    ClinicStore.instance.resetForTesting();
    OfflineSyncService().stopAutoSyncTimer();
  });

  Future<void> attachBackend() async {
    backend = FakeAuthBackend({
      'doctor@clinic.test': (password: 'Doctor@123', role: UserRole.physician),
      'admin@clinic.test': (password: 'Admin@123', role: UserRole.admin),
    });
    await AuthService.instance.attach(backend);
  }

  group('Logout Confirmation Dialog Unit & Component Tests', () {
    testWidgets('showLogoutConfirmationDialog renders title, warning text, and functional buttons', (WidgetTester tester) async {
      bool? dialogResult;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  dialogResult = await showLogoutConfirmationDialog(context);
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      // Open the dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Verify title and icon
      expect(find.text('Confirm Logout'), findsWidgets);
      expect(find.byIcon(Icons.logout_rounded), findsOneWidget);

      // Verify warning message
      expect(find.text('Are you sure you want to log out?'), findsOneWidget);
      expect(find.textContaining('You will need to sign in again to access patient records and clinical workspaces.'), findsOneWidget);

      // Verify action buttons
      final cancelBtn = find.widgetWithText(TextButton, 'Cancel');
      final confirmBtn = find.widgetWithText(ElevatedButton, 'Confirm Logout');
      expect(cancelBtn, findsOneWidget);
      expect(confirmBtn, findsOneWidget);

      // Test Cancel dismisses and returns false
      await tester.tap(cancelBtn);
      await tester.pumpAndSettle();
      expect(dialogResult, isFalse);
      expect(find.byType(AlertDialog), findsNothing);

      // Re-open and test Confirm returns true
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm Logout'));
      await tester.pumpAndSettle();
      expect(dialogResult, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  group('Account Menu Logout Flow Acceptance Criteria Tests', () {
    testWidgets('Clicking "Log out" opens confirmation modal rather than logging out instantly', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool loggedOut = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MainLayout(
            onLogout: () => loggedOut = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final accountTrigger = find.byKey(const ValueKey('account-menu-trigger'));
      expect(accountTrigger, findsOneWidget);

      // Open account popup menu
      await tester.tap(accountTrigger);
      await tester.pumpAndSettle();

      final logoutItem = find.text('Log out');
      expect(logoutItem, findsOneWidget);

      // Tap Log out
      await tester.tap(logoutItem);
      await tester.pumpAndSettle();

      // Acceptance Criteria 1: Modal opens rather than logging out instantly
      expect(loggedOut, isFalse);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Confirm Logout'), findsWidgets);

      // Acceptance Criteria 2: Modal contains functional Cancel and Confirm Logout buttons
      final cancelBtn = find.widgetWithText(TextButton, 'Cancel');
      final confirmBtn = find.widgetWithText(ElevatedButton, 'Confirm Logout');
      expect(cancelBtn, findsOneWidget);
      expect(confirmBtn, findsOneWidget);

      // Acceptance Criteria 3: Clicking Cancel dismisses modal and keeps user logged in
      await tester.tap(cancelBtn);
      await tester.pumpAndSettle();
      expect(loggedOut, isFalse);
      expect(find.byType(AlertDialog), findsNothing);

      // Open account menu again to confirm logout
      await tester.tap(accountTrigger);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();

      // Acceptance Criteria 4: Clicking Confirm Logout successfully triggers logout
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();
      expect(loggedOut, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('Full App Integration: Confirming logout triggers AuthService sign out and routes to login screen', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await attachBackend();
      await AuthService.instance.signIn('doctor@clinic.test', 'Doctor@123');

      // Stop auto sync timer to avoid active timer test hang
      OfflineSyncService().stopAutoSyncTimer();

      await tester.pumpWidget(const OphthalmologyApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(AuthService.instance.isSignedIn, isTrue);
      expect(find.byType(MainLayout), findsOneWidget);

      final accountTrigger = find.byKey(const ValueKey('account-menu-trigger'));
      expect(accountTrigger, findsOneWidget);

      // Open account menu
      await tester.tap(accountTrigger);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap Log out
      await tester.tap(find.text('Log out'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify modal is open and user is still signed in
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(AuthService.instance.isSignedIn, isTrue);

      // Dismiss via Cancel
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(AlertDialog), findsNothing);
      expect(AuthService.instance.isSignedIn, isTrue);

      // Open again and confirm logout
      await tester.tap(accountTrigger);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('Log out'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Confirm Logout
      await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm Logout'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Verify user is signed out from AuthService and routed to login screen
      expect(AuthService.instance.isSignedIn, isFalse);
      expect(find.text('Sign In to Workstation'), findsOneWidget);
    });
  });
}
