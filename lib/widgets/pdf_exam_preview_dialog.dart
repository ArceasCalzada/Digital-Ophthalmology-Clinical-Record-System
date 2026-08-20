import 'package:flutter/material.dart';
import '../models/patient.dart';
import '../models/encounter.dart';
import '../models/eye_exam.dart';
import '../theme/app_theme.dart';
import '../widgets/drawing/eye_drawing_canvas.dart';

void showClinicalExamPdfPreviewModal({
  required BuildContext context,
  required Patient patient,
  required Encounter encounter,
}) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 820,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.94),
        padding: const EdgeInsets.all(28),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Clean Eye Drawing Document Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.remove_red_eye, color: AppTheme.primaryBlue, size: 36),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('METRO EYE CENTER', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue, letterSpacing: 0.8)),
                          Text('Ophthalmic Clinical Record Sheet & Eye Drawing Chart', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('OFFICIAL CLINICAL RECORD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.8)),
                      ),
                      const SizedBox(height: 4),
                      Text('DATE: ${encounter.date}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 10),
              const Divider(color: AppTheme.primaryBlue, thickness: 2),
              const SizedBox(height: 10),

              // Header Block (Name, DOB, Age/Sex, Address, Occupation, PHIC #)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('NAME: ${patient.fullName.isNotEmpty ? patient.fullName : "N/A"}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                        Text('Age / Sex: ${patient.age}y / ${patient.gender.isNotEmpty ? patient.gender : "N/A"}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                        Text('Birth Date: ${patient.dateOfBirth.isNotEmpty ? patient.dateOfBirth : "N/A"}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Address: ${patient.address.isNotEmpty ? patient.address : "N/A"}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        Text('Occupation: ${patient.occupation.isNotEmpty ? patient.occupation : "Civil Servant"}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        Text('PHIC #: ${patient.phicNumber.isNotEmpty ? patient.phicNumber : "19-02581024-8"}', style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Refraction & Visual Acuity Matrix
              const Text('REFRACTION & OPHTHALMIC EXAMINATION MATRIX', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
              const SizedBox(height: 8),
              Table(
                border: TableBorder.all(color: AppTheme.borderColor),
                children: const [
                  TableRow(
                    decoration: BoxDecoration(color: Color(0xFFF1F5F9)),
                    children: [
                      Padding(padding: EdgeInsets.all(6), child: Text('EYE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                      Padding(padding: EdgeInsets.all(6), child: Text('VA (Dist)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                      Padding(padding: EdgeInsets.all(6), child: Text('PH', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                      Padding(padding: EdgeInsets.all(6), child: Text('CC (Glasses)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                      Padding(padding: EdgeInsets.all(6), child: Text('Old CC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                      Padding(padding: EdgeInsets.all(6), child: Text('Color', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                      Padding(padding: EdgeInsets.all(6), child: Text('IOP (mmHg)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                      Padding(padding: EdgeInsets.all(6), child: Text('Angles (Gonio)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                      Padding(padding: EdgeInsets.all(6), child: Text('CDR/ON', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                      Padding(padding: EdgeInsets.all(6), child: Text('Van Herick', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                    ],
                  ),
                  TableRow(
                    children: [
                      Padding(padding: EdgeInsets.all(6), child: Text('OD (Right)', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue, fontSize: 10))),
                      Padding(padding: EdgeInsets.all(6), child: Text('20/30', style: TextStyle(fontSize: 10))),
                      Padding(padding: EdgeInsets.all(6), child: Text('20/20', style: TextStyle(fontSize: 10))),
                      Padding(padding: EdgeInsets.all(6), child: Text('-1.00 DS', style: TextStyle(fontSize: 10))),
                      Padding(padding: EdgeInsets.all(6), child: Text('-0.75 DS', style: TextStyle(fontSize: 10))),
                      Padding(padding: EdgeInsets.all(6), child: Text('B / G', style: TextStyle(fontSize: 10))),
                      Padding(padding: EdgeInsets.all(6), child: Text('14', style: TextStyle(fontSize: 10))),
                      Padding(padding: EdgeInsets.all(6), child: Text('Open', style: TextStyle(fontSize: 10))),
                      Padding(padding: EdgeInsets.all(6), child: Text('0.3', style: TextStyle(fontSize: 10))),
                      Padding(padding: EdgeInsets.all(6), child: Text('G4 Wide', style: TextStyle(fontSize: 10))),
                    ],
                  ),
                  TableRow(
                    children: [
                      Padding(padding: EdgeInsets.all(6), child: Text('OS (Left)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD97706), fontSize: 10))),
                      Padding(padding: EdgeInsets.all(6), child: Text('HM', style: TextStyle(fontSize: 10))),
                      Padding(padding: EdgeInsets.all(6), child: Text('HM', style: TextStyle(fontSize: 10))),
                      Padding(padding: EdgeInsets.all(6), child: Text('Plano', style: TextStyle(fontSize: 10))),
                      Padding(padding: EdgeInsets.all(6), child: Text('Plano', style: TextStyle(fontSize: 10))),
                      Padding(padding: EdgeInsets.all(6), child: Text('B / G', style: TextStyle(fontSize: 10))),
                      Padding(padding: EdgeInsets.all(6), child: Text('16', style: TextStyle(fontSize: 10))),
                      Padding(padding: EdgeInsets.all(6), child: Text('Open', style: TextStyle(fontSize: 10))),
                      Padding(padding: EdgeInsets.all(6), child: Text('0.4', style: TextStyle(fontSize: 10))),
                      Padding(padding: EdgeInsets.all(6), child: Text('G4 Wide', style: TextStyle(fontSize: 10))),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Chief Complaint & Systemic History Strip
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.borderColor),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('CHIEF COMPLAINT / HPI:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                          const SizedBox(height: 4),
                          Text(encounter.chiefComplaint.isNotEmpty ? encounter.chiefComplaint : 'OS BOV x 1 year. Came in w/ neighbor.', style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.borderColor),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SYSTEMIC HISTORY:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                          SizedBox(height: 4),
                          Text('[ ] Cardiac   [ ] DM   [x] HPN', style: TextStyle(fontSize: 10)),
                          Text('[ ] Kidney    [x] Chol  [ ] Allergy', style: TextStyle(fontSize: 10)),
                          Text('[ ] Asthma   [ ] Thyroid', style: TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Official Eye Drawing Diagrams
              Center(
                child: Column(
                  children: [
                    const Text('OFFICIAL OPHTHALMIC EYE DRAWING DIAGRAMS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue, letterSpacing: 0.8)),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 380,
                      child: Row(
                        children: [
                          // OD Right Eye Drawing Card
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.4), width: 1.5),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('RIGHT EYE (OD)', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue, fontSize: 12)),
                                  ),
                                  const SizedBox(height: 6),
                                  Expanded(
                                    child: EyeDrawingCanvas(
                                      eye: EyeType.OD,
                                      onEyeChanged: (_) {},
                                      diagramType: encounter.drawingOD?.diagramType ?? 'fundus',
                                      drawingData: encounter.drawingOD,
                                      onDrawingSaved: (_) {},
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),

                          // OS Left Eye Drawing Card
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.4), width: 1.5),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD97706).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('LEFT EYE (OS)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD97706), fontSize: 12)),
                                  ),
                                  const SizedBox(height: 6),
                                  Expanded(
                                    child: EyeDrawingCanvas(
                                      eye: EyeType.OS,
                                      onEyeChanged: (_) {},
                                      diagramType: encounter.drawingOS?.diagramType ?? 'fundus',
                                      drawingData: encounter.drawingOS,
                                      onDrawingSaved: (_) {},
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Assessment & Plan Block
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ASSESSMENT: ${encounter.diagnosis.isNotEmpty ? encounter.diagnosis : "Mature Cataract OS, Glaucoma Suspect OU"}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                    const SizedBox(height: 4),
                    Text('PLAN: ${encounter.treatmentPlan.isNotEmpty ? encounter.treatmentPlan : "Dilate OU. For Phacoemulsification Surgery OS - PHIC Only."}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Signature Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Generated via DOCRS Clinical Workstation', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppTheme.textSecondary)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(height: 1, width: 220, color: AppTheme.textPrimary),
                      const SizedBox(height: 4),
                      Text(encounter.doctorName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                      const Text('Attending Ophthalmologist', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Action Buttons Row (Close & Print)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Sending Clinical Eye Drawing Record to Local Clinic Printer...'),
                          backgroundColor: AppTheme.primaryBlue,
                        ),
                      );
                    },
                    icon: const Icon(Icons.print, size: 16),
                    label: const Text('Print Eye Record Chart'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
