import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/models/calendar_event.dart';
import 'package:ophthalmology_clinical_record_system/models/patient.dart';
import 'package:ophthalmology_clinical_record_system/services/auth_service.dart';
import 'package:ophthalmology_clinical_record_system/services/offline_sync_service.dart';
import 'package:ophthalmology_clinical_record_system/widgets/sync_status_indicator.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Offline-First Architecture & Background Sync Engine Tests', () {
    late OfflineSyncService syncService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      syncService = OfflineSyncService();
      syncService.resetForTesting();
    });

    tearDown(() {
      syncService.stopAutoSyncTimer();
    });

    test('OfflineSyncService initializes online and queues mutations offline', () {
      expect(syncService.isOnline, isTrue);

      syncService.setNetworkState(NetworkConnectivityState.offline);
      expect(syncService.isOffline, isTrue);
      expect(syncService.syncState, equals(SyncStatusState.offlineSaved));

      syncService.enqueueMutation(
        id: 'mut-001',
        entityType: 'Patient',
        action: 'CREATE',
        payload: {'fullName': 'Offline Test Patient'},
      );

      expect(syncService.pendingCount, equals(1));
      expect(syncService.pendingQueue.first.entityType, equals('Patient'));
    });

    test('Background Sync payload executes when network connectivity is restored', () async {
      syncService.setNetworkState(NetworkConnectivityState.offline);
      syncService.enqueueMutation(
        id: 'mut-002',
        entityType: 'CalendarEvent',
        action: 'CREATE',
        payload: {'title': 'Offline Cataract Surgery'},
      );

      expect(syncService.pendingCount, equals(1));

      // Restore network connection -> triggers auto sync
      syncService.setNetworkState(NetworkConnectivityState.online);

      // Wait for sync completed
      await Future.delayed(const Duration(milliseconds: 1400));

      expect(syncService.pendingCount, equals(0));
      expect(syncService.syncState, equals(SyncStatusState.upToDate));
      expect(syncService.lastSyncedAt, isNotNull);
    });

    test('Conflict Resolution System logically merges local and remote records', () {
      final localRecord = {
        'id': 'pat-100',
        'fullName': 'Carlos Mendoza Local Edit',
        'phone': '+63 917 111 2222',
        'lastModified': '2026-09-26T14:30:00.000Z',
      };

      final remoteRecord = {
        'id': 'pat-100',
        'fullName': 'Carlos Mendoza Remote',
        'phone': '+63 917 999 8888',
        'address': 'Davao City Clinic',
        'lastModified': '2026-09-26T12:00:00.000Z',
      };

      final merged = syncService.resolveConflict(
        localRecord: localRecord,
        remoteRecord: remoteRecord,
      );

      expect(merged['id'], equals('pat-100'));
      expect(merged['fullName'], equals('Carlos Mendoza Local Edit'));
      expect(merged['address'], equals('Davao City Clinic'));
      expect(merged['conflictResolved'], isTrue);
    });

    test('Repositories write operations register sync mutations', () {
      final initialQueueLength = syncService.pendingCount;

      final newPatient = Patient(
        id: 'pat-sync-test',
        mrn: 'MRN-SYNC-01',
        fullName: 'Sync Test Patient',
        dateOfBirth: '1985-06-15',
        gender: 'Female',
        phone: '+63 919 000 1111',
        address: 'General Santos City',
        medicalHistory: [],
        allergies: [],
        encounters: [],
        lastVisitDate: '2026-09-26',
        totalVisits: 1,
      );

      PatientRepository.addPatient(newPatient);
      expect(syncService.pendingCount, greaterThan(initialQueueLength));

      final newEvt = CalendarEvent(
        id: 'evt-sync-test',
        title: 'Glaucoma Evaluation',
        eventType: 'IOP Check',
        location: 'Davao',
        dateTime: DateTime.now(),
        patientName: 'Sync Test Patient',
      );

      CalendarEventRepository().addEvent(newEvt);
      expect(syncService.pendingCount, greaterThan(initialQueueLength + 1));
    });

    testWidgets('SyncStatusIndicator renders status badge and opens details dialog', (WidgetTester tester) async {
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

      expect(find.byType(SyncStatusIndicator), findsOneWidget);
      expect(find.text('Synced with Firebase'), findsOneWidget);

      // Tap status indicator to open modal details
      await tester.tap(find.byType(SyncStatusIndicator));
      await tester.pumpAndSettle();

      expect(find.text('Offline-First & Cloud Sync'), findsOneWidget);
      expect(find.text('Local-First Guarantee'), findsOneWidget);
      expect(find.text('Simulate Network Connection'), findsOneWidget);
    });

    test('hasPermissionError flags permission errors and suppresses auto-retries', () {
      final mut = SyncMutation(
        id: 'mut-perm-1',
        entityType: 'Prescription',
        action: 'CREATE',
        payload: {'patientId': 'pat-1'},
        timestamp: DateTime.now(),
      );

      expect(syncService.hasPermissionError, isFalse);

      syncService.failMutationForTesting(
        mut,
        'permission-denied: Missing or insufficient permissions.',
      );

      expect(syncService.hasPermissionError, isTrue);
      expect(syncService.syncState, equals(SyncStatusState.error));
      expect(syncService.failedMutations.length, equals(1));

      // Network toggle should NOT auto-retry permission-denied errors
      syncService.setNetworkState(NetworkConnectivityState.offline);
      syncService.setNetworkState(NetworkConnectivityState.online);

      expect(syncService.failedMutations.length, equals(1));
      expect(syncService.hasPermissionError, isTrue);
    });

    testWidgets('SyncStatusIndicator displays clear guidance when permission-denied error occurs', (WidgetTester tester) async {
      final mut = SyncMutation(
        id: 'mut-perm-2',
        entityType: 'Patient',
        action: 'CREATE',
        payload: {'fullName': 'Jane Doe'},
        timestamp: DateTime.now(),
      );

      syncService.failMutationForTesting(
        mut,
        'permission-denied: Missing or insufficient permissions.',
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

      expect(find.text('Not saved (1)'), findsOneWidget);

      // Open details dialog
      await tester.tap(find.byType(SyncStatusIndicator));
      await tester.pumpAndSettle();

      expect(find.text('1 change(s) were NOT saved to the cloud'), findsOneWidget);
      expect(
        find.textContaining('Permission Denied: Your account does not have write access to this workspace.'),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(AlertDialog), matching: find.text('Retry')),
        findsOneWidget,
      );
      expect(find.text('Discard'), findsOneWidget);
    });

    test('canUserWriteToWorkspace validates Owner, Editor, Physician, and Admin roles case-insensitively', () {
      expect(syncService.canUserWriteToWorkspace(roleOverride: 'Owner'), isTrue);
      expect(syncService.canUserWriteToWorkspace(roleOverride: 'owner'), isTrue);
      expect(syncService.canUserWriteToWorkspace(roleOverride: 'OWNER'), isTrue);
      expect(syncService.canUserWriteToWorkspace(roleOverride: 'Editor'), isTrue);
      expect(syncService.canUserWriteToWorkspace(roleOverride: 'editor'), isTrue);
      expect(syncService.canUserWriteToWorkspace(roleOverride: 'Physician'), isTrue);
      expect(syncService.canUserWriteToWorkspace(roleOverride: 'physician'), isTrue);
      expect(syncService.canUserWriteToWorkspace(roleOverride: 'Doctor'), isTrue);
      expect(syncService.canUserWriteToWorkspace(roleOverride: 'Admin'), isTrue);
      expect(syncService.canUserWriteToWorkspace(roleOverride: 'Leader'), isTrue);

      expect(syncService.canUserWriteToWorkspace(roleOverride: 'Viewer'), isFalse);
      expect(syncService.canUserWriteToWorkspace(roleOverride: 'viewer'), isFalse);
      expect(syncService.canUserWriteToWorkspace(roleOverride: 'Guest'), isFalse);
      expect(syncService.canUserWriteToWorkspace(roleOverride: 'unauthorized'), isFalse);
      expect(syncService.canUserWriteToWorkspace(roleOverride: 'readonly'), isFalse);
    });

    test('canUserWriteToWorkspace evaluates custom claims mapping and workspace-scoped roles', () {
      // Global claims mapping
      expect(
        syncService.canUserWriteToWorkspace(customClaims: {'role': 'Owner'}),
        isTrue,
      );
      expect(
        syncService.canUserWriteToWorkspace(customClaims: {'userRole': 'Editor'}),
        isTrue,
      );
      expect(
        syncService.canUserWriteToWorkspace(customClaims: {'teamRole': 'Physician'}),
        isTrue,
      );
      expect(
        syncService.canUserWriteToWorkspace(customClaims: {'role': 'Viewer'}),
        isFalse,
      );

      // Workspace-scoped claims mapping
      final scopedClaims = {
        'workspaces': {
          'ws-clinic-alpha': {'role': 'Editor'},
          'ws-clinic-beta': {'role': 'Viewer'},
        }
      };
      expect(
        syncService.canUserWriteToWorkspace(
          workspaceId: 'ws-clinic-alpha',
          customClaims: scopedClaims,
        ),
        isTrue,
      );
      expect(
        syncService.canUserWriteToWorkspace(
          workspaceId: 'ws-clinic-beta',
          customClaims: scopedClaims,
        ),
        isFalse,
      );
    });

    test('Security context binds activeWorkspaceId, UID, role, and custom claims', () {
      final sec = syncService.securityContext;
      expect(sec, isNotNull);
      expect(sec.customClaims, isNotNull);
      expect(sec.toString(), contains('SyncSecurityContext'));
    });

    test('Syncing as Owner or Editor pushes queued mutations without permission errors', () async {
      syncService.enqueueMutation(
        id: 'mut-owner-1',
        entityType: 'Patient',
        action: 'CREATE',
        payload: {'fullName': 'Owner Test Patient', 'teamId': 'c-default-team'},
      );

      expect(syncService.pendingCount, equals(1));

      // With default/owner permissions, wait for background sync to complete
      await Future.delayed(const Duration(milliseconds: 500));

      expect(syncService.pendingCount, equals(0));
      expect(syncService.hasPermissionError, isFalse);
      expect(syncService.failedMutations, isEmpty);
      expect(syncService.syncState, equals(SyncStatusState.upToDate));
    });

    test('Unauthorized role (Viewer) is restricted and triggers permission error', () async {
      // Inject restricted viewer claim
      AuthService.instance.setCustomClaims({'role': 'Viewer'});

      syncService.enqueueMutation(
        id: 'mut-viewer-1',
        entityType: 'Patient',
        action: 'CREATE',
        payload: {'fullName': 'Unauthorized Patient Mutation', 'teamId': 'restricted-workspace'},
      );

      await syncService.syncNow();

      expect(syncService.hasPermissionError, isTrue);
      expect(syncService.failedMutations.length, equals(1));
      expect(
        syncService.lastError,
        contains('Your account does not have write access to this workspace'),
      );
      expect(syncService.syncState, equals(SyncStatusState.error));

      // Clean up claim
      AuthService.instance.setCustomClaims({});
    });

    test('Retry as workspace Owner successfully clears mutation queue and syncs without error', () async {
      // 1. Simulate initial permission rejection under restricted role
      AuthService.instance.setCustomClaims({'role': 'Viewer'});
      syncService.enqueueMutation(
        id: 'mut-retry-1',
        entityType: 'Patient',
        action: 'CREATE',
        payload: {'fullName': 'Pending Retry Patient', 'teamId': 'c-default-team'},
      );
      await syncService.syncNow();

      expect(syncService.hasPermissionError, isTrue);
      expect(syncService.failedMutations.length, equals(1));

      // 2. Elevate user role credentials to Owner via custom claims
      AuthService.instance.setCustomClaims({'role': 'Owner'});

      // 3. User clicks "Retry"
      await syncService.retryFailed();

      // 4. Mutation queue is cleared and synced cleanly
      expect(syncService.hasPermissionError, isFalse);
      expect(syncService.failedMutations, isEmpty);
      expect(syncService.pendingCount, equals(0));
      expect(syncService.syncState, equals(SyncStatusState.upToDate));

      // Clean up claim
      AuthService.instance.setCustomClaims({});
    });
  });
}
