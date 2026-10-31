import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/services/profile_store.dart';
import 'package:ophthalmology_clinical_record_system/theme/app_theme.dart';
import 'package:ophthalmology_clinical_record_system/views/settings_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    ThemeController.instance.setThemeMode(ThemeMode.light);
  });

  Widget buildSettingsApp() {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeController.instance.themeMode,
          home: const Scaffold(body: SettingsView()),
        );
      },
    );
  }

  group('Dark Mode Component Theme Adaptation Tests', () {
    testWidgets(
      'Doctor Information banner adapts between light and dark modes',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        // 1. Light Mode
        ThemeController.instance.setThemeMode(ThemeMode.light);
        await tester.pumpWidget(buildSettingsApp());
        await tester.pumpAndSettle();

        // Find the Doctor Information info container
        final doctorInfoBannerFinder = find
            .ancestor(
              of: find.byIcon(Icons.info_outline),
              matching: find.byType(Container),
            )
            .first;
        expect(doctorInfoBannerFinder, findsOneWidget);

        Container lightBanner = tester.widget<Container>(
          doctorInfoBannerFinder,
        );
        BoxDecoration lightDecoration = lightBanner.decoration as BoxDecoration;
        expect(lightDecoration.color, equals(const Color(0xFFF1F5F9)));

        // 2. Dark Mode
        ThemeController.instance.setThemeMode(ThemeMode.dark);
        await tester.pumpAndSettle();

        Container darkBanner = tester.widget<Container>(doctorInfoBannerFinder);
        BoxDecoration darkDecoration = darkBanner.decoration as BoxDecoration;
        expect(darkDecoration.color, equals(const Color(0xFF0F172A)));
        expect(
          (darkDecoration.border as Border).top.color,
          equals(const Color(0xFF334155)),
        );

        // Verify text contrast in dark mode
        final doctorNameText = tester.widget<Text>(
          find.textContaining('Dr. Sigrid Robillos').first,
        );
        expect(doctorNameText.style?.color, equals(const Color(0xFFF8FAFC)));
      },
    );

    testWidgets('Clinic Branch cards adapt between light and dark modes', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Ensure profile has active branches
      final profile = ProfileStore.instance;
      expect(profile.activeBranches.isNotEmpty, isTrue);
      final firstBranch = profile.activeBranches.first;

      // 1. Light Mode
      ThemeController.instance.setThemeMode(ThemeMode.light);
      await tester.pumpWidget(buildSettingsApp());
      await tester.pumpAndSettle();

      // Find the first branch card container
      final branchCardFinder = find
          .ancestor(
            of: find.text(firstBranch.name).first,
            matching: find.byType(Container),
          )
          .first;
      expect(branchCardFinder, findsOneWidget);

      Container lightBranchCard = tester.widget<Container>(branchCardFinder);
      BoxDecoration lightDecoration =
          lightBranchCard.decoration as BoxDecoration;
      expect(lightDecoration.color, equals(const Color(0xFFF8FAFC)));

      // 2. Dark Mode
      ThemeController.instance.setThemeMode(ThemeMode.dark);
      await tester.pumpAndSettle();

      Container darkBranchCard = tester.widget<Container>(branchCardFinder);
      BoxDecoration darkDecoration = darkBranchCard.decoration as BoxDecoration;
      expect(darkDecoration.color, equals(const Color(0xFF0F172A)));
      expect(
        (darkDecoration.border as Border).top.color,
        equals(const Color(0xFF334155)),
      );

      // Verify branch title text inherits high contrast light color
      final branchNameText = tester.widget<Text>(
        find.text(firstBranch.name).first,
      );
      expect(branchNameText.style?.color, equals(const Color(0xFFF8FAFC)));
    });

    testWidgets('Signature box adapts between light and dark modes', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // 1. Light Mode
      ThemeController.instance.setThemeMode(ThemeMode.light);
      await tester.pumpWidget(buildSettingsApp());
      await tester.pumpAndSettle();

      final signatureBoxFinder = find
          .ancestor(
            of: find.text('Sarah Jenkins'),
            matching: find.byType(Container),
          )
          .first;
      expect(signatureBoxFinder, findsOneWidget);

      Container lightBox = tester.widget<Container>(signatureBoxFinder);
      BoxDecoration lightDecoration = lightBox.decoration as BoxDecoration;
      expect(lightDecoration.color, equals(Colors.white));

      // 2. Dark Mode
      ThemeController.instance.setThemeMode(ThemeMode.dark);
      await tester.pumpAndSettle();

      Container darkBox = tester.widget<Container>(signatureBoxFinder);
      BoxDecoration darkDecoration = darkBox.decoration as BoxDecoration;
      expect(darkDecoration.color, equals(const Color(0xFF0F172A)));
      expect(
        (darkDecoration.border as Border).top.color,
        equals(const Color(0xFF334155)),
      );
    });

    testWidgets('Archived clinic branch cards adapt properly in dark mode', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final profile = ProfileStore.instance;
      // Archive a branch so we have an archived branch to display
      final branchToArchive = profile.activeBranches.first;
      await profile.archiveBranch(branchToArchive.id);

      ThemeController.instance.setThemeMode(ThemeMode.dark);
      await tester.pumpWidget(buildSettingsApp());
      await tester.pumpAndSettle();

      // Expand archived branches ExpansionTile
      final expansionTileFinder = find.textContaining('Archived Branches');
      expect(expansionTileFinder, findsOneWidget);
      await tester.tap(expansionTileFinder);
      await tester.pumpAndSettle();

      // Find restore button
      final restoreButtonFinder = find.byKey(
        Key('restore_branch_${branchToArchive.id}'),
      );
      expect(restoreButtonFinder, findsOneWidget);

      // Find the archived branch card container
      final archivedCardFinder = find
          .ancestor(of: restoreButtonFinder, matching: find.byType(Container))
          .first;
      Container darkArchivedCard = tester.widget<Container>(archivedCardFinder);
      BoxDecoration darkDecoration =
          darkArchivedCard.decoration as BoxDecoration;
      expect(darkDecoration.color, equals(const Color(0xFF0F172A)));
      expect(
        (darkDecoration.border as Border).top.color,
        equals(const Color(0xFF334155)),
      );

      // Find the "Archived" pill tag container
      final archivedTagFinder = find
          .ancestor(of: find.text('Archived'), matching: find.byType(Container))
          .first;
      Container darkTagContainer = tester.widget<Container>(archivedTagFinder);
      BoxDecoration darkTagDecoration =
          darkTagContainer.decoration as BoxDecoration;
      expect(darkTagDecoration.color, equals(const Color(0xFF334155)));

      final archivedTagText = tester.widget<Text>(find.text('Archived'));
      expect(archivedTagText.style?.color, equals(const Color(0xFFE2E8F0)));

      // Restore branch back for tearDown cleanliness
      await profile.restoreBranch(branchToArchive.id);
    });

    testWidgets(
      'Toggling between light and dark modes reactively updates cards instantly',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        ThemeController.instance.setThemeMode(ThemeMode.light);
        await tester.pumpWidget(buildSettingsApp());
        await tester.pumpAndSettle();

        final infoBannerFinder = find
            .ancestor(
              of: find.byIcon(Icons.info_outline),
              matching: find.byType(Container),
            )
            .first;

        // Initially Light
        expect(
          (tester.widget<Container>(infoBannerFinder).decoration
                  as BoxDecoration)
              .color,
          equals(const Color(0xFFF1F5F9)),
        );

        // Switch to Dark
        ThemeController.instance.setThemeMode(ThemeMode.dark);
        await tester.pumpAndSettle();

        expect(
          (tester.widget<Container>(infoBannerFinder).decoration
                  as BoxDecoration)
              .color,
          equals(const Color(0xFF0F172A)),
        );

        // Switch back to Light
        ThemeController.instance.setThemeMode(ThemeMode.light);
        await tester.pumpAndSettle();

        expect(
          (tester.widget<Container>(infoBannerFinder).decoration
                  as BoxDecoration)
              .color,
          equals(const Color(0xFFF1F5F9)),
        );
      },
    );
  });
}
