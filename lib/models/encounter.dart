import 'dart:typed_data';

import '../config/app_limits.dart';
import 'eye_exam.dart';
import 'drawing_stroke.dart';

class Encounter {
  final String id;
  final String patientId;
  final String date; // ISO String e.g. "2026-08-14"
  final String doctorName;
  final String chiefComplaint;
  final EyeExamData examOD;
  final EyeExamData examOS;
  final EyeDrawingData? drawingOD;
  final EyeDrawingData? drawingOS;
  final PaperSheetDrawingData? paperSheetDrawing;
  final String diagnosis;
  final String treatmentPlan;
  final String status; // 'in-progress' | 'completed'

  Encounter({
    required this.id,
    required this.patientId,
    required this.date,
    this.doctorName = 'Attending Physician',
    required this.chiefComplaint,
    required this.examOD,
    required this.examOS,
    this.drawingOD,
    this.drawingOS,
    this.paperSheetDrawing,
    required this.diagnosis,
    required this.treatmentPlan,
    this.status = 'completed',
  });

  /// Plain JSON without drawings (used for previews and in-memory copies).
  Map<String, dynamic> toJson() => {
        'id': id,
        'patientId': patientId,
        'date': date,
        'doctorName': doctorName,
        'chiefComplaint': chiefComplaint,
        'examOD': examOD.toJson(),
        'examOS': examOS.toJson(),
        'diagnosis': diagnosis,
        'treatmentPlan': treatmentPlan,
        'status': status,
      };

  /// Document stored at `patients/{patientId}/encounters/{id}`. Drawings are
  /// packed into compact byte fields ([DrawingCodec]) instead of point maps.
  ///
  /// Throws [FormatException] when a text field is over its limit and
  /// `DrawingTooLargeException` when a drawing cannot be packed small enough.
  Map<String, dynamic> toFirestore() {
    _requireLength('Chief complaint', chiefComplaint, AppLimits.maxLongTextLength);
    _requireLength('Diagnosis', diagnosis, AppLimits.maxLongTextLength);
    _requireLength('Treatment plan', treatmentPlan, AppLimits.maxLongTextLength);
    for (final (label, exam) in [('OD', examOD), ('OS', examOS)]) {
      _requireLength('Slit-lamp notes ($label)', exam.slitLampNotes, AppLimits.maxNotesLength);
      _requireLength('Fundoscopy notes ($label)', exam.fundoscopyNotes, AppLimits.maxNotesLength);
      _requireShortFields(label, exam.toJson());
    }
    _requireLength('Doctor name', doctorName, AppLimits.maxShortTextLength);
    _requireLength('Date', date, AppLimits.maxShortTextLength);

    final data = toJson();
    data['patientId'] = patientId;
    if (paperSheetDrawing != null && paperSheetDrawing!.strokes.isNotEmpty) {
      data['paperSheet'] = paperSheetDrawing!.toPacked();
    }
    if (drawingOD != null && drawingOD!.strokes.isNotEmpty) {
      data['drawOD'] = drawingOD!.toPacked();
    }
    if (drawingOS != null && drawingOS!.strokes.isNotEmpty) {
      data['drawOS'] = drawingOS!.toPacked();
    }
    data['lastModified'] = DateTime.now().toIso8601String();
    return data;
  }

  static const _noteKeys = {'slitLampNotes', 'fundoscopyNotes'};

  static void _requireShortFields(String eye, Map<String, dynamic> exam) {
    exam.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        _requireShortFields(eye, value);
      } else if (value is String && !_noteKeys.contains(key)) {
        _requireLength('Exam field "$key" ($eye)', value, AppLimits.maxShortTextLength);
      }
    });
  }

  static void _requireLength(String label, String value, int max) {
    if (value.length > max) {
      throw FormatException('$label is too long (${value.length} characters, limit $max).');
    }
  }

  factory Encounter.fromJson(Map<String, dynamic> json) => Encounter(
        id: json['id'] as String,
        patientId: json['patientId'] as String,
        date: json['date'] as String,
        doctorName: json['doctorName'] as String? ?? 'Attending Physician',
        chiefComplaint: json['chiefComplaint'] as String? ?? '',
        examOD: json['examOD'] != null ? EyeExamData.fromJson(json['examOD'] as Map<String, dynamic>) : EyeExamData(acuity: VisualAcuity(), refraction: Refraction()),
        examOS: json['examOS'] != null ? EyeExamData.fromJson(json['examOS'] as Map<String, dynamic>) : EyeExamData(acuity: VisualAcuity(), refraction: Refraction()),
        diagnosis: json['diagnosis'] as String? ?? '',
        treatmentPlan: json['treatmentPlan'] as String? ?? '',
        status: json['status'] as String? ?? 'completed',
      );

  /// Rebuilds an encounter from a Firestore document. Byte fields must already be
  /// [Uint8List]. A drawing that fails to decode is skipped rather than blocking
  /// the whole record.
  factory Encounter.fromFirestore(Map<String, dynamic> json) {
    final base = Encounter.fromJson(json);
    final id = base.id;
    final patientId = base.patientId;

    T? tryUnpack<T>(Object? raw, T Function(Uint8List) build) {
      if (raw is! Uint8List) return null;
      try {
        return build(raw);
      } catch (_) {
        return null;
      }
    }

    return Encounter(
      id: id,
      patientId: patientId,
      date: base.date,
      doctorName: base.doctorName,
      chiefComplaint: base.chiefComplaint,
      examOD: base.examOD,
      examOS: base.examOS,
      diagnosis: base.diagnosis,
      treatmentPlan: base.treatmentPlan,
      status: base.status,
      paperSheetDrawing: tryUnpack(
        json['paperSheet'],
        (b) => PaperSheetDrawingData.fromPacked(b, encounterId: id, patientId: patientId),
      ),
      drawingOD: tryUnpack(
        json['drawOD'],
        (b) => EyeDrawingData.fromPacked(b, encounterId: id, patientId: patientId, eye: EyeType.OD),
      ),
      drawingOS: tryUnpack(
        json['drawOS'],
        (b) => EyeDrawingData.fromPacked(b, encounterId: id, patientId: patientId, eye: EyeType.OS),
      ),
    );
  }
}
