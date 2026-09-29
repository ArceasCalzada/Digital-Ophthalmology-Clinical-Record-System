import 'package:flutter/material.dart';
import '../models/patient.dart';
import '../models/encounter.dart';
import '../models/eye_exam.dart';
import '../widgets/drawing/eye_drawing_canvas.dart';
import '../widgets/clinical_dropdown_field.dart';
import '../widgets/clinical_modal_picker.dart';
import '../widgets/field_label.dart';
import '../theme/app_theme.dart';

class HistoricalComparisonView extends StatefulWidget {
  final Patient patient;

  const HistoricalComparisonView({super.key, required this.patient});

  @override
  State<HistoricalComparisonView> createState() => _HistoricalComparisonViewState();
}

class _HistoricalComparisonViewState extends State<HistoricalComparisonView> {
  late Encounter _encounterLeft;
  late Encounter _encounterRight;
  EyeType _selectedEye = EyeType.OD;

  @override
  void initState() {
    super.initState();
    final encounters = widget.patient.encounters;
    _encounterLeft = encounters.length > 1 ? encounters[1] : encounters.first;
    _encounterRight = encounters.first;
  }

  @override
  Widget build(BuildContext context) {
    final encounters = widget.patient.encounters;

    final drawingLeft = _selectedEye == EyeType.OD ? _encounterLeft.drawingOD : _encounterLeft.drawingOS;
    final drawingRight = _selectedEye == EyeType.OD ? _encounterRight.drawingOD : _encounterRight.drawingOS;

    final examLeft = _selectedEye == EyeType.OD ? _encounterLeft.examOD : _encounterLeft.examOS;
    final examRight = _selectedEye == EyeType.OD ? _encounterRight.examOD : _encounterRight.examOS;

    return Scaffold(
      appBar: AppBar(
        title: Text('Historical Drawing Comparison: ${widget.patient.fullName}', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: SegmentedButton<EyeType>(
              segments: const [
                ButtonSegment(value: EyeType.OD, label: Text('OD (Right)')),
                ButtonSegment(value: EyeType.OS, label: Text('OS (Left)')),
              ],
              selected: {_selectedEye},
              onSelectionChanged: (val) => setState(() => _selectedEye = val.first),
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppTheme.primaryBlue,
                selectedForegroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Controls & Encounter Selection Bar
            Card(
              color: AppTheme.cardBg,
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppTheme.borderColor),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: ClinicalDropdownField<Encounter>(
                        label: const FieldLabel('Prior Visit', fontSize: 12),
                        placeholder: 'Select visit...',
                        value: _encounterLeft,
                        displayText: '${formatClinicalDate(_encounterLeft.date)} — ${_encounterLeft.diagnosis}',
                        items: [
                          for (final e in encounters)
                            ClinicalPickerItem<Encounter>(
                              value: e,
                              label: formatClinicalDate(e.date),
                              subtitle: '${e.diagnosis} • ${e.doctorName}',
                            ),
                        ],
                        onChanged: (e) => setState(() => _encounterLeft = e),
                      ),
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Icon(Icons.compare_arrows, color: AppTheme.primaryBlue, size: 28),
                    ),

                    Expanded(
                      child: ClinicalDropdownField<Encounter>(
                        label: const FieldLabel('Recent Visit', fontSize: 12),
                        placeholder: 'Select visit...',
                        value: _encounterRight,
                        displayText: '${formatClinicalDate(_encounterRight.date)} — ${_encounterRight.diagnosis}',
                        items: [
                          for (final e in encounters)
                            ClinicalPickerItem<Encounter>(
                              value: e,
                              label: formatClinicalDate(e.date),
                              subtitle: '${e.diagnosis} • ${e.doctorName}',
                            ),
                        ],
                        onChanged: (e) => setState(() => _encounterRight = e),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Side-by-Side Comparative Canvas Cards
            Expanded(
              child: Row(
                children: [
                  // Previous Visit Canvas & Details
                  Expanded(
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
                          children: [
                            Text(
                              'Prior Examination (${_encounterLeft.date})',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'IOP: ${examLeft.iop} mmHg  •  VA: ${examLeft.acuity.uncorrected}  •  C/D: ${drawingLeft?.cdRatio ?? 0.50}',
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                            ),
                            const SizedBox(height: 12),

                            Expanded(
                              child: EyeDrawingCanvas(
                                eye: _selectedEye,
                                onEyeChanged: (_) {},
                                drawingData: drawingLeft,
                                onDrawingSaved: (_) {},
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Current Visit Canvas & Details
                  Expanded(
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
                          children: [
                            Text(
                              'Current Examination (${_encounterRight.date})',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'IOP: ${examRight.iop} mmHg  •  VA: ${examRight.acuity.uncorrected}  •  C/D: ${drawingRight?.cdRatio ?? 0.50}',
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                            ),
                            const SizedBox(height: 12),

                            Expanded(
                              child: EyeDrawingCanvas(
                                eye: _selectedEye,
                                onEyeChanged: (_) {},
                                drawingData: drawingRight,
                                priorDrawingData: drawingLeft, // Ghost Overlay comparison!
                                onDrawingSaved: (_) {},
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
