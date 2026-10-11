import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/models/patient.dart';
import 'package:ophthalmology_clinical_record_system/models/prescription.dart';
import 'package:ophthalmology_clinical_record_system/services/profile_store.dart';
import 'package:ophthalmology_clinical_record_system/theme/app_theme.dart';
import 'package:ophthalmology_clinical_record_system/views/settings_view.dart';
import 'package:ophthalmology_clinical_record_system/widgets/rx_pad_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    // Reset ProfileStore to standard defaults
    final profile = ProfileStore.instance;
    profile.doctorName.text = 'Dr. Sigrid Robillos, MD';
    profile.doctorTitle.text = 'Attending Ophthalmologist';
    profile.specialization.text = 'Cornea & Anterior Segment Specialist';
    profile.license.text = 'PRC Lic. No. 091823';
    profile.ptrNo.text = 'PTR No. 7821940';
    profile.clinic1Name.text = 'St. Joseph Southern Bukidnon Hosp.';
    profile.clinic1Location.text = 'Maramag, Bukidnon';
    profile.clinic1Days.text = 'Monday & Tuesday';
    profile.clinic1Hours.text = '9am - 12nn';
    profile.clinic2Name.text = 'Malta Medical Center';
    profile.clinic2Location.text = 'Toril, Davao City';
    profile.clinic2Days.text = 'Thursday & Saturday';
    profile.clinic2Hours.text = '10am - 12nn';
    profile.clinic3Name.text = 'Adventist Hospital Davao';
    profile.clinic3Location.text = 'Bangkal, Davao City';
    profile.clinic3Days.text = 'Friday';
    profile.clinic3Hours.text = '10am - 12nn';
  });

  group('ProfileStore Prescription Settings & Validation', () {
    test('validation requires Doctor Name and License Number', () {
      final profile = ProfileStore.instance;
      profile.doctorName.text = 'Dr. John Doe, MD';
      profile.license.text = 'PRC-123456';
      expect(profile.validatePrescriptionSettings(), isNull);

      profile.doctorName.text = '   ';
      expect(profile.validatePrescriptionSettings(), contains('Doctor Name'));

      profile.doctorName.text = 'Dr. John Doe, MD';
      profile.license.text = '   ';
      expect(profile.validatePrescriptionSettings(), contains('License Number'));
    });

    test('toMap and fromMap serialize and restore all doctor details and clinic headers', () {
      final profile = ProfileStore.instance;
      final testData = {
        'doctorName': 'Dr. Elena Rostova, MD',
        'doctorTitle': 'Chief Vitreoretinal Surgeon',
        'specialization': 'Retina & Vitreous Specialist',
        'license': 'PRC-998877',
        'ptrNo': 'PTR-5544332',
        'clinic1Name': 'Metro Eye Institute',
        'clinic1Location': 'Manila City',
        'clinic1Days': 'Mon-Wed',
        'clinic1Hours': '8am - 1pm',
        'clinic2Name': 'Vision Care Center',
        'clinic2Location': 'Makati City',
        'clinic2Days': 'Thu-Fri',
        'clinic2Hours': '2pm - 5pm',
        'clinic3Name': 'Global Ophthalmic Clinic',
        'clinic3Location': 'Taguig City',
        'clinic3Days': 'Saturday',
        'clinic3Hours': '9am - 12pm',
      };

      profile.fromMap(testData);

      expect(profile.doctorName.text, 'Dr. Elena Rostova, MD');
      expect(profile.doctorTitle.text, 'Chief Vitreoretinal Surgeon');
      expect(profile.specialization.text, 'Retina & Vitreous Specialist');
      expect(profile.license.text, 'PRC-998877');
      expect(profile.ptrNo.text, 'PTR-5544332');
      expect(profile.clinic1Name.text, 'Metro Eye Institute');
      expect(profile.clinic1Location.text, 'Manila City');
      expect(profile.clinic1Days.text, 'Mon-Wed');
      expect(profile.clinic1Hours.text, '8am - 1pm');

      final serialized = profile.toMap();
      expect(serialized['doctorName'], 'Dr. Elena Rostova, MD');
      expect(serialized['clinic1Name'], 'Metro Eye Institute');
    });

    test('saveToFirestore and loadFromFirestore persist and recover settings locally', () async {
      final profile = ProfileStore.instance;
      profile.doctorName.text = 'Dr. Test Persist, MD';
      profile.clinic1Name.text = 'Persist Clinic 1';

      await profile.saveToFirestore();

      // Reset and reload from prefs
      profile.doctorName.text = 'temp';
      profile.clinic1Name.text = 'temp';
      await profile.loadFromFirestore();

      expect(profile.doctorName.text, 'Dr. Test Persist, MD');
      expect(profile.clinic1Name.text, 'Persist Clinic 1');
    });
  });

  group('RxPadWidget Dynamic Rendering', () {
    testWidgets('renders dynamic doctor details and clinic schedule headers', (tester) async {
      final profile = ProfileStore.instance;
      profile.doctorName.text = 'Dr. Victor Frank, MD';
      profile.specialization.text = 'Pediatric Ophthalmology';
      profile.license.text = 'PRC-54321';
      profile.ptrNo.text = 'PTR-98765';
      profile.clinic1Name.text = 'Children Vision Center';
      profile.clinic1Location.text = 'Cebu City';
      profile.clinic1Days.text = 'Tues & Thurs';
      profile.clinic1Hours.text = '1pm - 4pm';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RxPadWidget(
              items: [
                PrescriptionItem(
                  id: 'rx-1',
                  medicationName: 'Tobramycin 0.3%',
                  strength: '0.3%',
                  dosage: '1 drop OD',
                  frequency: 'TID',
                  duration: '5 days',
                  instructions: 'Instill 1 drop in Right Eye three times daily.',
                ),
              ],
              date: '2026-10-11',
            ),
          ),
        ),
      );

      // Verify doctor header and footer render dynamic values
      expect(find.text('Dr. Victor Frank, MD'), findsNWidgets(2)); // Header & Signature block
      expect(find.text('PEDIATRIC OPHTHALMOLOGY'), findsOneWidget);
      expect(find.text('License No. PRC-54321'), findsOneWidget);
      expect(find.text('PTR-98765'), findsOneWidget);

      // Verify clinic column renders dynamic clinic values
      expect(find.text('Children Vision Center'), findsOneWidget);
      expect(find.text('Cebu City'), findsOneWidget);
      expect(find.text('Tues & Thurs'), findsOneWidget);
      expect(find.text('1pm - 4pm'), findsOneWidget);
    });
  });

  group('SettingsView Prescription Settings Tab', () {
    testWidgets('toggles Edit mode for Doctor Information and Clinic Headers', (tester) async {
      tester.view.physicalSize = const Size(1600, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: SettingsView()),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure Prescription Settings tab is active
      expect(find.text('Doctor Information'), findsOneWidget);
      expect(find.text('Clinic Branch Headers & Schedules'), findsOneWidget);
      expect(find.text('Prescription Template Layout'), findsOneWidget);

      // Initially in summary mode
      expect(find.byKey(const Key('edit_doctor_info_button')), findsOneWidget);
      expect(find.byKey(const Key('edit_clinic_headers_button')), findsOneWidget);
      expect(find.text('Doctor Name *'), findsNothing);
      expect(find.text('Clinic Branch 1'), findsNothing);

      // Click Edit on Doctor Information
      await tester.tap(find.byKey(const Key('edit_doctor_info_button')));
      await tester.pumpAndSettle();

      // Editable inputs are now visible
      expect(find.text('Doctor Name *'), findsOneWidget);
      expect(find.text('PRC License Number *'), findsOneWidget);
      expect(find.text('PTR Number'), findsOneWidget);
      expect(find.text('Specialization'), findsOneWidget);

      // Click Edit on Clinic Headers
      await tester.tap(find.byKey(const Key('edit_clinic_headers_button')));
      await tester.pumpAndSettle();

      // Editable inputs for clinic branches are now visible
      expect(find.text('Clinic Branch 1'), findsOneWidget);
      expect(find.text('Clinic Branch 2'), findsOneWidget);
      expect(find.text('Clinic Branch 3'), findsOneWidget);
    });

    testWidgets('Live Prescription Pad Preview dynamically updates when input fields change', (tester) async {
      tester.view.physicalSize = const Size(1600, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: SettingsView()),
        ),
      );
      await tester.pumpAndSettle();

      // Toggle edit mode for doctor info
      await tester.tap(find.byKey(const Key('edit_doctor_info_button')));
      await tester.pumpAndSettle();

      // Edit Doctor Name field
      final doctorNameInput = find.widgetWithText(TextFormField, 'Dr. Sigrid Robillos, MD');
      expect(doctorNameInput, findsOneWidget);
      await tester.enterText(doctorNameInput, 'Dr. Marcus Brody, MD');
      await tester.pumpAndSettle();

      // Verify that the Live Prescription Pad Preview reflects the new name
      expect(find.text('Dr. Marcus Brody, MD'), findsWidgets);
    });

    testWidgets('Validates required Doctor Name and License Number on Save Changes', (tester) async {
      tester.view.physicalSize = const Size(1600, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: SettingsView()),
        ),
      );
      await tester.pumpAndSettle();

      // Open Doctor Info edit mode
      await tester.tap(find.byKey(const Key('edit_doctor_info_button')));
      await tester.pumpAndSettle();

      final doctorNameInput = find.byKey(const Key('doctor_name_input'));
      final licenseInput = find.byKey(const Key('doctor_license_input'));

      // Clear Doctor Name
      await tester.enterText(doctorNameInput, '');
      await tester.pumpAndSettle();

      // Scroll and tap Save Changes
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      // Expect validation error message
      expect(find.text('Doctor Name is required and cannot be empty.'), findsOneWidget);

      // Now restore Doctor Name but clear License Number
      await tester.enterText(doctorNameInput, 'Dr. Valid Doctor, MD');
      await tester.enterText(licenseInput, '');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      // Expect license validation error
      expect(find.text('License Number is required and cannot be empty.'), findsOneWidget);

      // Now provide valid values and save
      await tester.enterText(licenseInput, 'PRC-887766');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      // Expect success modal / feedback
      expect(find.text('Settings Saved Successfully'), findsOneWidget);
      expect(find.text('Prescription settings and clinic headers updated.'), findsOneWidget);
    });
  });
}
