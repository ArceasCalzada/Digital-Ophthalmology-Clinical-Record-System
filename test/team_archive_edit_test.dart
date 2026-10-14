import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ophthalmology_clinical_record_system/models/team.dart';
import 'package:ophthalmology_clinical_record_system/services/team_service.dart';
import 'package:ophthalmology_clinical_record_system/views/teams_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Team Model isArchived Serialization Tests', () {
    test('Team defaults isArchived to false', () {
      const team = Team(
        id: 't-test-1',
        name: 'Vision Eye Center',
        ownerId: 'user-1',
        inviteCode: 'DOC-1234',
        createdAt: '2026-10-14T00:00:00.000',
      );

      expect(team.isArchived, isFalse);
    });

    test('Team.toJson includes isArchived flag', () {
      const team = Team(
        id: 't-test-2',
        name: 'Archived Clinic',
        ownerId: 'user-2',
        inviteCode: 'DOC-5678',
        createdAt: '2026-10-14T00:00:00.000',
        isArchived: true,
      );

      final json = team.toJson();
      expect(json['isArchived'], isTrue);
    });

    test('Team.fromJson correctly parses isArchived flag', () {
      final jsonWithArchive = {
        'id': 't-test-3',
        'name': 'Retired Practice',
        'ownerId': 'user-3',
        'inviteCode': 'DOC-9999',
        'createdAt': '2026-10-14T00:00:00.000',
        'isArchived': true,
      };

      final team = Team.fromJson(jsonWithArchive);
      expect(team.isArchived, isTrue);

      final jsonWithoutArchive = {
        'id': 't-test-4',
        'name': 'Active Practice',
        'ownerId': 'user-4',
        'inviteCode': 'DOC-8888',
        'createdAt': '2026-10-14T00:00:00.000',
      };

      final activeTeam = Team.fromJson(jsonWithoutArchive);
      expect(activeTeam.isArchived, isFalse);
    });

    test('Team.copyWith preserves or updates isArchived', () {
      const team = Team(
        id: 't-test-5',
        name: 'Original Clinic',
        ownerId: 'user-5',
        inviteCode: 'DOC-1111',
        createdAt: '2026-10-14T00:00:00.000',
        isArchived: false,
      );

      final archived = team.copyWith(isArchived: true);
      expect(archived.isArchived, isTrue);
      expect(archived.name, 'Original Clinic');

      final restored = archived.copyWith(isArchived: false);
      expect(restored.isArchived, isFalse);
    });
  });

  group('TeamService Edit & Archive / Restore Logic Tests', () {
    test('updateTeam modifies team name and updates active workspace if active', () async {
      final service = TeamService.instance;
      await service.load('owner-1', userEmail: 'doc@docrs.app', displayName: 'Dr. Jane');

      final team = await service.createTeam('Initial Clinic Name', location: 'Branch A');
      expect(service.activeTeam?.id, team.id);
      expect(service.activeTeam?.name, 'Initial Clinic Name');

      final updated = await service.updateTeam(
        team.id,
        name: 'Updated Metro Clinic',
        location: 'Downtown Branch',
      );

      expect(updated.name, 'Updated Metro Clinic');
      expect(updated.location, 'Downtown Branch');
      expect(service.activeTeam?.name, 'Updated Metro Clinic');
      expect(service.teams.any((t) => t.name == 'Updated Metro Clinic'), isTrue);
    });

    test('updateTeamName convenience method updates name successfully', () async {
      final service = TeamService.instance;
      final team = await service.createTeam('Old Name Practice');

      await service.updateTeamName(team.id, 'Renamed Practice');
      expect(service.teams.any((t) => t.name == 'Renamed Practice'), isTrue);
    });

    test('archiveTeam moves team to archivedTeams and removes from teams', () async {
      final service = TeamService.instance;
      await service.load('owner-1', userEmail: 'doc@docrs.app', displayName: 'Dr. Jane');

      final activeTeam = await service.createTeam('Active Clinic');
      final teamToArchive = await service.createTeam('Old Clinic to Archive');

      // Make activeTeam the current active workspace so teamToArchive can be archived
      await service.switchTo(activeTeam.id);
      expect(service.activeTeam?.id, activeTeam.id);

      expect(service.teams.any((t) => t.id == teamToArchive.id), isTrue);
      expect(service.archivedTeams.any((t) => t.id == teamToArchive.id), isFalse);

      await service.archiveTeam(teamToArchive.id);

      expect(service.teams.any((t) => t.id == teamToArchive.id), isFalse);
      expect(service.archivedTeams.any((t) => t.id == teamToArchive.id), isTrue);
    });

    test('archiveTeam throws StateError when attempting to archive currently active workspace', () async {
      final service = TeamService.instance;
      await service.load('owner-1', userEmail: 'doc@docrs.app', displayName: 'Dr. Jane');

      final team = await service.createTeam('Primary Active Workspace');
      expect(service.activeTeam?.id, team.id);

      expect(
        () => service.archiveTeam(team.id),
        throwsA(isA<StateError>()),
      );
    });

    test('restoreTeam unarchives team and moves it back to teams', () async {
      final service = TeamService.instance;
      await service.load('owner-1', userEmail: 'doc@docrs.app', displayName: 'Dr. Jane');

      final activeTeam = await service.createTeam('Current Workspace');
      final teamToArchive = await service.createTeam('Temporary Archive');

      await service.switchTo(activeTeam.id);
      await service.archiveTeam(teamToArchive.id);

      expect(service.teams.any((t) => t.id == teamToArchive.id), isFalse);
      expect(service.archivedTeams.any((t) => t.id == teamToArchive.id), isTrue);

      await service.restoreTeam(teamToArchive.id);

      expect(service.teams.any((t) => t.id == teamToArchive.id), isTrue);
      expect(service.archivedTeams.any((t) => t.id == teamToArchive.id), isFalse);
    });
  });

  group('TeamsView Edit & Archive Widget Tests', () {
    testWidgets('Each team card renders Edit and Archive action buttons', (tester) async {
      final service = TeamService.instance;
      await service.load('owner-1', userEmail: 'doc@docrs.app', displayName: 'Dr. Jane');
      await service.createTeam('Widget Test Clinic');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TeamsView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsWidgets);
      expect(find.text('Archive'), findsWidgets);
    });

    testWidgets('Clicking Edit opens modal dialog and updates team details', (tester) async {
      final service = TeamService.instance;
      await service.load('owner-1', userEmail: 'doc@docrs.app', displayName: 'Dr. Jane');
      await service.createTeam('Editable Eye Clinic');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TeamsView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find Edit button for the team and tap it
      final editBtn = find.widgetWithText(OutlinedButton, 'Edit');
      expect(editBtn, findsWidgets);
      await tester.tap(editBtn.last);
      await tester.pumpAndSettle();

      // Verify modal dialog appeared
      expect(find.text('Edit Team Details'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);

      // Modify team name
      final nameField = find.widgetWithText(TextFormField, 'Editable Eye Clinic');
      expect(nameField, findsOneWidget);
      await tester.enterText(nameField, 'Renamed Eye Specialist Center');
      await tester.pumpAndSettle();

      // Tap Save Changes
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      // Verify success modal appeared
      expect(find.text('Team Updated Successfully'), findsOneWidget);

      // Dismiss modal by clicking Close
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.text('Renamed Eye Specialist Center'), findsWidgets);
    });

    testWidgets('Attempting to archive active workspace displays warning dialog and blocks archiving', (tester) async {
      final service = TeamService.instance;
      await service.load('owner-1', userEmail: 'doc@docrs.app', displayName: 'Dr. Jane');

      // Explicitly set the first team as active
      final activeTeam = service.teams.first;
      await service.switchTo(activeTeam.id);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TeamsView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Archive button on the first (active) workspace
      final archiveBtn = find.widgetWithText(OutlinedButton, 'Archive');
      await tester.tap(archiveBtn.first);
      await tester.pumpAndSettle();

      // Verify warning dialog prevented archiving
      expect(find.text('Cannot Archive Active Workspace'), findsOneWidget);
      expect(find.textContaining('is currently your active workspace'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Verify team remains active and non-archived
      expect(service.teams.any((t) => t.id == activeTeam.id), isTrue);
      expect(service.archivedTeams.any((t) => t.id == activeTeam.id), isFalse);
    });

    testWidgets('Archiving inactive team moves it to Archived Teams with Restore capability', (tester) async {
      final service = TeamService.instance;
      await service.load('owner-1', userEmail: 'doc@docrs.app', displayName: 'Dr. Jane');
      final team1 = await service.createTeam('Workspace Keep Active');
      final team2 = await service.createTeam('Workspace To Retire');

      // Make team1 active so team2 is inactive
      await service.switchTo(team1.id);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TeamsView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find Archive button for the inactive team (team2 is last)
      final archiveButtons = find.widgetWithText(OutlinedButton, 'Archive');
      await tester.ensureVisible(archiveButtons.last);
      await tester.tap(archiveButtons.last);
      await tester.pumpAndSettle();

      // Verify confirmation dialog
      expect(find.text('Archive Team Workspace?'), findsOneWidget);
      expect(find.textContaining('Are you sure you want to archive'), findsOneWidget);

      // Confirm archive
      final confirmBtn = find.widgetWithText(ElevatedButton, 'Archive');
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Success modal
      expect(find.text('Team Archived'), findsOneWidget);

      // Dismiss modal by tapping Close
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // In Archived Teams section: tap to expand
      final archivedHeader = find.textContaining('Archived Teams (1)');
      expect(archivedHeader, findsOneWidget);
      await tester.ensureVisible(archivedHeader);
      await tester.tap(archivedHeader);
      await tester.pumpAndSettle();

      // Check that retired team is displayed in Archived Teams with Restore button
      expect(find.text('Workspace To Retire'), findsOneWidget);
      expect(find.text('Archived'), findsOneWidget);
      expect(find.text('Restore'), findsOneWidget);

      // Tap Restore button
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();

      // Verify Restore confirmation dialog
      expect(find.text('Restore Team Workspace?'), findsOneWidget);
      await tester.tap(find.text('Restore Workspace'));
      await tester.pumpAndSettle();

      // Verify restored modal
      expect(find.text('Team Restored Successfully'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // Verify team is now back in active teams
      expect(service.teams.any((t) => t.id == team2.id), isTrue);
      expect(service.archivedTeams.any((t) => t.id == team2.id), isFalse);
    });
  });
}
