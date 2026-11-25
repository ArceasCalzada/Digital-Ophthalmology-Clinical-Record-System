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
import '../widgets/sync_status_indicator.dart';
import 'prescription_view.dart';
import '../services/drawing_codec.dart';
import '../services/examination_preferences_store.dart';
import '../services/profile_store.dart';
import '../services/draft_manager_service.dart';

class EyeExamView extends StatefulWidget {
  final Patient? patient;
  final Encounter? encounter;
  final Function(Patient)? onExamComplete;
  final Function(Patient)? onOpenPrescription;
  final String? initialLayout;
  final String? initialTemplate;

  const EyeExamView({
    super.key,
    this.patient,
    this.encounter,
    this.onExamComplete,
    this.onOpenPrescription,
    this.initialLayout,
    this.initialTemplate,
  });

  @override
  State<EyeExamView> createState() => _EyeExamViewState();
}

class _EyeExamViewState extends State<EyeExamView> {
  late Patient _activePatient;
  late String _currentLayout;
  late String _drawingTemplate;

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
    _currentLayout = widget.initialLayout ?? ExaminationPreferencesStore.instance.defaultExamLayout;
    _drawingTemplate = widget.initialTemplate ?? ExaminationPreferencesStore.instance.defaultDrawingTemplate;

    if (widget.encounter != null) {
      final p = widget.patient ?? PatientRepository.getPatientById(widget.encounter!.patientId);
      if (p != null) {
        _activePatient = p;
      } else {
        _initEmptyPatient();
      }
      _populateFromEncounter(widget.encounter!);
    } else if (widget.patient != null) {
      _populateFromPatient(widget.patient!);
    } else {
      _initEmptyPatient();
      _clearAllFieldsForNewPatient();
    }
    _checkAndRestoreDraft();
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

  Patient get _currentPatientContext {
    final enteredName = _nameController.text.trim();
    if (enteredName.isNotEmpty && _activePatient.fullName != enteredName) {
      return _activePatient.copyWith(
        fullName: enteredName,
        middleName: _middleNameController.text.trim(),
      );
    }
    return _activePatient;
  }

  void _checkAndRestoreDraft() {
    final draft = DraftManagerService().getValidDraft('eye_exam');
    if (draft == null) return;

    if (draft.patientId == _activePatient.id || (widget.patient == null && widget.encounter == null)) {
      _restoreDraft(draft.payload);
    }
  }

