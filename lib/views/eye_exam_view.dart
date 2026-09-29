import 'package:flutter/material.dart';
import '../models/patient.dart';
import '../models/eye_exam.dart';
import '../models/encounter.dart';
import '../models/drawing_stroke.dart';
import '../widgets/drawing/paper_sheet_canvas.dart';
import '../widgets/pdf_exam_preview_dialog.dart';
import '../theme/app_theme.dart';
import 'prescription_view.dart';
import '../services/drawing_codec.dart';

class EyeExamView extends StatefulWidget {
  final Patient? patient;
  final Function(Patient)? onExamComplete;

  const EyeExamView({super.key, this.patient, this.onExamComplete});

  @override
  State<EyeExamView> createState() => _EyeExamViewState();
}

class _EyeExamViewState extends State<EyeExamView> {
  late Patient _activePatient;

  // Digital Ink Strokes over the Paper Sheet
  List<VectorStroke> _paperStrokes = [];

  // Header Demographics Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _middleNameController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _ageSexController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _occupationController = TextEditingController();
  final TextEditingController _phicController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();

  // Table 1: Visual Acuity & Refraction (OD - Right Eye)
  final TextEditingController _vaODController = TextEditingController();
  final TextEditingController _phODController = TextEditingController();
  final TextEditingController _ccODController = TextEditingController();
  final TextEditingController _oldCcODController = TextEditingController();
  final TextEditingController _arODController = TextEditingController();
  final TextEditingController _akODController = TextEditingController();

  // Table 1: Visual Acuity & Refraction (OS - Left Eye)
  final TextEditingController _vaOSController = TextEditingController();
  final TextEditingController _phOSController = TextEditingController();
  final TextEditingController _ccOSController = TextEditingController();
  final TextEditingController _oldCcOSController = TextEditingController();
  final TextEditingController _arOSController = TextEditingController();
  final TextEditingController _akOSController = TextEditingController();

  // Table 2: Clinical Examination Measurements (OD - Right Eye)
  final TextEditingController _colorODController = TextEditingController();
  final TextEditingController _iopODController = TextEditingController();
  String _anglesOD = 'Open';
  final TextEditingController _cdrODController = TextEditingController();
  String _confrontationOD = 'WNL';
  String _vanHerickOD = 'G4 Wide';

  // Table 2: Clinical Examination Measurements (OS - Left Eye)
  final TextEditingController _colorOSController = TextEditingController();
  final TextEditingController _iopOSController = TextEditingController();
  String _anglesOS = 'Open';
  final TextEditingController _cdrOSController = TextEditingController();
  String _confrontationOS = 'WNL';
  String _vanHerickOS = 'G4 Wide';

  // Systemic Medical History Checkboxes
  final Map<String, bool> _systemicHistory = {
    'Cardiac Problem': false,
    'DM': false,
    'HPN': false,
    'Kidney Problem': false,
    'Cholesterol det': false,
    'Allergy Hx': false,
    'Asthma Hx': false,
    'Thyroid Problem': false,
  };

  // Clinical Notes
  final TextEditingController _chiefComplaintController = TextEditingController();
  final TextEditingController _assessmentController = TextEditingController();
  final TextEditingController _planController = TextEditingController();



  @override
  void initState() {
    super.initState();
    if (widget.patient != null) {
      _activePatient = widget.patient!;
      _populateFromPatient(_activePatient);
    } else {
      _activePatient = Patient(
        id: 'pat-${DateTime.now().millisecondsSinceEpoch}',
        mrn: 'MRN-${DateTime.now().year}-${(DateTime.now().millisecondsSinceEpoch % 10000).toString().padLeft(4, "0")}',
        fullName: '',
        middleName: '',
        dateOfBirth: '',
        gender: '',
        phone: '',
        address: '',
        occupation: '',
        phicNumber: '',
        referringDoctor: '',
        medicalHistory: [],
        allergies: [],
        previousDiagnoses: [],
        previousPrescriptions: [],
        prescriptions: [],
        encounters: [],
        lastVisitDate: '',
        totalVisits: 0,
      );
      _clearAllFieldsForNewPatient();
    }
  }

