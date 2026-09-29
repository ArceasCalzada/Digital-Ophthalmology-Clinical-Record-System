// Captures the exact Firestore writes the app produces for realistic data, so the
// security rules can be tested against the real payloads (see
// firebase-rules-tests/app-payloads.test.mjs).
//
// Run with DOCRS_WRITE_FIXTURES=1 to (re)generate
// firebase-rules-tests/fixtures/app_payloads.json:
//   DOCRS_WRITE_FIXTURES=1 flutter test test/rules_fixtures_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/config/app_limits.dart';
import 'package:ophthalmology_clinical_record_system/models/calendar_event.dart';
import 'package:ophthalmology_clinical_record_system/models/clinical_notification.dart';
import 'package:ophthalmology_clinical_record_system/models/drawing_stroke.dart';
import 'package:ophthalmology_clinical_record_system/models/encounter.dart';
import 'package:ophthalmology_clinical_record_system/models/eye_exam.dart';
import 'package:ophthalmology_clinical_record_system/models/patient.dart';
import 'package:ophthalmology_clinical_record_system/models/prescription.dart';
import 'package:ophthalmology_clinical_record_system/services/offline_sync_service.dart';
import 'package:ophthalmology_clinical_record_system/services/storage_optimization_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

dynamic _jsonSafe(dynamic v) {
  if (v is Uint8List) return {r'$bytes': base64Encode(v)};
  if (v is Map) return {for (final e in v.entries) e.key.toString(): _jsonSafe(e.value)};
  if (v is List) return [for (final e in v) _jsonSafe(e)];
  return v;
}

List<VectorStroke> _strokes(Random r, int strokes, int pointsEach) => List.generate(strokes, (i) {
      var x = 100 + r.nextDouble() * 500, y = 100 + r.nextDouble() * 700, a = r.nextDouble() * 2 * pi;
      final pts = <Offset>[];
      for (var k = 0; k < pointsEach; k++) {
        a += (r.nextDouble() - 0.5) * 0.35;
        x += cos(a) * 1.5;
        y += sin(a) * 1.5;
        pts.add(Offset(x, y));
      }
      return VectorStroke(id: 'stk-$i', tool: DrawingTool.pen, color: const Color(0xFFD32F2F), size: 2.5, points: pts);
    });

