import 'package:flutter/material.dart';
import '../models/patient.dart';
import '../models/eye_exam.dart';
import '../models/encounter.dart';
import '../models/drawing_stroke.dart';
import '../widgets/drawing/paper_sheet_canvas.dart';
import '../widgets/pdf_exam_preview_dialog.dart';
import '../widgets/clinical_date_picker.dart';
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

  // View Mode: 'structured_form' (Form Matrix default) vs 'tablet_sheet' (Stylus Inking over Paper)
  String _activeViewMode = 'structured_form';

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

  // Autocomplete Suggestions for Patient Name
  List<Patient> _nameSuggestions = [];
  bool _showNameDropdown = false;

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

  void _onNameChanged(String query) {
    setState(() {
      final q = query.trim();
      if (q.isEmpty) {
        _nameSuggestions = [];
        _showNameDropdown = false;
      } else {
        final matches = PatientRepository.searchPatients(q);
        _nameSuggestions = matches;
        // ONLY show dropdown if there are actual matching names in database!
        // If it's a new name, show NO popup at all!
        _showNameDropdown = matches.isNotEmpty;
      }
    });
  }

  void _selectPatientFromDropdown(Patient p) {
    setState(() {
      _showNameDropdown = false;
      _nameSuggestions = [];
      _populateFromPatient(p);
    });
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final now = DateTime.now();
    DateTime initial = now;
    try {
      final parsed = DateTime.tryParse(controller.text);
      if (parsed != null) initial = parsed;
    } catch (_) {}

    final picked = await showClinicalDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1920),
      lastDate: DateTime(2040),
    );

    if (picked != null) {
      setState(() {
        controller.text = formatClinicalDate('${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
      });
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

    PatientRepository.addEncounter(_activePatient.id, tempEncounter);

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
          // Mode Switcher: ⌨️ Form Matrix (Left) vs ✍️ Tablet Stylus Sheet (Right) - Locked to 1 single line!
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: 'structured_form',
                icon: Icon(Icons.grid_view, size: 15),
                label: Text('Form Matrix', maxLines: 1, softWrap: false),
              ),
              ButtonSegment(
                value: 'tablet_sheet',
                icon: Icon(Icons.edit_note, size: 16),
                label: Text('Tablet Stylus Sheet', maxLines: 1, softWrap: false),
              ),
            ],
            selected: {_activeViewMode},
            onSelectionChanged: (val) => setState(() => _activeViewMode = val.first),
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: AppTheme.primaryBlue,
              selectedForegroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 10),

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
      body: _activeViewMode == 'tablet_sheet'
          ? PaperSheetCanvas(
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
            )
          : _buildStructuredFormView(),
    );
  }

  // ==========================================
  // STRUCTURED FORM VIEW (PDF-STYLED CLINICAL MATRIX)
  // ==========================================
  Widget _buildStructuredFormView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Quick Switch Prompt Banner
                _buildSwitchToStylusBanner(),
                const SizedBox(height: 16),

                // 2. Patient Demographics Matrix Block
                _buildPaperHeaderBox(),
                const SizedBox(height: 18),

                // 3. Section 1: Refraction & Visual Acuity Matrix (Clean Paper/PDF Form)
                _buildRefractionTable(),
                const SizedBox(height: 18),

                // 4. Section 2: Clinical Exam Table & Systemic Medical History
                _buildClinicalExamAndHistorySection(),
                const SizedBox(height: 18),

                // 5. Section 3: Clinical Notes & Ocular Anatomy Diagrams
                _buildNotesAndEyeDiagramsSection(),
                const SizedBox(height: 24),

                // 6. Bottom Action Bar
                _buildFormBottomActionBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPdfStyleHeaderBanner() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.remove_red_eye, color: AppTheme.primaryBlue, size: 28),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'METRO EYE SPECIALISTS & REFRACTIVE CENTER',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue, letterSpacing: 0.5),
                ),
                Text(
                  'Ophthalmic Clinical Consultation Record Sheet',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'FORM MATRIX VIEW',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchToStylusBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.draw_outlined, color: AppTheme.primaryBlue, size: 18),
              SizedBox(width: 8),
              Text(
                'Prefer handwriting or sketching eye diagrams directly?',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF)),
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: () {
              setState(() => _activeViewMode = 'tablet_sheet');
            },
            icon: const Icon(Icons.edit_note, size: 16),
            label: const Text('✍️ Switch to Stylus Drawing Canvas', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormBottomActionBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton.icon(
          onPressed: () {
            setState(() => _activeViewMode = 'tablet_sheet');
          },
          icon: const Icon(Icons.draw, size: 16, color: AppTheme.primaryBlue),
          label: const Text('Open Stylus Canvas', style: TextStyle(fontSize: 12, color: AppTheme.primaryBlue, fontWeight: FontWeight.bold)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppTheme.primaryBlue),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: _saveConsultationRecord,
          icon: const Icon(Icons.save, size: 16),
          label: const Text('Save Consultation Record', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildPaperHeaderBox() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF94A3B8), width: 1.2),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'NAME',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppTheme.primaryBlue,
                              width: 1.2,
                            ),
                          ),
                          child: TextField(
                            controller: _nameController,
                            onChanged: _onNameChanged,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                            decoration: const InputDecoration(
                              hintText: 'LAST NAME, FIRST NAME',
                              hintStyle: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // True Floating Overlay Dropdown (Hovers above subsequent rows without adjusting/pushing form)
                    if (_showNameDropdown && _nameSuggestions.isNotEmpty)
                      Positioned(
                        top: 54,
                        left: 0,
                        right: 0,
                        child: Material(
                          elevation: 10,
                          borderRadius: BorderRadius.circular(8),
                          shadowColor: Colors.black38,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.primaryBlue, width: 1.2),
                            ),
                            constraints: const BoxConstraints(maxHeight: 200),
                            child: ListView.separated(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: _nameSuggestions.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final p = _nameSuggestions[index];
                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => _selectPatientFromDropdown(p),
                                    hoverColor: AppTheme.primaryBlue.withValues(alpha: 0.08),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 12,
                                            backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                            child: Text(
                                              p.fullName.isNotEmpty ? p.fullName[0].toUpperCase() : 'P',
                                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  p.fullName,
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                                ),
                                                Text(
                                                  '${p.mrn} • ${p.gender}, ${p.age} yrs • ${p.phone}',
                                                  style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'Select',
                                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _buildHeaderTextField(label: 'Middle Name', controller: _middleNameController, hint: 'MIDDLE NAME'),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _buildHeaderTextField(
                  label: 'DATE',
                  controller: _dateController,
                  hint: 'Aug 21, 2026',
                  isHighlighted: true,
                  isDatePicker: true,
                  onCalendarTap: () => _selectDate(context, _dateController),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _buildHeaderTextField(label: 'Age/Sex', controller: _ageSexController, hint: '63 / M'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _buildHeaderTextField(label: 'Address', controller: _addressController, hint: 'BARANGAY / CITY'),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _buildHeaderTextField(label: 'Contact #', controller: _contactController, hint: '+63 9XX XXX XXXX'),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _buildHeaderTextField(label: 'Occupation', controller: _occupationController, hint: 'OCCUPATION'),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _buildHeaderTextField(label: 'PHIC #', controller: _phicController, hint: 'PHILHEALTH #', isMonospace: true),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _buildHeaderTextField(
                  label: 'Birth Date',
                  controller: _birthDateController,
                  hint: 'May 7, 1963',
                  isDatePicker: true,
                  onCalendarTap: () => _selectDate(context, _birthDateController),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    bool isBold = false,
    bool isHighlighted = false,
    bool isMonospace = false,
    bool isDatePicker = false,
    VoidCallback? onCalendarTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: isHighlighted ? AppTheme.primaryBlue : const Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 3),
        Container(
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isHighlighted ? AppTheme.primaryBlue : const Color(0xFFCBD5E1),
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                    fontFamily: isMonospace ? 'monospace' : null,
                    color: const Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                  ),
                ),
              ),
              if (isDatePicker)
                IconButton(
                  icon: const Icon(Icons.calendar_today, size: 14, color: AppTheme.primaryBlue),
                  tooltip: 'Pick date',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: onCalendarTap,
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // SECTION 1: REFRACTION & VA TABLE (INTERACTIVE)
  // ==========================================
  Widget _buildRefractionTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Table(
        border: TableBorder.all(color: const Color(0xFFE2E8F0), width: 1.0),
        columnWidths: const {
          0: FixedColumnWidth(44), // OD / OS Header
          1: FixedColumnWidth(44), // VA / PH Header
          2: FlexColumnWidth(1.2), // VA / PH Field
          3: FixedColumnWidth(44), // CC Header
          4: FlexColumnWidth(1.2), // CC Field
          5: FixedColumnWidth(50), // Old CC Header
          6: FlexColumnWidth(1.4), // Old CC Field
          7: FixedColumnWidth(44), // AR Header
          8: FlexColumnWidth(2.0), // AR Field
          9: FixedColumnWidth(44), // AK Header
          10: FlexColumnWidth(2.0), // AK Field
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
            children: [
              _buildTableHeaderCell('OD', isPrimary: true),
              _buildTableHeaderCell('VA'),
              _buildTableInputCell(_vaODController, hint: '20/20'),
              _buildTableHeaderCell('CC'),
              _buildTableInputCell(_ccODController, hint: '-1.25'),
              _buildTableHeaderCell('Old CC'),
              _buildTableInputCell(_oldCcODController, hint: '-1.00'),
              _buildTableHeaderCell('AR'),
              _buildTableInputCell(_arODController, hint: '-1.25 -0.50 x 180'),
              _buildTableHeaderCell('AK'),
              _buildTableInputCell(_akODController, hint: '42.50 / 43.00 @ 90'),
            ],
          ),
          TableRow(
            decoration: const BoxDecoration(color: Colors.white),
            children: [
              _buildTableHeaderCell('OS', isPrimary: true),
              _buildTableHeaderCell('PH'),
              _buildTableInputCell(_phOSController, hint: '20/20'),
              _buildTableHeaderCell('CC'),
              _buildTableInputCell(_ccOSController, hint: '-1.50'),
              _buildTableHeaderCell('Old CC'),
              _buildTableInputCell(_oldCcOSController, hint: '-1.25'),
              _buildTableHeaderCell('AR'),
              _buildTableInputCell(_arOSController, hint: '-1.50 -0.75 x 175'),
              _buildTableHeaderCell('AK'),
              _buildTableInputCell(_akOSController, hint: '42.75 / 43.25 @ 95'),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SECTION 2: CLINICAL EXAM & SYSTEMIC HISTORY (INTERACTIVE)
  // ==========================================
  Widget _buildClinicalExamAndHistorySection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 880;
        return Flex(
          direction: isMobile ? Axis.vertical : Axis.horizontal,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: isMobile ? 0 : 7,
              child: _buildClinicalExamTable(),
            ),
            if (!isMobile) const SizedBox(width: 16),
            if (isMobile) const SizedBox(height: 16),
            Expanded(
              flex: isMobile ? 0 : 3,
              child: _buildSystemicMedicalHistoryInteractive(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildClinicalExamTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Table(
        border: TableBorder.all(color: const Color(0xFFE2E8F0), width: 1.0),
        columnWidths: const {
          0: FixedColumnWidth(44), // Blank / OD / OS
          1: FixedColumnWidth(54), // Color
          2: FixedColumnWidth(60), // IOP
          3: FlexColumnWidth(2.2), // Angles Gonioscopy
          4: FlexColumnWidth(1.2), // CDR / ON
          5: FlexColumnWidth(2.0), // Confrontation / Peripheral
          6: FlexColumnWidth(2.0), // Van Herick
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
            children: [
              _buildTableHeaderCell(''),
              _buildTableHeaderCell('Color', fontSize: 10.5),
              _buildTableHeaderCell('IOP', fontSize: 10.5),
              _buildTableHeaderCell('Angles Gonioscopy', fontSize: 10.5),
              _buildTableHeaderCell('CDR / ON', fontSize: 10.5),
              _buildTableHeaderCell('Confrontation', fontSize: 10.5),
              _buildTableHeaderCell('Van Herick', fontSize: 10.5),
            ],
          ),
          TableRow(
            decoration: const BoxDecoration(color: Colors.white),
            children: [
              _buildTableHeaderCell('OD', isPrimary: true),
              _buildTableInputCell(_colorODController, hint: 'B/G'),
              _buildTableInputCell(_iopODController, hint: '14'),
              _buildTableDropdownCell(
                value: _anglesOD,
                items: const ['Open', 'Narrow', 'Closed'],
                onChanged: (val) => setState(() => _anglesOD = val ?? 'Open'),
              ),
              _buildTableInputCell(_cdrODController, hint: '0.3'),
              _buildTableDropdownCell(
                value: _confrontationOD,
                items: const ['WNL', 'Defect', 'Restricted'],
                onChanged: (val) => setState(() => _confrontationOD = val ?? 'WNL'),
              ),
              _buildTableDropdownCell(
                value: _vanHerickOD,
                items: const ['G1', 'G2', 'G3', 'G4 Wide'],
                onChanged: (val) => setState(() => _vanHerickOD = val ?? 'G4 Wide'),
              ),
            ],
          ),
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
            children: [
              _buildTableHeaderCell('OS', isPrimary: true),
              _buildTableInputCell(_colorOSController, hint: 'B/G'),
              _buildTableInputCell(_iopOSController, hint: '15'),
              _buildTableDropdownCell(
                value: _anglesOS,
                items: const ['Open', 'Narrow', 'Closed'],
                onChanged: (val) => setState(() => _anglesOS = val ?? 'Open'),
              ),
              _buildTableInputCell(_cdrOSController, hint: '0.3'),
              _buildTableDropdownCell(
                value: _confrontationOS,
                items: const ['WNL', 'Defect', 'Restricted'],
                onChanged: (val) => setState(() => _confrontationOS = val ?? 'WNL'),
              ),
              _buildTableDropdownCell(
                value: _vanHerickOS,
                items: const ['G1', 'G2', 'G3', 'G4 Wide'],
                onChanged: (val) => setState(() => _vanHerickOS = val ?? 'G4 Wide'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSystemicMedicalHistoryInteractive() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Systemic Medical History',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
          ),
          const SizedBox(height: 6),
          ..._systemicHistory.keys.map((key) {
            final isChecked = _systemicHistory[key] ?? false;
            return InkWell(
              onTap: () {
                setState(() {
                  _systemicHistory[key] = !isChecked;
                });
              },
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.5, horizontal: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: Checkbox(
                        value: isChecked,
                        onChanged: (val) {
                          setState(() {
                            _systemicHistory[key] = val ?? false;
                          });
                        },
                        activeColor: AppTheme.primaryBlue,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        key,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
                          color: isChecked ? AppTheme.primaryBlue : AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ==========================================
  // SECTION 3: NOTES & EYE DIAGRAMS (INTERACTIVE)
  // ==========================================
  Widget _buildNotesAndEyeDiagramsSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 880;
        return Flex(
          direction: isMobile ? Axis.vertical : Axis.horizontal,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: isMobile ? 0 : 7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInteractiveNoteBox('Chief Complaint / HPI', _chiefComplaintController, minLines: 3, maxLines: 5, hint: 'Patient complaints, symptoms, onset...'),
                  const SizedBox(height: 14),
                  _buildInteractiveNoteBox('Assessment', _assessmentController, minLines: 2, maxLines: 4, hint: 'Clinical impressions & diagnoses...'),
                  const SizedBox(height: 14),
                  _buildInteractiveNoteBox('Plan', _planController, minLines: 3, maxLines: 5, hint: 'Treatment, medications, follow-up schedule...'),
                ],
              ),
            ),
            if (!isMobile) const SizedBox(width: 16),
            if (isMobile) const SizedBox(height: 16),
            Expanded(
              flex: isMobile ? 0 : 3,
              child: _buildEyeDiagramsInteractiveCard(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInteractiveNoteBox(
    String title,
    TextEditingController controller, {
    int minLines = 2,
    int maxLines = 4,
    String hint = '',
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          minLines: minLines,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 12.5, color: AppTheme.textPrimary, height: 1.3),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(10),
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEyeDiagramsInteractiveCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.visibility, size: 14, color: AppTheme.primaryBlue),
              SizedBox(width: 4),
              Text(
                'Anterior Cornea / Slit Lamp',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMiniEyeDiagram(label: 'OD', isCornea: true, isOD: true),
              const SizedBox(width: 20),
              _buildMiniEyeDiagram(label: 'OS', isCornea: true, isOD: false),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lens, size: 12, color: AppTheme.primaryBlue),
              SizedBox(width: 4),
              Text(
                'Dilated Fundus Exam',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMiniEyeDiagram(label: 'OD', isCornea: false, isOD: true),
              const SizedBox(width: 20),
              _buildMiniEyeDiagram(label: 'OS', isCornea: false, isOD: false),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() => _activeViewMode = 'tablet_sheet');
              },
              icon: const Icon(Icons.draw, size: 14, color: AppTheme.primaryBlue),
              label: const Text('Draw on Stylus Canvas', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                side: const BorderSide(color: AppTheme.primaryBlue),
                foregroundColor: AppTheme.primaryBlue,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniEyeDiagram({required String label, required bool isCornea, required bool isOD}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label == 'OD') ...[
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.0,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(width: 6),
        ],
        CustomPaint(
          size: const Size(60, 48),
          painter: MiniEyeDiagramPainter(isCornea: isCornea, isOD: isOD),
        ),
        if (label == 'OS') ...[
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.0,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTableHeaderCell(
    String text, {
    bool isPrimary = false,
    double fontSize = 11.5,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      alignment: Alignment.center,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: isPrimary ? AppTheme.primaryBlue : const Color(0xFF334155),
        ),
      ),
    );
  }

  Widget _buildTableInputCell(
    TextEditingController controller, {
    required String hint,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      alignment: Alignment.center,
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          isDense: true,
          border: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 1.2),
          ),
        ),
      ),
    );
  }

  Widget _buildTableDropdownCell({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      alignment: Alignment.center,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          isExpanded: true,
          isDense: true,
          iconSize: 14,
          iconEnabledColor: const Color(0xFF64748B),
          style: const TextStyle(fontSize: 10.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class MiniEyeDiagramPainter extends CustomPainter {
  final bool isCornea;
  final bool isOD;

  MiniEyeDiagramPainter({required this.isCornea, required this.isOD});

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final center = Offset(size.width / 2, size.height / 2);

    if (isCornea) {
      // Crescent bracket
      const double angleSpan = 0.40 * 3.14159;
      final outerRect = Rect.fromCircle(center: Offset(center.dx - 6, center.dy), radius: 20);
      final path = Path()..addArc(outerRect, 3.14159 - angleSpan, angleSpan * 2);
      final innerRect = Rect.fromCircle(center: Offset(center.dx - 6, center.dy), radius: 15);
      path.arcTo(innerRect, 3.14159 + angleSpan, -angleSpan * 2, false);
      path.close();
      canvas.drawPath(path, borderPaint);

      // Cornea circle
      canvas.drawCircle(Offset(center.dx + 6, center.dy), 14, borderPaint);
    } else {
      // Outer fundus circle
      const double radius = 24.0;
      canvas.drawCircle(center, radius, borderPaint);

      // Optic disc
      final double discOffsetX = isOD ? radius * 0.44 : -radius * 0.44;
      final discCenter = Offset(center.dx + discOffsetX, center.dy);
      const double discRadius = radius * 0.22;
      canvas.drawCircle(discCenter, discRadius, borderPaint);

      // Superior arcade
      final sup = Path()
        ..moveTo(discCenter.dx, discCenter.dy - discRadius)
        ..quadraticBezierTo(center.dx, center.dy - radius * 0.8, isOD ? center.dx - radius * 0.6 : center.dx + radius * 0.6, center.dy - radius * 0.4);
      canvas.drawPath(sup, borderPaint);

      // Inferior arcade
      final inf = Path()
        ..moveTo(discCenter.dx, discCenter.dy + discRadius)
        ..quadraticBezierTo(center.dx, center.dy + radius * 0.8, isOD ? center.dx - radius * 0.6 : center.dx + radius * 0.6, center.dy + radius * 0.4);
      canvas.drawPath(inf, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant MiniEyeDiagramPainter oldDelegate) =>
      oldDelegate.isCornea != isCornea || oldDelegate.isOD != isOD;
}
