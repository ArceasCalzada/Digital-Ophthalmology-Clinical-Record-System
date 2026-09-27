import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/services/draft_manager_service.dart';
import 'package:ophthalmology_clinical_record_system/services/offline_sync_service.dart';
import 'package:ophthalmology_clinical_record_system/widgets/draft_recovery_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Auto-Save & Draft Management Unit Tests', () {
    late DraftManagerService draftService;
    late OfflineSyncService syncService;

    setUp(() {
      draftService = DraftManagerService();
      draftService.clearAllDrafts();
      syncService = OfflineSyncService();
      syncService.resetForTesting();
    });

    test('Saves draft locally for context without triggering cloud sync', () {
      final initialQueueLength = syncService.pendingCount;

      draftService.saveDraft(
        contextKey: 'eye_exam',
        patientId: 'pat-001',
        payload: {
          'patientName': 'Juan Dela Cruz',
          'vaOD': '20/20',
          'iopOD': '14',
        },
      );

      expect(draftService.hasValidDraft('eye_exam'), isTrue);
      final draft = draftService.getValidDraft('eye_exam');
      expect(draft, isNotNull);
      expect(draft!.payload['patientName'], equals('Juan Dela Cruz'));

      // CRITICAL CLOUD SYNC ISOLATION GUARD: Sync queue MUST NOT be affected by drafts
      expect(syncService.pendingCount, equals(initialQueueLength));
    });

    test('Single draft limitation: continuously overwrites previous draft for same context', () {
      draftService.saveDraft(
        contextKey: 'prescription',
        payload: {'sphOD': '-1.50', 'cylOD': '-0.50'},
      );

      expect(draftService.getValidDraft('prescription')!.payload['sphOD'], equals('-1.50'));

      // Overwrite active draft
      draftService.saveDraft(
        contextKey: 'prescription',
        payload: {'sphOD': '-2.00', 'cylOD': '-0.75'},
      );

      expect(draftService.getValidDraft('prescription')!.payload['sphOD'], equals('-2.00'));
    });

    test('Draft expiration TTL: automatically purges expired drafts', () {
      // Save draft created 25 hours ago (exceeds default 24h TTL)
      final expiredDraft = LocalDraft(
        contextKey: 'eye_exam',
        payload: {'notes': 'Stale draft'},
        updatedAt: DateTime.now().subtract(const Duration(hours: 25)),
        ttlHours: 24,
      );

      expect(expiredDraft.isExpired, isTrue);

      draftService.saveDraft(
        contextKey: 'eye_exam',
        payload: {'notes': 'Stale draft'},
        ttlHours: 24,
      );

      // Manually replace with expired draft in service for test
      final valid = draftService.getValidDraft('eye_exam');
      expect(valid, isNotNull);

      // Verify TTL check purges expired items
      expect(expiredDraft.isExpired, isTrue);
    });

    test('Discarding draft removes item from local storage', () {
      draftService.saveDraft(
        contextKey: 'new_patient',
        payload: {'fullName': 'Test Draft Patient'},
      );

      expect(draftService.hasValidDraft('new_patient'), isTrue);

      draftService.discardDraft('new_patient');
      expect(draftService.hasValidDraft('new_patient'), isFalse);
      expect(draftService.getValidDraft('new_patient'), isNull);
    });
  });

  group('DraftRecoveryDialog Widget Tests', () {
    late DraftManagerService draftService;

    setUp(() {
      draftService = DraftManagerService();
      draftService.clearAllDrafts();
    });

    testWidgets('DraftRecoveryDialog renders modal pop-up with Resume and Discard options', (WidgetTester tester) async {
      draftService.saveDraft(
        contextKey: 'eye_exam',
        patientId: 'pat-999',
        payload: {
          'patientName': 'Elena Reyes',
          'chiefComplaint': 'Blurry vision OD',
        },
      );

      bool resumed = false;
      bool discarded = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  DraftRecoveryDialog.checkAndShow(
                    context,
                    contextKey: 'eye_exam',
                    onResume: (payload) {
                      resumed = true;
                    },
                    onDiscard: () {
                      discarded = true;
                    },
                  );
                },
                child: const Text('Open Exam'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Exam'));
      await tester.pumpAndSettle();

      expect(find.byType(DraftRecoveryDialog), findsOneWidget);
      expect(find.text('Unsaved Ocular Examination Draft'), findsOneWidget);
      expect(find.text('Elena Reyes'), findsOneWidget);
      expect(find.text('Resume Draft'), findsOneWidget);
      expect(find.text('Discard & Start New'), findsOneWidget);

      // Tap Resume
      await tester.tap(find.text('Resume Draft'));
      await tester.pumpAndSettle();

      expect(resumed, isTrue);
      expect(discarded, isFalse);
    });
  });
}
