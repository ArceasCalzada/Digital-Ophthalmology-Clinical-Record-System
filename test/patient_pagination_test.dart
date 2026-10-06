import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/models/patient.dart';
import 'package:ophthalmology_clinical_record_system/views/patients_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Patient Repository Pagination Unit Tests', () {
    test('getPaginatedPatients correctly slices items, counts pages, and reports navigation flags', () {
      // Seed 25 patients
      for (int i = 1; i <= 25; i++) {
        PatientRepository.addPatient(
          Patient(
            id: 'pat-page-$i',
            mrn: 'PT-${i.toString().padLeft(6, '0')}',
            fullName: 'Patient Number $i',
            dateOfBirth: '1990-01-01',
            gender: 'Male',
            phone: '+63 900 000 ${i.toString().padLeft(4, '0')}',
            address: 'City Address $i',
            medicalHistory: [],
            allergies: [],
            encounters: [],
            lastVisitDate: '2026-10-01',
            totalVisits: 1,
          ),
        );
      }

      // Test Page 1 of size 10 (newest added first)
      final page1 = PatientRepository.getPaginatedPatients(page: 1, pageSize: 10);
      expect(page1.totalCount, equals(25));
      expect(page1.totalPages, equals(3));
      expect(page1.items.length, equals(10));
      expect(page1.items.first.fullName, equals('Patient Number 25'));
      expect(page1.hasPrevious, isFalse);
      expect(page1.hasNext, isTrue);

      // Test Page 2 of size 10
      final page2 = PatientRepository.getPaginatedPatients(page: 2, pageSize: 10);
      expect(page2.items.length, equals(10));
      expect(page2.items.first.fullName, equals('Patient Number 15'));
      expect(page2.hasPrevious, isTrue);
      expect(page2.hasNext, isTrue);

      // Test Page 3 (last page with 5 items)
      final page3 = PatientRepository.getPaginatedPatients(page: 3, pageSize: 10);
      expect(page3.items.length, equals(5));
      expect(page3.items.first.fullName, equals('Patient Number 5'));
      expect(page3.hasPrevious, isTrue);
      expect(page3.hasNext, isFalse);
    });

    test('getPaginatedPatients filters by search query and quick condition filters', () {
      PatientRepository.addPatient(
        Patient(
          id: 'pat-glaucoma-1',
          mrn: 'PT-777001',
          fullName: 'Glaucoma Special Patient',
          dateOfBirth: '1980-05-12',
          gender: 'Female',
          phone: '+63 917 111 2233',
          address: 'Davao City',
          medicalHistory: [],
          allergies: [],
          previousDiagnoses: ['Primary Open-Angle Glaucoma'],
          encounters: [],
          lastVisitDate: '2026-10-02',
          totalVisits: 2,
        ),
      );

      final glaucomaResult = PatientRepository.getPaginatedPatients(page: 1, pageSize: 10, filter: 'Glaucoma');
      expect(glaucomaResult.totalCount, greaterThanOrEqualTo(1));
      expect(glaucomaResult.items.any((p) => p.id == 'pat-glaucoma-1'), isTrue);

      final searchResult = PatientRepository.getPaginatedPatients(page: 1, pageSize: 10, searchQuery: 'Special Patient');
      expect(searchResult.totalCount, equals(1));
      expect(searchResult.items.first.id, equals('pat-glaucoma-1'));
    });
  });

  group('PatientsScreen Pagination UI Widget Tests', () {
    testWidgets('PatientsScreen renders pagination controls bar and responds to page navigation', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PatientsScreen(onSelectPatient: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Showing 1–'), findsOneWidget);
      expect(find.textContaining('Rows per page:'), findsOneWidget);
      expect(find.textContaining('Page 1 of'), findsOneWidget);
      expect(find.byTooltip('Next Page'), findsOneWidget);
      expect(find.byTooltip('Previous Page'), findsOneWidget);
    });

    testWidgets('Tapping Next Page navigates to page 2 and updates page count indicator', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Ensure enough records exist to span multiple pages (e.g. 25 items, 20 per page = 2 pages)
      for (int i = 1; i <= 25; i++) {
        PatientRepository.addPatient(
          Patient(
            id: 'widget-pat-$i',
            mrn: 'PT-W-${i.toString().padLeft(4, '0')}',
            fullName: 'Widget Patient $i',
            dateOfBirth: '1985-04-12',
            gender: 'Male',
            phone: '+63 920 000 ${i.toString().padLeft(4, '0')}',
            address: 'Clinic Location',
            medicalHistory: [],
            allergies: [],
            encounters: [],
            lastVisitDate: '2026-10-03',
            totalVisits: 1,
          ),
        );
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PatientsScreen(onSelectPatient: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final nextPageBtn = find.byTooltip('Next Page');
      expect(nextPageBtn, findsOneWidget);

      await tester.ensureVisible(nextPageBtn);
      await tester.tap(nextPageBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('Page 2 of'), findsOneWidget);

      final prevPageBtn = find.byTooltip('Previous Page');
      expect(prevPageBtn, findsOneWidget);

      await tester.ensureVisible(prevPageBtn);
      await tester.tap(prevPageBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('Page 1 of'), findsOneWidget);
    });
  });
}
