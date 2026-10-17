import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/models/encounter.dart';
import 'package:ophthalmology_clinical_record_system/models/eye_exam.dart';
import 'package:ophthalmology_clinical_record_system/models/patient.dart';
import 'package:ophthalmology_clinical_record_system/models/drawing_stroke.dart';
import 'package:ophthalmology_clinical_record_system/theme/app_theme.dart';
import 'package:ophthalmology_clinical_record_system/widgets/drawing/paper_sheet_canvas.dart';
import 'package:ophthalmology_clinical_record_system/widgets/pdf_exam_preview_dialog.dart';

void main() {
  group('Clinical Exam Traditional Paper Print Preview Tests', () {
    final testPatient = Patient(
      id: 'PT-100200',
      mrn: 'PT-100200',
      firstName: 'Edgardo',
      middleName: 'Perez',
      lastName: 'Asturias',
      fullName: 'Edgardo Perez Asturias',
      dateOfBirth: '1963-05-07',
      gender: 'Male',
      phone: '+63 917 882 1963',
      address: 'Apas, Davao City',
      occupation: 'Civil Servant',
      phicNumber: '19-02581024-8',
      medicalHistory: const ['Hypertension', 'Diabetes Mellitus'],
      allergies: const ['Penicillin'],
      encounters: const [],
      lastVisitDate: '2026-10-18',
      totalVisits: 1,
    );

    final testEncounter = Encounter(
      id: 'enc-test-print-1',
      patientId: 'PT-100200',
      date: 'Oct 18, 2026',
      doctorName: 'Dr. Sigrid Robillos, MD',
      chiefComplaint: 'OS Blurred vision for 6 months',
      diagnosis: 'Mature Cataract OS, Glaucoma Suspect OU',
      treatmentPlan: 'Phacoemulsification with IOL OS',
      examOD: EyeExamData(
        acuity: VisualAcuity(uncorrected: '20/25', bestCorrected: '20/20', oldCc: '20/30', ar: '-0.50', ak: '43.50'),
        refraction: Refraction(sph: '-0.50', cyl: '-0.25', axis: '90'),
        color: 'Normal',
        iop: '16',
        anglesGonioscopy: 'Open G4',
        cdrOn: '0.3',
        confrontationPeripheral: 'WNL',
        vanHerick: 'G4 Wide',
        slitLampNotes: 'Clear cornea',
        fundoscopyNotes: 'Normal retina',
      ),
      examOS: EyeExamData(
        acuity: VisualAcuity(uncorrected: '20/200', bestCorrected: '20/100', oldCc: '20/150', ar: '-2.75', ak: '44.00'),
        refraction: Refraction(sph: '-2.50', cyl: '-0.50', axis: '180'),
        color: 'Reduced',
        iop: '22',
        anglesGonioscopy: 'Narrow G2',
        cdrOn: '0.6',
        confrontationPeripheral: 'Defect',
        vanHerick: 'G2',
        slitLampNotes: 'Dense nuclear sclerosis',
        fundoscopyNotes: 'Hazy view',
      ),
      paperSheetDrawing: PaperSheetDrawingData(
        id: 'drw-enc-test-print-1',
        encounterId: 'enc-test-print-1',
        patientId: 'PT-100200',
        updatedAt: '2026-10-18T00:00:00.000',
        strokes: [
          VectorStroke(
            id: 'stk-1',
            points: [const Offset(100, 100), const Offset(120, 120), const Offset(140, 140)],
            color: const Color(0xFFDC2626),
            size: 2.0,
            tool: DrawingTool.pen,
          ),
        ],
      ),
    );

    testWidgets('showClinicalExamPdfPreviewModal renders traditional canvas preview and actions', (tester) async {
      tester.view.physicalSize = const Size(1400, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showClinicalExamPdfPreviewModal(
                  context: context,
                  patient: testPatient,
                  encounter: testEncounter,
                ),
                child: const Text('Open Print Preview'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Print Preview'));
      await tester.pumpAndSettle();

      // Header Bar
      expect(find.text('PRINT PREVIEW - CLINICAL CONSULTATION SHEET'), findsOneWidget);
      expect(find.text('Traditional Paper Form Visual Format'), findsOneWidget);
      expect(find.byIcon(Icons.print_rounded), findsOneWidget);

      // Verify custom painters for traditional form and vector strokes
      final formPainterFinder = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is PrintedPaperSheetPainter,
      );
      expect(formPainterFinder, findsOneWidget);

      final inkingPainterFinder = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is PaperSheetInkingPainter,
      );
      expect(inkingPainterFinder, findsOneWidget);

      // Verify action buttons
      expect(find.text('Close'), findsOneWidget);
      expect(find.text('Print Consultation Sheet'), findsOneWidget);

      // Test Print action
      await tester.tap(find.text('Print Consultation Sheet'));
      await tester.pump();
      expect(find.text('Sending Clinical Consultation Record to Local Clinic Printer...'), findsOneWidget);

      // Test Close action
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('PRINT PREVIEW - CLINICAL CONSULTATION SHEET'), findsNothing);
    });

    test('PrintedPaperSheetPainter paints all form sections on canvas without error', () {
      final painter = PrintedPaperSheetPainter(
        width: 820.0,
        height: 1082.4,
        patientName: testPatient.fullName,
        middleName: testPatient.middleName,
        date: testEncounter.date,
        ageSex: '${testPatient.age}y / ${testPatient.gender}',
        address: testPatient.address,
        contactNumber: testPatient.phone,
        occupation: testPatient.occupation,
        phicNumber: testPatient.phicNumber,
        birthDate: testPatient.dateOfBirth,
        encounter: testEncounter,
        medicalHistory: testPatient.medicalHistory,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 820, 1082.4));

      // Should execute all drawing commands (Refraction grid, measurements, systemic history checkboxes, drawings)
      expect(() => painter.paint(canvas, const Size(820, 1082.4)), returnsNormally);
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });
  });
}
