import 'package:flutter/material.dart';
import '../models/patient.dart';
import '../models/prescription.dart';
import '../theme/app_theme.dart';

class PrescriptionView extends StatefulWidget {
  final Patient? initialPatient;

  const PrescriptionView({super.key, this.initialPatient});

  @override
  State<PrescriptionView> createState() => _PrescriptionViewState();
}

class _PrescriptionViewState extends State<PrescriptionView> {
  Patient? _selectedPatient;
  final List<PrescriptionItem> _medications = [];
  final _doctorName = 'Dr. Sarah Jenkins, MD';

  // Form Controllers
  final _medNameController = TextEditingController();
  final _strengthController = TextEditingController();
  final _dosageController = TextEditingController();
  final _frequencyController = TextEditingController();
  final _durationController = TextEditingController();
  final _instructionsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final allPatients = PatientRepository.getAllPatients();
    _selectedPatient = widget.initialPatient ?? (allPatients.isNotEmpty ? allPatients.first : null);
    _addInitialMedicationDraft();
  }

  void _addInitialMedicationDraft() {
    _medications.add(
      PrescriptionItem(
        id: 'item-${DateTime.now().millisecondsSinceEpoch}',
        medicationName: 'Latanoprost 0.005% Ophthalmic Solution',
        strength: '0.005%',
        dosage: '1 drop',
        frequency: 'Once daily at bedtime',
        duration: '30 days',
        instructions: 'Instill 1 drop in both eyes (OU) every night before sleep.',
      ),
    );
  }

  void _addMedicationFromInput() {
    if (_medNameController.text.trim().isEmpty) return;

    setState(() {
      _medications.add(
        PrescriptionItem(
          id: 'item-${DateTime.now().millisecondsSinceEpoch}',
          medicationName: _medNameController.text.trim(),
          strength: _strengthController.text.trim().isEmpty ? '1%' : _strengthController.text.trim(),
          dosage: _dosageController.text.trim().isEmpty ? '1 drop' : _dosageController.text.trim(),
          frequency: _frequencyController.text.trim().isEmpty ? 'Once daily' : _frequencyController.text.trim(),
          duration: _durationController.text.trim().isEmpty ? '30 days' : _durationController.text.trim(),
          instructions: _instructionsController.text.trim().isEmpty ? 'Instill as directed.' : _instructionsController.text.trim(),
        ),
      );
      _medNameController.clear();
      _strengthController.clear();
      _dosageController.clear();
      _frequencyController.clear();
      _durationController.clear();
      _instructionsController.clear();
    });
  }

  void _savePrescription() {
    if (_selectedPatient == null || _medications.isEmpty) return;

    final newRx = Prescription(
      id: 'rx-${DateTime.now().millisecondsSinceEpoch}',
      patientId: _selectedPatient!.id,
      encounterId: 'enc-${DateTime.now().millisecondsSinceEpoch}',
      doctorName: _doctorName,
      date: DateTime.now().toString().substring(0, 10),
      items: List.from(_medications),
    );

    PatientRepository.addPrescription(_selectedPatient!.id, newRx);
    _showPdfPreviewModal(newRx);
  }

  void _showPdfPreviewModal(Prescription rx) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 640,
          padding: const EdgeInsets.all(32),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Banner
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
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
                            Text('DIGITAL OPHTHALMOLOGY CLINICAL RECORD SYSTEM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryBlue)),
                            Text('Metro Eye Specialists & Refractive Center', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: AppTheme.borderColor),
                const SizedBox(height: 16),

                // Rx Patient Details
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PATIENT: ${_selectedPatient?.fullName ?? 'Patient'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary)),
                        Text('MRN: ${_selectedPatient?.mrn ?? ''}  •  Age/Sex: ${_selectedPatient?.age}y / ${_selectedPatient?.gender}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('DATE: ${rx.date}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
                        Text('PHYSICIAN: ${rx.doctorName}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Large Rx Symbol
                const Text('℞', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                const SizedBox(height: 12),

                // Medications Table
                Table(
                  border: TableBorder.all(color: AppTheme.borderColor, width: 1),
                  columnWidths: const {
                    0: FlexColumnWidth(3),
                    1: FlexColumnWidth(1.5),
                    2: FlexColumnWidth(2),
                    3: FlexColumnWidth(3.5),
                  },
                  children: [
                    TableRow(
                      decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
                      children: const [
                        Padding(padding: EdgeInsets.all(8), child: Text('Medication', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        Padding(padding: EdgeInsets.all(8), child: Text('Dosage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        Padding(padding: EdgeInsets.all(8), child: Text('Frequency', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        Padding(padding: EdgeInsets.all(8), child: Text('Instructions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      ],
                    ),
                    ...rx.items.map((item) {
                      return TableRow(
                        children: [
                          Padding(padding: const EdgeInsets.all(8), child: Text('${item.medicationName} (${item.strength})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                          Padding(padding: const EdgeInsets.all(8), child: Text(item.dosage, style: const TextStyle(fontSize: 12))),
                          Padding(padding: const EdgeInsets.all(8), child: Text(item.frequency, style: const TextStyle(fontSize: 12))),
                          Padding(padding: const EdgeInsets.all(8), child: Text(item.instructions, style: const TextStyle(fontSize: 12))),
                        ],
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 32),

                // Signature Area
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 200,
                          height: 40,
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: AppTheme.textPrimary, width: 1.5)),
                          ),
                          child: const Center(
                            child: Text(
                              'Dr. Sarah Jenkins, MD',
                              style: TextStyle(fontFamily: 'serif', fontStyle: FontStyle.italic, fontSize: 18, color: AppTheme.primaryBlue),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text('Physician Signature & License No. 091823', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Prescription PDF downloaded successfully.')),
                        );
                      },
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('Download PDF'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Sent to clinic prescription printer.')),
                        );
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.print, size: 16),
                      label: const Text('Print Prescription'),
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

  @override
  Widget build(BuildContext context) {
    final allPatients = PatientRepository.getAllPatients();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Banner
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Prescriptions Workspace', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  SizedBox(height: 4),
                  Text('Create, preview, and print clinical eye prescriptions.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _medications.isEmpty ? null : _savePrescription,
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                label: const Text('Generate Printable PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Patient Selector Bar
          Card(
            color: AppTheme.cardBg,
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppTheme.borderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.person, color: AppTheme.primaryBlue),
                  const SizedBox(width: 12),
                  const Text('Select Patient:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<Patient>(
                      initialValue: _selectedPatient,
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                      items: allPatients.map((p) {
                        return DropdownMenuItem(
                          value: p,
                          child: Text('${p.fullName} (${p.mrn}) • Age ${p.age}'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedPatient = val);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Add Medication Form & Active Items
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Add Medication Form
              Expanded(
                flex: 5,
                child: Card(
                  color: AppTheme.cardBg,
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppTheme.borderColor),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Add Ophthalmic Medication', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary)),
                        const SizedBox(height: 16),
                        const Text('Medication Name *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _medNameController,
                          decoration: const InputDecoration(hintText: 'e.g. Timolol 0.5% Maleate Drops'),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Strength', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
                                  const SizedBox(height: 6),
                                  TextFormField(controller: _strengthController, decoration: const InputDecoration(hintText: '0.5%')),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Dosage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
                                  const SizedBox(height: 6),
                                  TextFormField(controller: _dosageController, decoration: const InputDecoration(hintText: '1 drop OU')),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Frequency', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
                                  const SizedBox(height: 6),
                                  TextFormField(controller: _frequencyController, decoration: const InputDecoration(hintText: 'Twice daily (BID)')),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Duration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
                                  const SizedBox(height: 6),
                                  TextFormField(controller: _durationController, decoration: const InputDecoration(hintText: '30 days')),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text('Special Instructions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _instructionsController,
                          decoration: const InputDecoration(hintText: 'Instill 1 drop in morning and evening.'),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _addMedicationFromInput,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Medication to Prescription'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 44),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),

              // Current Prescription Draft List
              Expanded(
                flex: 6,
                child: Card(
                  color: AppTheme.cardBg,
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppTheme.borderColor),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Active Prescription Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary)),
                            Text('${_medications.length} items', style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _medications.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(32),
                                child: Center(child: Text('No medications added yet.', style: TextStyle(color: AppTheme.textSecondary))),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _medications.length,
                                separatorBuilder: (_, __) => const Divider(color: AppTheme.borderColor),
                                itemBuilder: (context, index) {
                                  final item = _medications[index];
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                      child: Text('${index + 1}', style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold)),
                                    ),
                                    title: Text(item.medicationName, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                                    subtitle: Text('${item.dosage} • ${item.frequency} • ${item.duration}\n${item.instructions}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                      onPressed: () {
                                        setState(() => _medications.removeAt(index));
                                      },
                                    ),
                                  );
                                },
                              ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
