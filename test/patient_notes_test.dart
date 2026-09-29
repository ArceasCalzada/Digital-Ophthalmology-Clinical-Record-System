import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/config/app_limits.dart';
import 'package:ophthalmology_clinical_record_system/models/patient.dart';

Patient patientWithNotes(String notes) => Patient(
      id: 'p1',
      mrn: 'PT-100001',
      fullName: 'Notes Test',
      dateOfBirth: 'Jan 2, 1990',
      gender: 'Female',
      phone: '',
      address: '',
      notes: notes,
      medicalHistory: const [],
      allergies: const [],
      encounters: const [],
      lastVisitDate: '2026-01-01',
      totalVisits: 1,
    );

void main() {
  test('a patient without notes is written exactly as before (no notes field at all)', () {
    expect(patientWithNotes('').toFirestore().containsKey('notes'), isFalse);
  });

  test('notes are stored, read back, and kept when the patient is copied', () {
    final patient = patientWithNotes('Prefers morning appointments');
    expect(patient.toFirestore()['notes'], 'Prefers morning appointments');

    final restored = Patient.fromJson({...patient.toFirestore(), 'id': 'p1'});
    expect(restored.notes, 'Prefers morning appointments');
    expect(restored.copyWith(totalVisits: 2).notes, 'Prefers morning appointments');
    expect(Patient.fromJson({'id': 'p2', 'fullName': 'No Notes'}).notes, isEmpty);
  });

  test('notes are limited to the same length the security rules allow', () {
    expect(() => patientWithNotes('n' * AppLimits.maxNotesLength).toFirestore(), returnsNormally);
    expect(() => patientWithNotes('n' * (AppLimits.maxNotesLength + 1)).toFirestore(), throwsFormatException);
  });
}
