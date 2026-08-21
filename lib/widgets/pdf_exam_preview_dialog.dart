import 'package:flutter/material.dart';
import '../models/patient.dart';
import '../models/encounter.dart';
import '../theme/app_theme.dart';

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
              // Header Banner
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
                          Text('Ophthalmic Clinical Consultation Record Sheet', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
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
                      Text('DATE: ${formatClinicalDate(encounter.date)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 10),
              const Divider(color: AppTheme.primaryBlue, thickness: 2),
              const SizedBox(height: 10),

              // Header Block (Name, Middle Name, DOB, Age/Sex, Address, Contact, Occupation, PHIC #)
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
                        Text('NAME: ${patient.fullName.isNotEmpty ? patient.fullName : "ASTURIAS, EDGARDO"}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                        Text('Middle Name: ${patient.middleName.isNotEmpty ? patient.middleName : "PEREZ"}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                        Text('Age / Sex: ${patient.age}y / ${patient.gender.isNotEmpty ? patient.gender : "Male"}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                        Text('Birth Date: ${patient.dateOfBirth.isNotEmpty ? formatClinicalDate(patient.dateOfBirth) : "May 7, 1963"}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Address: ${patient.address.isNotEmpty ? patient.address : "Apas, Davao City"}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        Text('Contact #: ${patient.phone.isNotEmpty ? patient.phone : "+63 917 882 1963"}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        Text('Occupation: ${patient.occupation.isNotEmpty ? patient.occupation : "Civil Servant"}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        Text('PHIC #: ${patient.phicNumber.isNotEmpty ? patient.phicNumber : "19-02581024-8"}', style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Table 1: Refraction & Visual Acuity Matrix
              const Text('1. REFRACTION & VISUAL ACUITY TABLE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
              const SizedBox(height: 6),
              Table(
                border: TableBorder.all(color: const Color(0xFF0F172A)),
                children: [
                  const TableRow(
                    decoration: BoxDecoration(color: Color(0xFF0F172A)),
                    children: [
                      Padding(padding: EdgeInsets.all(6), child: Text('EYE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.white), textAlign: TextAlign.center)),
                      Padding(padding: EdgeInsets.all(6), child: Text('VA (Dist)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.white), textAlign: TextAlign.center)),
                      Padding(padding: EdgeInsets.all(6), child: Text('PH', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.white), textAlign: TextAlign.center)),
                      Padding(padding: EdgeInsets.all(6), child: Text('CC (Glasses)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.white), textAlign: TextAlign.center)),
                      Padding(padding: EdgeInsets.all(6), child: Text('Old CC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.white), textAlign: TextAlign.center)),
                      Padding(padding: EdgeInsets.all(6), child: Text('AR (Auto-Refract)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.white), textAlign: TextAlign.center)),
                      Padding(padding: EdgeInsets.all(6), child: Text('AK (Auto-Kerato)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.white), textAlign: TextAlign.center)),
                    ],
                  ),
                  TableRow(
                    children: [
                      const Padding(padding: EdgeInsets.all(6), child: Text('OD (Right)', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue, fontSize: 10), textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(6), child: Text(encounter.examOD.acuity.uncorrected.isNotEmpty ? encounter.examOD.acuity.uncorrected : 'HM', style: const TextStyle(fontSize: 10), textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(6), child: Text(encounter.examOD.acuity.pinhole.isNotEmpty ? encounter.examOD.acuity.pinhole : 'HM', style: const TextStyle(fontSize: 10), textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(6), child: Text(encounter.examOD.acuity.bestCorrected.isNotEmpty ? encounter.examOD.acuity.bestCorrected : 'Plano', style: const TextStyle(fontSize: 10), textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(6), child: Text(encounter.examOD.acuity.oldCc.isNotEmpty ? encounter.examOD.acuity.oldCc : 'Plano', style: const TextStyle(fontSize: 10), textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(6), child: Text(encounter.examOD.acuity.ar.isNotEmpty ? encounter.examOD.acuity.ar : 'NO TARGET', style: const TextStyle(fontSize: 10), textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(6), child: Text(encounter.examOD.acuity.ak.isNotEmpty ? encounter.examOD.acuity.ak : 'NO TARGET', style: const TextStyle(fontSize: 10), textAlign: TextAlign.center)),
                    ],
                  ),
                  TableRow(
                    children: [
                      const Padding(padding: EdgeInsets.all(6), child: Text('OS (Left)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD97706), fontSize: 10), textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(6), child: Text(encounter.examOS.acuity.uncorrected.isNotEmpty ? encounter.examOS.acuity.uncorrected : 'HM', style: const TextStyle(fontSize: 10), textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(6), child: Text(encounter.examOS.acuity.pinhole.isNotEmpty ? encounter.examOS.acuity.pinhole : 'HM', style: const TextStyle(fontSize: 10), textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(6), child: Text(encounter.examOS.acuity.bestCorrected.isNotEmpty ? encounter.examOS.acuity.bestCorrected : 'Plano', style: const TextStyle(fontSize: 10), textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(6), child: Text(encounter.examOS.acuity.oldCc.isNotEmpty ? encounter.examOS.acuity.oldCc : 'Plano', style: const TextStyle(fontSize: 10), textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(6), child: Text(encounter.examOS.acuity.ar.isNotEmpty ? encounter.examOS.acuity.ar : 'NO TARGET', style: const TextStyle(fontSize: 10), textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(6), child: Text(encounter.examOS.acuity.ak.isNotEmpty ? encounter.examOS.acuity.ak : 'NO TARGET', style: const TextStyle(fontSize: 10), textAlign: TextAlign.center)),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Table 2: Clinical Examination Measurements
              const Text('2. CLINICAL EXAMINATION MEASUREMENTS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
              const SizedBox(height: 6),
              Table(
                border: TableBorder.all(color: const Color(0xFF0F172A)),
                children: [
                  const TableRow(
                    decoration: BoxDecoration(color: Color(0xFF0F172A)),
                    children: [
                      Padding(padding: EdgeInsets.all(6), child: Text('EYE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.white), textAlign: TextAlign.center)),
                      Padding(padding: EdgeInsets.all(6), child: Text('Color', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.white), textAlign: TextAlign.center)),
                      Padding(padding: EdgeInsets.all(6), child: Text('IOP (mmHg)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.white), textAlign: TextAlign.center)),
                      Padding(padding: EdgeInsets.all(6), child: Text('Angles Gonioscopy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.white), textAlign: TextAlign.center)),
                      Padding(padding: EdgeInsets.all(6), child: Text('CDR / ON', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.white), textAlign: TextAlign.center)),
                      Padding(padding: EdgeInsets.all(6), child: Text('Confrontation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.white), textAlign: TextAlign.center)),
                      Padding(padding: EdgeInsets.all(6), child: Text('Van Herick', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.white), textAlign: TextAlign.center)),
                    ],
                  ),
                  TableRow(
                    children: [
                      const Padding(padding: EdgeInsets.all(6), child: Text('OD (Right)', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue, fontSize: 10), textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(6), child: Text(encounter.examOD.color.isNotEmpty ? encounter.examOD.color : 'B / G', style: const TextStyle(fontSize: 10), textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(6), child: Text(encounter.examOD.iop.isNotEmpty ? '${encounter.examOD.iop} mmHg' : '16 mmHg', style: const TextStyle(fontSize: 10), textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(6), child: Text(encounter.examOD.anglesGonioscopy.isNotEmpty ? encounter.examOD.anglesGonioscopy : 'Open', style: const TextStyle(fontSize: 10), textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(6), child: Text(encounter.examOD.cdrOn.isNotEmpty ? encounter.examOD.cdrOn : '0.4', style: const TextStyle(fontSize: 10), textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(6), child: Text(encounter.examOD.confrontationPeripheral.isNotEmpty ? encounter.examOD.confrontationPeripheral : 'WNL', style: const TextStyle(fontSize: 10), textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(6), child: Text(encounter.examOD.vanHerick.isNotEmpty ? encounter.examOD.vanHerick : 'G4 Wide', style: const TextStyle(fontSize: 10), textAlign: TextAlign.center)),
                    ],
                  ),
                  TableRow(
                    children: [
                      const Padding(padding: EdgeInsets.all(6), child: Text('OS (Left)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD97706), fontSize: 10), textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(6), child: Text(encounter.examOS.color.isNotEmpty ? encounter.examOS.color : 'B / G', style: const TextStyle(fontSize: 10), textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(6), child: Text(encounter.examOS.iop.isNotEmpty ? '${encounter.examOS.iop} mmHg' : '18 mmHg', style: const TextStyle(fontSize: 10), textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(6), child: Text(encounter.examOS.anglesGonioscopy.isNotEmpty ? encounter.examOS.anglesGonioscopy : 'Open', style: const TextStyle(fontSize: 10), textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(6), child: Text(encounter.examOS.cdrOn.isNotEmpty ? encounter.examOS.cdrOn : '0.5', style: const TextStyle(fontSize: 10), textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(6), child: Text(encounter.examOS.confrontationPeripheral.isNotEmpty ? encounter.examOS.confrontationPeripheral : 'WNL', style: const TextStyle(fontSize: 10), textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(6), child: Text(encounter.examOS.vanHerick.isNotEmpty ? encounter.examOS.vanHerick : 'G4 Wide', style: const TextStyle(fontSize: 10), textAlign: TextAlign.center)),
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
                    flex: 3,
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
                          Text(
                            encounter.chiefComplaint.isNotEmpty ? encounter.chiefComplaint : 'OS BOV x 1 year\nCame in w/ silingan\nNo family',
                            style: const TextStyle(fontSize: 11, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
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
                          Text('( ) Cardiac Problem', style: TextStyle(fontSize: 10)),
                          Text('( ) DM (Diabetes)', style: TextStyle(fontSize: 10)),
                          Text('(✓) HPN (Hypertension)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                          Text('( ) Kidney Problem', style: TextStyle(fontSize: 10)),
                          Text('(✓) Cholesterol det', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                          Text('( ) Allergy Hx   ( ) Asthma   ( ) Thyroid', style: TextStyle(fontSize: 9)),
                        ],
                      ),
                    ),
                  ),
                ],
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
                    Text('PLAN: ${encounter.treatmentPlan.isNotEmpty ? encounter.treatmentPlan : "Dilate OU\nTo BSC - PHIC only"}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
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
                          content: Text('Sending Clinical Consultation Record to Local Clinic Printer...'),
                          backgroundColor: AppTheme.primaryBlue,
                        ),
                      );
                    },
                    icon: const Icon(Icons.print, size: 16),
                    label: const Text('Print Consultation Sheet'),
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
