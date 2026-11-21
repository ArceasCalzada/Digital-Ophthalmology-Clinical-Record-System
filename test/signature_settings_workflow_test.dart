import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/models/patient.dart';
import 'package:ophthalmology_clinical_record_system/models/prescription.dart';
import 'package:ophthalmology_clinical_record_system/services/offline_sync_service.dart';
import 'package:ophthalmology_clinical_record_system/services/prescription_pdf_service.dart';
import 'package:ophthalmology_clinical_record_system/services/profile_store.dart';
import 'package:ophthalmology_clinical_record_system/services/signature_service.dart';
import 'package:ophthalmology_clinical_record_system/theme/app_theme.dart';
import 'package:ophthalmology_clinical_record_system/views/settings_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ProfileStore.instance.clearSignatureForTesting();
    SignatureService.filePickerOverride = null;
    OfflineSyncService().stopAutoSyncTimer();
  });

  tearDown(() {
    ProfileStore.instance.clearSignatureForTesting();
    SignatureService.filePickerOverride = null;
  });

  group('SignatureService Unit Tests', () {
    test('validateSignatureFile accepts transparent PNG up to 1 MB', () {
      final validPng = SignatureService.createDummyPngBytes();
      final result = SignatureService.validateSignatureFile(
        fileName: 'doctor_signature.png',
        bytes: validPng,
      );

      expect(result.isValid, isTrue);
      expect(result.errorMessage, isNull);
      expect(result.bytes, equals(validPng));
    });

    test('validateSignatureFile rejects non-PNG extensions', () {
      final validPng = SignatureService.createDummyPngBytes();

      final jpgResult = SignatureService.validateSignatureFile(
        fileName: 'doctor_signature.jpg',
        bytes: validPng,
      );
      expect(jpgResult.isValid, isFalse);
      expect(jpgResult.errorMessage, contains('Only transparent PNG images'));

      final pdfResult = SignatureService.validateSignatureFile(
        fileName: 'doctor_signature.pdf',
        bytes: validPng,
      );
      expect(pdfResult.isValid, isFalse);
      expect(pdfResult.errorMessage, contains('Only transparent PNG images'));
    });

    test('validateSignatureFile rejects files with invalid PNG magic bytes', () {
      final fakePngBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      final result = SignatureService.validateSignatureFile(
        fileName: 'fake_signature.png',
        bytes: fakePngBytes,
      );

      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('not a valid PNG image'));
    });

    test('validateSignatureFile rejects files larger than 1 MB', () {
      final validPng = SignatureService.createDummyPngBytes();
      final oversize = 1024 * 1024 + 100; // 1 MB + 100 bytes

      final result = SignatureService.validateSignatureFile(
        fileName: 'heavy_signature.png',
        bytes: validPng,
        size: oversize,
      );

      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('File size exceeds 1 MB limit'));
    });
  });

  group('ProfileStore & Offline Persistence Tests', () {
    test('Signature base64 saves to preferences and sync queue', () async {
      final store = ProfileStore.instance;
      final dummyPng = SignatureService.createDummyPngBytes();
      final base64String = base64Encode(dummyPng);

      store.setSignatureBase64(base64String);
      expect(store.hasSignature, isTrue);
      expect(store.signatureBytes, equals(dummyPng));

      await store.saveToFirestore();

      // Verify in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('profile_store_settings');
      expect(raw, isNotNull);
      final decoded = jsonDecode(raw!) as Map<String, dynamic>;
      expect(decoded['signatureBase64'], equals(base64String));

      // Verify mutation in OfflineSyncService queue
      final pending = OfflineSyncService().pendingQueue;
      expect(pending.any((m) => m.entityType == 'PrescriptionSettings'), isTrue);

      // Verify removeSignature clears locally and enqueues update
      store.removeSignature();
      expect(store.hasSignature, isFalse);
      expect(store.signatureBytes, isNull);

      await store.saveToFirestore();
      final rawAfterRemove = prefs.getString('profile_store_settings');
      final decodedAfterRemove = jsonDecode(rawAfterRemove!) as Map<String, dynamic>;
      expect(decodedAfterRemove['signatureBase64'], isNull);
    });
  });

  group('Prescription PDF Export Integration Tests', () {
    test('generatePrescriptionPdf embeds signature when present', () async {
      final dummyPng = SignatureService.createDummyPngBytes();
      ProfileStore.instance.setSignatureBase64(base64Encode(dummyPng));

      final patient = Patient(
        id: 'p-sig-test',
        mrn: 'MRN-SIG-1',
        fullName: 'Test Patient',
        dateOfBirth: '1990-01-01',
        gender: 'Male',
        phone: '09123456789',
        address: 'Davao City',
        medicalHistory: const [],
        allergies: const [],
        encounters: const [],
        lastVisitDate: '2026-11-01',
        totalVisits: 1,
        prescriptions: const [],
      );

      final pdfBytes = await PrescriptionPdfService.generatePrescriptionPdf(
        patient: patient,
        items: [
          PrescriptionItem(
            id: 'item-1',
            medicationName: 'Moxifloxacin',
            strength: '0.5%',
            dosage: '1 drop',
            frequency: 'QID',
            duration: '7 days',
            instructions: 'Instill 1 drop in OD',
          ),
        ],
        date: '2026-11-21',
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(1000));
    });
  });

  group('SettingsView Signature Upload & Removal UI Tests', () {
    testWidgets('Uploads PNG signature, updates preview, and displays success modal', (tester) async {
      final validPng = SignatureService.createDummyPngBytes();
      SignatureService.filePickerOverride = () async {
        return PickedSignatureFile(
          name: 'doctor_dr_robillos_sig.png',
          bytes: validPng,
        );
      };

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: SettingsView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure Signature preview box is displayed
      expect(find.byKey(const Key('signature_preview_box')), findsOneWidget);
      expect(find.text('No Signature Uploaded'), findsOneWidget);

      // Tap Upload Signature Image
      final uploadBtn = find.byKey(const Key('btn_upload_signature'));
      expect(uploadBtn, findsOneWidget);
      await tester.ensureVisible(uploadBtn);
      await tester.tap(uploadBtn);
      await tester.pumpAndSettle();

      // Verify that Settings Saved Successfully modal appears
      expect(find.text('Settings Saved Successfully'), findsOneWidget);
      expect(find.text('Doctor signature uploaded and saved successfully.'), findsOneWidget);

      // Dismiss modal by clicking Close/Got It
      final okBtn = find.text('Got It');
      if (okBtn.evaluate().isNotEmpty) {
        await tester.tap(okBtn);
        await tester.pumpAndSettle();
      }

      // Verify signature image preview is now displayed
      expect(find.byKey(const Key('signature_image_preview')), findsOneWidget);
      expect(find.byKey(const Key('btn_remove_signature')), findsOneWidget);

      // Verify ProfileStore has signature persisted
      expect(ProfileStore.instance.hasSignature, isTrue);
    });

    testWidgets('Rejects non-PNG file with clear error feedback and no success modal', (tester) async {
      SignatureService.filePickerOverride = () async {
        return PickedSignatureFile(
          name: 'signature.jpg',
          bytes: Uint8List.fromList([1, 2, 3, 4]),
        );
      };

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: SettingsView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final uploadBtn = find.byKey(const Key('btn_upload_signature'));
      await tester.ensureVisible(uploadBtn);
      await tester.tap(uploadBtn);
      await tester.pumpAndSettle();

      // Must NOT display Settings Saved Successfully modal
      expect(find.text('Settings Saved Successfully'), findsNothing);

      // Must display clear validation error
      expect(find.byKey(const Key('signature_error_text')), findsOneWidget);
      expect(find.textContaining('Only transparent PNG images'), findsWidgets);

      // Preview remains empty
      expect(find.text('No Signature Uploaded'), findsOneWidget);
      expect(ProfileStore.instance.hasSignature, isFalse);
    });

    testWidgets('Rejects file > 1 MB with clear error feedback', (tester) async {
      final validPng = SignatureService.createDummyPngBytes();
      SignatureService.filePickerOverride = () async {
        return PickedSignatureFile(
          name: 'oversized_sig.png',
          bytes: validPng,
          size: 2 * 1024 * 1024, // 2 MB
        );
      };

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: SettingsView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final uploadBtn = find.byKey(const Key('btn_upload_signature'));
      await tester.ensureVisible(uploadBtn);
      await tester.tap(uploadBtn);
      await tester.pumpAndSettle();

      // Must NOT display Settings Saved Successfully modal
      expect(find.text('Settings Saved Successfully'), findsNothing);

      // Must display clear validation error
      expect(find.byKey(const Key('signature_error_text')), findsOneWidget);
      expect(find.textContaining('File size exceeds 1 MB limit'), findsWidgets);

      // Preview remains empty
      expect(find.text('No Signature Uploaded'), findsOneWidget);
      expect(ProfileStore.instance.hasSignature, isFalse);
    });

    testWidgets('Remove Signature clears preview, removes from store, and shows success modal', (tester) async {
      final validPng = SignatureService.createDummyPngBytes();
      ProfileStore.instance.setSignatureBase64(base64Encode(validPng));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: SettingsView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial state has signature
      expect(find.byKey(const Key('signature_image_preview')), findsOneWidget);
      final removeBtn = find.byKey(const Key('btn_remove_signature'));
      expect(removeBtn, findsOneWidget);

      // Tap Remove Signature
      await tester.ensureVisible(removeBtn);
      await tester.tap(removeBtn);
      await tester.pumpAndSettle();

      // Success modal should appear
      expect(find.text('Settings Saved Successfully'), findsOneWidget);
      expect(find.text('Doctor signature removed successfully.'), findsOneWidget);

      // Dismiss modal
      final okBtn = find.text('Got It');
      if (okBtn.evaluate().isNotEmpty) {
        await tester.tap(okBtn);
        await tester.pumpAndSettle();
      }

      // Preview resets to empty
      expect(find.text('No Signature Uploaded'), findsOneWidget);
      expect(find.byKey(const Key('btn_remove_signature')), findsNothing);
      expect(ProfileStore.instance.hasSignature, isFalse);
    });
  });
}
