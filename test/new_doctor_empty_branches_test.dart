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

class _FakeQueryDoc implements QueryDocumentSnapshot<Map<String, dynamic>> {
  @override
  final String id;
  final Map<String, dynamic> _data;
  _FakeQueryDoc(this.id, this._data);

  @override
  Map<String, dynamic> data() => _data;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeQuerySnapshot implements QuerySnapshot<Map<String, dynamic>> {
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  _FakeQuerySnapshot(this.docs);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ProfileStore.instance.reset();
  });

  tearDown(() {
    ProfileStore.instance.stopListeningToBranches();
    ProfileStore.instance.reset();
  });

  group('New Doctor Account Branch Scoping & Isolation Tests', () {
    test('Newly initialized ProfileStore starts with empty branches and blank controllers', () {
      final profile = ProfileStore.instance;
      expect(profile.branches, isEmpty);
      expect(profile.activeBranches, isEmpty);
      expect(profile.archivedBranches, isEmpty);
      expect(profile.clinic1Name.text, isEmpty);
      expect(profile.clinic2Name.text, isEmpty);
      expect(profile.clinic3Name.text, isEmpty);
    });

    test('reset() clears branches and resets listening state', () {
      final profile = ProfileStore.instance;
      profile.setBranches([
        ClinicBranch(
          id: 'branch-100',
          name: 'Existing Clinic',
          address: 'Downtown',
          days: 'Mon',
          hours: '8am',
        ),
      ]);
      expect(profile.branches.length, 1);

      profile.reset();

      expect(profile.branches, isEmpty);
      expect(profile.activeBranches, isEmpty);
      expect(profile.listeningTeamId, isNull);
      expect(profile.clinic1Name.text, isEmpty);
    });

    test('fromMap with empty branches array preserves empty branches and does not create defaults', () {
      final profile = ProfileStore.instance;
      profile.fromMap({
        'doctorName': 'Dr. New Physician, MD',
        'branches': <Map<String, dynamic>>[],
      });

      expect(profile.branches, isEmpty);
      expect(profile.activeBranches, isEmpty);
      expect(profile.clinic1Name.text, isEmpty);
    });

    test('Preferences storage is strictly scoped per team workspace key', () async {
      final profile = ProfileStore.instance;

      // Doctor A adds a branch in team-doctor-a
      await profile.addBranch(
        name: "Doctor A's Private Eye Clinic",
        address: 'Medical Tower 1',
        days: 'Mon-Wed',
        hours: '9am - 12pm',
        teamId: 'team-doctor-a',
      );
      expect(profile.branches.length, 1);
      expect(profile.branches.first.teamId, 'team-doctor-a');

      // Now Doctor B logs in with team-doctor-b
      profile.reset();
      expect(profile.branches, isEmpty);

      // Load preferences for team-doctor-b (which has no saved data yet)
      await profile.loadFromPreferences(teamId: 'team-doctor-b');

      // Doctor B must NOT see Doctor A's clinic branches
      expect(profile.branches, isEmpty);
      expect(profile.activeBranches, isEmpty);
      expect(profile.clinic1Name.text, isEmpty);
    });

    test('addBranch attaches active workspace teamId to newly created clinic branch', () async {
      final profile = ProfileStore.instance;

      await profile.addBranch(
        name: 'St. Luke Eye Institute',
        address: 'BGC, Taguig',
        days: 'Tuesday & Thursday',
        hours: '1pm - 5pm',
        teamId: 'team-alpha-99',
      );

      expect(profile.branches.length, 1);
      final branch = profile.branches.first;
      expect(branch.name, 'St. Luke Eye Institute');
      expect(branch.teamId, 'team-alpha-99');
    });

    test('listenToBranches subscribes to workspace branches and clears on empty snapshot', () async {
      final profile = ProfileStore.instance;
      final controller = StreamController<QuerySnapshot<Map<String, dynamic>>>();

      profile.listenToBranches('new-practice-workspace', branchStream: controller.stream);
      expect(profile.listeningTeamId, 'new-practice-workspace');
      expect(profile.isBranchesLoading, isTrue);

      // Emit empty snapshot (as when a new doctor has no branches created yet)
      controller.add(_FakeQuerySnapshot([]));
      await Future.delayed(Duration.zero);

      expect(profile.isBranchesLoading, isFalse);
      expect(profile.branches, isEmpty);
      expect(profile.activeBranches, isEmpty);

      await controller.close();
    });

    test('switching between doctor workspaces isolates clinic branches cleanly', () async {
      final profile = ProfileStore.instance;

      // Practice 1 Stream
      final controller1 = StreamController<QuerySnapshot<Map<String, dynamic>>>();
      profile.listenToBranches('practice-1', branchStream: controller1.stream);

      controller1.add(_FakeQuerySnapshot([
        _FakeQueryDoc('b-1', {
          'name': 'Practice 1 Clinic',
          'address': 'Location 1',
          'days': 'Mon',
          'hours': '9am',
          'teamId': 'practice-1',
          'isArchived': false,
        }),
      ]));
      await Future.delayed(Duration.zero);
      expect(profile.branches.length, 1);
      expect(profile.branches.first.name, 'Practice 1 Clinic');

      // Switch to Practice 2 (New doctor account with no branches)
      final controller2 = StreamController<QuerySnapshot<Map<String, dynamic>>>();
      profile.listenToBranches('practice-2-new', branchStream: controller2.stream);

      // Verify that old branches are immediately wiped on workspace switch
      expect(profile.branches, isEmpty);
      expect(profile.listeningTeamId, 'practice-2-new');

      // Emit empty snapshot for Practice 2
      controller2.add(_FakeQuerySnapshot([]));
      await Future.delayed(Duration.zero);

      expect(profile.branches, isEmpty);
      expect(profile.activeBranches, isEmpty);

      await controller1.close();
      await controller2.close();
    });
  });

  group('New Doctor Account Empty State UI Rendering', () {
    testWidgets('SettingsView displays empty state with "No clinic branches registered" for new account', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      ProfileStore.instance.reset();

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

      // Verify empty state is displayed in the settings branch list card
      expect(find.byKey(const Key('branches_empty_state')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('branches_empty_state')),
          matching: find.text('No clinic branches registered'),
        ),
        findsOneWidget,
      );
      expect(
        find.text('Click "Add Branch" above to register consultation locations and schedules for this clinic.'),
        findsOneWidget,
      );

      // Verify no sample branches from other accounts are rendered
      expect(find.text('St. Joseph Southern Bukidnon Hosp.'), findsNothing);
      expect(find.text('Malta Medical Center'), findsNothing);
      expect(find.text('Adventist Hospital Davao'), findsNothing);
    });

    testWidgets('RxPadWidget displays empty state placeholder when doctor has no branches configured', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      ProfileStore.instance.reset();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RxPadWidget(
              branches: [],
              items: [],
              date: '2026-11-09',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('rx_pad_branches_empty_state')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('rx_pad_branches_empty_state')),
          matching: find.text('No clinic branches registered'),
        ),
        findsOneWidget,
      );
    });
  });
}
