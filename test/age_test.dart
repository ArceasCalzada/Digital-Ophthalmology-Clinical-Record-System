import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/models/patient.dart';

void main() {
  // A fixed "today" so the birthday edge cases are exact.
  final now = DateTime(2026, 9, 29, 15);

  group('parseDateOfBirth', () {
    test('reads the formats the app stores', () {
      expect(parseDateOfBirth('1985-06-15'), DateTime(1985, 6, 15));
      expect(parseDateOfBirth('Jun 15, 1985'), DateTime(1985, 6, 15));
      expect(parseDateOfBirth('June 15, 1985'), DateTime(1985, 6, 15));
      expect(parseDateOfBirth('6/15/1985'), DateTime(1985, 6, 15));
      expect(parseDateOfBirth(' 1985-6-5 '), DateTime(1985, 6, 5));
    });

    test('two-digit years pick the latest century that is not in the future', () {
      expect(parseDateOfBirth('6/15/85', now: now), DateTime(1985, 6, 15));
      expect(parseDateOfBirth('6/15/05', now: now), DateTime(2005, 6, 15));
      expect(parseDateOfBirth('6/15/27', now: now), DateTime(1927, 6, 15), reason: '2027 is in the future');
    });

    test('rejects text and impossible dates', () {
      expect(parseDateOfBirth(''), isNull);
      expect(parseDateOfBirth('abc'), isNull);
      expect(parseDateOfBirth('Feb 30, 2000'), isNull);
      expect(parseDateOfBirth('2001-13-01'), isNull);
      expect(parseDateOfBirth('Foo 3, 2000'), isNull);
    });
  });

  group('formatAge', () {
    String? age(String dob) => formatAge(dob, now: now);

    test('counts whole years, and only after the birthday has passed', () {
      expect(age('1985-06-15'), '41 years');
      expect(age('1985-12-01'), '40 years', reason: 'birthday later this year');
      expect(age('1985-09-29'), '41 years', reason: 'birthday is today');
      expect(age('1985-09-30'), '40 years', reason: 'birthday is tomorrow');
      expect(age('Jun 15, 1985'), '41 years');
      expect(age('2025-09-29'), '1 year');
    });

    test('uses months for under a year and days for under a month', () {
      expect(age('2026-01-30'), '7 months');
      expect(age('2026-08-29'), '1 month');
      expect(age('2026-09-10'), '19 days');
      expect(age('2026-09-28'), '1 day');
      expect(age('2026-09-29'), '0 days');
    });

    test('is null for unreadable or future dates', () {
      expect(age('abc'), isNull);
      expect(age('2027-01-01'), isNull);
    });
  });

  test('Patient.age honours the birthday for the "Jun 15, 1985" format the form stores', () {
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));
    // Thirty years ago tomorrow: still 29 today.
    final dob = DateTime(tomorrow.year - 30, tomorrow.month, tomorrow.day);
    final iso = '${dob.year}-${dob.month.toString().padLeft(2, '0')}-${dob.day.toString().padLeft(2, '0')}';

    Patient withDob(String value) => Patient(
          id: 'p',
          mrn: 'PT-1',
          fullName: 'Age Test',
          dateOfBirth: value,
          gender: 'Female',
          phone: '',
          address: '',
          medicalHistory: const [],
          allergies: const [],
          encounters: const [],
          lastVisitDate: '2026-01-01',
          totalVisits: 0,
        );

    expect(withDob(iso).age, 29);
    // The same day written the way the registration form saves it: it used to count 30.
    expect(withDob(formatClinicalDate(iso)).age, 29);
  });
}
