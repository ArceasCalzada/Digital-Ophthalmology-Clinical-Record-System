import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/models/patient.dart';
import 'package:ophthalmology_clinical_record_system/models/prescription.dart';
import 'package:ophthalmology_clinical_record_system/services/prescription_pdf_service.dart';
import 'package:ophthalmology_clinical_record_system/theme/app_theme.dart';
import 'package:ophthalmology_clinical_record_system/views/prescription_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testPatient = Patient(
    id: 'p-101',
    mrn: 'MRN-101',
    fullName: 'Juan dela Cruz',
    dateOfBirth: '1985-05-12',
    gender: 'Male',
    phone: '+63 917 123 4567',
    address: 'Davao City, Philippines',
    medicalHistory: const [],
    allergies: const [],
    encounters: const [],
    lastVisitDate: '2026-10-01',
    totalVisits: 2,
  );

  final testItems = [
    PrescriptionItem(
      id: 'item-1',
      medicationName: 'Latanoprost 0.005% Ophthalmic Solution',
      strength: '0.005%',
      dosage: '1 drop',
      frequency: 'Once daily at bedtime',
      duration: '30 days',
      instructions: 'Instill 1 drop in both eyes (OU) at night.',
    ),
    PrescriptionItem(
      id: 'item-2',
      medicationName: 'Prednisolone Acetate 1%',
      strength: '1%',
      dosage: '1 drop',
      frequency: 'QID',
      duration: '7 days',
      instructions: 'Instill 1 drop 4 times daily.',
    ),
  ];

  group('PrescriptionPdfService PDF Generation Tests', () {
    test('generatePrescriptionPdf creates non-empty PDF document bytes', () async {
      final pdfBytes = await PrescriptionPdfService.generatePrescriptionPdf(
        patient: testPatient,
        items: testItems,
        date: '2026-10-06',
        doctorName: 'Dr. Sigrid T. Robillos',
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.isNotEmpty, isTrue);
      // PDF documents start with %PDF header magic bytes
      final pdfHeader = String.fromCharCodes(pdfBytes.take(4));
      expect(pdfHeader, '%PDF');
    });

    test('generatePrescriptionPdf works cleanly even with null patient', () async {
      final pdfBytes = await PrescriptionPdfService.generatePrescriptionPdf(
        patient: null,
        items: testItems,
        date: '2026-10-06',
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.isNotEmpty, isTrue);
      final pdfHeader = String.fromCharCodes(pdfBytes.take(4));
      expect(pdfHeader, '%PDF');
    });
  });

  group('Prescription Document Modal Integration Tests', () {
    testWidgets('PrescriptionView modal renders functional Download PDF and Print Prescription buttons', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: PrescriptionView(initialPatient: testPatient),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Prescriptions Workspace'), findsOneWidget);
      expect(find.text('Generate Printable PDF'), findsOneWidget);

      // Tap Generate Printable PDF to save prescription and open preview modal
      await tester.tap(find.text('Generate Printable PDF'));
      await tester.pumpAndSettle();

      // Dismiss the initial Save Success modal to reveal the document preview modal
      if (find.text('Close').evaluate().isNotEmpty) {
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
      }

      expect(find.text('Official Prescription Document Preview'), findsOneWidget);
      expect(find.text('Download PDF'), findsOneWidget);
      expect(find.text('Print Prescription'), findsOneWidget);

      // Verify prescription details inside modal
      expect(find.text('Rx'), findsWidgets);
      expect(find.text('Dr. Sigrid T. Robillos'), findsWidgets);
    });
  });
}
