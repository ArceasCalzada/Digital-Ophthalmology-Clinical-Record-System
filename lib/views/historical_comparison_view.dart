import 'package:flutter/material.dart';
import '../models/patient.dart';
import '../models/encounter.dart';
import '../models/eye_exam.dart';
import '../widgets/drawing/eye_drawing_canvas.dart';
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
                      child: Row(
                        children: [
                          const Text('Prior Visit: ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButton<Encounter>(
                              value: _encounterLeft,
                              dropdownColor: AppTheme.cardBg,
                              isExpanded: true,
                              underline: Container(),
                              items: encounters.map((e) {
                                return DropdownMenuItem(
                                  value: e,
                                  child: Text('${e.date} — ${e.diagnosis}', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _encounterLeft = val);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Icon(Icons.compare_arrows, color: AppTheme.primaryBlue, size: 28),
                    ),

                    Expanded(
                      child: Row(
                        children: [
                          const Text('Recent Visit: ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButton<Encounter>(
                              value: _encounterRight,
                              dropdownColor: AppTheme.cardBg,
                              isExpanded: true,
                              underline: Container(),
                              items: encounters.map((e) {
                                return DropdownMenuItem(
                                  value: e,
                                  child: Text('${e.date} — ${e.diagnosis}', style: const TextStyle(color: AppTheme.primaryBlue, fontSize: 13, fontWeight: FontWeight.bold)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _encounterRight = val);
                              },
                            ),
                          ),
                        ],
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
