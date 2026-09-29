import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/config/app_limits.dart';
import 'package:ophthalmology_clinical_record_system/models/encounter.dart';
import 'package:ophthalmology_clinical_record_system/models/eye_exam.dart';
import 'package:ophthalmology_clinical_record_system/models/patient.dart';
import 'package:ophthalmology_clinical_record_system/models/prescription.dart';
import 'package:ophthalmology_clinical_record_system/services/offline_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Patient _patient(int i, {String? name, List<String>? allergies}) => Patient(
      id: 'pat-$i',
      mrn: 'MRN-$i',
      fullName: name ?? 'Patient $i',
      dateOfBirth: '1980-01-01',
      gender: 'Female',
      phone: '+63 900 000 0000',
      address: 'Davao City',
      medicalHistory: const [],
      allergies: allergies ?? const [],
      encounters: const [],
      lastVisitDate: '2026-08-14',
      totalVisits: 1,
    );

Encounter _encounter(String id, String patientId) => Encounter(
      id: id,
      patientId: patientId,
      date: 'Aug 14, 2026',
      chiefComplaint: 'Blurred vision',
      examOD: EyeExamData(acuity: VisualAcuity(), refraction: Refraction()),
      examOS: EyeExamData(acuity: VisualAcuity(), refraction: Refraction()),
      diagnosis: 'Cataract',
      treatmentPlan: 'Review',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PatientRepository.clearForTesting();
    OfflineSyncService().resetForTesting();
  });

  tearDown(() async {
    // Let any in-flight local sync (300 ms) finish so it cannot clear the next test's queue.
    await Future<void>.delayed(const Duration(milliseconds: 350));
  });

  test('limit is 1000 stored patients', () {
    expect(AppLimits.maxPatients, 1000);
    expect(PatientRepository.maxPatients, 1000);
  });

  test('accepts exactly 1000 patients and refuses the 1001st', () {
    for (var i = 0; i < 1000; i++) {
      PatientRepository.addPatient(_patient(i));
    }
    expect(PatientRepository.getAllPatients().length, 1000);

    expect(
      () => PatientRepository.addPatient(_patient(1000)),
      throwsA(isA<PatientLimitReachedException>()),
    );
    expect(PatientRepository.getAllPatients().length, 1000);
    expect(PatientLimitReachedException(1000).toString(), contains('1000'));
  });

  test('editing an existing patient is still allowed when the clinic is full', () {
    for (var i = 0; i < 1000; i++) {
      PatientRepository.addPatient(_patient(i));
    }
    PatientRepository.addPatient(_patient(5, name: 'Renamed Patient'));
    expect(PatientRepository.getAllPatients().length, 1000);
    expect(PatientRepository.getPatientById('pat-5')!.fullName, 'Renamed Patient');
  });

  test('a refused 1001st patient queues nothing to sync', () {
    for (var i = 0; i < 1000; i++) {
      PatientRepository.addPatient(_patient(i));
    }
    final queued = OfflineSyncService().pendingCount;
    try {
      PatientRepository.addPatient(_patient(1000));
    } on PatientLimitReachedException {
      // expected
    }
    expect(OfflineSyncService().pendingCount, queued);
  });

  test('new patient writes the patient doc and bumps the server counter atomically', () {
    PatientRepository.addPatient(_patient(1));
    final m = OfflineSyncService().pendingQueue.last;
    final ops = m.resolveOps();
    expect(ops.map((o) => '${o.kind}:${o.path}'), ['set:patients/pat-1', 'increment:meta/counters']);
    expect(ops[1].data, {'patientCount': 1});
  });

  test('editing an existing patient does not bump the counter', () {
    PatientRepository.addPatient(_patient(1));
    PatientRepository.addPatient(_patient(1, name: 'Edited'));
    final ops = OfflineSyncService().pendingQueue.last.resolveOps();
    expect(ops.map((o) => o.kind), ['set']);
  });

  test('patient document holds demographics only, never embedded visits or prescriptions', () {
    final data = _patient(1).toFirestore();
    expect(data.containsKey('encounters'), isFalse);
    expect(data.containsKey('prescriptions'), isFalse);
    expect(data['lastModified'], isA<String>());
  });

  test('over-long patient fields are rejected and nothing is added or queued', () {
    expect(
      () => PatientRepository.addPatient(_patient(1, name: 'N' * 400)),
      throwsA(isA<FormatException>()),
    );
    expect(PatientRepository.getAllPatients(), isEmpty);
    expect(OfflineSyncService().pendingCount, 0);

    expect(
      () => PatientRepository.addPatient(_patient(2, allergies: List.generate(16, (i) => 'a$i'))),
      throwsA(isA<FormatException>()),
    );
  });

  group('encounters and prescriptions', () {
    setUp(() => PatientRepository.addPatient(_patient(1)));

    test('addEncounter stores the visit under the patient, updates the summary, and counts it', () {
      PatientRepository.addEncounter('pat-1', _encounter('enc-1', 'pat-1'));

      final p = PatientRepository.getPatientById('pat-1')!;
      expect(p.encounters.single.id, 'enc-1');
      expect(p.totalVisits, 2);
      expect(p.previousDiagnoses.first, 'Cataract');

      final ops = OfflineSyncService().pendingQueue.last.resolveOps();
      expect(ops.map((o) => '${o.kind}:${o.path}'), [
        'set:patients/pat-1/encounters/enc-1',
        'set:patients/pat-1',
        'increment:meta/counters',
      ]);
      expect(ops[1].data.keys, containsAll(['lastVisitDate', 'totalVisits', 'previousDiagnoses']));
      expect(ops[1].data.containsKey('encounters'), isFalse);
      expect(ops[2].data, {'encounterCount': 1});
    });

    test('a new visit is kept even if the directory refreshes (regression: visits used to vanish)', () {
      PatientRepository.addEncounter('pat-1', _encounter('enc-1', 'pat-1'));
      // Simulates the cloud directory refreshing: the encounter list must be preserved.
      final before = PatientRepository.getPatientById('pat-1')!;
      final refreshed = _patient(1).copyWith(encounters: before.encounters, prescriptions: before.prescriptions);
      expect(refreshed.encounters.length, 1);
    });

    test('refuses a 201st visit for one patient', () {
      for (var i = 0; i < AppLimits.maxEncountersPerPatient; i++) {
        PatientRepository.addEncounter('pat-1', _encounter('enc-$i', 'pat-1'));
      }
      expect(
        () => PatientRepository.addEncounter('pat-1', _encounter('enc-over', 'pat-1')),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('200'))),
      );
      expect(PatientRepository.getPatientById('pat-1')!.encounters.length, 200);
    });

    test('previous diagnoses summary is capped so the patient document cannot grow', () {
      for (var i = 0; i < 25; i++) {
        PatientRepository.addEncounter('pat-1', _encounter('enc-$i', 'pat-1'));
      }
      expect(PatientRepository.getPatientById('pat-1')!.previousDiagnoses.length, AppLimits.maxDiagnosisSummary);
    });

    test('addPrescription stores under the patient with its own counter', () {
      PatientRepository.addPrescription(
        'pat-1',
        Prescription(
          id: 'rx-1',
          patientId: 'pat-1',
          encounterId: 'enc-1',
          doctorName: 'Dr. Test',
          date: '2026-08-14',
          items: [
            PrescriptionItem(
              id: 'i1',
              medicationName: 'Latanoprost',
              strength: '0.005%',
              dosage: '1 drop',
              frequency: 'QHS',
              duration: '30 days',
              instructions: 'Both eyes',
            ),
          ],
        ),
      );
      final ops = OfflineSyncService().pendingQueue.last.resolveOps();
      expect(ops.map((o) => '${o.kind}:${o.path}'), ['set:patients/pat-1/prescriptions/rx-1', 'increment:meta/counters']);
      expect(ops[1].data, {'prescriptionCount': 1});
      expect(PatientRepository.getPatientById('pat-1')!.prescriptions.length, 1);
    });

    test('over-long prescription fields are refused with a clear message', () {
      PrescriptionItem item(String name) => PrescriptionItem(
            id: 'i1',
            medicationName: name,
            strength: '1%',
            dosage: '1',
            frequency: 'daily',
            duration: '7d',
            instructions: '-',
          );
      expect(
        () => PatientRepository.addPrescription(
          'pat-1',
          Prescription(id: 'rx-y', patientId: 'pat-1', encounterId: 'e', doctorName: 'Dr', date: 'd', items: [item('m' * 201)]),
        ),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('Medication name'))),
      );
    });

    test('a prescription with more than 10 medications is refused', () {
      final items = List.generate(
        11,
        (i) => PrescriptionItem(
          id: 'i$i',
          medicationName: 'Drug $i',
          strength: '1%',
          dosage: '1',
          frequency: 'daily',
          duration: '7d',
          instructions: '-',
        ),
      );
      expect(
        () => PatientRepository.addPrescription(
          'pat-1',
          Prescription(id: 'rx-x', patientId: 'pat-1', encounterId: 'e', doctorName: 'Dr', date: 'd', items: items),
        ),
        throwsFormatException,
      );
    });
  });

  group('SyncMutation.resolveOps', () {
    SyncMutation m(String type, String action, Map<String, dynamic> payload, {String id = 'x1'}) => SyncMutation(
          id: id,
          entityType: type,
          action: action,
          payload: payload,
          timestamp: DateTime.now(),
        );

    test('maps calendar events and notifications to top-level collections', () {
      expect(m('CalendarEvent', 'CREATE', {'title': 't'}).resolveOps().single.path, 'calendarEvents/x1');
      expect(m('Notification', 'UPDATE', {'isRead': true}).resolveOps().single.path, 'notifications/x1');
    });

    test('DELETE becomes a delete op', () {
      expect(m('CalendarEvent', 'DELETE', {}).resolveOps().single.kind, 'delete');
    });

    test('encounters and prescriptions need a patientId, otherwise they refuse to guess a path', () {
      expect(m('Encounter', 'CREATE', {'patientId': 'p9'}).resolveOps().single.path, 'patients/p9/encounters/x1');
      expect(() => m('Encounter', 'CREATE', {}).resolveOps(), throwsStateError);
      expect(() => m('Mystery', 'CREATE', {}).resolveOps(), throwsStateError);
    });
  });

  group('legacy local data purge', () {
    test('init() removes patient data older versions stored unencrypted in local storage', () async {
      SharedPreferences.setMockInitialValues({
        'docrs_patients_v1': '[{"fullName":"Secret Patient"}]',
        'docrs_user_logged_in': true,
        'docrs_user_email': 'dr@x.y',
        'unrelated_setting': 'keep',
      });
      await PatientRepository.init();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('docrs_patients_v1'), isFalse);
      expect(prefs.containsKey('docrs_user_logged_in'), isFalse);
      expect(prefs.containsKey('docrs_user_email'), isFalse);
      expect(prefs.getString('unrelated_setting'), 'keep');
    });
  });
}
