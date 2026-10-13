import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/models/drawing_stroke.dart';
import 'package:ophthalmology_clinical_record_system/models/patient.dart';
import 'package:ophthalmology_clinical_record_system/services/draft_manager_service.dart';
import 'package:ophthalmology_clinical_record_system/theme/app_theme.dart';
import 'package:ophthalmology_clinical_record_system/views/eye_exam_view.dart';
import 'package:ophthalmology_clinical_record_system/views/main_layout.dart';
import 'package:ophthalmology_clinical_record_system/views/prescription_view.dart';
import 'package:ophthalmology_clinical_record_system/widgets/drawing/paper_sheet_canvas.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testPatient = Patient(
    id: 'pt-nav-test-01',
    mrn: 'MRN-NAV-2026',
    fullName: 'Juan Dela Cruz',
    dateOfBirth: '1988-04-12',
    gender: 'Male',
    phone: '+63 917 123 4567',
    address: 'Davao City, Philippines',
    medicalHistory: const ['DM', 'HPN'],
    allergies: const ['Penicillin'],
    encounters: const [],
    lastVisitDate: '2026-10-10',
    totalVisits: 1,
  );

  setUp(() {
    DraftManagerService().clearAllDrafts();
    PatientRepository.clearForTesting();
    PatientRepository.addPatient(testPatient);
  });

  tearDown(() {
    DraftManagerService().clearAllDrafts();
  });

  group('Clinical Consultation Record to Prescriptions Workspace Routing', () {
    testWidgets('Clicking + Prescription button in EyeExamView triggers onOpenPrescription with patient context', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      Patient? passedPatient;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: EyeExamView(
              patient: testPatient,
              onOpenPrescription: (p) => passedPatient = p,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final prescriptionButton = find.byKey(const Key('btn_add_prescription'));
      expect(prescriptionButton, findsOneWidget);
      expect(find.text('+ Prescription'), findsOneWidget);

      await tester.tap(prescriptionButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(passedPatient, isNotNull);
      expect(passedPatient!.id, equals(testPatient.id));
      expect(passedPatient!.fullName, equals(testPatient.fullName));
      expect(passedPatient!.mrn, equals(testPatient.mrn));
    });

    testWidgets('Clicking + Prescription button preserves canvas strokes and form data in local draft', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: EyeExamView(
              patient: testPatient,
              onOpenPrescription: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(DraftManagerService().hasValidDraft('eye_exam'), isFalse);

      // Tap + Prescription
      final prescriptionButton = find.byKey(const Key('btn_add_prescription'));
      await tester.tap(prescriptionButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify draft was saved in DraftManagerService
      final draft = DraftManagerService().getValidDraft('eye_exam');
      expect(draft, isNotNull);
      expect(draft!.patientId, equals(testPatient.id));
      expect(draft.payload['patientName'], equals(testPatient.fullName));
    });

    testWidgets('Draft is restored when reopening EyeExamView for same patient', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Seed a draft with custom stroke and demographic name
      final dummyStroke = VectorStroke(
        id: 'strk-test-1',
        tool: DrawingTool.pen,
        color: const Color(0xFF1D4ED8),
        size: 2.0,
        points: [const Offset(100, 100), const Offset(120, 120)],
      );

      DraftManagerService().saveDraft(
        contextKey: 'eye_exam',
        patientId: testPatient.id,
        payload: {
          'patientId': testPatient.id,
          'patientName': 'Juan Restored Dela Cruz',
          'name': 'Juan Restored Dela Cruz',
          'strokes': [dummyStroke.toJson()],
          'assessment': 'Dry Eye Syndrome',
          'chiefComplaint': 'Blurry vision and irritation',
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: EyeExamView(
              patient: testPatient,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify restored content is visible in AppBar and PaperSheetCanvas
      expect(find.text('Juan Restored Dela Cruz'), findsOneWidget);
      final canvas = tester.widget<PaperSheetCanvas>(find.byType(PaperSheetCanvas));
      expect(canvas.initialStrokes.length, equals(1));
      expect(canvas.initialStrokes.first.id, equals('strk-test-1'));
    });

    testWidgets('PrescriptionView automatically selects patient passed via initialPatient', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Prescriptions Workspace'), findsOneWidget);
      expect(find.text('${testPatient.fullName} (${testPatient.mrn})'), findsOneWidget);
    });

    testWidgets('MainLayout full flow: Exam -> click + Prescription -> seamlessly switches to Prescriptions Workspace with patient pre-selected', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MainLayout(onLogout: () {}),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // 1. Open patient profile for testPatient
      final viewHistoryBtn = find.text('View History').first;
      expect(viewHistoryBtn, findsOneWidget);
      await tester.tap(viewHistoryBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // 2. Start new examination for this patient
      final startExamBtn = find.text('+ New Examination');
      expect(startExamBtn, findsOneWidget);
      await tester.tap(startExamBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Confirm we are on the Clinical Consultation Record with the patient
      expect(find.text('Clinical Consultation Record'), findsOneWidget);
      expect(find.text(testPatient.fullName), findsWidgets);

      // Verify the + Prescription button is present
      final prescriptionButton = find.byKey(const Key('btn_add_prescription'));
      expect(prescriptionButton, findsOneWidget);

      // Tap + Prescription button
      await tester.tap(prescriptionButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Verify seamless switch to Prescriptions Workspace
      expect(find.text('Prescriptions Workspace'), findsOneWidget);
      expect(find.text('Create, preview, and print clinical eye prescriptions.'), findsOneWidget);

      // Verify active patient is preselected in the Prescriptions Workspace
      expect(find.text('${testPatient.fullName} (${testPatient.mrn})'), findsOneWidget);

      // Verify draft was preserved
      expect(DraftManagerService().hasValidDraft('eye_exam'), isTrue);
    });
  });
}
