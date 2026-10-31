// ignore_for_file: subtype_of_sealed_class
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/models/clinic_branch.dart';
import 'package:ophthalmology_clinical_record_system/services/profile_store.dart';
import 'package:ophthalmology_clinical_record_system/views/settings_view.dart';
import 'package:ophthalmology_clinical_record_system/widgets/rx_pad_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Lightweight fake QuerySnapshot and QueryDocumentSnapshot for stream testing
class FakeQueryDocumentSnapshot implements QueryDocumentSnapshot<Map<String, dynamic>> {
  @override
  final String id;
  final Map<String, dynamic> _data;

  FakeQueryDocumentSnapshot(this.id, this._data);

  @override
  Map<String, dynamic> data() => _data;

  @override
  bool get exists => true;

  @override
  dynamic get(Object field) => _data[field];

  @override
  dynamic operator [](Object field) => _data[field];

  @override
  SnapshotMetadata get metadata => throw UnimplementedError();

  @override
  DocumentReference<Map<String, dynamic>> get reference => throw UnimplementedError();
}

class FakeQuerySnapshot implements QuerySnapshot<Map<String, dynamic>> {
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

  FakeQuerySnapshot(this.docs);

  @override
  List<DocumentChange<Map<String, dynamic>>> get docChanges => [];

  @override
  SnapshotMetadata get metadata => throw UnimplementedError();

