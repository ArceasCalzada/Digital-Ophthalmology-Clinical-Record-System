import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/models/patient.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Patient Directory & Firestore Integration Tests', () {
    test('Patient.fromJson parses Firestore documents with missing or alternative field names', () {
      final firestoreDocData = {
        'id': 'pat-1790593390272',
        'fullName': 'Arceas John Calzada',
        'mrn': 'PT-328067',
        'phone': '+63 900 000 0000',
        // Missing dateOfBirth, gender, address, medicalHistory, allergies
      };

      final patient = Patient.fromJson(firestoreDocData);

      expect(patient.id, equals('pat-1790593390272'));
      expect(patient.fullName, equals('Arceas John Calzada'));
      expect(patient.mrn, equals('PT-328067'));
      expect(patient.phone, equals('+63 900 000 0000'));
      expect(patient.dateOfBirth, isNotEmpty);
      expect(patient.gender, isNotEmpty);
      expect(patient.address, isNotEmpty);
    });

    test('Patient.fromJson handles alternative keys (name, dob, sex, contactNumber)', () {
      final altKeysDocData = {
        'patientId': 'pat-99999',
        'name': 'Maria Clara Santos',
        'MRN': 'PT-999123',
        'dob': '1992-04-10',
        'sex': 'Female',
        'contactNumber': '+63 918 123 4567',
      };

      final patient = Patient.fromJson(altKeysDocData);

      expect(patient.id, equals('pat-99999'));
      expect(patient.fullName, equals('Maria Clara Santos'));
      expect(patient.mrn, equals('PT-999123'));
      expect(patient.dateOfBirth, equals('1992-04-10'));
      expect(patient.gender, equals('Female'));
      expect(patient.phone, equals('+63 918 123 4567'));
    });

    test('PatientRepository search retrieves records by Full Name, MRN, and Phone Number', () {
      final targetPatient = Patient(
        id: 'pat-1790593390272',
        mrn: 'PT-328067',
        fullName: 'Arceas John Calzada',
        dateOfBirth: '1988-11-20',
        gender: 'Male',
        phone: '+63 917 888 7766',
        address: 'Davao City, Philippines',
        medicalHistory: ['Asthma'],
        allergies: ['Dust'],
        encounters: [],
        lastVisitDate: '2026-09-29',
        totalVisits: 2,
      );

      PatientRepository.addPatient(targetPatient);

      // Search by Full Name
      final nameMatches = PatientRepository.searchPatients('Arceas John Calzada');
      expect(nameMatches.any((p) => p.id == 'pat-1790593390272'), isTrue);

      // Search by Partial Name
      final partialMatches = PatientRepository.searchPatients('Calzada');
      expect(partialMatches.any((p) => p.id == 'pat-1790593390272'), isTrue);

      // Search by MRN
      final mrnMatches = PatientRepository.searchPatients('PT-328067');
      expect(mrnMatches.any((p) => p.id == 'pat-1790593390272'), isTrue);

      // Search by Phone Number
      final phoneMatches = PatientRepository.searchPatients('+63 917 888 7766');
      expect(phoneMatches.any((p) => p.id == 'pat-1790593390272'), isTrue);

      // Search by Clean Phone Digits
      final phoneDigitMatches = PatientRepository.searchPatients('9178887766');
      expect(phoneDigitMatches.any((p) => p.id == 'pat-1790593390272'), isTrue);
    });

    test('Newly registered patients immediately appear in search directory', () {
      final newRegPatient = Patient(
        id: 'pat-new-999',
        mrn: 'PT-888888',
        fullName: 'Juan Dela Cruz',
        dateOfBirth: '1995-01-01',
        gender: 'Male',
        phone: '+63 919 111 2222',
        address: 'Quezon City',
        medicalHistory: [],
        allergies: [],
        encounters: [],
        lastVisitDate: '2026-09-29',
        totalVisits: 1,
      );

      PatientRepository.addPatient(newRegPatient);

      final searchResult = PatientRepository.searchPatients('Juan Dela Cruz');
      expect(searchResult.isNotEmpty, isTrue);
      expect(searchResult.first.fullName, equals('Juan Dela Cruz'));
    });
  });
}
