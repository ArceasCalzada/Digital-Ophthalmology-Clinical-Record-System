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
}
