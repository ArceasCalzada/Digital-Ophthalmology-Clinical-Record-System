import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/models/patient.dart';
import 'package:ophthalmology_clinical_record_system/services/auth_service.dart';
import 'package:ophthalmology_clinical_record_system/services/examination_preferences_store.dart';
import 'package:ophthalmology_clinical_record_system/theme/app_theme.dart';
import 'package:ophthalmology_clinical_record_system/views/eye_exam_view.dart';
import 'package:ophthalmology_clinical_record_system/views/main_layout.dart';
import 'package:ophthalmology_clinical_record_system/views/patient_profile_view.dart';
import 'package:ophthalmology_clinical_record_system/views/prescription_view.dart';
import 'package:ophthalmology_clinical_record_system/views/settings_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_auth_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAuthBackend backend;

  final testPatient = Patient(
    id: 'pt-nav-test-01',
    mrn: 'MRN-NAV-2026',
    fullName: 'Eleanor Vance',
    dateOfBirth: '1988-04-12',
    gender: 'Female',
    phone: '+63 917 123 4567',
    address: 'Davao City, Philippines',
    medicalHistory: const ['DM', 'HPN'],
    allergies: const ['Penicillin'],
    encounters: const [],
    lastVisitDate: '2026-10-10',
    totalVisits: 1,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.instance.resetForTesting();
    ExaminationPreferencesStore.instance.reset();
    PatientRepository.clearForTesting();
    PatientRepository.addPatient(testPatient);
  });

  tearDown(() async {
    await AuthService.instance.resetForTesting();
    ExaminationPreferencesStore.instance.reset();
    PatientRepository.clearForTesting();
  });

  Future<void> attachBackend() async {
    backend = FakeAuthBackend({
      'doctor@clinic.test': (password: 'Doctor@123', role: UserRole.physician),
    });
    await AuthService.instance.attach(backend);
  }

  Patient createSamplePatient({String id = 'pat-100', String name = 'Eleanor Vance'}) {
    return Patient(
      id: id,
      mrn: 'MRN-2026-001',
      fullName: name,
      middleName: 'M',
      dateOfBirth: '1980-05-15',
      gender: 'Female',
      phone: '09175550192',
      address: 'Davao City',
      occupation: 'Engineer',
      phicNumber: 'PHIC-123',
      referringDoctor: 'Dr. Calzada',
      medicalHistory: [],
      allergies: [],
      previousDiagnoses: [],
      previousPrescriptions: [],
      prescriptions: [],
      encounters: [],
      lastVisitDate: '2026-11-20',
      totalVisits: 2,
    );
  }

  group('ExaminationPreferencesStore Persistence & Mapping Unit Tests', () {
    test('initial defaults are Standard 2-Column, Fundus / Retina Map, and Patient EHR Profile', () {
      final store = ExaminationPreferencesStore.instance;
      expect(store.defaultExamLayout, ExaminationPreferencesStore.layoutStandard2Column);
      expect(store.defaultDrawingTemplate, ExaminationPreferencesStore.templateFundus);
      expect(store.defaultPatientView, ExaminationPreferencesStore.viewEhrProfile);
      expect(store.templateDiagramType, 'fundus');
    });

    test('templateDiagramType correctly maps human readable template to diagram identifier', () {
      final store = ExaminationPreferencesStore.instance;

      store.fromMap({'defaultDrawingTemplate': ExaminationPreferencesStore.templateFundus});
      expect(store.templateDiagramType, 'fundus');

      store.fromMap({'defaultDrawingTemplate': ExaminationPreferencesStore.templateAnterior});
      expect(store.templateDiagramType, 'anterior');

      store.fromMap({'defaultDrawingTemplate': ExaminationPreferencesStore.templateExternal});
      expect(store.templateDiagramType, 'plain');
    });

    test('updatePreferences persists to SharedPreferences locally and can be reloaded', () async {
      final store = ExaminationPreferencesStore.instance;

      await store.updatePreferences(
        examLayout: ExaminationPreferencesStore.layoutExpandedSingleCanvas,
        drawingTemplate: ExaminationPreferencesStore.templateAnterior,
        patientView: ExaminationPreferencesStore.viewNewExam,
        uid: 'doc_123',
      );

      expect(store.defaultExamLayout, ExaminationPreferencesStore.layoutExpandedSingleCanvas);
      expect(store.defaultDrawingTemplate, ExaminationPreferencesStore.templateAnterior);
      expect(store.defaultPatientView, ExaminationPreferencesStore.viewNewExam);

      // Verify in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('examination_preferences_doc_123');
      expect(raw, isNotNull);
      final map = jsonDecode(raw!) as Map<String, dynamic>;
      expect(map['defaultExamLayout'], ExaminationPreferencesStore.layoutExpandedSingleCanvas);
      expect(map['defaultDrawingTemplate'], ExaminationPreferencesStore.templateAnterior);
      expect(map['defaultPatientView'], ExaminationPreferencesStore.viewNewExam);

      // Reset store and reload from storage
      store.reset();
      expect(store.defaultExamLayout, ExaminationPreferencesStore.layoutStandard2Column);

      await store.loadLocal('doc_123');
      expect(store.defaultExamLayout, ExaminationPreferencesStore.layoutExpandedSingleCanvas);
      expect(store.defaultDrawingTemplate, ExaminationPreferencesStore.templateAnterior);
      expect(store.defaultPatientView, ExaminationPreferencesStore.viewNewExam);
    });
  });

  group('EyeExamView Dynamic Layout & Template Pre-selection Tests', () {
    testWidgets('EyeExamView initializes with Standard 2-Column layout and Fundus template by default', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final patient = createSamplePatient();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: EyeExamView(
            patient: patient,
          ),
        ),
      );
      await tester.pump();

      // Check layout and template indicators in AppBar
      expect(find.byKey(const Key('exam_layout_indicator')), findsOneWidget);
      expect(find.byKey(const Key('exam_template_indicator')), findsOneWidget);
      expect(find.text('Standard 2-Column'), findsWidgets);
      expect(find.text('Fundus / Retina Map'), findsWidgets);

      // Verify Standard 2-Column body contains both the paper canvas and clinical findings panel
      expect(find.byKey(const Key('exam_layout_standard_2_column')), findsOneWidget);
      expect(find.byKey(const Key('exam_clinical_findings_panel')), findsOneWidget);
      expect(find.byKey(const Key('eye_exam_paper_canvas')), findsOneWidget);
      expect(find.byKey(const Key('paper_sheet_template_badge')), findsOneWidget);
    });

    testWidgets('EyeExamView initializes with Expanded Single Canvas when configured in preferences', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      ExaminationPreferencesStore.instance.fromMap({
        'defaultExamLayout': ExaminationPreferencesStore.layoutExpandedSingleCanvas,
        'defaultDrawingTemplate': ExaminationPreferencesStore.templateAnterior,
      });

      final patient = createSamplePatient();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: EyeExamView(
            patient: patient,
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('exam_layout_expanded_single_canvas')), findsOneWidget);
      expect(find.byKey(const Key('exam_clinical_findings_panel')), findsNothing);
      expect(find.text('Expanded Single Canvas'), findsWidgets);
      expect(find.text('Anterior Segment / Cornea'), findsWidgets);
    });

    testWidgets('EyeExamView initializes with Clinical Tabbed layout when configured in preferences', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      ExaminationPreferencesStore.instance.fromMap({
        'defaultExamLayout': ExaminationPreferencesStore.layoutClinicalTabbed,
        'defaultDrawingTemplate': ExaminationPreferencesStore.templateExternal,
      });

      final patient = createSamplePatient();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: EyeExamView(
            patient: patient,
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('exam_layout_clinical_tabbed')), findsOneWidget);
      expect(find.byKey(const Key('tab_exam_paper_chart')), findsOneWidget);
      expect(find.byKey(const Key('tab_exam_acuity_refraction')), findsOneWidget);
      expect(find.byKey(const Key('tab_exam_findings')), findsOneWidget);
      expect(find.text('External Eye & Lids'), findsWidgets);
    });
  });

  group('SettingsView Examination Preferences UI & Feedback Tests', () {
    testWidgets('Changing dropdowns in SettingsView updates store and triggers confirmation modal', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await attachBackend();
      await AuthService.instance.signIn('doctor@clinic.test', 'Doctor@123');

      final store = ExaminationPreferencesStore.instance;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: SettingsView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to System Preferences
      final systemTab = find.text('System Preferences');
      expect(systemTab, findsOneWidget);
      await tester.tap(systemTab);
      await tester.pumpAndSettle();

      expect(find.text('Examination Preferences'), findsOneWidget);
      expect(find.byKey(const Key('dropdown_default_exam_layout')), findsOneWidget);
      expect(find.byKey(const Key('dropdown_default_drawing_template')), findsOneWidget);
      expect(find.byKey(const Key('dropdown_default_patient_view')), findsOneWidget);

      // 1. Change Layout dropdown to 'Expanded Single Canvas'
      await tester.tap(find.byKey(const Key('dropdown_default_exam_layout')));
      await tester.pumpAndSettle();

      final expandedOption = find.text('Expanded Single Canvas').last;
      await tester.tap(expandedOption);
      await tester.pumpAndSettle();

      expect(store.defaultExamLayout, ExaminationPreferencesStore.layoutExpandedSingleCanvas);
      expect(find.text('Settings Saved Successfully'), findsOneWidget);
      expect(find.text('Default examination layout updated to Expanded Single Canvas.'), findsOneWidget);

      // Dismiss modal
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // 2. Change Template dropdown to 'Anterior Segment / Cornea'
      await tester.tap(find.byKey(const Key('dropdown_default_drawing_template')));
      await tester.pumpAndSettle();

      final anteriorOption = find.text('Anterior Segment / Cornea').last;
      await tester.tap(anteriorOption);
      await tester.pumpAndSettle();

      expect(store.defaultDrawingTemplate, ExaminationPreferencesStore.templateAnterior);
      expect(find.text('Settings Saved Successfully'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // 3. Change Patient View dropdown to 'New Eye Exam Workstation'
      await tester.tap(find.byKey(const Key('dropdown_default_patient_view')));
      await tester.pumpAndSettle();

      final newExamOption = find.text('New Eye Exam Workstation').last;
      await tester.tap(newExamOption);
      await tester.pumpAndSettle();

      expect(store.defaultPatientView, ExaminationPreferencesStore.viewNewExam);
      expect(find.text('Settings Saved Successfully'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // 4. Test "Save Preferences" button saves all current preferences
      final saveBtn = find.text('Save Preferences');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(find.text('Settings Saved Successfully'), findsOneWidget);
      expect(find.text('Examination and system preferences saved successfully.'), findsOneWidget);
    });
  });

  group('Patient Selection Dynamic Routing Tests', () {
    testWidgets('Opening patient routes directly to New Eye Exam Workstation when configured', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await attachBackend();
      await AuthService.instance.signIn('doctor@clinic.test', 'Doctor@123');

      ExaminationPreferencesStore.instance.fromMap({
        'defaultPatientView': ExaminationPreferencesStore.viewNewExam,
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MainLayout(onLogout: () {}),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Click Eleanor Vance
      final patientName = find.text('Eleanor Vance');
      expect(patientName, findsWidgets);
      await tester.ensureVisible(patientName.first);
      await tester.tap(patientName.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Directly routes into EyeExamView (Clinical Consultation Record)
      expect(find.byType(EyeExamView), findsOneWidget);
      expect(find.text('Clinical Consultation Record'), findsOneWidget);
    });

    testWidgets('Opening patient routes directly to Prescriptions when configured', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await attachBackend();
      await AuthService.instance.signIn('doctor@clinic.test', 'Doctor@123');

      ExaminationPreferencesStore.instance.fromMap({
        'defaultPatientView': ExaminationPreferencesStore.viewPrescriptions,
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MainLayout(onLogout: () {}),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final patientName = find.text('Eleanor Vance');
      expect(patientName, findsWidgets);
      await tester.ensureVisible(patientName.first);
      await tester.tap(patientName.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Directly routes into PrescriptionView
      expect(find.byType(PrescriptionView), findsOneWidget);
    });

    testWidgets('Opening patient routes to Past Encounters Timeline tab when configured', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await attachBackend();
      await AuthService.instance.signIn('doctor@clinic.test', 'Doctor@123');

      ExaminationPreferencesStore.instance.fromMap({
        'defaultPatientView': ExaminationPreferencesStore.viewEncountersTimeline,
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MainLayout(onLogout: () {}),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final patientName = find.text('Eleanor Vance');
      expect(patientName, findsWidgets);
      await tester.ensureVisible(patientName.first);
      await tester.tap(patientName.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Opens PatientProfileView with initialTabIndex = 1 (Examination History / Timeline)
      expect(find.byType(PatientProfileView), findsOneWidget);
      final profileView = tester.widget<PatientProfileView>(find.byType(PatientProfileView));
      expect(profileView.initialTabIndex, 1);
    });

    testWidgets('Opening patient routes to Patient EHR Profile (Overview) by default', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await attachBackend();
      await AuthService.instance.signIn('doctor@clinic.test', 'Doctor@123');

      ExaminationPreferencesStore.instance.fromMap({
        'defaultPatientView': ExaminationPreferencesStore.viewEhrProfile,
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MainLayout(onLogout: () {}),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final patientName = find.text('Eleanor Vance');
      expect(patientName, findsWidgets);
      await tester.ensureVisible(patientName.first);
      await tester.tap(patientName.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Opens PatientProfileView with initialTabIndex = 0 (Overview)
      expect(find.byType(PatientProfileView), findsOneWidget);
      final profileView = tester.widget<PatientProfileView>(find.byType(PatientProfileView));
      expect(profileView.initialTabIndex, 0);
    });
  });
}
