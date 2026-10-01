import 'package:flutter/material.dart';
import '../models/encounter.dart';
import '../models/patient.dart';
import 'eye_exam_view.dart';

class ExaminationDetailView extends StatelessWidget {
  final Patient patient;
  final Encounter encounter;

  const ExaminationDetailView({
    super.key,
    required this.patient,
    required this.encounter,
  });

  @override
  Widget build(BuildContext context) {
    return EyeExamView(
      patient: patient,
      encounter: encounter,
    );
  }
}
