import 'package:flutter/material.dart';
import '../models/patient.dart';
import '../models/eye_exam.dart';
import '../models/drawing_stroke.dart';
import '../models/encounter.dart';
import '../widgets/drawing/eye_drawing_canvas.dart';
import '../widgets/pdf_exam_preview_dialog.dart';
import '../theme/app_theme.dart';
import 'prescription_view.dart';

class EyeExamView extends StatefulWidget {
  final Patient? patient;
  final Function(Patient)? onExamComplete;

  const EyeExamView({super.key, this.patient, this.onExamComplete});

  @override
  State<EyeExamView> createState() => _EyeExamViewState();
}

class _EyeExamViewState extends State<EyeExamView> {
  late Patient _activePatient;

  // Header controllers
  final TextEditingController _occupationController = TextEditingController();
  final TextEditingController _phicController = TextEditingController();

  // Refraction & Visual Acuity controllers (OD)
  final TextEditingController _vaODController = TextEditingController(text: '20/30');
  final TextEditingController _phODController = TextEditingController(text: '20/20');
  final TextEditingController _ccODController = TextEditingController(text: '-1.00 DS');
  final TextEditingController _oldCcODController = TextEditingController(text: '-0.75 DS');
  final TextEditingController _arODController = TextEditingController(text: '-1.00 +0.25 x 90');

  // Refraction & Visual Acuity controllers (OS)
  final TextEditingController _vaOSController = TextEditingController(text: 'HM');
  final TextEditingController _phOSController = TextEditingController(text: 'HM');
  final TextEditingController _ccOSController = TextEditingController(text: 'Plano');
  final TextEditingController _oldCcOSController = TextEditingController(text: 'Plano');
  final TextEditingController _arOSController = TextEditingController(text: 'NO TARGET');

  // Clinical Exam controllers (OD)
  final TextEditingController _colorODController = TextEditingController(text: 'B / G');
  final TextEditingController _iopODController = TextEditingController(text: '14');
  String _anglesOD = 'Open';
  final TextEditingController _cdrODController = TextEditingController(text: '0.3');
  String _confrontationOD = 'WNL';
  String _vanHerickOD = 'G4 Wide';

  // Clinical Exam controllers (OS)
  final TextEditingController _colorOSController = TextEditingController(text: 'B / G');
  final TextEditingController _iopOSController = TextEditingController(text: '16');
  String _anglesOS = 'Open';
  final TextEditingController _cdrOSController = TextEditingController(text: '0.4');
  String _confrontationOS = 'WNL';
  String _vanHerickOS = 'G4 Wide';

  // Systemic History Checkboxes
  final Map<String, bool> _systemicHistory = {
    'Cardiac Problem': false,
    'DM (Diabetes Mellitus)': false,
    'HPN (Hypertension)': true,
    'Kidney Problem': false,
    'Cholesterol det': true,
    'Allergy Hx': false,
    'Asthma Hx': false,
    'Thyroid Problem': false,
  };

  // Chief Complaint, Assessment & Plan
  final TextEditingController _chiefComplaintController = TextEditingController();
  final TextEditingController _assessmentController = TextEditingController();
  final TextEditingController _planController = TextEditingController();

  final EyeExamData _examOD = EyeExamData(acuity: VisualAcuity(), refraction: Refraction());
  final EyeExamData _examOS = EyeExamData(acuity: VisualAcuity(), refraction: Refraction());

  EyeDrawingData? _drawingOD;
  EyeDrawingData? _drawingOS;

  String _diagramType = 'fundus';

  @override
  void initState() {
    super.initState();
    _activePatient = widget.patient ?? PatientRepository.getAllPatients().first;
    _occupationController.text = _activePatient.occupation;
    _phicController.text = _activePatient.phicNumber;

    _chiefComplaintController.text = 'OS BOV x 1 year. Came in w/ neighbor. No family history.';
    _assessmentController.text = 'Mature Cataract OS, Glaucoma Suspect OU';
    _planController.text = 'Dilate OU. For Phacoemulsification Surgery OS - PHIC Only.';

    if (_activePatient.encounters.isNotEmpty) {
      final lastEnc = _activePatient.encounters.first;
      _drawingOD = lastEnc.drawingOD;
      _drawingOS = lastEnc.drawingOS;
    }
  }

