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
    this.doctorName = 'Dr. Sigrid Robillos, MD',
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

  factory Encounter.fromJson(Map<String, dynamic> json) => Encounter(
        id: json['id'] as String,
        patientId: json['patientId'] as String,
        date: json['date'] as String,
        doctorName: json['doctorName'] as String? ?? 'Dr. Sigrid Robillos, MD',
        chiefComplaint: json['chiefComplaint'] as String? ?? '',
        examOD: json['examOD'] != null ? EyeExamData.fromJson(json['examOD'] as Map<String, dynamic>) : EyeExamData(acuity: VisualAcuity(), refraction: Refraction()),
        examOS: json['examOS'] != null ? EyeExamData.fromJson(json['examOS'] as Map<String, dynamic>) : EyeExamData(acuity: VisualAcuity(), refraction: Refraction()),
        diagnosis: json['diagnosis'] as String? ?? '',
        treatmentPlan: json['treatmentPlan'] as String? ?? '',
        status: json['status'] as String? ?? 'completed',
      );
}
