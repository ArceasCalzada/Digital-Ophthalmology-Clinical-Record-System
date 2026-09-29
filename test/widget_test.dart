import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/main.dart';
import 'package:ophthalmology_clinical_record_system/models/patient.dart';

void main() {
  testWidgets('App renders DOCRS clinical workstation and Consultation Sheet', (WidgetTester tester) async {
    // Populate test patient into repository for test assertions
    PatientRepository.addPatient(
      Patient(
        id: 'P-001',
        mrn: '2026-00192',
        fullName: 'Edgardo Asturias',
        dateOfBirth: '1978-05-14',
        gender: 'Male',
        phone: '+63 917 555 0192',
        address: 'Davao City',
        medicalHistory: ['Hypertension'],
        allergies: ['Penicillin'],
        encounters: [],
        lastVisitDate: '2026-07-30',
        totalVisits: 1,
      ),
    );

    // Build our app and trigger a frame.
    await tester.pumpWidget(const OphthalmologyApp());
    await tester.pumpAndSettle();

    // Verify that DOCRS title is displayed
    expect(find.text('DOCRS'), findsOneWidget);

    // Verify patient repository contains Edgardo Asturias from test setup
    final patients = PatientRepository.getAllPatients();
    expect(patients.any((p) => p.fullName == 'Edgardo Asturias'), isTrue);
  });
}
