import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/models/patient.dart';
import 'package:ophthalmology_clinical_record_system/theme/app_theme.dart';
import 'package:ophthalmology_clinical_record_system/views/main_layout.dart';
import 'package:ophthalmology_clinical_record_system/views/patient_profile_view.dart';

void main() {
  testWidgets('PatientProfileView renders patient details properly', (WidgetTester tester) async {
    final patient = Patient(
      id: 'test-pt-1',
      mrn: 'PT-328067',
      fullName: 'Arceas John Calzada',
      dateOfBirth: '1985-06-15',
      gender: 'Male',
      phone: '09773464378',
      address: 'Davao City',
      medicalHistory: ['Hypertension'],
      allergies: ['Penicillin'],
      encounters: [],
      lastVisitDate: '2026-09-28',
      totalVisits: 1,
    );
    PatientRepository.addPatient(patient);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: PatientProfileView(
            patientId: patient.id,
            patient: patient,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Arceas John Calzada'), findsOneWidget);
    expect(find.text('PT-328067'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Examination History'), findsOneWidget);
    expect(find.text('Prescriptions'), findsOneWidget);
  });

  testWidgets('MainLayout displays PatientProfileView when View History is clicked', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final patient = Patient(
      id: 'test-pt-2',
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

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MainLayout(onLogout: () {}),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Verify Dashboard is displayed
    expect(find.text('Clinical Patient Records'), findsOneWidget);

    // Find and tap 'View History' button for Arceas John Calzada
    final viewHistoryBtn = find.text('View History').first;
    await tester.tap(viewHistoryBtn);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Verify PatientProfileView content is rendered cleanly
    expect(find.text('Arceas John Calzada'), findsAtLeast(1));
    expect(find.text('PT-328067'), findsAtLeast(1));
    expect(find.text('Overview'), findsOneWidget);
  });
}
