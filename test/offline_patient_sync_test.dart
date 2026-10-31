import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ophthalmology_clinical_record_system/models/patient.dart';
import 'package:ophthalmology_clinical_record_system/services/offline_sync_service.dart';
import 'package:ophthalmology_clinical_record_system/theme/app_theme.dart';
import 'package:ophthalmology_clinical_record_system/views/main_layout.dart';
import 'package:ophthalmology_clinical_record_system/views/patients_screen.dart';
import 'package:ophthalmology_clinical_record_system/widgets/sync_status_indicator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Offline Patient Registration & Synchronization Tests', () {
    late OfflineSyncService syncService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      syncService = OfflineSyncService();
      syncService.resetForTesting();
      PatientRepository.disconnect();
      await PatientRepository.init();
    });

    tearDown(() {
      syncService.stopAutoSyncTimer();
      PatientRepository.disconnect();
    });

    test('Registering patient offline caches locally and retains record in directory', () {
      syncService.setNetworkState(NetworkConnectivityState.offline);
      expect(syncService.isOffline, isTrue);

      final patient = Patient(
        id: 'pat-offline-001',
        mrn: 'MRN-OFFLINE-01',
        fullName: 'Juan Dela Cruz Offline',
        dateOfBirth: '1990-01-01',
        gender: 'Male',
        phone: '+63 917 123 4567',
        address: 'Manila, Philippines',
        medicalHistory: ['Asthma'],
        allergies: ['None'],
        encounters: [],
        lastVisitDate: '2026-10-16',
        totalVisits: 1,
      );

      PatientRepository.addPatient(patient);

      // Verify patient is saved locally in memory cache
      expect(PatientRepository.getAllPatients().any((p) => p.id == 'pat-offline-001'), isTrue);
      expect(PatientRepository.getPatientById('pat-offline-001')!.fullName, equals('Juan Dela Cruz Offline'));

      // Verify queued in offline sync queue
      expect(syncService.pendingCount, equals(1));
      expect(syncService.pendingQueue.first.id, equals('pat-offline-001'));
      expect(syncService.syncState, equals(SyncStatusState.offlineSaved));
    });

    testWidgets('SyncStatusIndicator shows "Not saved" status with Retry button when pending/failed', (WidgetTester tester) async {
      syncService.setNetworkState(NetworkConnectivityState.offline);

      syncService.enqueueMutation(
        id: 'pat-offline-002',
        entityType: 'Patient',
        action: 'CREATE',
        payload: {'fullName': 'Maria Santos'},
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SyncStatusIndicator(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check that "Offline - Changes saved locally" is rendered accurately
      expect(find.text('Offline - Changes saved locally'), findsOneWidget);

      // Check that the manual retry button is present next to the indicator
      final retryButton = find.byKey(const ValueKey('sync-indicator-retry-button'));
      expect(retryButton, findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Setting online and tapping retry executes force-sync
      syncService.setNetworkState(NetworkConnectivityState.online);
      await tester.tap(retryButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // In local/test mode without Firebase, sync clears the queue
      expect(syncService.pendingCount, equals(0));
      expect(find.text('Synced with Firebase'), findsOneWidget);
    });

    testWidgets('PatientsScreen updates dynamically when an offline patient is added without reload', (WidgetTester tester) async {
      syncService.setNetworkState(NetworkConnectivityState.offline);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: PatientsScreen(
              onSelectPatient: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Juan Dela Cruz Instant'), findsNothing);

      // Add a patient while screen is active
      final patient = Patient(
        id: 'pat-dynamic-001',
        mrn: 'MRN-DYN-01',
        fullName: 'Juan Dela Cruz Instant',
        dateOfBirth: '1992-05-20',
        gender: 'Male',
        phone: '+63 920 999 8888',
        address: 'Quezon City',
        medicalHistory: [],
        allergies: [],
        encounters: [],
        lastVisitDate: '2026-10-16',
        totalVisits: 1,
      );

      PatientRepository.addPatient(patient);
      await tester.pumpAndSettle();

      // Should instantly appear on screen without page refresh
      expect(find.text('Juan Dela Cruz Instant'), findsOneWidget);
    });

    testWidgets('MainLayout blocks logout and warns when unsaved patient records are pending', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool loggedOut = false;

      // Set offline mode so queued mutation stays pending
      syncService.setNetworkState(NetworkConnectivityState.offline);

      // Queue an unsynced record
      syncService.enqueueMutation(
        id: 'pat-unsaved-001',
        entityType: 'Patient',
        action: 'CREATE',
        payload: {'fullName': 'Unsaved Patient'},
      );
      expect(syncService.pendingCount, equals(1));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MainLayout(
            onLogout: () {
              loggedOut = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open the account menu trigger
      final accountTrigger = find.byKey(const ValueKey('account-menu-trigger'));
      expect(accountTrigger, findsOneWidget);
      await tester.tap(accountTrigger);
      await tester.pumpAndSettle();

      // Tap Log out
      final logoutItem = find.text('Log out');
      expect(logoutItem, findsOneWidget);
      await tester.tap(logoutItem);
      await tester.pumpAndSettle();

      // Verify the warning modal appears
      expect(find.text('Unsaved Records Pending Sync'), findsOneWidget);
      expect(find.textContaining('You have 1 patient record or mutation(s) pending synchronization'), findsOneWidget);
      expect(loggedOut, isFalse);

      // Tap 'Stay on Page' -> cancels logout
      await tester.tap(find.text('Stay on Page'));
      await tester.pumpAndSettle();
      expect(loggedOut, isFalse);

      // Open account menu again and confirm exit
      await tester.tap(accountTrigger);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();

      // Tap 'Leave Anyway' -> allows logout
      await tester.tap(find.text('Leave Anyway'));
      await tester.pumpAndSettle();
      expect(loggedOut, isTrue);
    });

    test('Offline patient registration automatically syncs when network is reconnected and updates local cache', () async {
      syncService.setNetworkState(NetworkConnectivityState.offline);
      expect(syncService.isOffline, isTrue);

      final patient = Patient(
        id: 'pat-reconnect-001',
        mrn: 'MRN-REC-01',
        fullName: 'Rosa Flordeliz',
        dateOfBirth: '1985-03-15',
        gender: 'Female',
        phone: '+63 918 333 4444',
        address: 'Cebu City, Philippines',
        medicalHistory: ['Hypertension'],
        allergies: [],
        encounters: [],
        lastVisitDate: '2026-10-16',
        totalVisits: 1,
      );

      PatientRepository.addPatient(patient);

      // Verify queued in offline queue
      expect(syncService.pendingCount, equals(1));
      expect(syncService.pendingQueue.first.id, equals('pat-reconnect-001'));
      expect(PatientRepository.getPatientById('pat-reconnect-001'), isNotNull);

      // Reconnect network
      syncService.setNetworkState(NetworkConnectivityState.online);
      expect(syncService.isOffline, isFalse);

      // In local/test mode, auto-triggered syncNow flushes in-memory queue
      await Future.delayed(const Duration(milliseconds: 500));

      expect(syncService.pendingCount, equals(0));
      expect(syncService.syncState, equals(SyncStatusState.upToDate));
      expect(PatientRepository.getPatientById('pat-reconnect-001')!.fullName, equals('Rosa Flordeliz'));
    });
  });
}
