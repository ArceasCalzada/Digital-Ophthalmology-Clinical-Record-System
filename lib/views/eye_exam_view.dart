import 'package:flutter/material.dart';
import '../models/patient.dart';
import '../models/eye_exam.dart';
import '../models/encounter.dart';
import '../models/drawing_stroke.dart';
import '../widgets/drawing/paper_sheet_canvas.dart';
import '../widgets/pdf_exam_preview_dialog.dart';
import '../theme/app_theme.dart';
import '../widgets/page_header.dart';
import '../widgets/success_modal.dart';
import 'prescription_view.dart';
import '../services/drawing_codec.dart';
import '../services/profile_store.dart';

class EyeExamView extends StatefulWidget {
  final Patient? patient;
  final Encounter? encounter;
  final Function(Patient)? onExamComplete;

  const EyeExamView({super.key, this.patient, this.encounter, this.onExamComplete});

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
    if (widget.encounter != null) {
      final p = widget.patient ?? PatientRepository.getPatientById(widget.encounter!.patientId);
      if (p != null) {
        _activePatient = p;
      } else {
        _initEmptyPatient();
      }
      _populateFromEncounter(widget.encounter!);
    } else if (widget.patient != null) {
      _activePatient = widget.patient!;
      if (_activePatient.encounters.isNotEmpty) {
        _populateFromEncounter(_activePatient.encounters.first);
      } else {
        _populateFromPatient(_activePatient);
      }
    } else {
      _initEmptyPatient();
      _clearAllFieldsForNewPatient();
    }
  }

  void _initEmptyPatient() {
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
  }

  void _populateFromEncounter(Encounter enc) {
    _nameController.text = _activePatient.fullName;
    _middleNameController.text = _activePatient.middleName;
    _dateController.text = enc.date.isNotEmpty ? formatClinicalDate(enc.date) : formatClinicalDate(DateTime.now().toString().substring(0, 10));
    _ageSexController.text = _activePatient.age > 0 ? '${_activePatient.age} / ${_activePatient.gender.isNotEmpty ? _activePatient.gender[0].toUpperCase() : ""}' : '';
    _addressController.text = _activePatient.address;
    _contactController.text = _activePatient.phone;
    _occupationController.text = _activePatient.occupation;
    _phicController.text = _activePatient.phicNumber;
    _birthDateController.text = _activePatient.dateOfBirth.isNotEmpty ? formatClinicalDate(_activePatient.dateOfBirth) : '';

    // Table 1 OD
    _vaODController.text = enc.examOD.acuity.uncorrected;
    _phODController.text = enc.examOD.acuity.pinhole;
    _ccODController.text = enc.examOD.acuity.bestCorrected;
    _oldCcODController.text = enc.examOD.acuity.oldCc;
    _arODController.text = enc.examOD.acuity.ar;
    _akODController.text = enc.examOD.acuity.ak;

    // Table 1 OS
    _vaOSController.text = enc.examOS.acuity.uncorrected;
    _phOSController.text = enc.examOS.acuity.pinhole;
    _ccOSController.text = enc.examOS.acuity.bestCorrected;
    _oldCcOSController.text = enc.examOS.acuity.oldCc;
    _arOSController.text = enc.examOS.acuity.ar;
    _akOSController.text = enc.examOS.acuity.ak;

    // Table 2 OD
    _colorODController.text = enc.examOD.color;
    _iopODController.text = enc.examOD.iop;
    _anglesOD = enc.examOD.anglesGonioscopy.isNotEmpty ? enc.examOD.anglesGonioscopy : 'Open';
    _cdrODController.text = enc.examOD.cdrOn;
    _confrontationOD = enc.examOD.confrontationPeripheral.isNotEmpty ? enc.examOD.confrontationPeripheral : 'WNL';
    _vanHerickOD = enc.examOD.vanHerick.isNotEmpty ? enc.examOD.vanHerick : 'G4 Wide';

    // Table 2 OS
    _colorOSController.text = enc.examOS.color;
    _iopOSController.text = enc.examOS.iop;
    _anglesOS = enc.examOS.anglesGonioscopy.isNotEmpty ? enc.examOS.anglesGonioscopy : 'Open';
    _cdrOSController.text = enc.examOS.cdrOn;
    _confrontationOS = enc.examOS.confrontationPeripheral.isNotEmpty ? enc.examOS.confrontationPeripheral : 'WNL';
    _vanHerickOS = enc.examOS.vanHerick.isNotEmpty ? enc.examOS.vanHerick : 'G4 Wide';

    // Notes & Diagnoses
    _chiefComplaintController.text = enc.chiefComplaint;
    _assessmentController.text = enc.diagnosis;
    _planController.text = enc.treatmentPlan;

    // Medical History
    for (final k in _systemicHistory.keys) {
      _systemicHistory[k] = _activePatient.medicalHistory.contains(k);
    }

    // Digital Vector Strokes
    if (enc.paperSheetDrawing != null && enc.paperSheetDrawing!.strokes.isNotEmpty) {
      _paperStrokes = List.from(enc.paperSheetDrawing!.strokes);
    } else {
      _paperStrokes = [];
    }
  }

  void _clearAllFieldsForNewPatient() {
    _nameController.text = '';
    _middleNameController.text = '';
    _dateController.text = formatClinicalDate(DateTime.now().toString().substring(0, 10));
    _ageSexController.text = '';
    _addressController.text = '';
    _contactController.text = '';
    _occupationController.text = '';
    _phicController.text = '';
    _birthDateController.text = '';

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
    if (p.encounters.isNotEmpty) {
      _populateFromEncounter(p.encounters.first);
      return;
    }

    _nameController.text = p.fullName;
    _middleNameController.text = p.middleName;
    _dateController.text = formatClinicalDate(DateTime.now().toString().substring(0, 10));
    _ageSexController.text = p.age > 0 ? '${p.age} / ${p.gender.isNotEmpty ? p.gender[0].toUpperCase() : ""}' : '';
    _addressController.text = p.address;
    _contactController.text = p.phone;
    _occupationController.text = p.occupation;
    _phicController.text = p.phicNumber;
    _birthDateController.text = p.dateOfBirth.isNotEmpty ? formatClinicalDate(p.dateOfBirth) : '';

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
      _systemicHistory[k] = p.medicalHistory.contains(k);
    }
  }

  bool _isSaving = false;

  void _saveConsultationRecord() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

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
      id: widget.encounter?.id ?? 'enc-${DateTime.now().millisecondsSinceEpoch}',
      patientId: _activePatient.id,
      date: _dateController.text.isNotEmpty ? _dateController.text : formatClinicalDate(DateTime.now().toString().substring(0, 10)),
      doctorName: ProfileStore.instance.doctorName.text.isNotEmpty ? ProfileStore.instance.doctorName.text : 'Attending Physician',
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
      if (mounted) setState(() => _isSaving = false);
      _showSaveError(e.message);
      return;
    } on DrawingTooLargeException catch (e) {
      if (mounted) setState(() => _isSaving = false);
      _showSaveError(e.toString());
      return;
    } catch (e) {
      if (mounted) setState(() => _isSaving = false);
      _showSaveError(e.toString());
      return;
    }

    if (!mounted) return;

    await showActionSuccessModal(
      context: context,
      title: 'Consultation Saved Successfully',
      message: 'The consultation encounter for ${_activePatient.fullName} has been saved successfully.',
      buttonText: 'Done',
    );

    if (mounted) {
      setState(() => _isSaving = false);
    }

    if (widget.onExamComplete != null) {
      final updated = PatientRepository.getPatientById(_activePatient.id) ?? _activePatient;
      widget.onExamComplete!(updated);
    }
  }

  void _showSaveError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Not saved: $message'),
        backgroundColor: Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 7),
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
      doctorName: ProfileStore.instance.doctorName.text.isNotEmpty ? ProfileStore.instance.doctorName.text : 'Attending Physician',
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
      backgroundColor: Color(0xFFE2E8F0),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        toolbarHeight: 76,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: AppTheme.textPrimary),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _activePatient.fullName.isNotEmpty ? _activePatient.fullName : 'New Patient',
              style: PageHeader.titleStyle,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 4),
            Text(
              'Clinical Consultation Record',
              style: PageHeader.subtitleStyle,
              overflow: TextOverflow.ellipsis,
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
            icon: Icon(Icons.medication, size: 16, color: AppTheme.primaryBlue),
            label: Text('Prescription', style: TextStyle(fontSize: 12, color: AppTheme.primaryBlue)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppTheme.primaryBlue),
            ),
          ),
          SizedBox(width: 8),

          // Print PDF
          IconButton(
            onPressed: _showPdfPreview,
            icon: Icon(Icons.print, color: AppTheme.primaryBlue),
            tooltip: 'Print / Export Clinical PDF',
          ),
          SizedBox(width: 4),

          // Save Record
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveConsultationRecord,
            icon: _isSaving
                ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(Icons.save, size: 16),
            label: Text(_isSaving ? 'Saving...' : 'Save Record', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          SizedBox(width: 16),
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
        onSave: _isSaving ? null : _saveConsultationRecord,
        onPrint: _showPdfPreview,
      ),
    );
  }
}
