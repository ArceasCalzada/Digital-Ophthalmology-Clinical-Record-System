import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/theme/app_theme.dart';
import 'package:ophthalmology_clinical_record_system/views/dashboard_screen.dart';
import 'package:ophthalmology_clinical_record_system/views/patients_screen.dart';
import 'package:ophthalmology_clinical_record_system/widgets/clinical_modal_picker.dart';

void main() {
  testWidgets('Dashboard and Patient Directory + New modals render identical titles, actions, and order', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // 1. Open Dashboard modal
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: DashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dashboardNewBtn = find.text('New');
    expect(dashboardNewBtn, findsOneWidget);
    await tester.tap(dashboardNewBtn);
    await tester.pumpAndSettle();

    expect(find.text('New Patient Action'), findsOneWidget);
    expect(find.text('Select an action to perform in patient records'), findsOneWidget);
    expect(find.text('New Examination'), findsOneWidget);
    expect(find.text('Open consultation sheet & exam'), findsOneWidget);
    expect(find.text('New Prescription'), findsOneWidget);
    expect(find.text('Write digital ophthalmic Rx'), findsOneWidget);
    expect(find.text('Register New Patient'), findsOneWidget);
    expect(find.text('Add new patient profile'), findsOneWidget);

    // Close modal
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // 2. Open Patient Directory modal
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: PatientsScreen(onSelectPatient: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final patientsNewBtn = find.text('New');
    expect(patientsNewBtn, findsOneWidget);
    await tester.tap(patientsNewBtn);
    await tester.pumpAndSettle();

    expect(find.text('New Patient Action'), findsOneWidget);
    expect(find.text('Select an action to perform in patient records'), findsOneWidget);
    expect(find.text('New Examination'), findsOneWidget);
    expect(find.text('Open consultation sheet & exam'), findsOneWidget);
    expect(find.text('New Prescription'), findsOneWidget);
    expect(find.text('Write digital ophthalmic Rx'), findsOneWidget);
    expect(find.text('Register New Patient'), findsOneWidget);
    expect(find.text('Add new patient profile'), findsOneWidget);
  });
}