  void _showExaminationSummaryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.assignment_turned_in, color: AppTheme.primaryBlue),
            SizedBox(width: 8),
            Text('Examination Record Verification', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          ],
        ),
        content: SizedBox(
          width: 540,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Patient: ${_activePatient.fullName} (${_activePatient.mrn})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text('Age/Sex: ${_activePatient.age}y / ${_activePatient.gender}  •  PHIC: ${_phicController.text}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const Divider(color: AppTheme.borderColor),
              const SizedBox(height: 8),
              Text('Chief Complaint: ${_chiefComplaintController.text}', style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              Text('Assessment: ${_assessmentController.text}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
              Text('Plan: ${_planController.text}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
              const SizedBox(height: 8),
              Text('Eye Drawings Saved: OD (${_drawingOD != null ? "✓ Recorded" : "None"}), OS (${_drawingOS != null ? "✓ Recorded" : "None"})', style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back to Edit'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              final parentContext = this.context;
              Navigator.pop(context);
              if (!mounted) return;
              final tempEncounter = Encounter(
                id: 'enc-${DateTime.now().millisecondsSinceEpoch}',
                patientId: _activePatient.id,
                date: DateTime.now().toIso8601String().substring(0, 10),
                doctorName: 'Dr. Sarah Jenkins, MD',
                chiefComplaint: _chiefComplaintController.text,
                examOD: _examOD,
                examOS: _examOS,
                drawingOD: _drawingOD,
                drawingOS: _drawingOS,
                diagnosis: _assessmentController.text,
                treatmentPlan: _planController.text,
              );
              showClinicalExamPdfPreviewModal(
                context: parentContext,
                patient: _activePatient,
                encounter: tempEncounter,
              );
            },
            icon: const Icon(Icons.picture_as_pdf, size: 16),
            label: const Text('Print / Export PDF'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _saveFullEncounter();
            },
            icon: const Icon(Icons.save, size: 16),
            label: const Text('Save Record to System'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _saveFullEncounter() {
    final newEncounter = Encounter(
      id: 'enc-${DateTime.now().millisecondsSinceEpoch}',
      patientId: _activePatient.id,
      date: DateTime.now().toIso8601String().substring(0, 10),
      doctorName: 'Dr. Sarah Jenkins, MD',
      chiefComplaint: _chiefComplaintController.text,
      examOD: _examOD,
      examOS: _examOS,
      drawingOD: _drawingOD,
      drawingOS: _drawingOS,
      diagnosis: _assessmentController.text,
      treatmentPlan: _planController.text,
    );

    PatientRepository.addEncounter(_activePatient.id, newEncounter);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF10B981)),
            SizedBox(width: 8),
            Text('Clinical Examination Record & Eye Drawings Saved!'),
          ],
        ),
        backgroundColor: AppTheme.cardBg,
      ),
    );

    if (widget.onExamComplete != null) {
      final updatedPatient = PatientRepository.getPatientById(_activePatient.id) ?? _activePatient;
      widget.onExamComplete!(updatedPatient);
    } else {
      Navigator.pop(context);
    }
  }

  void _openPrescriptionGenerator() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PrescriptionView(initialPatient: _activePatient),
      ),
    );
  }

  void _openFullScreenDualEyeWorkspace() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog.fullscreen(
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            return Scaffold(
              backgroundColor: const Color(0xFF0F172A),
              appBar: AppBar(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                title: Text('Fullscreen Digital Eye Canvas Workspace — ${_activePatient.fullName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                actions: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'fundus', label: Text('Fundus / Retina')),
                      ButtonSegment(value: 'anterior', label: Text('Anterior Segment')),
                      ButtonSegment(value: 'plain', label: Text('Plain Canvas')),
                    ],
                    selected: {_diagramType},
                    onSelectionChanged: (val) {
                      setState(() => _diagramType = val.first);
                      setDialogState(() {});
                    },
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Done Drawing'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue, foregroundColor: Colors.white),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          const Text('RIGHT EYE (OD)', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue, fontSize: 16)),
                          const SizedBox(height: 8),
                          EyeDrawingCanvas(
                            eye: EyeType.OD,
                            onEyeChanged: (_) {},
                            diagramType: _diagramType,
                            drawingData: _drawingOD,
                            onDrawingSaved: (data) {
                              setState(() => _drawingOD = data);
                              setDialogState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        children: [
                          const Text('LEFT EYE (OS)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD97706), fontSize: 16)),
                          const SizedBox(height: 8),
                          EyeDrawingCanvas(
                            eye: EyeType.OS,
                            onEyeChanged: (_) {},
                            diagramType: _diagramType,
                            drawingData: _drawingOS,
                            onDrawingSaved: (data) {
                              setState(() => _drawingOS = data);
                              setDialogState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      appBar: AppBar(
        title: Text('Ophthalmic Clinical Examination Record — ${_activePatient.fullName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textPrimary)),
        actions: [
          OutlinedButton.icon(
            onPressed: _openPrescriptionGenerator,
            icon: const Icon(Icons.local_pharmacy, size: 16),
            label: const Text('Create Prescription'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryBlue,
              side: const BorderSide(color: AppTheme.borderColor),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _showExaminationSummaryDialog,
            icon: const Icon(Icons.save, size: 18),
            label: const Text('Review & Save Record'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SECTION 1: Patient Header Banner (Mirroring Paper Sheet Header)
            Card(
              color: AppTheme.cardBg,
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppTheme.borderColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                          child: Text(_activePatient.fullName.substring(0, 1), style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Wrap(
                            spacing: 16,
                            runSpacing: 8,
                            children: [
                              Text('NAME: ${_activePatient.fullName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary)),
                              Text('DATE: ${DateTime.now().toString().substring(0, 10)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue, fontSize: 13)),
                              Text('AGE/SEX: ${_activePatient.age}y / ${_activePatient.gender}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                              Text('DOB: ${_activePatient.dateOfBirth}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16, color: AppTheme.borderColor),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: TextEditingController(text: _activePatient.address),
                            decoration: const InputDecoration(labelText: 'Address', isDense: true),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _occupationController,
                            decoration: const InputDecoration(labelText: 'Occupation', isDense: true),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _phicController,
                            decoration: const InputDecoration(labelText: 'PHIC # (PhilHealth)', isDense: true),
                            style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // SECTION 2 & 3: Refraction & Ophthalmic Examination Tables
            Card(
              color: AppTheme.cardBg,
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppTheme.borderColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('REFRACTION, VISUAL ACUITY & CLINICAL EXAMINATION MATRIX', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryBlue)),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Table(
                        border: TableBorder.all(color: AppTheme.borderColor),
                        defaultColumnWidth: const FixedColumnWidth(100),
                        children: [
                          // Table Header
                          const TableRow(
                            decoration: BoxDecoration(color: Color(0xFFF1F5F9)),
                            children: [
                              Padding(padding: EdgeInsets.all(8), child: Text('EYE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              Padding(padding: EdgeInsets.all(8), child: Text('VA (Dist)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              Padding(padding: EdgeInsets.all(8), child: Text('PH', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              Padding(padding: EdgeInsets.all(8), child: Text('CC (Glasses)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              Padding(padding: EdgeInsets.all(8), child: Text('Old CC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              Padding(padding: EdgeInsets.all(8), child: Text('AR / AK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              Padding(padding: EdgeInsets.all(8), child: Text('Color', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              Padding(padding: EdgeInsets.all(8), child: Text('IOP (mmHg)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              Padding(padding: EdgeInsets.all(8), child: Text('Angles (Gonio)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              Padding(padding: EdgeInsets.all(8), child: Text('CDR / ON', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              Padding(padding: EdgeInsets.all(8), child: Text('Confrontation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              Padding(padding: EdgeInsets.all(8), child: Text('Van Herick', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            ],
                          ),
                          // Row OD (Right Eye)
                          TableRow(
                            children: [
                              const Padding(padding: EdgeInsets.all(8), child: Text('OD (Right)', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue, fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(4), child: TextField(controller: _vaODController, decoration: const InputDecoration(isDense: true), style: const TextStyle(fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(4), child: TextField(controller: _phODController, decoration: const InputDecoration(isDense: true), style: const TextStyle(fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(4), child: TextField(controller: _ccODController, decoration: const InputDecoration(isDense: true), style: const TextStyle(fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(4), child: TextField(controller: _oldCcODController, decoration: const InputDecoration(isDense: true), style: const TextStyle(fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(4), child: TextField(controller: _arODController, decoration: const InputDecoration(isDense: true), style: const TextStyle(fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(4), child: TextField(controller: _colorODController, decoration: const InputDecoration(isDense: true), style: const TextStyle(fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(4), child: TextField(controller: _iopODController, decoration: const InputDecoration(isDense: true), style: const TextStyle(fontSize: 11))),
                              Padding(
                                padding: const EdgeInsets.all(4),
                                child: DropdownButton<String>(
                                  value: _anglesOD,
                                  isDense: true,
                                  isExpanded: true,
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary),
                                  items: ['Open', 'Narrow', 'Closed'].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                                  onChanged: (val) => setState(() => _anglesOD = val!),
                                ),
                              ),
                              Padding(padding: const EdgeInsets.all(4), child: TextField(controller: _cdrODController, decoration: const InputDecoration(isDense: true), style: const TextStyle(fontSize: 11))),
                              Padding(
                                padding: const EdgeInsets.all(4),
                                child: DropdownButton<String>(
                                  value: _confrontationOD,
                                  isDense: true,
                                  isExpanded: true,
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary),
                                  items: ['WNL', 'Defect'].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                                  onChanged: (val) => setState(() => _confrontationOD = val!),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(4),
                                child: DropdownButton<String>(
                                  value: _vanHerickOD,
                                  isDense: true,
                                  isExpanded: true,
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary),
                                  items: ['G1', 'G2', 'G3', 'G4 Wide'].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                                  onChanged: (val) => setState(() => _vanHerickOD = val!),
                                ),
                              ),
                            ],
                          ),
                          // Row OS (Left Eye)
                          TableRow(
                            children: [
                              const Padding(padding: EdgeInsets.all(8), child: Text('OS (Left)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD97706), fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(4), child: TextField(controller: _vaOSController, decoration: const InputDecoration(isDense: true), style: const TextStyle(fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(4), child: TextField(controller: _phOSController, decoration: const InputDecoration(isDense: true), style: const TextStyle(fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(4), child: TextField(controller: _ccOSController, decoration: const InputDecoration(isDense: true), style: const TextStyle(fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(4), child: TextField(controller: _oldCcOSController, decoration: const InputDecoration(isDense: true), style: const TextStyle(fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(4), child: TextField(controller: _arOSController, decoration: const InputDecoration(isDense: true), style: const TextStyle(fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(4), child: TextField(controller: _colorOSController, decoration: const InputDecoration(isDense: true), style: const TextStyle(fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(4), child: TextField(controller: _iopOSController, decoration: const InputDecoration(isDense: true), style: const TextStyle(fontSize: 11))),
                              Padding(
                                padding: const EdgeInsets.all(4),
                                child: DropdownButton<String>(
                                  value: _anglesOS,
                                  isDense: true,
                                  isExpanded: true,
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary),
                                  items: ['Open', 'Narrow', 'Closed'].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                                  onChanged: (val) => setState(() => _anglesOS = val!),
                                ),
                              ),
                              Padding(padding: const EdgeInsets.all(4), child: TextField(controller: _cdrOSController, decoration: const InputDecoration(isDense: true), style: const TextStyle(fontSize: 11))),
                              Padding(
                                padding: const EdgeInsets.all(4),
                                child: DropdownButton<String>(
                                  value: _confrontationOS,
                                  isDense: true,
                                  isExpanded: true,
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary),
                                  items: ['WNL', 'Defect'].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                                  onChanged: (val) => setState(() => _confrontationOS = val!),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(4),
                                child: DropdownButton<String>(
                                  value: _vanHerickOS,
                                  isDense: true,
                                  isExpanded: true,
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary),
                                  items: ['G1', 'G2', 'G3', 'G4 Wide'].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                                  onChanged: (val) => setState(() => _vanHerickOS = val!),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // SECTION 4 & 5: Chief Complaint / HPI & Systemic History
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 768;
                return Flex(
                  direction: isMobile ? Axis.vertical : Axis.horizontal,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Chief Complaint & HPI
                    Expanded(
                      flex: isMobile ? 0 : 2,
                      child: Card(
                        color: AppTheme.cardBg,
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: AppTheme.borderColor),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('CHIEF COMPLAINT / HPI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryBlue)),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _chiefComplaintController,
                                maxLines: 4,
                                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                                decoration: const InputDecoration(
                                  hintText: 'e.g. OS BOV x 1 year. Came in w/ neighbor. No family history...',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (!isMobile) const SizedBox(width: 16),
                    if (isMobile) const SizedBox(height: 16),

                    // Systemic Medical History Checkboxes
                    Expanded(
                      flex: isMobile ? 0 : 1,
                      child: Card(
                        color: AppTheme.cardBg,
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: AppTheme.borderColor),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('SYSTEMIC MEDICAL HISTORY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryBlue)),
                              const SizedBox(height: 8),
                              Wrap(
                                children: _systemicHistory.keys.map((key) {
                                  return CheckboxListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(key, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    value: _systemicHistory[key],
                                    onChanged: (val) => setState(() => _systemicHistory[key] = val ?? false),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // SECTION 6: Digital Eye Drawing Workspace
            Card(
              color: AppTheme.cardBg,
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppTheme.borderColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.brush, color: AppTheme.primaryBlue),
                            SizedBox(width: 8),
                            Text('DIGITAL EYE DRAWING DIAGRAMS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary)),
                          ],
                        ),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(value: 'fundus', label: Text('Fundus / Retina')),
                                ButtonSegment(value: 'anterior', label: Text('Anterior Segment')),
                                ButtonSegment(value: 'plain', label: Text('Plain Canvas')),
                              ],
                              selected: {_diagramType},
                              onSelectionChanged: (val) => setState(() => _diagramType = val.first),
                            ),
                            ElevatedButton.icon(
                              onPressed: _openFullScreenDualEyeWorkspace,
                              icon: const Icon(Icons.fullscreen, size: 18),
                              label: const Text('Full Screen Canvas', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isDualColumn = constraints.maxWidth > 700;
                        if (isDualColumn) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    const Text('RIGHT EYE (OD)', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                                    const SizedBox(height: 8),
                                    EyeDrawingCanvas(
                                      eye: EyeType.OD,
                                      onEyeChanged: (_) {},
                                      diagramType: _diagramType,
                                      drawingData: _drawingOD,
                                      onDrawingSaved: (data) => setState(() => _drawingOD = data),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  children: [
                                    const Text('LEFT EYE (OS)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                                    const SizedBox(height: 8),
                                    EyeDrawingCanvas(
                                      eye: EyeType.OS,
                                      onEyeChanged: (_) {},
                                      diagramType: _diagramType,
                                      drawingData: _drawingOS,
                                      onDrawingSaved: (data) => setState(() => _drawingOS = data),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        } else {
                          return Column(
                            children: [
                              Column(
                                children: [
                                  const Text('RIGHT EYE (OD)', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                                  const SizedBox(height: 8),
                                  EyeDrawingCanvas(
                                    eye: EyeType.OD,
                                    onEyeChanged: (_) {},
                                    diagramType: _diagramType,
                                    drawingData: _drawingOD,
                                    onDrawingSaved: (data) => setState(() => _drawingOD = data),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Column(
                                children: [
                                  const Text('LEFT EYE (OS)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                                  const SizedBox(height: 8),
                                  EyeDrawingCanvas(
                                    eye: EyeType.OS,
                                    onEyeChanged: (_) {},
                                    diagramType: _diagramType,
                                    drawingData: _drawingOS,
                                    onDrawingSaved: (data) => setState(() => _drawingOS = data),
                                  ),
                                ],
                              ),
                            ],
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // SECTION 7: Assessment & Plan (Diagnosis & Treatment)
            Card(
              color: AppTheme.cardBg,
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppTheme.borderColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('CLINICAL ASSESSMENT & MANAGEMENT PLAN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryBlue)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _assessmentController,
                      maxLines: 2,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD97706), fontSize: 14),
                      decoration: const InputDecoration(
                        labelText: 'Assessment / Impression (e.g. Mature Cataract OS)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _planController,
                      maxLines: 3,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Plan / Treatment (e.g. Dilate OU. For Phacoemulsification - PHIC Only)',
                        border: OutlineInputBorder(),
                      ),
                    ),
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
