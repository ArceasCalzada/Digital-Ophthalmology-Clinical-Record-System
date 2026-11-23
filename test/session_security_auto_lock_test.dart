import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/services/auth_service.dart';
import 'package:ophthalmology_clinical_record_system/services/security_settings_store.dart';
import 'package:ophthalmology_clinical_record_system/theme/app_theme.dart';
import 'package:ophthalmology_clinical_record_system/views/settings_view.dart';
import 'package:ophthalmology_clinical_record_system/widgets/inactivity_guard.dart';
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
  });

  tearDown(() async {
    await AuthService.instance.resetForTesting();
    SecuritySettingsStore.instance.reset();
  });

  Future<void> attachBackend() async {
    backend = FakeAuthBackend({
      'doctor@clinic.test': (password: 'Doctor@123', role: UserRole.physician),
    });
    await AuthService.instance.attach(backend);
  }

  group('SecuritySettingsStore Persistence & Mapping Tests', () {
    test('persists auto-lock toggle and timeout duration to SharedPreferences', () async {
      final store = SecuritySettingsStore.instance;

      // Initial defaults
      expect(store.autoLockEnabled, isTrue);
      expect(store.autoLockDuration, '15 minutes');
      expect(store.timeoutDuration, const Duration(minutes: 15));

      // Update to 5 minutes with specific UID
      await store.updateAutoLock(enabled: true, duration: '5 minutes', uid: 'user_123');
      expect(store.autoLockEnabled, isTrue);
      expect(store.autoLockDuration, '5 minutes');
      expect(store.timeoutDuration, const Duration(minutes: 5));

      // Verify persisted in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userRaw = prefs.getString('security_settings_user_123');
      expect(userRaw, isNotNull);
      final userData = jsonDecode(userRaw!) as Map<String, dynamic>;
      expect(userData['autoLockEnabled'], isTrue);
      expect(userData['autoLockDuration'], '5 minutes');

      // Update to 1 hour
      await store.updateAutoLock(enabled: true, duration: '1 hour', uid: 'user_123');
      expect(store.timeoutDuration, const Duration(hours: 1));

      // Update to Never
      await store.updateAutoLock(enabled: true, duration: 'Never', uid: 'user_123');
      expect(store.timeoutDuration, isNull);

      // Disable Auto-Lock entirely
      await store.updateAutoLock(enabled: false, duration: '15 minutes', uid: 'user_123');
      expect(store.autoLockEnabled, isFalse);
      expect(store.timeoutDuration, isNull);

      // Reload into fresh store state
      store.reset();
      await store.loadLocal('user_123');
      expect(store.autoLockEnabled, isFalse);
      expect(store.autoLockDuration, '15 minutes');
    });

    test('lockScreen respects autoLockEnabled unless force is true', () {
      final store = SecuritySettingsStore.instance;
      store.reset();

      // Enabled: auto-lock locks screen
      expect(store.autoLockEnabled, isTrue);
      store.lockScreen();
      expect(store.isLocked, isTrue);

      store.unlock();
      expect(store.isLocked, isFalse);

      // Disabled: normal timeout lockScreen does nothing
      store.fromMap({'autoLockEnabled': false, 'autoLockDuration': '15 minutes'});
      store.lockScreen();
      expect(store.isLocked, isFalse);

      // Force lock (e.g. manual user action) locks even when auto-lock disabled
      store.lockScreen(force: true);
      expect(store.isLocked, isTrue);
    });
  });

  group('InactivityGuard Interaction & Timeout Tests', () {
    testWidgets('triggers onTimeout callback after duration of inactivity', (WidgetTester tester) async {
      var timeoutFired = false;

      await tester.pumpWidget(
        MaterialApp(
          home: InactivityGuard(
            timeout: const Duration(seconds: 2),
            onTimeout: () => timeoutFired = true,
            child: const Scaffold(
              body: Center(child: Text('Clinical View Content')),
            ),
          ),
        ),
      );

      expect(timeoutFired, isFalse);

      // Advance by 1 second (less than timeout)
      await tester.pump(const Duration(seconds: 1));
      expect(timeoutFired, isFalse);

      // Advance past remaining second
      await tester.pump(const Duration(seconds: 1, milliseconds: 100));
      expect(timeoutFired, isTrue);
    });

    testWidgets('pointer interaction resets inactivity countdown timer', (WidgetTester tester) async {
      var timeoutFired = false;

      await tester.pumpWidget(
        MaterialApp(
          home: InactivityGuard(
            timeout: const Duration(seconds: 2),
            onTimeout: () => timeoutFired = true,
            child: const Scaffold(
              body: Center(child: Text('Clinical View Content')),
            ),
          ),
        ),
      );

      // Advance 1.5 seconds
      await tester.pump(const Duration(milliseconds: 1500));
      expect(timeoutFired, isFalse);

      // User moves mouse or touches screen
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(const Offset(50, 50));
      await tester.pump();

      // Advance another 1.5 seconds (total elapsed 3s, but reset at 1.5s -> 1.5s remaining)
      await tester.pump(const Duration(milliseconds: 1500));
      expect(timeoutFired, isFalse);

      // Advance past the 2s mark since reset
      await tester.pump(const Duration(milliseconds: 600));
      expect(timeoutFired, isTrue);

      await gesture.removePointer();
    });

    testWidgets('keystroke interaction resets inactivity countdown timer', (WidgetTester tester) async {
      var timeoutFired = false;

      await tester.pumpWidget(
        MaterialApp(
          home: InactivityGuard(
            timeout: const Duration(seconds: 2),
            onTimeout: () => timeoutFired = true,
            child: const Scaffold(
              body: Center(
                child: TextField(
                  key: Key('note_field'),
                ),
              ),
            ),
          ),
        ),
      );

      // Advance 1.5 seconds
      await tester.pump(const Duration(milliseconds: 1500));
      expect(timeoutFired, isFalse);

      // User types on keyboard via HardwareKeyboard handler
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pump();

      // Advance 1.5 seconds from keypress
      await tester.pump(const Duration(milliseconds: 1500));
      expect(timeoutFired, isFalse);

      // Complete countdown
      await tester.pump(const Duration(milliseconds: 600));
      expect(timeoutFired, isTrue);
    });

    testWidgets('scrolling interaction resets inactivity countdown timer', (WidgetTester tester) async {
      var timeoutFired = false;

      await tester.pumpWidget(
        MaterialApp(
          home: InactivityGuard(
            timeout: const Duration(seconds: 2),
            onTimeout: () => timeoutFired = true,
            child: Scaffold(
              body: ListView.builder(
                itemCount: 50,
                itemBuilder: (context, index) => ListTile(title: Text('Patient $index')),
              ),
            ),
          ),
        ),
      );

      // Advance 1.5 seconds
      await tester.pump(const Duration(milliseconds: 1500));
      expect(timeoutFired, isFalse);

      // User scrolls list
      await tester.drag(find.text('Patient 0'), const Offset(0, -100));
      await tester.pump();

      // Advance 1.5 seconds from scroll
      await tester.pump(const Duration(milliseconds: 1500));
      expect(timeoutFired, isFalse);

      // Complete countdown
      await tester.pump(const Duration(milliseconds: 600));
      expect(timeoutFired, isTrue);
    });

    testWidgets('route transition resets inactivity countdown via InactivityRouteObserver', (WidgetTester tester) async {
      var timeoutFired = false;
      final observer = InactivityRouteObserver();

      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: InactivityGuard(
            timeout: const Duration(seconds: 2),
            onTimeout: () => timeoutFired = true,
            child: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const Scaffold(body: Text('Sub Route Screen')),
                      ),
                    );
                  },
                  child: const Text('Open Route'),
                ),
              ),
            ),
          ),
        ),
      );

      // Advance 1.5 seconds
      await tester.pump(const Duration(milliseconds: 1500));
      expect(timeoutFired, isFalse);

      // Push new route
      await tester.tap(find.text('Open Route'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Advance 1.5 seconds from route push
      await tester.pump(const Duration(milliseconds: 1500));
      expect(timeoutFired, isFalse);

      // Complete countdown
      await tester.pump(const Duration(milliseconds: 600));
      expect(timeoutFired, isTrue);
    });

    testWidgets('disabling timeout duration cancels timer and prevents auto-lock', (WidgetTester tester) async {
      var timeoutFired = false;

      await tester.pumpWidget(
        MaterialApp(
          home: InactivityGuard(
            timeout: null, // Disabled
            onTimeout: () => timeoutFired = true,
            child: const Scaffold(
              body: Center(child: Text('Content')),
            ),
          ),
        ),
      );

      // Advance 30 seconds
      await tester.pump(const Duration(seconds: 30));
      expect(timeoutFired, isFalse);
    });

    testWidgets('pauses timer when isLocked is true so timeout does not repeatedly fire', (WidgetTester tester) async {
      var timeoutCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: InactivityGuard(
            timeout: const Duration(seconds: 2),
            isLocked: true, // Already locked
            onTimeout: () => timeoutCount++,
            child: const Scaffold(
              body: Center(child: Text('Locked Content')),
            ),
          ),
        ),
      );

      // Advance 10 seconds
      await tester.pump(const Duration(seconds: 10));
      expect(timeoutCount, 0);
    });
  });

  group('Full Session Auto-Lock and Unlock Workflow Tests', () {
    testWidgets('auto-lock triggers SessionLockOverlay and unlocking preserves form view state', (WidgetTester tester) async {
      await attachBackend();
      await AuthService.instance.signIn('doctor@clinic.test', 'Doctor@123');

      final store = SecuritySettingsStore.instance;
      final textController = TextEditingController(text: 'Draft clinical prescription notes');

      await tester.pumpWidget(
        ListenableBuilder(
          listenable: store,
          builder: (context, _) => MaterialApp(
            theme: AppTheme.lightTheme,
            builder: (context, child) {
              return InactivityGuard(
                timeout: const Duration(seconds: 2),
                isLocked: store.isLocked,
                onTimeout: () => store.lockScreen(),
                child: Stack(
                  children: [
                    child ?? const SizedBox.shrink(),
                    if (store.isLocked)
                      Overlay(
                        initialEntries: [
                          OverlayEntry(
                            builder: (_) => SessionLockOverlay(
                              onUnlock: (pass) => store.unlockSession(pass),
                              onLogout: () {},
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
            home: Scaffold(
              body: Center(
                child: TextField(
                  key: const Key('prescription_notes_field'),
                  controller: textController,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Draft clinical prescription notes'), findsOneWidget);
      expect(find.text('Workstation Locked'), findsNothing);

      // Wait 2 seconds of inactivity -> locks screen
      await tester.pump(const Duration(seconds: 2, milliseconds: 100));
      await tester.pump();

      expect(store.isLocked, isTrue);
      expect(find.text('Workstation Locked'), findsOneWidget);
      expect(find.text('Session paused due to inactivity to protect patient confidentiality.'), findsOneWidget);

      // Enter incorrect password
      final lockPassField = find.byKey(const Key('session_lock_password_field'));
      expect(lockPassField, findsOneWidget);
      await tester.enterText(lockPassField, 'WrongPassword');
      await tester.tap(find.byKey(const Key('session_lock_unlock_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(store.isLocked, isTrue);
      expect(find.text('Incorrect password. Please try again.'), findsOneWidget);

      // Enter correct password
      await tester.enterText(lockPassField, 'Doctor@123');
      await tester.tap(find.byKey(const Key('session_lock_unlock_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(store.isLocked, isFalse);
      expect(find.text('Workstation Locked'), findsNothing);

      // Crucial: The underlying draft input and clinical text remain completely intact!
      expect(find.text('Draft clinical prescription notes'), findsOneWidget);
      expect(textController.text, 'Draft clinical prescription notes');
    });

    testWidgets('SettingsView toggles Auto-Lock, changes timeout duration, and triggers confirmation modal', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await attachBackend();
      await AuthService.instance.signIn('doctor@clinic.test', 'Doctor@123');

      final store = SecuritySettingsStore.instance;

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
      await tester.tap(find.text('Security'));
      await tester.pumpAndSettle();

      final autoLockSwitch = find.byKey(const Key('auto_lock_switch'));
      expect(autoLockSwitch, findsOneWidget);
      expect(tester.widget<SwitchListTile>(autoLockSwitch).value, isTrue);

      // Toggle Auto-Lock OFF
      await tester.tap(autoLockSwitch);
      await tester.pumpAndSettle();

      expect(store.autoLockEnabled, isFalse);
      expect(store.timeoutDuration, isNull);
      expect(find.text('Settings Saved Successfully'), findsOneWidget);
      expect(find.text('Auto-lock system disabled.'), findsOneWidget);

      // Dismiss confirmation modal
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // Toggle Auto-Lock back ON
      await tester.tap(autoLockSwitch);
      await tester.pumpAndSettle();

      expect(store.autoLockEnabled, isTrue);
      expect(find.text('Settings Saved Successfully'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // Select 5 minutes timeout from dropdown
      final dropdown = find.byKey(const Key('inactivity_timeout_dropdown'));
      expect(dropdown, findsOneWidget);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      final fiveMinItem = find.text('5 minutes').last;
      await tester.tap(fiveMinItem);
      await tester.pumpAndSettle();

      expect(store.autoLockDuration, '5 minutes');
      expect(store.timeoutDuration, const Duration(minutes: 5));
      expect(find.text('Settings Saved Successfully'), findsOneWidget);
      expect(find.text('Inactivity timeout set to 5 minutes.'), findsOneWidget);
    });
  });
}
