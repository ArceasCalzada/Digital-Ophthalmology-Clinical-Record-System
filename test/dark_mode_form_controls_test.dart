import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ophthalmology_clinical_record_system/theme/app_theme.dart';
import 'package:ophthalmology_clinical_record_system/widgets/clinical_dropdown_field.dart';
import 'package:ophthalmology_clinical_record_system/widgets/clinical_modal_picker.dart';
import 'package:ophthalmology_clinical_record_system/widgets/clinical_date_picker.dart';
import 'package:ophthalmology_clinical_record_system/widgets/clinical_time_picker.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    ThemeController.instance.setThemeMode(ThemeMode.light);
  });

  group('Dark Mode Form Controls Audit', () {
    testWidgets('AppTheme darkTheme specifies dark canvasColor and dropdown/picker themes', (tester) async {
      final dark = AppTheme.darkTheme;
      expect(dark.canvasColor, const Color(0xFF1E293B));
      expect(dark.cardColor, const Color(0xFF1E293B));
      expect(dark.dropdownMenuTheme.menuStyle?.backgroundColor?.resolve({}), const Color(0xFF1E293B));
      expect(dark.popupMenuTheme.color, const Color(0xFF1E293B));
      expect(dark.datePickerTheme.backgroundColor, const Color(0xFF1E293B));
      expect(dark.timePickerTheme.backgroundColor, const Color(0xFF1E293B));
      expect(dark.timePickerTheme.hourMinuteColor, const Color(0xFF0F172A));
    });

    testWidgets('DropdownButton renders with dark background and proper text in Dark Mode', (tester) async {
      ThemeController.instance.setThemeMode(ThemeMode.dark);

      int selected = 20;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Container(
                  key: const Key('dropdown_container'),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      key: const Key('test_dropdown'),
                      value: selected,
                      isDense: true,
                      dropdownColor: AppTheme.cardBg,
                      iconEnabledColor: AppTheme.textPrimary,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                      items: const [10, 20, 50].map((size) {
                        return DropdownMenuItem<int>(
                          value: size,
                          child: Text('$size', style: TextStyle(color: AppTheme.textPrimary)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => selected = val);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check container decoration color
      final container = tester.widget<Container>(find.byKey(const Key('dropdown_container')));
      final boxDecoration = container.decoration as BoxDecoration;
      expect(boxDecoration.color, const Color(0xFF1E293B)); // dark cardBg

      // Tap dropdown to open popup menu
      await tester.tap(find.byKey(const Key('test_dropdown')));
      await tester.pumpAndSettle();

      // Verify dropdown popup menu items exist
      expect(find.text('10'), findsWidgets);
      expect(find.text('20'), findsWidgets);
      expect(find.text('50'), findsWidgets);
    });

    testWidgets('ClinicalDropdownField adapts to Dark Mode', (tester) async {
      ThemeController.instance.setThemeMode(ThemeMode.dark);

      String selected = 'Follow-Up';

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: Scaffold(
            body: ClinicalDropdownField<String>(
              label: Text('Event Type', style: TextStyle(color: AppTheme.textPrimary)),
              value: selected,
              searchable: true,
              items: [
                ClinicalPickerItem(value: 'Follow-Up', label: 'Follow-Up'),
                ClinicalPickerItem(value: 'Check-Up', label: 'Check-Up'),
                ClinicalPickerItem(value: 'Surgery', label: 'Surgery'),
              ],
              onChanged: (val) => selected = val,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Expect field trigger is rendered with dark colors
      final inkWellFinder = find.byType(InkWell);
      expect(inkWellFinder, findsWidgets);

      // Open dropdown menu
      await tester.tap(inkWellFinder.first);
      await tester.pumpAndSettle();

      // Verify the search field has dark theme styling
      expect(find.byType(TextField), findsOneWidget);
      final searchField = tester.widget<TextField>(find.byType(TextField));
      expect(searchField.style?.color, const Color(0xFFF8FAFC));
      expect(searchField.decoration?.fillColor, const Color(0xFF0F172A)); // AppTheme.lightBg in dark mode
    });

    testWidgets('ClinicalDatePicker renders with dark background in Dark Mode', (tester) async {
      ThemeController.instance.setThemeMode(ThemeMode.dark);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showClinicalDatePicker(
                      context: context,
                      initialDate: DateTime(2026, 11, 8),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                  },
                  child: const Text('Open Date Picker'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Date Picker'));
      await tester.pumpAndSettle();

      // Verify dialog has dark background
      final dialog = tester.widget<Dialog>(find.byType(Dialog));
      expect(dialog.backgroundColor, const Color(0xFF1E293B));

      // Month name text is visible with darkTextPrimary
      expect(find.text('November 2026'), findsOneWidget);
    });

    testWidgets('ClinicalTimePicker renders with dark background and styled number steppers', (tester) async {
      ThemeController.instance.setThemeMode(ThemeMode.dark);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showClinicalTimePicker(
                      context: context,
                      initialTime: const TimeOfDay(hour: 10, minute: 30),
                    );
                  },
                  child: const Text('Open Time Picker'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Time Picker'));
      await tester.pumpAndSettle();

      // Verify dialog has dark background
      final dialog = tester.widget<Dialog>(find.byType(Dialog));
      expect(dialog.backgroundColor, const Color(0xFF1E293B));

      // Verify hour and minute text fields use dark fill and textPrimary color
      final hourField = tester.widget<TextField>(find.byKey(const ValueKey('hour-field')));
      expect(hourField.style?.color, const Color(0xFFF8FAFC));
      expect(hourField.decoration?.fillColor, const Color(0xFF0F172A));

      final minuteField = tester.widget<TextField>(find.byKey(const ValueKey('minute-field')));
      expect(minuteField.style?.color, const Color(0xFFF8FAFC));
      expect(minuteField.decoration?.fillColor, const Color(0xFF0F172A));
    });

    testWidgets('Toggling theme mode instantly updates AppTheme colors', (tester) async {
      ThemeController.instance.setThemeMode(ThemeMode.light);
      expect(AppTheme.cardBg, const Color(0xFFFFFFFF));
      expect(AppTheme.lightBg, const Color(0xFFF8FAFC));
      expect(AppTheme.textPrimary, const Color(0xFF0F172A));

      ThemeController.instance.setThemeMode(ThemeMode.dark);
      expect(AppTheme.cardBg, const Color(0xFF1E293B));
      expect(AppTheme.lightBg, const Color(0xFF0F172A));
      expect(AppTheme.textPrimary, const Color(0xFFF8FAFC));
    });
  });
}
