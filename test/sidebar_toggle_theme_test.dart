import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/theme/app_theme.dart';
import 'package:ophthalmology_clinical_record_system/views/main_layout.dart';

void main() {
  testWidgets('Sidebar toggle button adapts background color to light and dark theme', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Light Mode Test
    ThemeController.instance.setThemeMode(ThemeMode.light);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeController.instance.themeMode,
        home: Scaffold(body: MainLayout(onLogout: () {})),
      ),
    );
    await tester.pumpAndSettle();

    final toggleFinder = find.ancestor(
      of: find.byIcon(Icons.chevron_left),
      matching: find.byType(Material),
    ).first;
    expect(toggleFinder, findsOneWidget);

    Material lightMaterial = tester.widget<Material>(toggleFinder);
    expect(lightMaterial.color, equals(const Color(0xFFFFFFFF)));

    // Dark Mode Test
    ThemeController.instance.setThemeMode(ThemeMode.dark);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeController.instance.themeMode,
        home: Scaffold(body: MainLayout(onLogout: () {})),
      ),
    );
    await tester.pumpAndSettle();

    Material darkMaterial = tester.widget<Material>(toggleFinder);
    expect(darkMaterial.color, equals(const Color(0xFF1E293B)));
  });
}
