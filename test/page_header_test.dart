import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/theme/app_theme.dart';
import 'package:ophthalmology_clinical_record_system/views/calendar_page_view.dart';
import 'package:ophthalmology_clinical_record_system/views/dashboard_screen.dart';
import 'package:ophthalmology_clinical_record_system/views/patients_screen.dart';
import 'package:ophthalmology_clinical_record_system/views/prescription_view.dart';
import 'package:ophthalmology_clinical_record_system/widgets/page_header.dart';

void main() {
  // (title, subtitle, page) for every screen that opens with a PageHeader.
  final pages = <(String, String, Widget)>[
    ('Good morning, Dr. Sigrid Robillos, MD', 'Manage patient records, review examination history, and create digital prescriptions.', const DashboardScreen()),
    ('Clinical Calendar & Scheduling', 'Patient appointments, surgeries & locations', CalendarPageView()),
    ('Patient Directory', 'Search and manage clinical patient records with modern patient cards.', PatientsScreen(onSelectPatient: (_) {})),
    ('Prescriptions Workspace', 'Create, preview, and print clinical eye prescriptions.', const PrescriptionView()),
  ];

  for (final (title, subtitle, page) in pages) {
    testWidgets('"$title" uses the shared header sizes and position', (tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: page)));
      await tester.pumpAndSettle();

      final titleText = tester.widget<Text>(find.text(title));
      final subtitleText = tester.widget<Text>(find.text(subtitle));
      expect(titleText.style, PageHeader.titleStyle);
      expect(subtitleText.style, PageHeader.subtitleStyle);

      // Every header starts at the same point: the shared page padding.
      final topLeft = tester.getTopLeft(find.text(title));
      expect(topLeft.dx, PageHeader.pagePadding);
      expect(topLeft.dy, PageHeader.pagePadding);
    });
  }
}
