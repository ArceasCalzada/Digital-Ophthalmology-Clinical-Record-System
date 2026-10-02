import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/models/patient.dart';
import 'package:ophthalmology_clinical_record_system/theme/app_theme.dart';
import 'package:ophthalmology_clinical_record_system/views/new_patient_modal.dart';
import 'package:ophthalmology_clinical_record_system/views/patients_screen.dart';
import 'helpers/shake_finders.dart';

Future<List<Patient>> openModal(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1000, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  final created = <Patient>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog(
              context: context,
              builder: (_) => NewPatientModal(onPatientCreated: created.add),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return created;
}

/// The red asterisk next to a label, if it has one.
bool hasRedAsterisk(WidgetTester tester, String label) {
  final matches = find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText() == '$label *');
  if (matches.evaluate().isEmpty) return false;
  TextSpan? star;
  tester.widget<RichText>(matches.first).text.visitChildren((span) {
    if (span is TextSpan && span.text == ' *') star = span;
    return true;
  });
  return star?.style?.color == const Color(0xFFDC2626);
}

void main() {
  testWidgets('date of birth and gender start empty, and the required fields have a red asterisk', (tester) async {
    await openModal(tester);

    // Nothing is pre-filled.
    final dob = tester.widget<TextField>(find.widgetWithText(TextField, 'Jun 15, 1985'));
    expect(dob.controller!.text, isEmpty);
    expect(find.text('Select gender'), findsOneWidget);
    expect(find.text('Male'), findsNothing);

    for (final label in ['First Name', 'Last Name', 'Date of Birth', 'Sex / Gender']) {
      expect(hasRedAsterisk(tester, label), isTrue, reason: '$label is required');
    }
    expect(hasRedAsterisk(tester, 'Middle Name'), isFalse);
    expect(hasRedAsterisk(tester, 'Contact Phone Number'), isFalse);

    // The patient ID is not on the form at all: it is assigned when the patient is saved.
    expect(find.textContaining('Patient ID'), findsNothing);
    expect(find.textContaining('MRN'), findsNothing);
    expect(find.textContaining('PT-'), findsNothing);
  });

  testWidgets('the age shows under the birthday as it is typed, and bad dates are refused', (tester) async {
    final created = await openModal(tester);
    final dobField = find.widgetWithText(TextFormField, 'Jun 15, 1985');

    expect(find.textContaining('Age:'), findsNothing);
    await tester.enterText(dobField, '1990-01-02');
    await tester.pump();
    expect(find.text('Age: ${formatAge('1990-01-02')}'), findsOneWidget);

    await tester.enterText(dobField, 'banana');
    await tester.pump();
    expect(find.textContaining('Age:'), findsNothing);

    await tester.tap(find.text('Register Patient'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid date, e.g. Jun 15, 1985'), findsOneWidget);

    final nextYear = DateTime.now().year + 1;
    await tester.enterText(dobField, '$nextYear-01-01');
    await tester.pump();
    await tester.tap(find.text('Register Patient'));
    await tester.pumpAndSettle();
    expect(find.text('Date is in the future'), findsOneWidget);
    expect(created, isEmpty);
  });

  testWidgets('registering with the required fields empty is refused, and each one says so', (tester) async {
    final created = await openModal(tester);

    final firstName = find.widgetWithText(TextFormField, 'e.g. Elena');
    final lastName = find.widgetWithText(TextFormField, 'e.g. Rostova');
    final dob = find.widgetWithText(TextFormField, 'Jun 15, 1985');
    final gender = find.text('Select gender');

    await tester.tap(find.text('Register Patient'));
    await letShakeStart(tester);
    // Each missing required field shakes; nothing says "Required".
    for (final field in [firstName, lastName, dob, gender]) {
      expect(shakeOffset(tester, field), isNot(0));
    }
    expect(find.text('Required'), findsNothing);
    expect(created, isEmpty);

    await tester.pumpAndSettle();
    expect(shakeOffset(tester, firstName), 0, reason: 'the shake settles');
  });

  testWidgets('a field that is filled in does not shake', (tester) async {
    await openModal(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'e.g. Elena'), 'Someone');

    await tester.tap(find.text('Register Patient'));
    await letShakeStart(tester);
    expect(shakeOffset(tester, find.widgetWithText(TextFormField, 'e.g. Elena')), 0);
    expect(shakeOffset(tester, find.text('Select gender')), isNot(0));
    await tester.pumpAndSettle();
  });

  testWidgets('gender is a dropdown under its field, and notes can be added', (tester) async {
    await openModal(tester);
    final dialogsBefore = find.byType(Dialog).evaluate().length + find.byType(AlertDialog).evaluate().length;

    final genderField = tester.getRect(find.ancestor(of: find.text('Select gender'), matching: find.byType(InkWell)).first);
    await tester.tap(find.text('Select gender'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog).evaluate().length + find.byType(AlertDialog).evaluate().length, dialogsBefore, reason: 'no pop-up');
    expect(tester.getTopLeft(find.text('Female')).dy, greaterThanOrEqualTo(genderField.bottom));
    await tester.tap(find.text('Female'));
    await tester.pumpAndSettle();
    expect(find.text('Select gender'), findsNothing);

    expect(find.text('Notes'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Anything else worth knowing about this patient'), findsOneWidget);
  });

  testWidgets('choosing a gender clears its error and the patient is saved with it', (tester) async {
    final created = await openModal(tester);
    final before = PatientRepository.getAllPatients().length;
    // The repository is shared by every test; drop the patient this one saves.
    addTearDown(PatientRepository.disconnect);

    await tester.tap(find.text('Register Patient'));
    await tester.pumpAndSettle();
    expect(created, isEmpty);

    await tester.enterText(find.widgetWithText(TextFormField, 'e.g. Elena'), 'Test');
    await tester.enterText(find.widgetWithText(TextFormField, 'e.g. Marie'), 'John');
    await tester.enterText(find.widgetWithText(TextFormField, 'e.g. Rostova'), 'Patient');
    await tester.enterText(find.widgetWithText(TextFormField, 'Jun 15, 1985'), '1990-01-02');
    await tester.enterText(find.widgetWithText(TextFormField, 'Anything else worth knowing about this patient'), 'Prefers morning appointments');
    await tester.tap(find.text('Select gender'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Female'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Register Patient'));
    await tester.pumpAndSettle();
    expect(created.single.gender, 'Female');
    expect(created.single.firstName, 'Test');
    expect(created.single.middleName, 'John');
    expect(created.single.lastName, 'Patient');
    expect(created.single.fullName, 'Test John Patient');
    expect(created.single.notes, 'Prefers morning appointments');
    expect(created.single.dateOfBirth, 'Jan 2, 1990', reason: 'stored in one format, however it was entered');
    // The hidden patient ID is assigned on save, in the app's PT-###### form.
    expect(created.single.mrn, matches(RegExp(r'^PT-\d{6}$')));
    expect(PatientRepository.getAllPatients().length, before + 1);
    // Saving queues a cloud sync behind a short timer; let it run before the test ends.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('quick filters wrap onto a second line on a narrow screen instead of running off the card', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: PatientsScreen(onSelectPatient: (_) {})),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('MRN'), findsNothing, reason: 'the search prompt does not ask for a patient ID');
    final label = tester.getRect(find.text('Quick Filters:'));
    for (final pill in ['All', 'Glaucoma', 'Diabetic Retinopathy', 'Cataract']) {
      final rect = tester.getRect(find.text(pill));
      expect(rect.right, lessThanOrEqualTo(420 - 24), reason: '"$pill" must stay inside the card');
    }
    // Something had to move to the next line to make room.
    expect(tester.getRect(find.text('Cataract')).top, greaterThan(label.top + 10));
  });
}
