import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/main.dart';
import 'package:ophthalmology_clinical_record_system/models/patient.dart';
import 'package:ophthalmology_clinical_record_system/services/auth_service.dart';
import 'package:ophthalmology_clinical_record_system/services/clinic_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_auth_backend.dart';
import 'helpers/shake_finders.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.instance.resetForTesting();
  });

  // Attached inside each test body (not setUp) so the fake's stream events are
  // delivered in the widget test's fake-async zone and advance with tester.pump().
  Future<void> attachFakeAuth() => AuthService.instance.attach(FakeAuthBackend({
        'doc@clinic.test': (password: 'battery-staple', role: UserRole.physician),
      }));

  tearDown(() async {
    await AuthService.instance.resetForTesting();
    ClinicStore.instance.resetForTesting();
  });

  testWidgets('Login form starts empty, has no quick-access bypass, and rejects a wrong password', (WidgetTester tester) async {
    await attachFakeAuth();
    await tester.pumpWidget(const OphthalmologyApp());
    await tester.pump();

    expect(find.text('DOCRS Clinical System'), findsOneWidget);
    expect(find.text('Quick Access'), findsNothing);

    final fields = tester.widgetList<EditableText>(find.byType(EditableText)).toList();
    expect(fields.length, 2);
    expect(fields[0].controller.text, isEmpty, reason: 'email must not be prefilled');
    expect(fields[1].controller.text, isEmpty, reason: 'password must not be prefilled');

    // Empty submit is blocked by validation.
    final signInButton = find.text('Sign In to Workstation');
    await tester.ensureVisible(signInButton);
    await tester.tap(signInButton);
    await tester.pump();
    // Both required fields shake (no wording), and nothing signed in.
    await tester.pump(const Duration(milliseconds: 60));
    expect(shakeOffset(tester, find.byType(EditableText).at(0)), isNot(0));
    expect(shakeOffset(tester, find.byType(EditableText).at(1)), isNot(0));
    expect(find.text('Enter your email'), findsNothing);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('DOCRS'), findsNothing);

    // Wrong password shows an error and stays on the login screen.
    await tester.enterText(find.byType(EditableText).at(0), 'doc@clinic.test');
    await tester.enterText(find.byType(EditableText).at(1), 'wrong-password');
    await tester.tap(signInButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Incorrect email or password.'), findsOneWidget);
    expect(find.text('DOCRS'), findsNothing);
  });

  testWidgets('App renders LoginView and transitions to DOCRS workstation upon real sign in', (WidgetTester tester) async {
    await attachFakeAuth();
    // Populate test patient into repository for test assertions
    PatientRepository.addPatient(
      Patient(
        id: 'P-001',
        mrn: '2026-00192',
        fullName: 'Edgardo Asturias',
        dateOfBirth: '1978-05-14',
        gender: 'Male',
        phone: '+63 917 555 0192',
        address: 'Davao City',
        medicalHistory: ['Hypertension'],
        allergies: ['Penicillin'],
        encounters: [],
        lastVisitDate: '2026-07-30',
        totalVisits: 1,
      ),
    );

    await tester.pumpWidget(const OphthalmologyApp());
    await tester.pump();

    expect(find.text('DOCRS Clinical System'), findsOneWidget);
    expect(find.text('Sign In to Workstation'), findsOneWidget);

    await tester.enterText(find.byType(EditableText).at(0), 'doc@clinic.test');
    await tester.enterText(find.byType(EditableText).at(1), 'battery-staple');
    final signInButton = find.text('Sign In to Workstation');
    await tester.ensureVisible(signInButton);
    await tester.tap(signInButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    // A new account goes straight to the workstation; a clinic is asked for later.
    // Verify that DOCRS workstation is displayed
    expect(find.text('DOCRS'), findsOneWidget);
    expect(find.text('Name your clinic'), findsNothing);

    // Verify patient repository contains Edgardo Asturias from test setup
    final patients = PatientRepository.getAllPatients();
    expect(patients.any((p) => p.fullName == 'Edgardo Asturias'), isTrue);

    // Signing out returns to the login screen and clears patient data from memory.
    await AuthService.instance.signOut();
    await tester.pump();
    await tester.pump();
    expect(find.text('Sign In to Workstation'), findsOneWidget);
    expect(PatientRepository.getAllPatients(), isEmpty);
  });
}
