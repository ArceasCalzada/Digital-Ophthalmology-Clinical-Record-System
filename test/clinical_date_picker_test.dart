import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/theme/app_theme.dart';
import 'package:ophthalmology_clinical_record_system/widgets/clinical_date_picker.dart';

/// Opens the picker like the date-of-birth field does: initial 1985-06-15, last date "now".
Future<void> openPicker(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showClinicalDatePicker(
              context: context,
              initialDate: DateTime(1985, 6, 15),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Today moves the calendar to the current month and returns today', (tester) async {
    DateTime? picked;
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                picked = await showClinicalDatePicker(
                  context: context,
                  initialDate: DateTime(1985, 6, 15),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('June 1985'), findsOneWidget);

    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    final now = DateTime.now();
    expect(find.text('${_month(now.month)} ${now.year}'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(picked, DateTime(now.year, now.month, now.day));
  });

  testWidgets('month and year are dropdowns with no icons, and the arrows sit on a row below them', (tester) async {
    await openPicker(tester);

    // The list opens directly below the field (not on top of it) and holds plain text only.
    final monthField = tester.getRect(find.ancestor(of: find.text('June'), matching: find.byType(InkWell)).first);
    await tester.tap(find.text('June'));
    await tester.pumpAndSettle();
    expect(find.text('March'), findsOneWidget);
    expect(tester.getTopLeft(find.text('March')).dy, greaterThanOrEqualTo(monthField.bottom));
    expect(find.byIcon(Icons.calendar_month_rounded), findsNothing);
    expect(find.byIcon(Icons.date_range_rounded), findsNothing);
    await tester.tap(find.text('March').last);
    await tester.pumpAndSettle();
    expect(find.text('March 1985'), findsOneWidget, reason: 'the shown month follows the dropdown');

    // Layout: dropdowns on top, arrows underneath.
    final dropdownY = tester.getCenter(find.text('March')).dy;
    final arrowY = tester.getCenter(find.byIcon(Icons.chevron_left)).dy;
    expect(arrowY, greaterThan(dropdownY));

    // The year dropdown lists years as text and changes the shown year.
    final yearField = tester.getRect(find.ancestor(of: find.text('1985'), matching: find.byType(InkWell)).first);
    await tester.tap(find.text('1985'));
    await tester.pumpAndSettle();
    // The list starts scrolled to the chosen year, so its neighbours are in view, below the field.
    expect(tester.getTopLeft(find.text('1986')).dy, greaterThanOrEqualTo(yearField.bottom));
    await tester.tap(find.text('1986'));
    await tester.pumpAndSettle();
    expect(find.text('March 1986'), findsOneWidget);
  });

  testWidgets('the year list always has at least 10 scrollable years, out-of-range ones greyed out', (tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // A narrow range (2 years), like the event date field used to have.
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showClinicalDatePicker(
                context: context,
                initialDate: DateTime(2027, 3, 5),
                firstDate: DateTime(2026, 9, 1),
                lastDate: DateTime(2027, 9, 1),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('2027'));
    await tester.pumpAndSettle();
    final list = find.byType(ListView);
    expect(list, findsOneWidget);
    final scrollable = tester.state<ScrollableState>(find.descendant(of: list, matching: find.byType(Scrollable)));
    // 10 rows of 40px do not fit in the list, so it scrolls.
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    expect(scrollable.position.maxScrollExtent + scrollable.position.viewportDimension, closeTo(400, 0.5));
  });

  testWidgets('choosing the last allowed year pulls the month back into range', (tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showClinicalDatePicker(
                context: context,
                initialDate: DateTime(2020, 12, 5),
                firstDate: DateTime(2019, 3, 1),
                lastDate: DateTime(2021, 4, 20),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('December 2020'), findsOneWidget);

    await tester.tap(find.text('2020'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2021'));
    await tester.pumpAndSettle();
    expect(find.text('April 2021'), findsOneWidget, reason: 'December 2021 is after the last allowed date');
  });
}

String _month(int m) => const [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ][m - 1];
