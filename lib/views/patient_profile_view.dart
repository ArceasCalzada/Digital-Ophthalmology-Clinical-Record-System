import 'package:flutter/material.dart';
import '../models/patient.dart';
import '../models/encounter.dart';
import '../models/eye_exam.dart';
import '../widgets/drawing/eye_drawing_canvas.dart';
import '../theme/app_theme.dart';
import 'eye_exam_view.dart';
import 'historical_comparison_view.dart';
import 'examination_detail_view.dart';
import 'prescription_view.dart';

class PatientProfileView extends StatefulWidget {
  final String patientId;
  final VoidCallback? onBack;
  final VoidCallback? onStartNewExam;

  const PatientProfileView({
    super.key,
    required this.patientId,
    this.onBack,
    this.onStartNewExam,
  });

  @override
  State<PatientProfileView> createState() => _PatientProfileViewState();
}

class _PatientProfileViewState extends State<PatientProfileView> {
  late Patient _patient;

  @override
  void initState() {
    super.initState();
    _loadPatient();
  }

  void _loadPatient() {
    final p = PatientRepository.getPatientById(widget.patientId);
    if (p != null) {
      _patient = p;
    }
  }

  void _startNewExamination() async {
    if (widget.onStartNewExam != null) {
      widget.onStartNewExam!();
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EyeExamView(patient: _patient),
      ),
    );
    setState(() {
      _loadPatient();
    });
  }

  void _openDrawingModal(BuildContext context, Encounter encounter) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: AppTheme.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppTheme.borderColor),
          ),
          child: Container(
            width: 720,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Examination Vector Drawing — ${encounter.date}',
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text('Patient: ${_patient.fullName} (${_patient.mrn})', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(color: AppTheme.borderColor),
                const SizedBox(height: 12),

                // Display OD / OS Drawings Side by Side or Tabs
                DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      const TabBar(
                        tabs: [
                          Tab(text: 'Right Eye (OD) Drawing'),
                          Tab(text: 'Left Eye (OS) Drawing'),
                        ],
                        indicatorColor: AppTheme.primaryBlue,
                        labelColor: AppTheme.primaryBlue,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 520,
                        child: TabBarView(
                          children: [
                            encounter.drawingOD != null
                                ? EyeDrawingCanvas(
                                    eye: EyeType.OD,
                                    onEyeChanged: (_) {},
                                    drawingData: encounter.drawingOD,
                                    onDrawingSaved: (_) {},
                                  )
                                : const Center(child: Text('No drawing recorded for OD.', style: TextStyle(color: AppTheme.textSecondary))),
                            encounter.drawingOS != null
                                ? EyeDrawingCanvas(
                                    eye: EyeType.OS,
                                    onEyeChanged: (_) {},
                                    drawingData: encounter.drawingOS,
                                    onDrawingSaved: (_) {},
                                  )
                                : const Center(child: Text('No drawing recorded for OS.', style: TextStyle(color: AppTheme.textSecondary))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openExamDetail(Encounter encounter) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExaminationDetailView(patient: _patient, encounter: encounter),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 768;

          return SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 12 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Navigation & Patient Header Card
                Card(
                  color: AppTheme.cardBg,
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppTheme.borderColor),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 14 : 20),
                    child: Column(
                      children: [
                        Flex(
                          direction: isMobile ? Axis.vertical : Axis.horizontal,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: isMobile ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                if (widget.onBack != null) ...[
                                  IconButton(
                                    icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
                                    onPressed: widget.onBack,
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                CircleAvatar(
                                  radius: isMobile ? 20 : 26,
                                  backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                  child: Text(
                                    _patient.fullName.isNotEmpty ? _patient.fullName.substring(0, 1) : 'P',
                                    style: TextStyle(fontSize: isMobile ? 16 : 20, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          Text(_patient.fullName, style: TextStyle(fontSize: isMobile ? 18 : 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              _patient.mrn,
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue, fontFamily: 'monospace'),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${_patient.gender}, ${_patient.age}y  •  DOB: ${formatClinicalDate(_patient.dateOfBirth)}',
                                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (isMobile) const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: isMobile ? MainAxisAlignment.start : MainAxisAlignment.end,
                              children: [
                                if (_patient.encounters.length >= 2)
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => HistoricalComparisonView(patient: _patient),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.compare, size: 14),
                                    label: const Text('Compare', style: TextStyle(fontSize: 12)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.primaryBlue,
                                      side: const BorderSide(color: AppTheme.borderColor),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    ),
                                  ),
                                if (_patient.encounters.length >= 2) const SizedBox(width: 10),
                                ElevatedButton.icon(
                                  onPressed: _startNewExamination,
                                  icon: const Icon(Icons.draw, size: 14),
                                  label: const Text('+ New Examination', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryBlue,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 20, vertical: isMobile ? 10 : 14),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

            // Profile Tabs: Overview | Examination History | Prescriptions
            Card(
              color: AppTheme.cardBg,
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppTheme.borderColor),
              ),
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'Overview'),
                      Tab(text: 'Examination History'),
                      Tab(text: 'Prescriptions'),
                    ],
                    indicatorColor: AppTheme.primaryBlue,
                    labelColor: AppTheme.primaryBlue,
                    unselectedLabelColor: AppTheme.textSecondary,
                  ),
                  const Divider(height: 1, color: AppTheme.borderColor),
                  SizedBox(
                    height: 580,
                    child: TabBarView(
                      children: [
                        // Tab 1: Overview
                        _buildOverviewTab(),

                        // Tab 2: Examination History
                        _buildExamHistoryTab(),

                        // Tab 3: Prescriptions
                        _buildPrescriptionsTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  ),
);
  }

  Widget _buildOverviewTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Demographics & Contact Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary)),
                    const SizedBox(height: 12),
                    Text('Date of Birth: ${_patient.dateOfBirth}', style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
                    const SizedBox(height: 6),
                    Text('Contact Phone: ${_patient.phone}', style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
                    const SizedBox(height: 6),
                    Text('Address: ${_patient.address}', style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
                    const SizedBox(height: 6),
                    Text('Referring Doctor: ${_patient.referringDoctor ?? 'Self-referred'}', style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Medical History & Allergies', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _patient.medicalHistory.map((item) {
                        return Chip(
                          label: Text(item, style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
                          backgroundColor: const Color(0xFFF1F5F9),
                          side: BorderSide.none,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _patient.allergies.map((item) {
                        return Chip(
                          label: Text(item, style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
                          backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                          side: const BorderSide(color: Colors.redAccent),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(color: AppTheme.borderColor),
          const SizedBox(height: 16),
          const Text('Latest Recorded Diagnosis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          _patient.previousDiagnoses.isEmpty
              ? const Text('No prior diagnosis recorded.', style: TextStyle(color: AppTheme.textSecondary))
              : Wrap(
                  spacing: 8,
                  children: _patient.previousDiagnoses.map((d) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(8)),
                      child: Text(d, style: const TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold, fontSize: 13)),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildExamHistoryTab() {
    if (_patient.encounters.isEmpty) {
      return const Center(
        child: Text('No historical examinations recorded yet.', style: TextStyle(color: AppTheme.textSecondary)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _patient.encounters.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final enc = _patient.encounters[index];
        final hasDrawing = enc.drawingOD != null || enc.drawingOS != null;

        return Card(
          color: const Color(0xFFF8FAFC),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppTheme.borderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.event_available, color: AppTheme.primaryBlue, size: 18),
                        const SizedBox(width: 8),
                        Text(formatClinicalDate(enc.date), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                        const SizedBox(width: 8),
                        Text('— ${enc.doctorName}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _openExamDetail(enc),
                          icon: const Icon(Icons.visibility, size: 14),
                          label: const Text('View Examination', style: TextStyle(fontSize: 11)),
                        ),
                        if (hasDrawing) ...[
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () => _openDrawingModal(context, enc),
                            icon: const Icon(Icons.draw, size: 14),
                            label: const Text('View Drawing', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Chief Complaint: ${enc.chiefComplaint}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.borderColor)),
                        child: Text(
                          'OD: VA ${enc.examOD.acuity.uncorrected} | IOP ${enc.examOD.iop} mmHg',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.borderColor)),
                        child: Text(
                          'OS: VA ${enc.examOS.acuity.uncorrected} | IOP ${enc.examOS.iop} mmHg',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Diagnosis: ${enc.diagnosis}', style: const TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPrescriptionsTab() {
    if (_patient.prescriptions.isEmpty) {
      return const Center(
        child: Text('No recorded prescriptions for this patient.', style: TextStyle(color: AppTheme.textSecondary)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _patient.prescriptions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final rx = _patient.prescriptions[index];

        return Card(
          color: const Color(0xFFF8FAFC),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppTheme.borderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Prescription — ${rx.date}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PrescriptionView(initialPatient: _patient),
                          ),
                        );
                      },
                      icon: const Icon(Icons.picture_as_pdf, size: 14),
                      label: const Text('View / Print PDF', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('${rx.items.length} Medications Prescribed:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryBlue)),
                const SizedBox(height: 6),
                ...rx.items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• ${item.medicationName} (${item.strength}) — ${item.dosage}, ${item.frequency}', style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}
