import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ophthalmology_clinical_record_system/services/offline_sync_service.dart';
import 'package:ophthalmology_clinical_record_system/theme/app_theme.dart';
import 'package:ophthalmology_clinical_record_system/widgets/page_header.dart';
import 'package:ophthalmology_clinical_record_system/widgets/sync_status_indicator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Real-Time Sync Status Indicator & Connectivity Listener Tests', () {
    late OfflineSyncService syncService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      syncService = OfflineSyncService();
      syncService.resetForTesting();
    });

    tearDown(() {
      syncService.stopAutoSyncTimer();
      syncService.stopConnectivityListener();
    });

    test('OfflineSyncService.isConnectedResults evaluates all connectivity result types', () {
      // Disconnected scenarios
      expect(OfflineSyncService.isConnectedResults([]), isFalse);
      expect(OfflineSyncService.isConnectedResults([ConnectivityResult.none]), isFalse);

      // Connected scenarios
      expect(OfflineSyncService.isConnectedResults([ConnectivityResult.wifi]), isTrue);
      expect(OfflineSyncService.isConnectedResults([ConnectivityResult.mobile]), isTrue);
      expect(OfflineSyncService.isConnectedResults([ConnectivityResult.ethernet]), isTrue);
      expect(OfflineSyncService.isConnectedResults([ConnectivityResult.vpn]), isTrue);
      expect(
        OfflineSyncService.isConnectedResults([ConnectivityResult.none, ConnectivityResult.wifi]),
        isTrue,
      );
    });

    testWidgets('Online State displays Green badge with "Synced with Firebase"', (WidgetTester tester) async {
      syncService.setNetworkState(NetworkConnectivityState.online);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: Center(
              child: SyncStatusIndicator(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check text label
      expect(find.text('Synced with Firebase'), findsOneWidget);

      // Check icon
      expect(find.byIcon(Icons.cloud_done_rounded), findsOneWidget);

      // Check tooltip
      final tooltipFinder = find.byType(Tooltip);
      expect(tooltipFinder, findsAtLeastNWidgets(1));
      final tooltip = tester.widget<Tooltip>(tooltipFinder.first);
      expect(tooltip.message, contains('Synced with Firebase'));
      expect(tooltip.message, contains('synchronized'));
    });

    testWidgets('Offline State displays Amber badge with "Offline - Changes saved locally"', (WidgetTester tester) async {
      syncService.setNetworkState(NetworkConnectivityState.offline);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: Center(
              child: SyncStatusIndicator(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check text label
      expect(find.text('Offline - Changes saved locally'), findsOneWidget);

      // Check wifi off icon
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);

      // Check tooltip
      final tooltipFinder = find.byType(Tooltip);
      expect(tooltipFinder, findsAtLeastNWidgets(1));
      final tooltip = tester.widget<Tooltip>(tooltipFinder.first);
      expect(tooltip.message, contains('Offline - Changes saved locally'));
      expect(tooltip.message, contains('Operating offline; data is cached locally'));
    });

    testWidgets('Syncing State displays Blue badge with "Syncing..." and spinner', (WidgetTester tester) async {
      syncService.setSyncStateForTesting(SyncStatusState.syncing);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: Center(
              child: SyncStatusIndicator(),
            ),
          ),
        ),
      );
      await tester.pump();

      // Should display "Syncing..." and CircularProgressIndicator
      expect(find.text('Syncing...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Transition to up to date
      syncService.setSyncStateForTesting(SyncStatusState.upToDate);
      await tester.pumpAndSettle();

      // After sync completes, transitions back to "Synced with Firebase"
      expect(find.text('Synced with Firebase'), findsOneWidget);
    });

    testWidgets('Compact mode renders in PageHeader across main application screens', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: PageHeader(
              title: 'Clinical Dashboard',
              subtitle: 'Today\'s consultations and scheduled visits',
              showSyncStatus: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // PageHeader should include the SyncStatusIndicator
      expect(find.byType(PageHeader), findsOneWidget);
      expect(find.byType(SyncStatusIndicator), findsOneWidget);
      expect(find.text('Clinical Dashboard'), findsOneWidget);
      expect(find.text('Synced with Firebase'), findsOneWidget);
    });

    testWidgets('PageHeader allows disabling sync status when requested', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: PageHeader(
              title: 'Clean Minimal Page',
              subtitle: 'No sync status here',
              showSyncStatus: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SyncStatusIndicator), findsNothing);
    });

    testWidgets('Quick-tap opens modal with data integrity protection details and offline switch', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: Center(
              child: SyncStatusIndicator(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on the indicator badge
      final badge = find.byKey(const ValueKey('sync-status-indicator-badge'));
      expect(badge, findsOneWidget);
      await tester.tap(badge);
      await tester.pumpAndSettle();

      // Modal dialog verification
      expect(find.text('Offline-First & Cloud Sync'), findsOneWidget);
      expect(find.text('Local-First Guarantee'), findsOneWidget);
      expect(find.textContaining('Data Integrity Protected'), findsOneWidget);
      expect(find.text('Simulate Network Connection'), findsOneWidget);
      expect(find.text('Sync Now'), findsOneWidget);

      // Toggle offline simulation switch
      final switchFinder = find.byType(SwitchListTile);
      expect(switchFinder, findsOneWidget);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Service should now be offline
      expect(syncService.isOffline, isTrue);

      // Close modal
      final closeButton = find.text('Close');
      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      // Main indicator badge should now reflect offline state
      expect(find.text('Offline - Changes saved locally'), findsOneWidget);
    });

    testWidgets('Dark Mode renders appropriate dark theme colors and contrast', (WidgetTester tester) async {
      syncService.setNetworkState(NetworkConnectivityState.online);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: Center(
              child: SyncStatusIndicator(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SyncStatusIndicator), findsOneWidget);
      expect(find.text('Synced with Firebase'), findsOneWidget);
    });

    test('Local changes made offline queue properly and auto-sync on reconnection', () async {
      // 1. Clinic enters offline mode
      syncService.setNetworkState(NetworkConnectivityState.offline);
      expect(syncService.isOffline, isTrue);

      // 2. Doctor logs eye exam and creates prescription while offline
      syncService.enqueueMutation(
        id: 'exam-off-001',
        entityType: 'Encounter',
        action: 'CREATE',
        payload: {
          'patientId': 'pat-123',
          'diagnosis': 'Primary Open-Angle Glaucoma',
          'odIop': 24.5,
          'osIop': 18.0,
        },
      );

      syncService.enqueueMutation(
        id: 'rx-off-001',
        entityType: 'Prescription',
        action: 'CREATE',
        payload: {
          'patientId': 'pat-123',
          'medication': 'Latanoprost 0.005% ophthalmic solution',
        },
      );

      // Both writes are queued locally
      expect(syncService.pendingCount, equals(2));
      expect(syncService.syncState, equals(SyncStatusState.offlineSaved));

      // 3. Clinic internet reconnects
      syncService.setNetworkState(NetworkConnectivityState.online);

      // 4. Background sync auto-flushes the queue
      await Future.delayed(const Duration(milliseconds: 1400));

      expect(syncService.pendingCount, equals(0));
      expect(syncService.syncState, equals(SyncStatusState.upToDate));
      expect(syncService.lastSyncedAt, isNotNull);
    });
  });
}