  @override
  int get size => docs.length;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ProfileStore.instance.resetToDefaultBranches();
  });

  tearDown(() {
    ProfileStore.instance.stopListeningToBranches();
    ProfileStore.instance.resetToDefaultBranches();
  });

  group('ProfileStore Firestore Branch Stream Listener', () {
    test('listenToBranches subscribes to stream and dynamically populates branches', () async {
      final profile = ProfileStore.instance;
      final controller = StreamController<QuerySnapshot<Map<String, dynamic>>>();

      profile.listenToBranches('team-alpha', branchStream: controller.stream);
      expect(profile.isBranchesLoading, isTrue);

      // Emit empty snapshot
      controller.add(FakeQuerySnapshot([]));
      await Future.delayed(Duration.zero);

      expect(profile.isBranchesLoading, isFalse);
      expect(profile.branches, isEmpty);
      expect(profile.activeBranches, isEmpty);
      expect(profile.clinic1Name.text, isEmpty);

      // Emit snapshot with 2 branches
      controller.add(FakeQuerySnapshot([
        FakeQueryDocumentSnapshot('branch-1', {
          'name': 'Davao Doctors Eye Center',
          'address': 'E. Quirino Ave, Davao City',
          'days': 'Mon-Wed',
          'hours': '9am - 12nn',
          'isArchived': false,
        }),
        FakeQueryDocumentSnapshot('branch-2', {
          'name': 'Tagum Vision Specialist',
          'address': 'National Highway, Tagum City',
          'days': 'Thursday',
          'hours': '1pm - 5pm',
          'isArchived': false,
        }),
      ]));
      await Future.delayed(Duration.zero);

      expect(profile.branches.length, 2);
      expect(profile.activeBranches.length, 2);
      expect(profile.activeBranches[0].name, 'Davao Doctors Eye Center');
      expect(profile.activeBranches[1].name, 'Tagum Vision Specialist');
      expect(profile.clinic1Name.text, 'Davao Doctors Eye Center');
      expect(profile.clinic2Name.text, 'Tagum Vision Specialist');

      // Emit snapshot with an archived branch
      controller.add(FakeQuerySnapshot([
        FakeQueryDocumentSnapshot('branch-1', {
          'name': 'Davao Doctors Eye Center',
          'address': 'E. Quirino Ave, Davao City',
          'days': 'Mon-Wed',
          'hours': '9am - 12nn',
          'isArchived': false,
        }),
        FakeQueryDocumentSnapshot('branch-2', {
          'name': 'Tagum Vision Specialist',
          'address': 'National Highway, Tagum City',
          'days': 'Thursday',
          'hours': '1pm - 5pm',
          'isArchived': true,
        }),
      ]));
      await Future.delayed(Duration.zero);

      expect(profile.branches.length, 2);
      expect(profile.activeBranches.length, 1);
      expect(profile.archivedBranches.length, 1);
      expect(profile.activeBranches.first.name, 'Davao Doctors Eye Center');

      await controller.close();
    });

    test('listenToBranches handles stream error gracefully', () async {
      final profile = ProfileStore.instance;
      final controller = StreamController<QuerySnapshot<Map<String, dynamic>>>();

      profile.listenToBranches('team-alpha', branchStream: controller.stream);
      expect(profile.isBranchesLoading, isTrue);

      controller.addError(Exception('Firebase network timeout'));
      await Future.delayed(Duration.zero);

      expect(profile.isBranchesLoading, isFalse);
      expect(profile.branchesError, isNotNull);
      expect(profile.branchesError.toString(), contains('Firebase network timeout'));

      await controller.close();
    });
  });

  group('RxPadWidget Header Multi-Branch Layout & Empty State', () {
    testWidgets('renders empty state placeholder when branch list is empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RxPadWidget(
              branches: const [],
              items: const [],
              date: '2026-10-31',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('rx_pad_branches_empty_state')), findsOneWidget);
      expect(find.text('No clinic branches registered'), findsOneWidget);
    });

    testWidgets('renders 1, 2, and 3 branches cleanly across header without overflow', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final branch1 = ClinicBranch(id: 'b1', name: 'Branch 1', address: 'Address 1', days: 'Mon', hours: '9am');
      final branch2 = ClinicBranch(id: 'b2', name: 'Branch 2', address: 'Address 2', days: 'Tue', hours: '10am');
      final branch3 = ClinicBranch(id: 'b3', name: 'Branch 3', address: 'Address 3', days: 'Wed', hours: '11am');

      // Test with 1 branch
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RxPadWidget(
              branches: [branch1],
              items: const [],
              date: '2026-10-31',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Branch 1'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Test with 3 branches
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RxPadWidget(
              branches: [branch1, branch2, branch3],
              items: const [],
              date: '2026-10-31',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Branch 1'), findsOneWidget);
      expect(find.text('Branch 2'), findsOneWidget);
      expect(find.text('Branch 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders 4 or more branches in responsive rows without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final branches = List.generate(
        5,
        (i) => ClinicBranch(
          id: 'b-$i',
          name: 'Specialist Clinic Branch #$i',
          address: 'Main St, Location #$i',
          days: 'Mon & Fri',
          hours: '8am - 12nn',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RxPadWidget(
                branches: branches,
                items: const [],
                date: '2026-10-31',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (var i = 0; i < 5; i++) {
        expect(find.text('Specialist Clinic Branch #$i'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('SettingsView Live Sync & Empty State', () {
    testWidgets('displays empty state in both settings card and live preview when no branches exist', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      ProfileStore.instance.clearBranches();

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

      // Empty state in Clinic Branch Headers card
      expect(find.byKey(const Key('branches_empty_state')), findsOneWidget);
      expect(find.text('No clinic branches registered'), findsWidgets);

      // Empty state in Prescription Pad Preview
      expect(find.byKey(const Key('rx_pad_branches_empty_state')), findsOneWidget);
    });

    testWidgets('adding and archiving branches live updates prescription preview header', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      ProfileStore.instance.clearBranches();

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

      // Initially empty
      expect(find.byKey(const Key('rx_pad_branches_empty_state')), findsOneWidget);

      // Add a branch via ProfileStore (simulating Firestore real-time push)
      await ProfileStore.instance.addBranch(
        name: 'Metro Davao Eye Specialist Clinic',
        address: 'Quirino Ave, Davao City',
        days: 'Wednesday & Saturday',
        hours: '1pm - 4pm',
      );
      await tester.pumpAndSettle();

      // Empty states disappear and new branch is visible in preview
      expect(find.byKey(const Key('rx_pad_branches_empty_state')), findsNothing);
      expect(find.text('Metro Davao Eye Specialist Clinic'), findsWidgets);

      // Archive the branch
      final addedBranch = ProfileStore.instance.activeBranches.first;
      await ProfileStore.instance.archiveBranch(addedBranch.id);
      await tester.pumpAndSettle();

      // Preview immediately returns to empty state
      expect(find.byKey(const Key('rx_pad_branches_empty_state')), findsOneWidget);
      expect(find.text('Metro Davao Eye Specialist Clinic'), findsNothing);
    });
  });
}
