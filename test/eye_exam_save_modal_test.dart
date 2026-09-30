import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/models/patient.dart';
import 'package:ophthalmology_clinical_record_system/theme/app_theme.dart';
import 'package:ophthalmology_clinical_record_system/views/eye_exam_view.dart';

void main() {
  testWidgets('Saving consultation encounter shows modal dialog with patient name and Done button', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final patient = Patient(
      id: 'test-pt-save-1',
      mrn: 'PT-328067',
      fullName: 'Arceas John Calzada',
      dateOfBirth: '1985-06-15',
      gender: 'Male',
      phone: '09773464378',
      address: 'Davao City',
      medicalHistory: [],
      allergies: [],
      encounters: [],
      lastVisitDate: '2026-09-28',
      totalVisits: 1,
    );
    PatientRepository.addPatient(patient);

    Patient? completedPatient;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: EyeExamView(
          patient: patient,
          onExamComplete: (p) => completedPatient = p,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Ensure SnackBar is not present initially
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Consultation Saved Successfully'), findsNothing);

    // Tap 'Save Record'
    final saveButton = find.text('Save Record');
    expect(saveButton, findsOneWidget);
    await tester.tap(saveButton);
    await tester.pump();

    // Verify modal dialog appears with title, patient name, and Done button
    expect(find.text('Consultation Saved Successfully'), findsOneWidget);
    expect(
      find.text('The consultation encounter for Arceas John Calzada has been saved successfully.'),
      findsOneWidget,
    );
    expect(find.text('Done'), findsOneWidget);

    // Verify bottom toast SnackBar is NOT shown
    expect(find.byType(SnackBar), findsNothing);

    // Verify encounter is saved in repository before closing modal
    final storedPatient = PatientRepository.getPatientById(patient.id);
    expect(storedPatient, isNotNull);
    expect(storedPatient!.encounters, isNotEmpty);

    // Tap Done button to dismiss modal
    await tester.tap(find.text('Done'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Modal is dismissed and onExamComplete was triggered
    expect(find.text('Consultation Saved Successfully'), findsNothing);
    expect(completedPatient, isNotNull);
    expect(completedPatient!.fullName, equals('Arceas John Calzada'));
  });
}
