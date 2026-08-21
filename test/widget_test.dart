import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/main.dart';
import 'package:ophthalmology_clinical_record_system/models/patient.dart';

void main() {
  testWidgets('App renders DOCRS clinical workstation and Consultation Sheet', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const OphthalmologyApp());
    await tester.pumpAndSettle();

    // Verify that DOCRS title is displayed
    expect(find.text('DOCRS'), findsOneWidget);

    // Verify patient repository contains Edgardo Asturias from paper chart
    final patients = PatientRepository.getAllPatients();
    expect(patients.any((p) => p.fullName == 'Edgardo Asturias'), isTrue);
  });
}
