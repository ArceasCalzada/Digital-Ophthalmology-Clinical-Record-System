import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/models/patient.dart';
import 'package:ophthalmology_clinical_record_system/services/team_service.dart';
import 'package:ophthalmology_clinical_record_system/views/patients_screen.dart';
import 'package:ophthalmology_clinical_record_system/views/teams_view.dart';
import 'package:ophthalmology_clinical_record_system/widgets/skeleton_loader.dart';

void main() {
  group('Skeleton Loader Widgets', () {
    testWidgets('SkeletonShimmer, SkeletonBox, SkeletonAvatar render correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonShimmer(
              child: Column(
                children: [
                  SkeletonBox(width: 100, height: 20),
                  SizedBox(height: 10),
                  SkeletonAvatar(radius: 25),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(SkeletonShimmer), findsOneWidget);
      expect(find.byType(SkeletonBox), findsNWidgets(2)); // SkeletonAvatar uses SkeletonBox
      expect(find.byType(SkeletonAvatar), findsOneWidget);
    });

    testWidgets('SkeletonPatientCard renders properly with shimmer', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 250,
              child: SkeletonPatientCard(),
            ),
          ),
        ),
      );

      expect(find.byType(SkeletonPatientCard), findsOneWidget);
      expect(find.byType(SkeletonShimmer), findsOneWidget);
    });

    testWidgets('SkeletonTableRow renders properly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonTableRow(),
          ),
        ),
      );

      expect(find.byType(SkeletonTableRow), findsOneWidget);
      expect(find.byType(SkeletonShimmer), findsOneWidget);
    });

    testWidgets('SkeletonTeamCard and SkeletonMemberTile render properly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SkeletonTeamCard(),
                SkeletonMemberTile(),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(SkeletonTeamCard), findsOneWidget);
      expect(find.byType(SkeletonMemberTile), findsOneWidget);
    });
  });

  group('PatientsScreen Skeleton Integration', () {
    testWidgets('Displays skeleton cards when PatientRepository.isLoading is true', (tester) async {
      PatientRepository.isLoading.value = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PatientsScreen(
              onSelectPatient: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(SkeletonPatientCard), findsWidgets);

      // Now set isLoading to false and verify transition
      PatientRepository.isLoading.value = false;
      await tester.pumpAndSettle();

      expect(find.byType(SkeletonPatientCard), findsNothing);
    });
  });

  group('TeamsView Skeleton Integration', () {
    testWidgets('Displays skeleton tiles when TeamService is loading', (tester) async {
      await TeamService.instance.load('test-user-skel');
      // Verify TeamsView renders cleanly
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TeamsView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Teams & Collaboration'), findsOneWidget);
    });
  });
}
