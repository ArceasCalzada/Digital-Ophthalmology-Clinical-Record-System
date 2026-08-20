import 'package:flutter/material.dart';
import '../models/patient.dart';
import '../theme/app_theme.dart';

class NewPatientModal extends StatefulWidget {
  final Function(Patient) onPatientCreated;

  const NewPatientModal({super.key, required this.onPatientCreated});

  @override
  State<NewPatientModal> createState() => _NewPatientModalState();
}

class _NewPatientModalState extends State<NewPatientModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mrnController = TextEditingController(text: 'PT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
  final _dobController = TextEditingController(text: '1985-06-15');
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _medHistoryController = TextEditingController();
  final _allergiesController = TextEditingController();
  String _gender = 'Male';

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final medHistory = _medHistoryController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final allergies = _allergiesController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final newPatient = Patient(
        id: 'pat-${DateTime.now().millisecondsSinceEpoch}',
        mrn: _mrnController.text.trim(),
        fullName: _nameController.text.trim(),
        dateOfBirth: _dobController.text.trim(),
        gender: _gender,
        phone: _phoneController.text.trim().isEmpty ? '+63 900 000 0000' : _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty ? 'Metro Manila, Philippines' : _addressController.text.trim(),
        medicalHistory: medHistory.isEmpty ? ['No Prior Medical Conditions'] : medHistory,
        allergies: allergies.isEmpty ? ['No Known Drug Allergies (NKDA)'] : allergies,
        previousDiagnoses: [],
        previousPrescriptions: [],
        prescriptions: [],
        encounters: [],
        lastVisitDate: DateTime.now().toString().substring(0, 10),
        totalVisits: 1,
      );

      PatientRepository.addPatient(newPatient);
      widget.onPatientCreated(newPatient);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.person_add_alt_1, color: AppTheme.primaryBlue),
              SizedBox(width: 8),
              Text('Register New Patient', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppTheme.textSecondary),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Full Name *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(hintText: 'e.g. Elena Rostova'),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Patient ID / MRN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _mrnController,
                            decoration: const InputDecoration(hintText: 'PT-00125'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Date of Birth (YYYY-MM-DD) *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _dobController,
                            decoration: const InputDecoration(hintText: '1985-06-15'),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Sex / Gender', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _gender,
                            decoration: const InputDecoration(),
                            items: ['Male', 'Female', 'Other'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _gender = val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                const Text('Contact Phone Number', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(hintText: '+63 917 123 4567'),
                ),
                const SizedBox(height: 14),

                const Text('Residential Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(hintText: 'Street Address, City, Province'),
                ),
                const SizedBox(height: 14),

                const Text('Relevant Medical History (comma separated)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _medHistoryController,
                  decoration: const InputDecoration(hintText: 'e.g. Type 2 Diabetes, Glaucoma Family History'),
                ),
                const SizedBox(height: 14),

                const Text('Allergies (comma separated)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _allergiesController,
                  decoration: const InputDecoration(hintText: 'e.g. Sulfa, Latex, Penicillin'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Register Patient'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