  void _clearAllFieldsForNewPatient() {
    _nameController.text = '';
    _middleNameController.text = '';
    _dateController.text = formatClinicalDate(DateTime.now().toString().substring(0, 10)); // The ONLY auto-fill!
    _ageSexController.text = '';
    _addressController.text = '';
    _contactController.text = '';
    _occupationController.text = '';
    _phicController.text = '';
    _birthDateController.text = '';

    // Clean examination - all clinical fields start completely blank!
    _paperStrokes = [];

    _vaODController.text = '';
    _phODController.text = '';
    _ccODController.text = '';
    _oldCcODController.text = '';
    _arODController.text = '';
    _akODController.text = '';

    _vaOSController.text = '';
    _phOSController.text = '';
    _ccOSController.text = '';
    _oldCcOSController.text = '';
    _arOSController.text = '';
    _akOSController.text = '';

    _colorODController.text = '';
    _iopODController.text = '';
    _anglesOD = 'Open';
    _cdrODController.text = '';
    _confrontationOD = 'WNL';
    _vanHerickOD = 'G4 Wide';

    _colorOSController.text = '';
    _iopOSController.text = '';
    _anglesOS = 'Open';
    _cdrOSController.text = '';
    _confrontationOS = 'WNL';
    _vanHerickOS = 'G4 Wide';

    _chiefComplaintController.text = '';
    _assessmentController.text = '';
    _planController.text = '';

    for (final k in _systemicHistory.keys) {
      _systemicHistory[k] = false;
    }
  }



  void _populateFromPatient(Patient p) {
    _activePatient = p;
    _nameController.text = p.fullName;
    _middleNameController.text = p.middleName;
    _dateController.text = formatClinicalDate(DateTime.now().toString().substring(0, 10)); // Today's date
    _ageSexController.text = p.age > 0 ? '${p.age} / ${p.gender.isNotEmpty ? p.gender[0].toUpperCase() : ""}' : '';
    _addressController.text = p.address;
    _contactController.text = p.phone;
    _occupationController.text = p.occupation;
    _phicController.text = p.phicNumber;
    _birthDateController.text = p.dateOfBirth.isNotEmpty ? formatClinicalDate(p.dateOfBirth) : '';

    // Clean examination - all clinical fields start completely blank!
    _paperStrokes = [];

    _vaODController.text = '';
    _phODController.text = '';
    _ccODController.text = '';
    _oldCcODController.text = '';
    _arODController.text = '';
    _akODController.text = '';

    _vaOSController.text = '';
    _phOSController.text = '';
    _ccOSController.text = '';
    _oldCcOSController.text = '';
    _arOSController.text = '';
    _akOSController.text = '';

    _colorODController.text = '';
    _iopODController.text = '';
    _anglesOD = 'Open';
    _cdrODController.text = '';
    _confrontationOD = 'WNL';
    _vanHerickOD = 'G4 Wide';

    _colorOSController.text = '';
    _iopOSController.text = '';
    _anglesOS = 'Open';
    _cdrOSController.text = '';
    _confrontationOS = 'WNL';
    _vanHerickOS = 'G4 Wide';

    _chiefComplaintController.text = '';
    _assessmentController.text = '';
    _planController.text = '';

    for (final k in _systemicHistory.keys) {
      _systemicHistory[k] = false;
    }
  }

