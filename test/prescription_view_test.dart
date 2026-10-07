import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/models/patient.dart';
import 'package:ophthalmology_clinical_record_system/models/prescription.dart';
import 'package:ophthalmology_clinical_record_system/views/prescription_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testPatientNoRx = Patient(
    id: 'p-no-rx',
    mrn: 'MRN-999',
    fullName: 'Maria Santos',
    dateOfBirth: '1990-01-01',
    gender: 'Female',
    phone: '+63 918 000 0000',
    address: 'Manila, Philippines',
    medicalHistory: const [],
    allergies: const [],
    encounters: const [],
    lastVisitDate: '2026-10-01',
    totalVisits: 1,
  );

  final testPatientWithRx = Patient(
    id: 'p-with-rx',
    mrn: 'MRN-888',
    fullName: 'Pedro Penduko',
    dateOfBirth: '1982-03-15',
    gender: 'Male',
    phone: '+63 919 111 2222',
    address: 'Cebu City, Philippines',
    medicalHistory: const [],
    allergies: const [],
    encounters: const [],
    lastVisitDate: '2026-10-01',
    totalVisits: 2,
    prescriptions: [
      Prescription(
        id: 'rx-1',
        patientId: 'p-with-rx',
        encounterId: 'enc-1',
        doctorName: 'Dr. Sigrid T. Robillos',
        date: '2026-10-07',
        items: [
          PrescriptionItem(
            id: 'item-101',
            medicationName: 'Timolol Maleate 0.5%',
            strength: '0.5%',
            dosage: '1 drop',
            frequency: 'BID',
            duration: '30 days',
            instructions: 'Instill 1 drop in affected eye twice daily.',
          ),
        ],
      ),
    ],
  );

  group('PrescriptionView Dynamic Rx List Tests', () {
    testWidgets('PrescriptionView begins empty for patient without saved prescriptions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrescriptionView(initialPatient: testPatientNoRx),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify hardcoded Latanoprost is NOT displayed
      expect(find.textContaining('Latanoprost'), findsNothing);
      expect(find.text('No prescribed medications added yet.'), findsOneWidget);
    });

    testWidgets('Adding a medication via input form populates Rx pad correctly', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrescriptionView(initialPatient: testPatientNoRx),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Fill in medication form
      final medNameField = find.byType(TextFormField).first;
      await tester.enterText(medNameField, 'Tobramycin + Dexamethasone');

      final addButton = find.widgetWithText(ElevatedButton, 'Add Medication to Prescription');
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      // Verify newly added medication appears and dummy data does not
      expect(find.textContaining('Tobramycin + Dexamethasone'), findsWidgets);
      expect(find.textContaining('Latanoprost'), findsNothing);
      expect(find.text('No prescribed medications added yet.'), findsNothing);
    });

    testWidgets('Loads existing prescriptions when patient has saved records', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrescriptionView(initialPatient: testPatientWithRx),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Timolol Maleate 0.5%'), findsWidgets);
      expect(find.textContaining('Latanoprost'), findsNothing);
    });
  });
}
