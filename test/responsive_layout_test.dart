import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/theme/app_theme.dart';
import 'package:ophthalmology_clinical_record_system/models/eye_exam.dart';
import 'package:ophthalmology_clinical_record_system/views/main_layout.dart';
import 'package:ophthalmology_clinical_record_system/views/prescription_view.dart';
import 'package:ophthalmology_clinical_record_system/widgets/drawing/eye_drawing_canvas.dart';
import 'package:ophthalmology_clinical_record_system/widgets/drawing/paper_sheet_canvas.dart';

void main() {
  group('Responsive Breakpoints Configuration Tests', () {
    test('ResponsiveBreakpoints constants are correctly defined', () {
      expect(ResponsiveBreakpoints.mobileMax, equals(599.0));
      expect(ResponsiveBreakpoints.tabletPortraitMax, equals(768.0));
      expect(ResponsiveBreakpoints.tabletLandscapeMax, equals(1024.0));
      expect(ResponsiveBreakpoints.desktopMin, equals(1025.0));
    });

    testWidgets('AppTheme responsive helper extensions function correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(768, 1024)),
          child: Builder(
            builder: (context) {
              expect(AppTheme.isTablet(context), isTrue);
              expect(AppTheme.isDesktop(context), isFalse);
              return Container();
            },
          ),
        ),
      );
    });
  });

  group('Prescriptions Workspace Stacking Tests', () {
    testWidgets('PrescriptionView stacks medication form and pad preview vertically on tablet viewport (768px)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PrescriptionView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add Ophthalmic Medication'), findsOneWidget);
      expect(find.text('Live Prescription Pad Preview'), findsOneWidget);

      // Verify vertically stacked layout by comparing Y offsets (Form above Preview)
      final formPos = tester.getTopLeft(find.text('Add Ophthalmic Medication'));
      final previewPos = tester.getTopLeft(find.text('Live Prescription Pad Preview'));

      expect(previewPos.dy, greaterThan(formPos.dy), reason: 'Pad preview must stack below medication form on tablet');
    });

    testWidgets('PrescriptionView places form and preview side-by-side on desktop viewport (1280px)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PrescriptionView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final formPos = tester.getTopLeft(find.text('Add Ophthalmic Medication'));
      final previewPos = tester.getTopLeft(find.text('Live Prescription Pad Preview'));

      expect(previewPos.dx, greaterThan(formPos.dx), reason: 'Pad preview must sit to the right of medication form on desktop');
    });
  });

  group('Clinical Consultation Record PaperSheetCanvas Fluid Scaling', () {
    testWidgets('PaperSheetCanvas fits inside 768px viewport without overflow', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PaperSheetCanvas(
                onStrokesChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PaperSheetCanvas), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'Must not throw layout/overflow exceptions on tablet size');
    });

    testWidgets('EyeDrawingCanvas scales proportionally on tablet portrait (768px) and landscape (1024px)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 350,
                height: 480,
                child: EyeDrawingCanvas(
                  eye: EyeType.OD,
                  onEyeChanged: (_) {},
                  onDrawingSaved: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EyeDrawingCanvas), findsOneWidget);
      expect(find.text('OD'), findsOneWidget);
      expect(find.text('OS'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Switch to OS
      await tester.tap(find.text('OS'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('Sidebar Responsive Auto-Collapse Tests', () {
    testWidgets('MainLayout defaults sidebar to collapsed mode on tablet screen (768px)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: MainLayout(onLogout: () {}),
        ),
      );
      await tester.pumpAndSettle();

      // In collapsed mode (72px rail), text 'DOCRS' is hidden in header
      expect(find.text('DOCRS'), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('MainLayout expands sidebar on desktop screen (1280px)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: MainLayout(onLogout: () {}),
        ),
      );
      await tester.pumpAndSettle();

      // On desktop, full header title is visible
      expect(find.text('DOCRS'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    });
  });
}
