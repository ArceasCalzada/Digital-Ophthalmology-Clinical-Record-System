import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/theme/app_theme.dart';
import 'package:ophthalmology_clinical_record_system/views/dashboard_screen.dart';

void main() {
  testWidgets('Dashboard renders greeting, queue, calendar and patient records', (WidgetTester tester) async {
    tester.binding.window.physicalSizeTestValue = const Size(1920, 1080);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: DashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Good morning, Dr. Sigrid Robillos, MD'), findsOneWidget);
    expect(find.text("Today's Patient Queue & Consultations"), findsOneWidget);
    expect(find.text('Clinic Calendar'), findsOneWidget);
    expect(find.textContaining('Clinical Patient Records'), findsOneWidget);
  });
}
