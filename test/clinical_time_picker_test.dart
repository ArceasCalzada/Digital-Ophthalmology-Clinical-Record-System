import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/theme/app_theme.dart';
import 'package:ophthalmology_clinical_record_system/widgets/clinical_time_picker.dart';

Future<void> openPicker(WidgetTester tester, TimeOfDay initial, void Function(TimeOfDay?) onResult) async {
  tester.view.physicalSize = const Size(900, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => onResult(await showClinicalTimePicker(context: context, initialTime: initial)),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

String fieldText(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(ValueKey(key))).controller!.text;

void main() {
  testWidgets('shows the initial time in fields; typing, nudging and AM/PM feed OK', (tester) async {
    TimeOfDay? picked;
    await openPicker(tester, const TimeOfDay(hour: 22, minute: 9), (t) => picked = t);

    // 10:09 PM
    expect(fieldText(tester, 'hour-field'), '10');
    expect(fieldText(tester, 'minute-field'), '09');

    await tester.enterText(find.byKey(const ValueKey('hour-field')), '3');
    await tester.enterText(find.byKey(const ValueKey('minute-field')), '44');
    await tester.tap(find.byKey(const ValueKey('minute-up')));
    await tester.tap(find.text('AM'));
    await tester.pumpAndSettle();
    expect(fieldText(tester, 'hour-field'), '3');
    expect(fieldText(tester, 'minute-field'), '45');

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(picked, const TimeOfDay(hour: 3, minute: 45));
  });

  testWidgets('up and down buttons nudge and wrap; the hour wraps without touching AM/PM', (tester) async {
    TimeOfDay? picked;
    await openPicker(tester, const TimeOfDay(hour: 23, minute: 59), (t) => picked = t); // 11:59 PM

    await tester.tap(find.byKey(const ValueKey('minute-up'))); // 59 -> 00, hour unchanged
    await tester.tap(find.byKey(const ValueKey('hour-up'))); // 11 -> 12
    await tester.tap(find.byKey(const ValueKey('hour-up'))); // 12 -> 1
    await tester.pumpAndSettle();
    expect(fieldText(tester, 'hour-field'), '1');
    expect(fieldText(tester, 'minute-field'), '00');

    await tester.tap(find.byKey(const ValueKey('hour-down'))); // 1 -> 12
    await tester.tap(find.byKey(const ValueKey('minute-down'))); // 00 -> 59
    await tester.pumpAndSettle();
    expect(fieldText(tester, 'hour-field'), '12');
    expect(fieldText(tester, 'minute-field'), '59');

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(picked, const TimeOfDay(hour: 12, minute: 59)); // 12:59 PM, still PM
  });

  testWidgets('typed values are cleaned up: 24-hour hours, 0, and out-of-range minutes', (tester) async {
    TimeOfDay? picked;
    await openPicker(tester, const TimeOfDay(hour: 9, minute: 30), (t) => picked = t);

    await tester.enterText(find.byKey(const ValueKey('hour-field')), '15'); // 3 PM
    await tester.enterText(find.byKey(const ValueKey('minute-field')), '99'); // clamped to 59
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(picked, const TimeOfDay(hour: 15, minute: 59));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('hour-field')), '0'); // 12 AM
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(picked, const TimeOfDay(hour: 0, minute: 30));
  });

  testWidgets('an empty field keeps its previous value, and non-digits are ignored', (tester) async {
    TimeOfDay? picked;
    await openPicker(tester, const TimeOfDay(hour: 14, minute: 7), (t) => picked = t);

    await tester.enterText(find.byKey(const ValueKey('hour-field')), '');
    await tester.enterText(find.byKey(const ValueKey('minute-field')), 'ab');
    expect(fieldText(tester, 'minute-field'), '');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(picked, const TimeOfDay(hour: 14, minute: 7));
  });

  testWidgets('Cancel returns nothing', (tester) async {
    TimeOfDay? picked = const TimeOfDay(hour: 1, minute: 0);
    await openPicker(tester, const TimeOfDay(hour: 9, minute: 30), (t) => picked = t);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(picked, isNull);
  });

  testWidgets('fits a 320 px phone screen without overflowing', (tester) async {
    await openPicker(tester, const TimeOfDay(hour: 10, minute: 38), (_) {});
    tester.view.physicalSize = const Size(320, 640);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('hour-field')), findsOneWidget);
  });
  testWidgets('has no tooltips, and the time group is centred in the dialog', (tester) async {
    await openPicker(tester, const TimeOfDay(hour: 10, minute: 38), (_) {});
    expect(find.byType(Tooltip), findsNothing);

    final dialog = tester.getRect(find.byType(Dialog));
    final group = Rect.fromLTRB(
      tester.getTopLeft(find.byKey(const ValueKey('hour-field'))).dx,
      0,
      tester.getTopRight(find.text('PM')).dx,
      0,
    );
    // Left and right gaps between the dialog edge and the time group are about equal.
    final leftGap = group.left - dialog.left;
    final rightGap = dialog.right - group.right;
    expect((leftGap - rightGap).abs(), lessThan(24));
  });

  testWidgets('holding an arrow keeps nudging until released; a plain tap nudges once', (tester) async {
    await openPicker(tester, const TimeOfDay(hour: 10, minute: 0), (_) {});
    int minute() => int.parse(fieldText(tester, 'minute-field'));

    await tester.tap(find.byKey(const ValueKey('minute-up')));
    await tester.pump(const Duration(seconds: 1)); // a released tap must not keep repeating
    expect(minute(), 1);

    final hold = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('minute-up'))));
    await tester.pump(const Duration(milliseconds: 100));
    expect(minute(), 2); // pressing nudges right away
    await tester.pump(const Duration(milliseconds: 200)); // still inside the hold delay
    expect(minute(), 2);
    await tester.pump(const Duration(milliseconds: 1000)); // now repeating
    final whileHeld = minute();
    expect(whileHeld, greaterThan(6));

    await hold.up();
    await tester.pump(const Duration(seconds: 1));
    expect(minute(), whileHeld); // released: it stops

    // Holding down works too, and the hour wraps.
    final holdDown = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('hour-down'))));
    await tester.pump(const Duration(milliseconds: 1500));
    await holdDown.up();
    await tester.pump(const Duration(seconds: 1));
    expect(int.parse(fieldText(tester, 'hour-field')), inInclusiveRange(1, 12));
    expect(int.parse(fieldText(tester, 'hour-field')), isNot(10));
  });

  testWidgets('there is no Now button', (tester) async {
    await openPicker(tester, const TimeOfDay(hour: 10, minute: 38), (_) {});
    expect(find.text('Now'), findsNothing);
  });
}