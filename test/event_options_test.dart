import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/models/calendar_event.dart';
import 'package:ophthalmology_clinical_record_system/services/event_options_store.dart';
import 'package:ophthalmology_clinical_record_system/theme/app_theme.dart';
import 'package:ophthalmology_clinical_record_system/views/calendar_page_view.dart';
import 'package:ophthalmology_clinical_record_system/widgets/filter_pill.dart';
import 'package:ophthalmology_clinical_record_system/widgets/add_event_modal.dart';

import 'add_event_modal_test.dart' show openModal;

Finder get _editPencil => find.byTooltip('Edit list');
Finder get _deleteButtons => find.byIcon(Icons.close_rounded);

void main() {
  final options = EventOptionsStore.instance;
  setUp(options.resetForTest);
  tearDown(options.resetForTest);

  group('the lists', () {
    test('start minimal: three event types and two locations', () {
      expect(options.types, ['Surgery', 'Checkup', 'Follow-up']);
      expect(options.locations, ['Bukidnon', 'Cebu']);
    });

    test('adding trims and tidies the name, and refuses blanks, duplicates and overlong names', () {
      expect(options.addType('  Laser   Procedure '), isTrue);
      expect(options.types.last, 'Laser Procedure');
      expect(options.addType('laser procedure'), isFalse, reason: 'same name, different case');
      expect(options.addType('   '), isFalse);
      expect(options.addType('x' * (EventOptionsStore.maxNameLength + 1)), isFalse);
      expect(options.types.length, 4);
    });

    test('the list has a size limit', () {
      for (var i = 0; options.types.length < EventOptionsStore.maxEntries; i++) {
        expect(options.addType('Type $i'), isTrue);
      }
      expect(options.addType('One too many'), isFalse);
    });

    test('removing takes the name off the list; removing something absent does nothing', () {
      options.removeLocation('Cebu');
      options.removeLocation('Nowhere');
      expect(options.locations, ['Bukidnon']);
    });
  });

  group('in the Add Event dropdowns', () {
    testWidgets('event type offers only Surgery, Checkup and Follow-up', (tester) async {
      await openModal(tester);

      await tester.tap(find.text('None').first);
      await tester.pumpAndSettle();
      for (final t in ['Surgery', 'Checkup', 'Follow-up']) {
        expect(find.text(t), findsOneWidget);
      }
      expect(find.text('IOP Check'), findsNothing);
      expect(find.text('Emergency'), findsNothing);
      expect(find.text('Laser Procedure'), findsNothing);
      await tester.tap(find.text('Surgery')); // choosing one closes the list
      await tester.pumpAndSettle();
      expect(find.text('Surgery'), findsOneWidget);
    });

    testWidgets('the pencil reveals an X beside each entry (not None), and Done hides them again', (tester) async {
      await openModal(tester);
      await tester.tap(find.text('None').first);
      await tester.pumpAndSettle();

      final xBefore = _deleteButtons.evaluate().length; // the modal's own close button
      expect(_editPencil, findsOneWidget);
      await tester.tap(_editPencil);
      await tester.pumpAndSettle();
      expect(_deleteButtons.evaluate().length - xBefore, 3, reason: 'one per event type, none for "None"');
      expect(find.text('Done'), findsOneWidget);

      // "+ Add new" keeps its full width beside "Done" (it used to be cut to "+ Add n...").
      final addNew = tester.renderObject<RenderParagraph>(find.text('+ Add new'));
      expect(addNew.size.width, greaterThanOrEqualTo(addNew.getMaxIntrinsicWidth(double.infinity)));
      expect(addNew.didExceedMaxLines, isFalse);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(_deleteButtons.evaluate().length, xBefore);
    });

    testWidgets('deleting asks first; Cancel keeps the entry, Delete removes it', (tester) async {
      await openModal(tester);
      await tester.tap(find.text('None').first);
      await tester.pumpAndSettle();
      await tester.tap(_editPencil);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Delete Checkup'));
      await tester.pumpAndSettle();
      expect(find.text('Delete event type?'), findsOneWidget);
      expect(find.textContaining('"Checkup" will be removed'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(options.types, contains('Checkup'));

      // The menu may have closed behind the dialog; open it again if so.
      if (find.byTooltip('Delete Checkup').evaluate().isEmpty) {
        await tester.tap(find.text('None').first);
        await tester.pumpAndSettle();
        await tester.tap(_editPencil);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byTooltip('Delete Checkup'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(options.types, ['Surgery', 'Follow-up']);
    });

    testWidgets('deleting the entry that is chosen clears the field back to None', (tester) async {
      await openModal(tester);
      await tester.tap(find.text('None').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Surgery'));
      await tester.pumpAndSettle();
      expect(find.text('Surgery'), findsOneWidget);

      await tester.tap(find.text('Surgery'));
      await tester.pumpAndSettle();
      await tester.tap(_editPencil);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete Surgery'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(options.types, ['Checkup', 'Follow-up']);
      expect(find.text('Surgery'), findsNothing, reason: 'gone from the list and from the field');
      expect(find.text('None'), findsWidgets);
    });

    testWidgets('a new event type can be typed in and joins the list', (tester) async {
      await openModal(tester);
      await tester.tap(find.text('None').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('+ Add new'));
      await tester.pumpAndSettle();
      // A name already on the list is refused: the existing entry lights up, then fades.
      Color rowColor() => tester.widget<ColoredBox>(find.ancestor(of: find.text('Checkup'), matching: find.byType(ColoredBox)).first).color;
      expect(rowColor().a, 0);
      await tester.enterText(find.widgetWithText(TextField, 'New event type name'), ' checkup ');
      await tester.tap(find.byTooltip('Add'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(rowColor().a, greaterThan(0.05), reason: 'the matching entry is highlighted');
      await tester.pumpAndSettle();
      expect(rowColor().a, 0, reason: 'and fades back');
      expect(options.types, ['Surgery', 'Checkup', 'Follow-up']);
      expect(find.widgetWithText(TextField, 'New event type name'), findsOneWidget, reason: 'the box stays open to correct the name');

      await tester.enterText(find.widgetWithText(TextField, 'New event type name'), 'Laser Procedure');
      await tester.tap(find.byTooltip('Add'));
      await tester.pumpAndSettle();
      expect(options.types, ['Surgery', 'Checkup', 'Follow-up', 'Laser Procedure']);
      expect(find.text('Laser Procedure'), findsOneWidget, reason: 'the open list shows it straight away');
    });

    testWidgets('an event whose type was deleted later still shows that type when edited', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      options.removeType('Follow-up');
      await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: const Scaffold(body: SizedBox())));
      final context = tester.element(find.byType(SizedBox));
      final repoEvent = CalendarEvent(
        id: 'evt-old-type',
        title: 'Old type',
        eventType: 'Follow-up',
        location: '',
        dateTime: DateTime(2030, 3, 4, 9),
        patientName: 'Someone',
      );
      AddEventModal.show(context, event: repoEvent);
      await tester.pumpAndSettle();

      expect(find.text('Follow-up'), findsOneWidget, reason: 'not shown as None');
    });
  });

  testWidgets('the calendar filters follow the lists and drop a filter that was deleted', (tester) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: CalendarPageView())));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Filter'));
    await tester.pumpAndSettle();

    expect(find.text('Follow-up'), findsWidgets);
    expect(find.text('Laser Procedure'), findsNothing);
    final pill = find.widgetWithText(FilterPill, 'Davao');
    expect(find.widgetWithText(FilterPill, 'Cebu'), findsOneWidget);
    expect(pill, findsNothing);

    options.addLocation('Davao');
    await tester.pumpAndSettle();
    expect(pill, findsOneWidget);

    await tester.tap(pill);
    await tester.pumpAndSettle();
    options.removeLocation('Davao');
    await tester.pumpAndSettle();
    expect(pill, findsNothing);
    expect(find.widgetWithText(FilterPill, 'All'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

