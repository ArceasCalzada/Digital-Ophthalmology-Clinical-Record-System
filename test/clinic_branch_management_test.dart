import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/models/clinic_branch.dart';
import 'package:ophthalmology_clinical_record_system/models/patient.dart';
import 'package:ophthalmology_clinical_record_system/models/prescription.dart';
import 'package:ophthalmology_clinical_record_system/services/profile_store.dart';
import 'package:ophthalmology_clinical_record_system/views/prescription_view.dart';
import 'package:ophthalmology_clinical_record_system/views/settings_view.dart';
import 'package:ophthalmology_clinical_record_system/widgets/rx_pad_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final profile = ProfileStore.instance;
    profile.resetToDefaultBranches();
  });

  tearDown(() {
    final profile = ProfileStore.instance;
    profile.resetToDefaultBranches();
  });

  group('ClinicBranch Model & ProfileStore Management', () {
    test('default branches are populated with standard clinics and are active', () {
      final profile = ProfileStore.instance;
      expect(profile.branches.length, 3);
      expect(profile.activeBranches.length, 3);
      expect(profile.archivedBranches, isEmpty);
      expect(profile.activeBranches[0].name, 'St. Joseph Southern Bukidnon Hosp.');
      expect(profile.activeBranches[1].name, 'Malta Medical Center');
      expect(profile.activeBranches[2].name, 'Adventist Hospital Davao');
    });

    test('addBranch adds a new clinic branch to active branches and syncs to controllers', () async {
      final profile = ProfileStore.instance;
      await profile.addBranch(
        name: 'Metro Davao Eye Specialist Clinic',
        address: 'Quirino Ave, Davao City',
        days: 'Wednesday & Saturday',
        hours: '1pm - 4pm',
      );

      expect(profile.branches.length, 4);
      expect(profile.activeBranches.length, 4);
      final newBranch = profile.activeBranches.last;
      expect(newBranch.name, 'Metro Davao Eye Specialist Clinic');
      expect(newBranch.address, 'Quirino Ave, Davao City');
      expect(newBranch.days, 'Wednesday & Saturday');
      expect(newBranch.hours, '1pm - 4pm');
      expect(newBranch.isArchived, isFalse);
    });

    test('archiveBranch flags branch as isArchived: true and excludes from activeBranches', () async {
      final profile = ProfileStore.instance;
      final targetBranch = profile.activeBranches[1]; // Malta Medical Center
      expect(targetBranch.name, 'Malta Medical Center');

      await profile.archiveBranch(targetBranch.id);

      expect(profile.branches.length, 3);
      expect(profile.activeBranches.length, 2);
      expect(profile.archivedBranches.length, 1);
      expect(profile.archivedBranches.first.name, 'Malta Medical Center');
      expect(profile.archivedBranches.first.isArchived, isTrue);

      // Verify active branches exclude archived branch
      expect(profile.activeBranches.any((b) => b.id == targetBranch.id), isFalse);
      expect(profile.activeBranches[0].name, 'St. Joseph Southern Bukidnon Hosp.');
      expect(profile.activeBranches[1].name, 'Adventist Hospital Davao');
    });

    test('restoreBranch returns archived branch back to activeBranches', () async {
      final profile = ProfileStore.instance;
      final targetBranch = profile.activeBranches[0];

      await profile.archiveBranch(targetBranch.id);
      expect(profile.activeBranches.length, 2);
      expect(profile.archivedBranches.length, 1);

      await profile.restoreBranch(targetBranch.id);
      expect(profile.activeBranches.length, 3);
      expect(profile.archivedBranches, isEmpty);
      expect(profile.activeBranches.any((b) => b.id == targetBranch.id && !b.isArchived), isTrue);
    });

    test('toMap and fromMap serialize and recover dynamic branch list with isArchived state', () {
      final profile = ProfileStore.instance;
      final branchId = profile.activeBranches[0].id;
      profile.archiveBranch(branchId);

      final map = profile.toMap();
      expect(map.containsKey('branches'), isTrue);
      final branchList = map['branches'] as List<dynamic>;
      expect(branchList.length, 3);

      final newStore = ProfileStore.instance;
      newStore.fromMap(map);
      expect(newStore.activeBranches.length, 2);
      expect(newStore.archivedBranches.length, 1);
      expect(newStore.archivedBranches.first.id, branchId);
    });
  });

  group('SettingsView Clinic Branch UI & Actions', () {
    testWidgets('renders "+ Add Branch" button and branch cards with Archive option', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SettingsView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify + Add Branch button is present
      final addBranchButton = find.byKey(const Key('add_branch_button'));
      expect(addBranchButton, findsOneWidget);

      // Verify active branch cards are rendered
      expect(find.text('St. Joseph Southern Bukidnon Hosp.'), findsWidgets);
      expect(find.text('Malta Medical Center'), findsWidgets);
      expect(find.text('Adventist Hospital Davao'), findsWidgets);

      // Verify Archive buttons are present on active branch cards
      final profile = ProfileStore.instance;
      for (final branch in profile.activeBranches) {
        expect(find.byKey(Key('archive_branch_${branch.id}')), findsOneWidget);
      }
    });

    testWidgets('Clicking "+ Add Branch" opens modal dialog with form fields and adds branch on submit', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SettingsView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Click "+ Add Branch"
      await tester.tap(find.byKey(const Key('add_branch_button')));
      await tester.pumpAndSettle();

      // Verify Modal Dialog is shown
      expect(find.text('Add Clinic Branch'), findsOneWidget);
      expect(find.byKey(const Key('new_branch_name_input')), findsOneWidget);
      expect(find.byKey(const Key('new_branch_address_input')), findsOneWidget);
      expect(find.byKey(const Key('new_branch_days_input')), findsOneWidget);
      expect(find.byKey(const Key('new_branch_hours_input')), findsOneWidget);

      // Enter new branch info
      await tester.enterText(find.byKey(const Key('new_branch_name_input')), 'Tagum Eye & Vision Center');
      await tester.enterText(find.byKey(const Key('new_branch_address_input')), 'Pioneer Ave, Tagum City');
      await tester.enterText(find.byKey(const Key('new_branch_days_input')), 'Tuesday & Friday');
      await tester.enterText(find.byKey(const Key('new_branch_hours_input')), '8am - 12nn');

      // Submit modal form
      await tester.tap(find.byKey(const Key('submit_add_branch_button')));
      await tester.pumpAndSettle();

      // Verify modal closed and new branch card is visible
      expect(find.text('Add Clinic Branch'), findsNothing);
      expect(find.text('Tagum Eye & Vision Center'), findsWidgets);
      expect(find.text('Pioneer Ave, Tagum City'), findsWidgets);
      expect(ProfileStore.instance.activeBranches.any((b) => b.name == 'Tagum Eye & Vision Center'), isTrue);
    });

    testWidgets('Clicking Archive opens confirmation dialog, and confirming archives branch', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SettingsView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final profile = ProfileStore.instance;
      final targetBranch = profile.activeBranches[1]; // Malta Medical Center
      final archiveBtn = find.byKey(Key('archive_branch_${targetBranch.id}'));

      // Tap Archive button
      await tester.tap(archiveBtn);
      await tester.pumpAndSettle();

      // Verify Confirmation Dialog
      expect(find.text('Archive Clinic Branch'), findsOneWidget);
      expect(find.textContaining('Are you sure you want to archive "Malta Medical Center"?'), findsOneWidget);
      expect(find.byKey(const Key('confirm_archive_button')), findsOneWidget);

      // Confirm archive
      await tester.tap(find.byKey(const Key('confirm_archive_button')));
      await tester.pumpAndSettle();

      // Verify branch is archived
      expect(profile.activeBranches.any((b) => b.name == 'Malta Medical Center'), isFalse);
      expect(profile.archivedBranches.any((b) => b.name == 'Malta Medical Center'), isTrue);

      // Archived branch is in the Archived Branches section
      expect(find.textContaining('Archived Branches (1)'), findsOneWidget);
    });
  });

  group('PrescriptionPad & Dropdowns Exclude Archived Branches', () {
    testWidgets('Archived branch is excluded from RxPadWidget header preview', (tester) async {
      final profile = ProfileStore.instance;
      final malta = profile.activeBranches.firstWhere((b) => b.name.contains('Malta'));

      // Before archive: Malta is displayed
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RxPadWidget(
              items: const [],
              date: '2026-10-15',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Malta Medical Center'), findsOneWidget);

      // Archive Malta
      await profile.archiveBranch(malta.id);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RxPadWidget(
              items: const [],
              date: '2026-10-15',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // After archive: Malta is no longer in prescription pad header
      expect(find.text('Malta Medical Center'), findsNothing);
      expect(find.text('St. Joseph Southern Bukidnon Hosp.'), findsOneWidget);
      expect(find.text('Adventist Hospital Davao'), findsOneWidget);
    });

    testWidgets('PrescriptionView branch dropdown excludes archived branches', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final profile = ProfileStore.instance;
      final malta = profile.activeBranches.firstWhere((b) => b.name.contains('Malta'));
      await profile.archiveBranch(malta.id);

      final dummyPatient = Patient(
        id: 'patient-test',
        mrn: 'MRN-TEST-1',
        fullName: 'Test Patient',
        dateOfBirth: '1980-01-01',
        gender: 'Male',
        phone: '1234567890',
        address: 'Davao City',
        medicalHistory: const [],
        allergies: const [],
        encounters: const [],
        lastVisitDate: '2026-10-15',
        totalVisits: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrescriptionView(initialPatient: dummyPatient),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open Clinic Branch dropdown
      final dropdown = find.byKey(const Key('prescription_clinic_branch_dropdown'));
      expect(dropdown, findsOneWidget);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      // Active branches appear as options
      expect(find.text('St. Joseph Southern Bukidnon Hosp.'), findsWidgets);
      expect(find.text('Adventist Hospital Davao'), findsWidgets);

      // Archived branch is excluded from dropdown options
      expect(find.text('Malta Medical Center'), findsNothing);
    });

    test('Historical prescription records retain archived branch information intact', () {
      final profile = ProfileStore.instance;
      final malta = profile.activeBranches.firstWhere((b) => b.name.contains('Malta'));

      // Create historical prescription with Malta branch
      final historicalRx = Prescription(
        id: 'rx-hist-001',
        patientId: 'patient-001',
        encounterId: 'enc-001',
        doctorName: 'Dr. Sigrid Robillos',
        date: '2026-05-10',
        items: [
          PrescriptionItem(
            id: 'item-1',
            medicationName: 'Brimonidine 0.2%',
            strength: '0.2%',
            dosage: '1 drop',
            frequency: 'TID',
            duration: '14 days',
            instructions: 'Instill in right eye.',
          ),
        ],
        clinicBranch: malta.name,
      );

      // Serialize and deserialize
      final json = historicalRx.toJson();
      expect(json['clinicBranch'], 'Malta Medical Center');

      // Now archive Malta
      profile.archiveBranch(malta.id);
      expect(profile.activeBranches.any((b) => b.name == 'Malta Medical Center'), isFalse);

      // Historical record recovered from database remains 100% intact
      final restoredRx = Prescription.fromJson(json);
      expect(restoredRx.clinicBranch, 'Malta Medical Center');
      expect(restoredRx.items.first.medicationName, 'Brimonidine 0.2%');
      expect(restoredRx.date, '2026-05-10');
    });
  });
}
