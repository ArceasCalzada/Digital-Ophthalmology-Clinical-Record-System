import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/services/reminder_settings_store.dart';
import 'package:ophthalmology_clinical_record_system/theme/app_theme.dart';
import 'package:ophthalmology_clinical_record_system/views/settings_view.dart';

void main() {
  test('reminder setting defaults to 30 minutes and ignores values that are not offered', () {
    final store = ReminderSettingsStore.instance;
    addTearDown(store.resetForTest);
    store.resetForTest();

    expect(store.minutesBefore, 30);
    store.minutesBefore = 7; // not one of the choices
    expect(store.minutesBefore, 30);
    store.minutesBefore = 1440;
    expect(store.minutesBefore, 1440);
  });

  testWidgets('System Preferences has the Notification Reminder Alert choice and it changes the setting', (tester) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final store = ReminderSettingsStore.instance;
    addTearDown(store.resetForTest);
    store.resetForTest();

    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: const Scaffold(body: SettingsView())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('System Preferences').first);
    await tester.pumpAndSettle();

    expect(find.text('Notification Reminder Alert'), findsOneWidget);
    for (final label in ['15 minutes before', '30 minutes before', '1 hour before', '1 day before']) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.ensureVisible(find.text('1 hour before'));
    await tester.tap(find.text('1 hour before'));
    await tester.pumpAndSettle();
    expect(store.minutesBefore, 60);
  });
}
