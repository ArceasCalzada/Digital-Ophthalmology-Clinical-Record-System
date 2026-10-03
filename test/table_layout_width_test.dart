import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/models/patient.dart';
import 'package:ophthalmology_clinical_record_system/theme/app_theme.dart';
import 'package:ophthalmology_clinical_record_system/views/patients_screen.dart';

void main() {
  testWidgets('Patient directory table expands to 100% card width', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final patient = Patient(
      id: 'test-pt-101',
      mrn: 'PT-101',
      fullName: 'John Doe',
      dateOfBirth: '1990-01-01',
      gender: 'Male',
      phone: '09170000000',
      address: 'Manila',
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
        home: Scaffold(
          body: PatientsScreen(onSelectPatient: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Switch to list view
    final tableBtn = find.byIcon(Icons.table_rows_rounded);
    expect(tableBtn, findsOneWidget);
    await tester.tap(tableBtn);
    await tester.pumpAndSettle();

    final cardFinder = find.ancestor(
      of: find.textContaining('Total Patient Records'),
      matching: find.byType(Card),
    ).first;
    final cardRect = tester.getRect(cardFinder);

    final dataTableFinder = find.byType(DataTable);
    final dataTableRect = tester.getRect(dataTableFinder);

    expect(dataTableRect.width, greaterThanOrEqualTo(cardRect.width - 16.0));

    // Verify all column headers exist
    final headers = ['Patient Name', 'Patient ID (MRN)', 'Age / Sex', 'Phone Contact', 'Last Visit', 'Visits', 'Action'];
    for (final h in headers) {
      expect(find.text(h), findsOneWidget);
    }
  });
}
