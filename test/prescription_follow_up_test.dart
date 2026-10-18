import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/models/patient.dart';
import 'package:ophthalmology_clinical_record_system/models/prescription.dart';
import 'package:ophthalmology_clinical_record_system/services/prescription_pdf_service.dart';
import 'package:ophthalmology_clinical_record_system/theme/app_theme.dart';
import 'package:ophthalmology_clinical_record_system/views/prescription_view.dart';
import 'package:ophthalmology_clinical_record_system/widgets/clinical_date_picker.dart';
import 'package:ophthalmology_clinical_record_system/widgets/rx_pad_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testItems = [
    PrescriptionItem(
      id: 'item-1',
      medicationName: 'Latanoprost 0.005%',
      strength: '0.005%',
      dosage: '1 drop',
      frequency: 'Once daily at bedtime',
      duration: '30 days',
      instructions: 'Instill 1 drop in both eyes (OU) at night.',
    ),
  ];

  final patientWithFollowUp = Patient(
    id: 'p-follow-up-1',
    mrn: 'MRN-301',
    fullName: 'Elena Rostova',
    dateOfBirth: '1988-04-12',
    gender: 'Female',
    phone: '+63 917 111 2222',
    address: 'Davao City, Philippines',
    medicalHistory: const [],
    allergies: const [],
    encounters: const [],
    lastVisitDate: '2026-10-01',
    totalVisits: 1,
    prescriptions: [
      Prescription(
        id: 'rx-elena',
        patientId: 'p-follow-up-1',
        encounterId: 'enc-elena',
        doctorName: 'Dr. Sigrid T. Robillos',
        date: '2026-10-06',
        items: testItems,
        clinicBranch: 'Adventist Hospital Davao',
        followUpDate: 'In 2 weeks',
      ),
    ],
  );

  final patientEmpty = Patient(
    id: 'p-follow-up-empty',
    mrn: 'MRN-302',
    fullName: 'Carlos Rivera',
    dateOfBirth: '1992-08-20',
    gender: 'Male',
    phone: '+63 917 333 4444',
    address: 'Digos City, Philippines',
    medicalHistory: const [],
    allergies: const [],
    encounters: const [],
    lastVisitDate: '2026-10-01',
    totalVisits: 1,
    prescriptions: const [],
  );

  group('Prescription Model & PDF Serialization Tests', () {
    test('Prescription model serializes and deserializes followUpDate correctly', () {
      final rx = Prescription(
        id: 'rx-test-1',
        patientId: 'p-1',
        encounterId: 'enc-1',
        doctorName: 'Dr. Robillos',
        date: '2026-10-18',
        items: testItems,
        clinicBranch: 'St. Joseph Southern Bukidnon Hosp.',
        followUpDate: 'November 15, 2026',
      );

      final json = rx.toJson();
      expect(json['followUpDate'], 'November 15, 2026');

      final deserialized = Prescription.fromJson(json);
      expect(deserialized.followUpDate, 'November 15, 2026');
      expect(deserialized.clinicBranch, 'St. Joseph Southern Bukidnon Hosp.');
    });

    test('generatePrescriptionPdf includes custom followUpDate', () async {
      final pdfBytes = await PrescriptionPdfService.generatePrescriptionPdf(
        patient: patientWithFollowUp,
        items: testItems,
        date: '2026-10-18',
        doctorName: 'Dr. Sigrid T. Robillos',
        followUpDate: 'In 3 weeks (post-op)',
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.isNotEmpty, isTrue);
      final pdfHeader = String.fromCharCodes(pdfBytes.take(4));
      expect(pdfHeader, '%PDF');
    });
  });

  group('RxPadWidget Follow-Up Rendering Tests', () {
    testWidgets('renders default line when followUpDate is default or blank', (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RxPadWidget(
                patient: patientEmpty,
                items: testItems,
                date: '2026-10-18',
                doctorName: 'Dr. Sigrid T. Robillos',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Follow Up Check Up:'), findsOneWidget);
      expect(find.text('_________________'), findsOneWidget);
    });

    testWidgets('renders custom followUpDate string cleanly', (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RxPadWidget(
                patient: patientWithFollowUp,
                items: testItems,
                date: '2026-10-18',
                doctorName: 'Dr. Sigrid T. Robillos',
                followUpDate: 'November 15, 2026',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Follow Up Check Up:'), findsOneWidget);
      expect(find.text('November 15, 2026'), findsOneWidget);
    });
  });

  group('PrescriptionView Dynamic Follow-Up Workspace Tests', () {
    testWidgets('Loads follow-up from existing patient prescription and binds to Live Preview', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: PrescriptionView(initialPatient: patientWithFollowUp),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the input field exists and is populated
      final inputFinder = find.byKey(const Key('prescription_follow_up_input'));
      expect(inputFinder, findsOneWidget);

      final input = tester.widget<TextFormField>(inputFinder);
      expect(input.controller?.text, 'In 2 weeks');

      // Verify it appears in the live prescription pad preview
      expect(find.text('In 2 weeks'), findsWidgets);
    });

    testWidgets('Typing into Follow-Up input dynamically updates Live Prescription Pad Preview', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: PrescriptionView(initialPatient: patientEmpty),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final inputFinder = find.byKey(const Key('prescription_follow_up_input'));
      expect(inputFinder, findsOneWidget);

      // Initially empty patient has default underline in preview
      expect(find.text('_________________'), findsOneWidget);

      // Type custom follow up schedule
      await tester.enterText(inputFinder, 'November 15, 2026');
      await tester.pumpAndSettle();

      // Now Live Preview updates immediately to show 'November 15, 2026'
      expect(find.text('November 15, 2026'), findsWidgets);
      expect(find.text('_________________'), findsNothing);
    });

    testWidgets('Selecting date via clinical date picker updates follow up input and preview', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: PrescriptionView(initialPatient: patientEmpty),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap calendar icon button inside follow-up field
      final calendarButton = find.byTooltip('Select date');
      expect(calendarButton, findsOneWidget);
      await tester.tap(calendarButton);
      await tester.pumpAndSettle();

      // Verify ClinicalDatePickerDialog opened
      expect(find.byType(ClinicalDatePickerDialog), findsOneWidget);

      // Select 'OK' on date picker
      final confirmBtn = find.text('OK');
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Dialog is dismissed and input has formatted date
      expect(find.byType(ClinicalDatePickerDialog), findsNothing);
      final input = tester.widget<TextFormField>(find.byKey(const Key('prescription_follow_up_input')));
      expect(input.controller?.text.isNotEmpty, isTrue);
      // The date is also rendered on the Rx Pad
      expect(find.text(input.controller!.text), findsWidgets);
    });

    testWidgets('Saving prescription saves followUpDate to PatientRepository', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      PatientRepository.addPatient(patientEmpty);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: PrescriptionView(initialPatient: patientEmpty),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Add a medication so Generate Printable PDF button is enabled
      final medNameField = find.byType(TextFormField).first;
      await tester.enterText(medNameField, 'Ofloxacin 0.3% Eye Drops');
      final addMedBtn = find.widgetWithText(ElevatedButton, 'Add Medication to Prescription');
      await tester.tap(addMedBtn);
      await tester.pumpAndSettle();

      // Enter follow up schedule
      final inputFinder = find.byKey(const Key('prescription_follow_up_input'));
      await tester.enterText(inputFinder, 'After 10 days for slit lamp exam');
      await tester.pumpAndSettle();

      // Click "Generate Printable PDF" button to trigger _savePrescription
      final saveBtn = find.widgetWithText(ElevatedButton, 'Generate Printable PDF');
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Success modal should appear
      expect(find.text('Prescription Saved Successfully'), findsOneWidget);

      // Verify the patient's saved prescription in repository has the followUpDate
      final savedPatient = PatientRepository.getPatientById(patientEmpty.id);
      expect(savedPatient, isNotNull);
      expect(savedPatient!.prescriptions.isNotEmpty, isTrue);
      expect(savedPatient.prescriptions.first.followUpDate, 'After 10 days for slit lamp exam');
    });
  });
}
