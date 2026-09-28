import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/models/calendar_event.dart';
import 'package:ophthalmology_clinical_record_system/models/patient.dart';
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
      expect(find.text('Up to date'), findsOneWidget);

      // Tap status indicator to open modal details
      await tester.tap(find.byType(SyncStatusIndicator));
      await tester.pumpAndSettle();

      expect(find.text('Offline-First & Cloud Sync'), findsOneWidget);
      expect(find.text('Local-First Guarantee'), findsOneWidget);
      expect(find.text('Simulate Network Connection'), findsOneWidget);
    });
  });
}
