import 'package:flutter/material.dart';
import '../models/encounter.dart';
import '../models/patient.dart';
import '../models/eye_exam.dart';
import '../theme/app_theme.dart';
import '../widgets/drawing/eye_drawing_canvas.dart';
import 'historical_comparison_view.dart';

import '../widgets/pdf_exam_preview_dialog.dart';

class ExaminationDetailView extends StatelessWidget {
  final Patient patient;
  final Encounter encounter;

  const ExaminationDetailView({
    super.key,
    required this.patient,
    required this.encounter,
  });

  void _openComparison(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HistoricalComparisonView(patient: patient),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      appBar: AppBar(
        title: Text('Examination Record — ${encounter.date}'),
        actions: [
          OutlinedButton.icon(
            onPressed: () => _openComparison(context),
            icon: const Icon(Icons.compare, size: 16),
            label: const Text('Compare with Previous'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryBlue,
              side: const BorderSide(color: AppTheme.borderColor),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () {
              showClinicalExamPdfPreviewModal(
                context: context,
                patient: patient,
                encounter: encounter,
              );
            },
            icon: const Icon(Icons.picture_as_pdf, size: 18),
            label: const Text('Print / Download PDF Record'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patient Header Summary
            Card(
              color: AppTheme.cardBg,
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppTheme.borderColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(patient.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                        Text('${patient.mrn}  •  ${patient.gender}, ${patient.age}y  •  DOB: ${patient.dateOfBirth}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Attending Physician: ${encounter.doctorName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryBlue)),
                        Text('Date of Exam: ${encounter.date}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Chief Complaint Summary Card
            Card(
              color: AppTheme.cardBg,
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppTheme.borderColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Chief Complaint & Consult Notes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    const SizedBox(height: 12),
                    Text(encounter.chiefComplaint.isEmpty ? 'Routine consultation' : encounter.chiefComplaint, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Read-Only Digital Eye Drawings Workspace
            Card(
              color: AppTheme.cardBg,
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppTheme.borderColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Saved Ophthalmic Vector Drawings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 480,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                const Text('Right Eye (OD) Findings', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: EyeDrawingCanvas(
                                    eye: EyeType.OD,
                                    onEyeChanged: (_) {},
                                    drawingData: encounter.drawingOD,
                                    onDrawingSaved: (_) {},
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              children: [
                                const Text('Left Eye (OS) Findings', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: EyeDrawingCanvas(
                                    eye: EyeType.OS,
                                    onEyeChanged: (_) {},
                                    drawingData: encounter.drawingOS,
                                    onDrawingSaved: (_) {},
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Diagnosis & Treatment Notes
            Card(
              color: AppTheme.cardBg,
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppTheme.borderColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Recorded Diagnosis', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: AppTheme.primaryBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text(encounter.diagnosis, style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    const SizedBox(height: 16),
                    const Text('Treatment & Management Plan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    const SizedBox(height: 6),
                    Text(encounter.treatmentPlan.isEmpty ? 'No notes entered.' : encounter.treatmentPlan, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