  void _saveConsultationRecord() {
    final examOD = EyeExamData(
      acuity: VisualAcuity(
        uncorrected: _vaODController.text.isNotEmpty ? _vaODController.text : 'HM',
        pinhole: _phODController.text.isNotEmpty ? _phODController.text : 'HM',
        bestCorrected: _ccODController.text,
        oldCc: _oldCcODController.text,
        ar: _arODController.text,
        ak: _akODController.text,
      ),
      refraction: Refraction(),
      color: _colorODController.text,
      iop: _iopODController.text,
      anglesGonioscopy: _anglesOD,
      cdrOn: _cdrODController.text,
      confrontationPeripheral: _confrontationOD,
      vanHerick: _vanHerickOD,
      slitLampNotes: 'Anterior segment drawn/logged on consultation sheet.',
      fundoscopyNotes: 'Posterior segment drawn/logged on consultation sheet.',
    );

    final examOS = EyeExamData(
      acuity: VisualAcuity(
        uncorrected: _vaOSController.text.isNotEmpty ? _vaOSController.text : 'HM',
        pinhole: _phOSController.text.isNotEmpty ? _phOSController.text : 'HM',
        bestCorrected: _ccOSController.text,
        oldCc: _oldCcOSController.text,
        ar: _arOSController.text,
        ak: _akOSController.text,
      ),
      refraction: Refraction(),
      color: _colorOSController.text,
      iop: _iopOSController.text,
      anglesGonioscopy: _anglesOS,
      cdrOn: _cdrOSController.text,
      confrontationPeripheral: _confrontationOS,
      vanHerick: _vanHerickOS,
      slitLampNotes: 'Anterior segment drawn/logged on consultation sheet.',
      fundoscopyNotes: 'Posterior segment drawn/logged on consultation sheet.',
    );

    final drawingData = PaperSheetDrawingData(
      id: 'drw-active',
      encounterId: 'enc-active',
      patientId: _activePatient.id,
      strokes: _paperStrokes,
      updatedAt: DateTime.now().toIso8601String(),
    );

    final tempEncounter = Encounter(
      id: 'enc-${DateTime.now().millisecondsSinceEpoch}',
      patientId: _activePatient.id,
      date: _dateController.text.isNotEmpty ? _dateController.text : formatClinicalDate(DateTime.now().toString().substring(0, 10)),
      doctorName: 'Dr. Sigrid Robillos, MD',
      chiefComplaint: _chiefComplaintController.text,
      examOD: examOD,
      examOS: examOS,
      paperSheetDrawing: drawingData,
      diagnosis: _assessmentController.text,
      treatmentPlan: _planController.text,
    );

    final medHist = <String>[];
    _systemicHistory.forEach((k, v) {
      if (v) medHist.add(k);
    });

    try {
      PatientRepository.addEncounter(_activePatient.id, tempEncounter);
    } on FormatException catch (e) {
      _showSaveError(e.message);
      return;
    } on DrawingTooLargeException catch (e) {
      _showSaveError(e.toString());
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text('Consultation encounter saved successfully for ${_activePatient.fullName}!'),
          ],
        ),
        backgroundColor: const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );

    if (widget.onExamComplete != null) {
      final updated = PatientRepository.getPatientById(_activePatient.id) ?? _activePatient;
      widget.onExamComplete!(updated);
    }
  }

  void _showSaveError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Not saved: $message'),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 7),
      ),
    );
  }

  void _showPdfPreview() {
    final examOD = EyeExamData(
      acuity: VisualAcuity(
        uncorrected: _vaODController.text.isNotEmpty ? _vaODController.text : 'HM',
        pinhole: _phODController.text.isNotEmpty ? _phODController.text : 'HM',
        bestCorrected: _ccODController.text,
        oldCc: _oldCcODController.text,
        ar: _arODController.text.isNotEmpty ? _arODController.text : 'NO TARGET',
        ak: _akODController.text.isNotEmpty ? _akODController.text : 'NO TARGET',
      ),
      refraction: Refraction(),
      color: _colorODController.text.isNotEmpty ? _colorODController.text : 'B / G',
      iop: _iopODController.text.isNotEmpty ? _iopODController.text : '16',
      anglesGonioscopy: _anglesOD,
      cdrOn: _cdrODController.text.isNotEmpty ? _cdrODController.text : '0.4',
      confrontationPeripheral: _confrontationOD,
      vanHerick: _vanHerickOD,
    );

    final examOS = EyeExamData(
      acuity: VisualAcuity(
        uncorrected: _vaOSController.text.isNotEmpty ? _vaOSController.text : 'HM',
        pinhole: _phOSController.text.isNotEmpty ? _phOSController.text : 'HM',
        bestCorrected: _ccOSController.text,
        oldCc: _oldCcOSController.text,
        ar: _arOSController.text.isNotEmpty ? _arOSController.text : 'NO TARGET',
        ak: _akOSController.text.isNotEmpty ? _akOSController.text : 'NO TARGET',
      ),
      refraction: Refraction(),
      color: _colorOSController.text.isNotEmpty ? _colorOSController.text : 'B / G',
      iop: _iopOSController.text.isNotEmpty ? _iopOSController.text : '18',
      anglesGonioscopy: _anglesOS,
      cdrOn: _cdrOSController.text.isNotEmpty ? _cdrOSController.text : '0.5',
      confrontationPeripheral: _confrontationOS,
      vanHerick: _vanHerickOS,
    );

    final drawingData = PaperSheetDrawingData(
      id: 'drw-active',
      encounterId: 'enc-active',
      patientId: _activePatient.id,
      strokes: _paperStrokes,
      updatedAt: DateTime.now().toIso8601String(),
    );

    final tempEncounter = Encounter(
      id: 'enc-${DateTime.now().millisecondsSinceEpoch}',
      patientId: _activePatient.id,
      date: _dateController.text.isNotEmpty ? _dateController.text : formatClinicalDate(DateTime.now().toString().substring(0, 10)),
      doctorName: 'Dr. Sigrid Robillos, MD',
      chiefComplaint: _chiefComplaintController.text.isNotEmpty ? _chiefComplaintController.text : 'OS BOV x 1 year\nCame in w/ silingan\nNo family',
      examOD: examOD,
      examOS: examOS,
      paperSheetDrawing: drawingData,
      diagnosis: _assessmentController.text.isNotEmpty ? _assessmentController.text : 'Mature Cataract OS, Glaucoma Suspect OU',
      treatmentPlan: _planController.text.isNotEmpty ? _planController.text : 'Dilate OU\nTo BSC - PHIC only',
    );

    showClinicalExamPdfPreviewModal(
      context: context,
      patient: _activePatient,
      encounter: tempEncounter,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE2E8F0),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.draw, color: AppTheme.primaryBlue, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _activePatient.fullName.isNotEmpty
                    ? '${_activePatient.fullName} • Clinical Consultation Record'
                    : 'New Patient Consultation Record',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          // Prescription Writer
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PrescriptionView(initialPatient: _activePatient),
                ),
              );
            },
            icon: const Icon(Icons.medication, size: 16, color: AppTheme.primaryBlue),
            label: const Text('Prescription', style: TextStyle(fontSize: 12, color: AppTheme.primaryBlue)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.primaryBlue),
            ),
          ),
          const SizedBox(width: 8),

          // Print PDF
          IconButton(
            onPressed: _showPdfPreview,
            icon: const Icon(Icons.print, color: AppTheme.primaryBlue),
            tooltip: 'Print / Export Clinical PDF',
          ),
          const SizedBox(width: 4),

          // Save Record
          ElevatedButton.icon(
            onPressed: _saveConsultationRecord,
            icon: const Icon(Icons.save, size: 16),
            label: const Text('Save Record', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: PaperSheetCanvas(
        initialStrokes: _paperStrokes,
        patientName: _nameController.text,
        middleName: _middleNameController.text,
        date: _dateController.text,
        ageSex: _ageSexController.text,
        address: _addressController.text,
        contactNumber: _contactController.text,
        occupation: _occupationController.text,
        phicNumber: _phicController.text,
        birthDate: _birthDateController.text,
        onStrokesChanged: (updatedStrokes) {
          _paperStrokes = updatedStrokes;
        },
        onSave: _saveConsultationRecord,
        onPrint: _showPdfPreview,
      ),
    );
  }
}
