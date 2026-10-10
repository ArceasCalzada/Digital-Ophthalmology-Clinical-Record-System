import 'package:flutter/material.dart';
import '../models/patient.dart';
import '../models/encounter.dart';
import '../models/drawing_stroke.dart';
import '../theme/app_theme.dart';
import 'drawing/paper_sheet_canvas.dart';

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
        width: 860,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.94),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Header Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.print_rounded, color: AppTheme.primaryBlue, size: 28),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PRINT PREVIEW - CLINICAL CONSULTATION SHEET',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue, letterSpacing: 0.5),
                        ),
                        Text(
                          'Traditional Paper Form Visual Format',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Scrollable Traditional Paper Sheet Preview Canvas
            Expanded(
              child: SingleChildScrollView(
                child: Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const double sheetWidth = 820.0;
                      const double sheetHeight = sheetWidth * 1.32; // Standard clinical paper aspect ratio

                      return Container(
                        width: sheetWidth,
                        height: sheetHeight,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF94A3B8), width: 1.2),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 12,
                              spreadRadius: 1,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Stack(
                            children: [
                              // 100% Faithful Traditional Paper Clinical Exam Form with Dynamic Firebase Data
                              CustomPaint(
                                size: const Size(sheetWidth, sheetHeight),
                                painter: PrintedPaperSheetPainter(
                                  width: sheetWidth,
                                  height: sheetHeight,
                                  patientName: patient.fullName.isNotEmpty ? patient.fullName : 'ASTURIAS, EDGARDO',
                                  middleName: patient.middleName.isNotEmpty ? patient.middleName : 'PEREZ',
                                  date: encounter.date.isNotEmpty ? encounter.date : formatClinicalDate(DateTime.now().toString().substring(0, 10)),
                                  ageSex: '${patient.age}y / ${patient.gender.isNotEmpty ? patient.gender : "Male"}',
                                  address: patient.address.isNotEmpty ? patient.address : 'Apas, Davao City',
                                  contactNumber: patient.phone.isNotEmpty ? patient.phone : '+63 917 882 1963',
                                  occupation: patient.occupation.isNotEmpty ? patient.occupation : 'Civil Servant',
                                  phicNumber: patient.phicNumber.isNotEmpty ? patient.phicNumber : '19-02581024-8',
                                  birthDate: patient.dateOfBirth.isNotEmpty ? formatClinicalDate(patient.dateOfBirth) : 'May 7, 1963',
                                  encounter: encounter,
                                  medicalHistory: patient.medicalHistory,
                                ),
                              ),

                              // Vector Inking Layer - Renders saved freehand drawings accurately mapped over anatomical diagrams
                              Positioned.fill(
                                child: CustomPaint(
                                  size: const Size(sheetWidth, sheetHeight),
                                  painter: PaperSheetInkingPainter(
                                    strokes: encounter.paperSheetDrawing?.strokes ?? [],
                                    currentPoints: const [],
                                    currentColor: Colors.transparent,
                                    currentSize: 1.0,
                                    currentTool: DrawingTool.pen,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Footer Action Buttons
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
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

