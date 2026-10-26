import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ophthalmology_clinical_record_system/models/team.dart';
import 'package:ophthalmology_clinical_record_system/services/profile_store.dart';
import 'package:ophthalmology_clinical_record_system/services/team_service.dart';
import 'package:ophthalmology_clinical_record_system/theme/app_theme.dart';
import 'package:ophthalmology_clinical_record_system/views/profile_view.dart';
import 'package:ophthalmology_clinical_record_system/views/settings_view.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    TeamService.instance.setActiveRoleForTesting(TeamRole.owner);
  });

  group('Assistant Role SettingsView Filtering', () {
    testWidgets('SettingsView defaults to Security and hides Doctor/Rx & Backup items for Assistant', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      TeamService.instance.setActiveRoleForTesting(TeamRole.assistant);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: SettingsView()),
        ),
      );
      await tester.pumpAndSettle();

      // Desktop Left Navigation checks:
      // "Prescription Settings" and "Backup & Data" must NOT be in navigation
      expect(find.widgetWithText(ListTile, 'Prescription Settings'), findsNothing);
      expect(find.widgetWithText(ListTile, 'Backup & Data'), findsNothing);
      expect(find.text('General'), findsNothing);

      // User-level preferences must be present in navigation
      expect(find.widgetWithText(ListTile, 'Security'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'System Preferences'), findsOneWidget);
      expect(find.text('ACCOUNT & SECURITY'), findsOneWidget);

      // Initial active section is Security (Change Password and Auto-Lock cards visible)
      expect(find.text('Change Password'), findsOneWidget);
      expect(find.text('Session Security & Auto-Lock'), findsOneWidget);
    });

    testWidgets('SettingsView shows all configurations for Physician / Owner role', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      TeamService.instance.setActiveRoleForTesting(TeamRole.owner);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: SettingsView()),
        ),
      );
      await tester.pumpAndSettle();

      // All sections in navigation should exist
      expect(find.widgetWithText(ListTile, 'Prescription Settings'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Security'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Backup & Data'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'System Preferences'), findsOneWidget);

      // Initial active section defaults to Prescription Settings
      expect(find.text('Doctor Information'), findsOneWidget);
    });

    testWidgets('Mobile navigation chips filter out Prescription and Backup for Assistant', (tester) async {
      tester.view.physicalSize = const Size(500, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      TeamService.instance.setActiveRoleForTesting(TeamRole.assistant);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: SettingsView()),
        ),
      );
      await tester.pumpAndSettle();

      // Mobile chips: only Security and Preferences
      expect(find.widgetWithText(ChoiceChip, 'Prescription'), findsNothing);
      expect(find.widgetWithText(ChoiceChip, 'Backup & Data'), findsNothing);
      expect(find.widgetWithText(ChoiceChip, 'Security'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Preferences'), findsOneWidget);
    });

    testWidgets('System Preferences hides Examination Preferences card for Assistant', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      TeamService.instance.setActiveRoleForTesting(TeamRole.assistant);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: SettingsView()),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to System Preferences
      await tester.tap(find.widgetWithText(ListTile, 'System Preferences'));
      await tester.pumpAndSettle();

      // General user preferences exist
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Date Format'), findsOneWidget);
      expect(find.text('Time Format'), findsOneWidget);

      // Clinical examination preferences must be hidden
      expect(find.text('Examination Preferences'), findsNothing);
      expect(find.text('Default Examination Layout'), findsNothing);
    });
  });

  group('Assistant Role ProfileView Filtering', () {
    testWidgets('ProfileView hides Doctor Profile and Clinic tabs for Assistant', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      TeamService.instance.setActiveRoleForTesting(TeamRole.assistant);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: ProfileView()),
        ),
      );
      await tester.pumpAndSettle();

      // Account card is visible
      expect(find.text('Account'), findsOneWidget);

      // Doctor Profile and Clinic Info tabs should NOT be rendered
      expect(find.widgetWithText(ChoiceChip, 'Doctor Profile'), findsNothing);
      expect(find.widgetWithText(ChoiceChip, 'Clinic Information'), findsNothing);

      // Restriction notice card is displayed
      expect(find.text('Clinical Configurations Restricted'), findsOneWidget);
    });

    testWidgets('ProfileView shows Doctor Profile and Clinic tabs for Physician / Owner', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      TeamService.instance.setActiveRoleForTesting(TeamRole.owner);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: ProfileView()),
        ),
      );
      await tester.pumpAndSettle();

      // Doctor Profile and Clinic Info tabs should be rendered
      expect(find.widgetWithText(ChoiceChip, 'Doctor Profile'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Clinic Information'), findsOneWidget);
      expect(find.text('Clinical Configurations Restricted'), findsNothing);
    });
  });

  group('ProfileStore Assistant Mutation Restrictions', () {
    test('ProfileStore ignores branch addition and mutation attempts when role is Assistant', () async {
      final store = ProfileStore.instance;
      final initialCount = store.branches.length;

      TeamService.instance.setActiveRoleForTesting(TeamRole.assistant);

      await store.addBranch(
        name: 'Unauthorized Branch',
        address: 'Nowhere',
        days: 'Never',
        hours: '00:00',
      );

      // Branch count should NOT increase
      expect(store.branches.length, equals(initialCount));

      // Attempt to save to firestore directly
      await store.saveToFirestore(teamId: 'team-xyz');
      // Should exit early without throwing
    });
  });
}