EyeExamData _exam() => EyeExamData(
      acuity: VisualAcuity(uncorrected: '20/40', bestCorrected: '20/25', pinhole: '20/20', oldCc: '-2.25 -0.50 x 180', ar: '-2.50 -0.75 x 175', ak: '43.25/44.00 @ 90'),
      refraction: Refraction(sph: '-2.25', cyl: '-0.50', axis: '180'),
      slitLampNotes: 'Lids/lashes: mild MGD. Conjunctiva quiet. Cornea clear. AC deep and quiet. Lens: early NS 1+.',
      fundoscopyNotes: 'Disc pink, sharp margins, C/D 0.3. Macula flat. Vessels normal. Periphery attached.',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('app writes for a realistic patient, visit (with drawings), prescription, event and notification', () {
    SharedPreferences.setMockInitialValues({});
    PatientRepository.clearForTesting();
    OfflineSyncService().resetForTesting();
    final r = Random(11);

    PatientRepository.addPatient(Patient(
      id: 'pat-1790593390272',
      mrn: 'PT-004521',
      fullName: 'Maria Clara Dela Cruz',
      middleName: 'Santos',
      dateOfBirth: 'Mar 12, 1958',
      gender: 'Female',
      phone: '+63 917 123 4567',
      address: 'Blk 5 Lot 12, Sampaguita St., Barangay Talomo, Davao City',
      medicalHistory: ['Hypertension', 'Type 2 Diabetes Mellitus'],
      allergies: ['Penicillin'],
      encounters: const [],
      lastVisitDate: '2026-08-14',
      totalVisits: 1,
    ));

    final sheet = PaperSheetDrawingData(
      id: 'drw-active',
      encounterId: 'enc-active',
      patientId: 'pat-1790593390272',
      strokes: _strokes(r, 50, 100), // a typical, busy consultation sheet (5,000 raw points)
      updatedAt: DateTime.now().toIso8601String(),
    );
    final od = EyeDrawingData(
      id: 'od',
      encounterId: 'enc-active',
      patientId: 'pat-1790593390272',
      eye: EyeType.OD,
      strokes: _strokes(r, 12, 60),
      cdRatio: 0.4,
      updatedAt: DateTime.now().toIso8601String(),
    );
    PatientRepository.addEncounter(
      'pat-1790593390272',
      Encounter(
        id: 'enc-1790593399999',
        patientId: 'pat-1790593390272',
        date: 'Aug 14, 2026',
        chiefComplaint: 'Blurring of vision OU, gradual, for 3 months. Difficulty reading small print.',
        examOD: _exam(),
        examOS: _exam(),
        paperSheetDrawing: sheet,
        drawingOD: od,
        diagnosis: 'H25.13 Age-related nuclear cataract, bilateral; H52.4 Presbyopia',
        treatmentPlan: 'Continue artificial tears QID OU. Update spectacle Rx. Return in 6 months for IOP and dilated fundus exam.',
      ),
    );

    PatientRepository.addPrescription(
      'pat-1790593390272',
      Prescription(
        id: 'rx-1790593399998',
        patientId: 'pat-1790593390272',
        encounterId: 'enc-1790593399999',
        doctorName: 'Dr. Sigrid Robillos, MD',
        date: '2026-08-14',
        items: [
          for (var i = 0; i < 3; i++)
            PrescriptionItem(
              id: 'it-$i',
              medicationName: 'Latanoprost 0.005% Ophthalmic Solution',
              strength: '0.005%',
              dosage: '1 drop',
              frequency: 'Once daily at bedtime',
              duration: '30 days',
              instructions: 'Instill in both eyes. Do not touch dropper tip to eye.',
            ),
        ],
      ),
    );

    final cal = CalendarEventRepository();
    cal.addEvent(CalendarEvent(
      id: 'evt-1790593400000',
      title: 'Cataract post-op check',
      eventType: 'Follow-up',
      location: 'Exam Room 1',
      dateTime: DateTime(2026, 9, 1, 9, 30),
      patientName: 'Maria Clara Dela Cruz',
      patientId: 'pat-1790593390272',
      notes: 'Bring current glasses.',
    ));
    cal.toggleEventStatus('evt-1790593400000');

    final notes = ClinicalNotificationRepository();
    notes.addNotification(ClinicalNotification(
      id: 'notif-1790593400001',
      title: 'Prescription Refill Request',
      message: 'Latanoprost refill requested for Maria Clara Dela Cruz.',
      category: 'Refill',
      severity: NotificationSeverity.warning,
      timestamp: DateTime(2026, 9, 1, 8, 0),
      patientName: 'Maria Clara Dela Cruz',
      patientId: 'pat-1790593390272',
    ));
    notes.markAsRead('notif-1790593400001');

    final mutations = OfflineSyncService().pendingQueue;
    expect(mutations.length, greaterThanOrEqualTo(6));

    // The stored visit must respect the size budget the rules assume.
    final encOps = mutations.firstWhere((m) => m.entityType == 'Encounter').resolveOps();
    final encData = encOps.first.data;
    expect(StorageOptimizationService.estimateDocumentBytes(encOps.first.path, encData), lessThan(AppLimits.maxEncounterDocBytes));
    expect((encData['paperSheet'] as Uint8List).length, lessThan(AppLimits.maxPaperSheetDrawingBytes));
    expect((encData['drawOD'] as Uint8List).length, lessThan(AppLimits.maxEyeDrawingBytes));

    final fixture = [
      for (final m in mutations)
        {
          'entityType': m.entityType,
          'action': m.action,
          'ops': [
            for (final op in m.resolveOps()) {'kind': op.kind, 'path': op.path, 'data': _jsonSafe(op.data)},
          ],
        },
    ];

    if (Platform.environment['DOCRS_WRITE_FIXTURES'] == '1') {
      final file = File('firebase-rules-tests/fixtures/app_payloads.json');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(fixture));
    }
  });
}
