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
import '../models/prescription.dart';
import '../services/prescription_pdf_service.dart';
import '../services/team_service.dart';
import '../widgets/rx_pad_widget.dart';
import '../widgets/success_modal.dart';

class PatientProfileView extends StatefulWidget {
  final String patientId;
  final Patient? patient;
  final VoidCallback? onBack;
  final VoidCallback? onStartNewExam;

  const PatientProfileView({
    super.key,
    required this.patientId,
    this.patient,
    this.onBack,
    this.onStartNewExam,
  });

  @override
  State<PatientProfileView> createState() => _PatientProfileViewState();
}

class _PatientProfileViewState extends State<PatientProfileView> {
  @override
  void initState() {
    super.initState();
    // Visits and prescriptions are not part of the patient directory; stream them
    // for the patient being viewed.
    PatientRepository.loadPatientDetails(widget.patientId);
    PatientRepository.changeNotifier.addListener(_onRepositoryChanged);
    TeamService.instance.addListener(_onRepositoryChanged);
  }

  @override
  void didUpdateWidget(covariant PatientProfileView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.patientId != widget.patientId) {
      PatientRepository.loadPatientDetails(widget.patientId);
    }
  }

  @override
  void dispose() {
    PatientRepository.changeNotifier.removeListener(_onRepositoryChanged);
    TeamService.instance.removeListener(_onRepositoryChanged);
    super.dispose();
  }

  void _onRepositoryChanged() {
    if (mounted) setState(() {});
  }

  Patient? get _patientNullable {
    final patient = PatientRepository.getPatientById(widget.patientId) ?? widget.patient;
    if (patient == null) return null;
    final activeTeamId = TeamService.instance.activeTeam?.id;
    if (activeTeamId != null && activeTeamId.isNotEmpty) {
      if (patient.teamId.isNotEmpty && patient.teamId != activeTeamId) {
        return null;
      }
    }
    return patient;
  }
  Patient get _patient => _patientNullable!;

  void _startNewExamination() async {
    if (_patientNullable == null) return;
    if (!TeamService.instance.canWriteVisits) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${TeamService.instance.activeRole.label} role cannot create or edit clinical visits.')),
      );
      return;
    }

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
    setState(() {});
  }

  void _openDrawingModal(BuildContext context, Encounter encounter) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: AppTheme.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppTheme.borderColor),
          ),
          child: Container(
            width: 720,
            padding: EdgeInsets.all(20),
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
                          style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text('Patient: ${_patient.fullName} (${_patient.mrn})', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: AppTheme.textSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                Divider(color: AppTheme.borderColor),
                SizedBox(height: 12),

                // Display OD / OS Drawings Side by Side or Tabs
                DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      TabBar(
                        tabs: [
                          Tab(text: 'Right Eye (OD) Drawing'),
                          Tab(text: 'Left Eye (OS) Drawing'),
                        ],
                        indicatorColor: AppTheme.primaryBlue,
                        labelColor: AppTheme.primaryBlue,
                      ),
                      SizedBox(height: 16),
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
                                : Center(child: Text('No drawing recorded for OD.', style: TextStyle(color: AppTheme.textSecondary))),
                            encounter.drawingOS != null
                                ? EyeDrawingCanvas(
                                    eye: EyeType.OS,
                                    onEyeChanged: (_) {},
                                    drawingData: encounter.drawingOS,
                                    onDrawingSaved: (_) {},
                                  )
                                : Center(child: Text('No drawing recorded for OS.', style: TextStyle(color: AppTheme.textSecondary))),
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
    if (_patientNullable == null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off_outlined, size: 48, color: AppTheme.textSecondary),
              SizedBox(height: 12),
              Text('Patient Record Not Found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: widget.onBack,
                icon: Icon(Icons.arrow_back, size: 16),
                label: Text('Back to Patient Directory'),
              ),
            ],
          ),
        ),
      );
    }

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
                    side: BorderSide(color: AppTheme.borderColor),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 14 : 20),
                    child: isMobile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                            Row(
                              children: [
                                if (widget.onBack != null) ...[
                                  IconButton(
                                    icon: Icon(Icons.arrow_back, color: AppTheme.textPrimary),
                                    onPressed: widget.onBack,
                                  ),
                                  SizedBox(width: 4),
                                ],
                                CircleAvatar(
                                  radius: isMobile ? 20 : 26,
                                  backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                  child: Text(
                                    _patient.fullName.isNotEmpty ? _patient.fullName.substring(0, 1) : 'P',
                                    style: TextStyle(fontSize: isMobile ? 16 : 20, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                                  ),
                                ),
                                SizedBox(width: 12),
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
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              _patient.mrn,
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue, fontFamily: 'monospace'),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        '${_patient.gender}, ${_patient.age}y  •  DOB: ${formatClinicalDate(_patient.dateOfBirth)}',
                                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (isMobile) SizedBox(height: 14),
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
                                    icon: Icon(Icons.compare, size: 14),
                                    label: Text('Compare', style: TextStyle(fontSize: 12)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.primaryBlue,
                                      side: BorderSide(color: AppTheme.borderColor),
                                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    ),
                                  ),
                                if (_patient.encounters.length >= 2) SizedBox(width: 10),
                                ElevatedButton.icon(
                                  onPressed: _startNewExamination,
                                  icon: Icon(Icons.draw, size: 14),
                                  label: Text('+ New Examination', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryBlue,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 20, vertical: isMobile ? 10 : 14),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  if (widget.onBack != null) ...[
                                    IconButton(
                                      icon: Icon(Icons.arrow_back, color: AppTheme.textPrimary),
                                      onPressed: widget.onBack,
                                    ),
                                    SizedBox(width: 4),
                                  ],
                                  CircleAvatar(
                                    radius: 26,
                                    backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                    child: Text(
                                      _patient.fullName.isNotEmpty ? _patient.fullName.substring(0, 1) : 'P',
                                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Wrap(
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          spacing: 8,
                                          runSpacing: 4,
                                          children: [
                                            Text(_patient.fullName, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                _patient.mrn,
                                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue, fontFamily: 'monospace'),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          '${_patient.gender}, ${_patient.age}y  •  DOB: ${formatClinicalDate(_patient.dateOfBirth)}',
                                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 16),
                            Row(
                              children: [
                                if (_patient.encounters.length >= 2) ...[
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => HistoricalComparisonView(patient: _patient),
                                        ),
                                      );
                                    },
                                    icon: Icon(Icons.compare, size: 14),
                                    label: Text('Compare', style: TextStyle(fontSize: 12)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.primaryBlue,
                                      side: BorderSide(color: AppTheme.borderColor),
                                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                ],
                                ElevatedButton.icon(
                                  onPressed: _startNewExamination,
                                  icon: Icon(Icons.draw, size: 14),
                                  label: Text('+ New Examination', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryBlue,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                  ),
                ),
                SizedBox(height: 20),

            // Profile Tabs: Overview | Examination History | Prescriptions
            Card(
              color: AppTheme.cardBg,
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppTheme.borderColor),
              ),
              child: Column(
                children: [
                  TabBar(
                    tabs: [
                      Tab(text: 'Overview'),
                      Tab(text: 'Examination History'),
                      Tab(text: 'Prescriptions'),
                    ],
                    indicatorColor: AppTheme.primaryBlue,
                    labelColor: AppTheme.primaryBlue,
                    unselectedLabelColor: AppTheme.textSecondary,
                  ),
                  Divider(height: 1, color: AppTheme.borderColor),
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
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
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
                    Text('Demographics & Contact Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary)),
                    SizedBox(height: 12),
                    Text('Date of Birth: ${_patient.dateOfBirth}', style: TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
                    SizedBox(height: 6),
                    Text('Registered: ${formatRegistrationDate(_patient.createdAt)}', style: TextStyle(fontSize: 14, color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                    SizedBox(height: 6),
                    Text('Contact Phone: ${_patient.phone}', style: TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
                    SizedBox(height: 6),
                    Text('Address: ${_patient.address}', style: TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
                    SizedBox(height: 6),
                    Text('Referring Doctor: ${_patient.referringDoctor ?? 'Self-referred'}', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Medical History & Allergies', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary)),
                    SizedBox(height: 12),
                    _patient.medicalHistory.isEmpty
                        ? Text('No prior medical history recorded.', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary))
                        : Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _patient.medicalHistory.map((item) {
                              return Chip(
                                label: Text(item, style: TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
                                backgroundColor: Color(0xFFF1F5F9),
                                side: BorderSide.none,
                              );
                            }).toList(),
                          ),
                    SizedBox(height: 12),
                    _patient.allergies.isEmpty
                        ? Text('No known allergies recorded.', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary))
                        : Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _patient.allergies.map((item) {
                              return Chip(
                                label: Text(item, style: TextStyle(fontSize: 12, color: Colors.redAccent)),
                                backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                                side: BorderSide(color: Colors.redAccent),
                              );
                            }).toList(),
                          ),
                  ],
                ),
              ),
            ],
          ),
          if (_patient.notes.isNotEmpty) ...[
            SizedBox(height: 16),
            Text('Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary)),
            SizedBox(height: 8),
            Text(_patient.notes, style: TextStyle(fontSize: 14, color: AppTheme.textPrimary, height: 1.4)),
          ],
          SizedBox(height: 24),
          Divider(color: AppTheme.borderColor),
          SizedBox(height: 16),
          Text('Latest Recorded Diagnosis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary)),
          SizedBox(height: 8),
          _patient.previousDiagnoses.isEmpty
              ? Text('No prior diagnosis recorded.', style: TextStyle(color: AppTheme.textSecondary))
              : Wrap(
                  spacing: 8,
                  children: _patient.previousDiagnoses.map((d) {
                    return Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(8)),
                      child: Text(d, style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold, fontSize: 13)),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildExamHistoryTab() {
    if (_patient.encounters.isEmpty) {
      return Center(
        child: Text('No historical examinations recorded yet.', style: TextStyle(color: AppTheme.textSecondary)),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.all(20),
      itemCount: _patient.encounters.length,
      separatorBuilder: (context, index) => SizedBox(height: 16),
      itemBuilder: (context, index) {
        final enc = _patient.encounters[index];
        final hasDrawing = enc.drawingOD != null || enc.drawingOS != null;

        return Card(
          color: AppTheme.cardBg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppTheme.borderColor),
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.event_available, color: AppTheme.primaryBlue, size: 18),
                        SizedBox(width: 8),
                        Text(formatClinicalDate(enc.date), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                        SizedBox(width: 8),
                        Text('— ${enc.doctorName}', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _openExamDetail(enc),
                          icon: Icon(Icons.visibility, size: 14),
                          label: Text('View Examination', style: TextStyle(fontSize: 11)),
                        ),
                        if (hasDrawing) ...[
                          SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () => _openDrawingModal(context, enc),
                            icon: Icon(Icons.draw, size: 14),
                            label: Text('View Drawing', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text('Chief Complaint: ${enc.chiefComplaint}', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.borderColor)),
                        child: Text(
                          'OD: VA ${enc.examOD.acuity.uncorrected} | IOP ${enc.examOD.iop} mmHg',
                          style: TextStyle(fontSize: 12, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.borderColor)),
                        child: Text(
                          'OS: VA ${enc.examOS.acuity.uncorrected} | IOP ${enc.examOS.iop} mmHg',
                          style: TextStyle(fontSize: 12, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text('Diagnosis: ${enc.diagnosis}', style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPdfPreviewModal(Prescription rx) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 640,
          padding: EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Official Prescription Document Preview',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(icon: Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                SizedBox(height: 16),
                RxPadWidget(
                  patient: _patient,
                  items: rx.items,
                  date: rx.date,
                  doctorName: rx.doctorName.isNotEmpty ? rx.doctorName : 'Dr. Sigrid T. Robillos',
                  showBorder: true,
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        await PrescriptionPdfService.downloadPdf(
                          patient: _patient,
                          items: rx.items,
                          date: rx.date,
                          doctorName: rx.doctorName.isNotEmpty ? rx.doctorName : 'Dr. Sigrid T. Robillos',
                        );
                        if (context.mounted) {
                          showActionSuccessModal(
                            context: context,
                            title: 'Prescription PDF Downloaded',
                            message: 'The official prescription document for ${_patient.fullName} has been exported to PDF.',
                            icon: Icons.file_download_outlined,
                          );
                        }
                      },
                      icon: Icon(Icons.download, size: 16),
                      label: Text('Download PDF'),
                    ),
                    SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await PrescriptionPdfService.printPrescription(
                          patient: _patient,
                          items: rx.items,
                          date: rx.date,
                          doctorName: rx.doctorName.isNotEmpty ? rx.doctorName : 'Dr. Sigrid T. Robillos',
                        );
                      },
                      icon: Icon(Icons.print, size: 16),
                      label: Text('Print Prescription'),
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

  Widget _buildPrescriptionsTab() {
    if (_patient.prescriptions.isEmpty) {
      return Center(
        child: Text('No recorded prescriptions for this patient.', style: TextStyle(color: AppTheme.textSecondary)),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.all(20),
      itemCount: _patient.prescriptions.length,
      separatorBuilder: (context, index) => SizedBox(height: 20),
      itemBuilder: (context, index) {
        final rx = _patient.prescriptions[index];

        return Card(
          color: AppTheme.cardBg,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppTheme.borderColor),
          ),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.local_pharmacy_rounded, color: AppTheme.primaryBlue, size: 20),
                        SizedBox(width: 8),
                        Text('Prescription Record — ${rx.date}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PrescriptionView(initialPatient: _patient),
                              ),
                            );
                          },
                          icon: Icon(Icons.edit_note_rounded, size: 16),
                          label: Text('Open in Workspace', style: TextStyle(fontSize: 12)),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _showPdfPreviewModal(rx),
                          icon: Icon(Icons.picture_as_pdf, size: 14),
                          label: Text('View / Print PDF', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // Live Prescription Pad Preview Layout
                RxPadWidget(
                  patient: _patient,
                  items: rx.items,
                  date: rx.date,
                  doctorName: rx.doctorName.isNotEmpty ? rx.doctorName : 'Dr. Sigrid T. Robillos',
                  showBorder: true,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