  void _restoreDraft(Map<String, dynamic> payload) {
    if (payload['strokes'] is List) {
      try {
        final strokeList = (payload['strokes'] as List)
            .map((item) => VectorStroke.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
        _paperStrokes = strokeList;
      } catch (e) {
        debugPrint('Error restoring paper strokes from draft: $e');
      }
    }
    if (payload['name'] != null && (payload['name'] as String).isNotEmpty) {
      _nameController.text = payload['name'];
      _activePatient = _activePatient.copyWith(fullName: payload['name']);
    }
    if (payload['middleName'] != null) _middleNameController.text = payload['middleName'];
    if (payload['date'] != null && (payload['date'] as String).isNotEmpty) _dateController.text = payload['date'];
    if (payload['ageSex'] != null) _ageSexController.text = payload['ageSex'];
    if (payload['address'] != null) _addressController.text = payload['address'];
    if (payload['contact'] != null) _contactController.text = payload['contact'];
    if (payload['occupation'] != null) _occupationController.text = payload['occupation'];
    if (payload['phic'] != null) _phicController.text = payload['phic'];
    if (payload['birthDate'] != null) _birthDateController.text = payload['birthDate'];

    if (payload['vaOD'] != null) _vaODController.text = payload['vaOD'];
    if (payload['phOD'] != null) _phODController.text = payload['phOD'];
    if (payload['ccOD'] != null) _ccODController.text = payload['ccOD'];
    if (payload['oldCcOD'] != null) _oldCcODController.text = payload['oldCcOD'];
    if (payload['arOD'] != null) _arODController.text = payload['arOD'];
    if (payload['akOD'] != null) _akODController.text = payload['akOD'];

    if (payload['vaOS'] != null) _vaOSController.text = payload['vaOS'];
    if (payload['phOS'] != null) _phOSController.text = payload['phOS'];
    if (payload['ccOS'] != null) _ccOSController.text = payload['ccOS'];
    if (payload['oldCcOS'] != null) _oldCcOSController.text = payload['oldCcOS'];
    if (payload['arOS'] != null) _arOSController.text = payload['arOS'];
    if (payload['akOS'] != null) _akOSController.text = payload['akOS'];

    if (payload['colorOD'] != null) _colorODController.text = payload['colorOD'];
    if (payload['iopOD'] != null) _iopODController.text = payload['iopOD'];
    if (payload['anglesOD'] != null) _anglesOD = payload['anglesOD'];
    if (payload['cdrOD'] != null) _cdrODController.text = payload['cdrOD'];
    if (payload['confrontationOD'] != null) _confrontationOD = payload['confrontationOD'];
    if (payload['vanHerickOD'] != null) _vanHerickOD = payload['vanHerickOD'];

    if (payload['colorOS'] != null) _colorOSController.text = payload['colorOS'];
    if (payload['iopOS'] != null) _iopOSController.text = payload['iopOS'];
    if (payload['anglesOS'] != null) _anglesOS = payload['anglesOS'];
    if (payload['cdrOS'] != null) _cdrOSController.text = payload['cdrOS'];
    if (payload['confrontationOS'] != null) _confrontationOS = payload['confrontationOS'];
    if (payload['vanHerickOS'] != null) _vanHerickOS = payload['vanHerickOS'];

    if (payload['chiefComplaint'] != null) _chiefComplaintController.text = payload['chiefComplaint'];
    if (payload['assessment'] != null) _assessmentController.text = payload['assessment'];
    if (payload['plan'] != null) _planController.text = payload['plan'];

    if (payload['systemicHistory'] is Map) {
      final map = payload['systemicHistory'] as Map;
      map.forEach((k, v) {
        if (v is bool && _systemicHistory.containsKey(k)) {
          _systemicHistory[k.toString()] = v;
        }
      });
    }
  }

  void _saveLocalDraft() {
    final patientContext = _currentPatientContext;
    final strokeJsonList = _paperStrokes.map((s) => s.toJson()).toList();
    final payload = <String, dynamic>{
      'patientId': patientContext.id,
      'patientName': patientContext.fullName.isNotEmpty ? patientContext.fullName : 'Active Patient',
      'strokes': strokeJsonList,
      'name': _nameController.text,
      'middleName': _middleNameController.text,
      'date': _dateController.text,
      'ageSex': _ageSexController.text,
      'address': _addressController.text,
      'contact': _contactController.text,
      'occupation': _occupationController.text,
      'phic': _phicController.text,
      'birthDate': _birthDateController.text,
      'vaOD': _vaODController.text,
      'phOD': _phODController.text,
      'ccOD': _ccODController.text,
      'oldCcOD': _oldCcODController.text,
      'arOD': _arODController.text,
      'akOD': _akODController.text,
      'vaOS': _vaOSController.text,
      'phOS': _phOSController.text,
      'ccOS': _ccOSController.text,
      'oldCcOS': _oldCcOSController.text,
      'arOS': _arOSController.text,
      'akOS': _akOSController.text,
      'colorOD': _colorODController.text,
      'iopOD': _iopODController.text,
      'anglesOD': _anglesOD,
      'cdrOD': _cdrODController.text,
      'confrontationOD': _confrontationOD,
      'vanHerickOD': _vanHerickOD,
      'colorOS': _colorOSController.text,
      'iopOS': _iopOSController.text,
      'anglesOS': _anglesOS,
      'cdrOS': _cdrOSController.text,
      'confrontationOS': _confrontationOS,
      'vanHerickOS': _vanHerickOS,
      'chiefComplaint': _chiefComplaintController.text,
      'assessment': _assessmentController.text,
      'plan': _planController.text,
      'systemicHistory': Map<String, bool>.from(_systemicHistory),
    };

    DraftManagerService().saveDraft(
      contextKey: 'eye_exam',
      patientId: patientContext.id,
      payload: payload,
    );
  }

  void _openPrescriptionsWorkspace() {
    _saveLocalDraft();
    final patient = _currentPatientContext;
    if (widget.onOpenPrescription != null) {
      widget.onOpenPrescription!(patient);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PrescriptionView(initialPatient: patient),
        ),
      );
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

    DraftManagerService().discardDraft('eye_exam');

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
      backgroundColor: AppTheme.lightBg,
      appBar: AppBar(
        backgroundColor: AppTheme.cardBg,
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
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Center(child: SyncStatusIndicator(compact: true)),
          ),
          // Drawing Template Indicator
          Container(
            key: const Key('exam_template_indicator'),
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.remove_red_eye_outlined, size: 14, color: AppTheme.primaryBlue),
                const SizedBox(width: 4),
                Text(
                  _drawingTemplate,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                ),
              ],
            ),
          ),

          // Examination Layout Indicator & Switcher
          PopupMenuButton<String>(
            key: const Key('exam_layout_indicator'),
            tooltip: 'Change Examination Layout',
            initialValue: _currentLayout,
            onSelected: (layout) => setState(() => _currentLayout = layout),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: ExaminationPreferencesStore.layoutStandard2Column,
                child: Text('Standard 2-Column'),
              ),
              const PopupMenuItem(
                value: ExaminationPreferencesStore.layoutExpandedSingleCanvas,
                child: Text('Expanded Single Canvas'),
              ),
              const PopupMenuItem(
                value: ExaminationPreferencesStore.layoutClinicalTabbed,
                child: Text('Clinical Tabbed'),
              ),
            ],
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.lightBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.view_quilt_outlined, size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    _currentLayout,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_drop_down, size: 16, color: AppTheme.textSecondary),
                ],
              ),
            ),
          ),

          // Prescription Writer
          OutlinedButton.icon(
            key: const Key('btn_add_prescription'),
            onPressed: _openPrescriptionsWorkspace,
            icon: Icon(Icons.medication, size: 16, color: AppTheme.primaryBlue),
            label: Text('+ Prescription', style: TextStyle(fontSize: 12, color: AppTheme.primaryBlue)),
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
      body: _buildLayoutBody(),
    );
  }

  Widget _buildPaperCanvas() {
    return PaperSheetCanvas(
      key: const Key('eye_exam_paper_canvas'),
      initialStrokes: _paperStrokes,
      drawingTemplate: _drawingTemplate,
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
    );
  }

  Widget _buildLayoutBody() {
    switch (_currentLayout) {
      case ExaminationPreferencesStore.layoutExpandedSingleCanvas:
        return Container(
          key: const Key('exam_layout_expanded_single_canvas'),
          child: _buildPaperCanvas(),
        );

      case ExaminationPreferencesStore.layoutClinicalTabbed:
        return Container(
          key: const Key('exam_layout_clinical_tabbed'),
          child: DefaultTabController(
            length: 3,
            child: Column(
              children: [
                Container(
                  color: AppTheme.cardBg,
                  child: TabBar(
                    labelColor: AppTheme.primaryBlue,
                    unselectedLabelColor: AppTheme.textSecondary,
                    indicatorColor: AppTheme.primaryBlue,
                    tabs: const [
                      Tab(
                        key: Key('tab_exam_paper_chart'),
                        icon: Icon(Icons.draw_outlined, size: 16),
                        text: 'Paper Chart & Drawing',
                      ),
                      Tab(
                        key: Key('tab_exam_acuity_refraction'),
                        icon: Icon(Icons.remove_red_eye_outlined, size: 16),
                        text: 'Visual Acuity & Refraction',
                      ),
                      Tab(
                        key: Key('tab_exam_findings'),
                        icon: Icon(Icons.assignment_outlined, size: 16),
                        text: 'Diagnostics & Assessment',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildPaperCanvas(),
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: _buildVisualAcuitySection(),
                      ),
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTonometrySection(),
                            const SizedBox(height: 20),
                            _buildNotesSection(),
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

      case ExaminationPreferencesStore.layoutStandard2Column:
      default:
        return Container(
          key: const Key('exam_layout_standard_2_column'),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 950) {
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      SizedBox(
                        height: 750,
                        child: _buildPaperCanvas(),
                      ),
                      _buildClinicalFindingsPanel(),
                    ],
                  ),
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 6,
                    child: _buildPaperCanvas(),
                  ),
                  Container(
                    width: 1,
                    color: AppTheme.borderColor,
                  ),
                  Expanded(
                    flex: 4,
                    child: _buildClinicalFindingsPanel(),
                  ),
                ],
              );
            },
          ),
        );
    }
  }

  Widget _buildClinicalFindingsPanel() {
    return Container(
      key: const Key('exam_clinical_findings_panel'),
      color: AppTheme.cardBg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assignment_turned_in_outlined, color: AppTheme.primaryBlue, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Clinical Examination Findings',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildVisualAcuitySection(),
            const SizedBox(height: 20),
            _buildTonometrySection(),
            const SizedBox(height: 20),
            _buildNotesSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildVisualAcuitySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.lightBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Visual Acuity & Refraction',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _vaODController,
                  decoration: const InputDecoration(
                    labelText: 'VA (OD - Right Eye)',
                    hintText: 'e.g. 20/20',
                    isDense: true,
                  ),
                  onChanged: (_) => _saveLocalDraft(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _vaOSController,
                  decoration: const InputDecoration(
                    labelText: 'VA (OS - Left Eye)',
                    hintText: 'e.g. 20/25',
                    isDense: true,
                  ),
                  onChanged: (_) => _saveLocalDraft(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _phODController,
                  decoration: const InputDecoration(
                    labelText: 'Pinhole OD',
                    isDense: true,
                  ),
                  onChanged: (_) => _saveLocalDraft(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _phOSController,
                  decoration: const InputDecoration(
                    labelText: 'Pinhole OS',
                    isDense: true,
                  ),
                  onChanged: (_) => _saveLocalDraft(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTonometrySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.lightBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tonometry & Biomicroscopy',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _iopODController,
                  decoration: const InputDecoration(
                    labelText: 'IOP (OD) mmHg',
                    hintText: '16',
                    isDense: true,
                  ),
                  onChanged: (_) => _saveLocalDraft(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _iopOSController,
                  decoration: const InputDecoration(
                    labelText: 'IOP (OS) mmHg',
                    hintText: '15',
                    isDense: true,
                  ),
                  onChanged: (_) => _saveLocalDraft(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cdrODController,
                  decoration: const InputDecoration(
                    labelText: 'C/D Ratio (OD)',
                    hintText: '0.3',
                    isDense: true,
                  ),
                  onChanged: (_) => _saveLocalDraft(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _cdrOSController,
                  decoration: const InputDecoration(
                    labelText: 'C/D Ratio (OS)',
                    hintText: '0.3',
                    isDense: true,
                  ),
                  onChanged: (_) => _saveLocalDraft(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.lightBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Diagnosis & Plan',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _chiefComplaintController,
            decoration: const InputDecoration(
              labelText: 'Chief Complaint',
              hintText: 'Blurry vision, eye strain...',
              isDense: true,
            ),
            onChanged: (_) => _saveLocalDraft(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _assessmentController,
            decoration: const InputDecoration(
              labelText: 'Assessment / Diagnosis',
              hintText: 'Primary Open Angle Glaucoma...',
              isDense: true,
            ),
            onChanged: (_) => _saveLocalDraft(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _planController,
            decoration: const InputDecoration(
              labelText: 'Treatment Plan',
              hintText: 'Latanoprost 0.005% QHS, follow up in 2 weeks...',
              isDense: true,
            ),
            onChanged: (_) => _saveLocalDraft(),
          ),
        ],
      ),
    );
  }
}
