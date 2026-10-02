import '../config/plan_limits.dart';
import '../widgets/paywall_dialog.dart';
import 'dart:math';

import 'package:flutter/material.dart';
import '../config/app_limits.dart';
import '../models/patient.dart';
import '../services/team_service.dart';
import '../widgets/clinical_date_picker.dart';
import '../widgets/clinical_dropdown_field.dart';
import '../widgets/clinical_modal_picker.dart';
import '../widgets/field_label.dart';
import '../widgets/required_text_form_field.dart';
import '../widgets/shake_widget.dart';
import '../widgets/success_modal.dart';
import '../theme/app_theme.dart';

class NewPatientModal extends StatefulWidget {
  final Function(Patient) onPatientCreated;

  const NewPatientModal({super.key, required this.onPatientCreated});

  @override
  State<NewPatientModal> createState() => _NewPatientModalState();
}

class _NewPatientModalState extends State<NewPatientModal> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _dobController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _medHistoryController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _notesController = TextEditingController();
  final _genderShake = GlobalKey<ShakeWidgetState>();
  String? _gender; // not assumed: the user must choose

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _dobController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _medHistoryController.dispose();
    _allergiesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// The patient ID is assigned here rather than typed or shown on the form: a fresh random
  /// "PT-######" that no loaded patient already has. (The old clock-based one repeated every
  /// ~17 minutes, and a repeat silently replaced the earlier patient.)
  String _newPatientId() {
    final taken = PatientRepository.getAllPatients().map((p) => p.mrn).toSet();
    final random = Random();
    String candidate;
    do {
      candidate = 'PT-${100000 + random.nextInt(900000)}';
    } while (taken.contains(candidate));
    return candidate;
  }

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
        mrn: _newPatientId(),
        firstName: _firstNameController.text.trim(),
        middleName: _middleNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        // Stored in one format whether it was picked or typed.
        dateOfBirth: formatClinicalDate(
          () {
            final dob = parseDateOfBirth(_dobController.text)!; // validated above
            return '${dob.year}-${dob.month.toString().padLeft(2, '0')}-${dob.day.toString().padLeft(2, '0')}';
          }(),
        ),
        gender: _gender!, // validated as chosen before we get here
        phone: _phoneController.text.trim().isEmpty ? '+63 900 000 0000' : _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty ? 'Metro Manila, Philippines' : _addressController.text.trim(),
        medicalHistory: medHistory.isEmpty ? ['No Prior Medical Conditions'] : medHistory,
        allergies: allergies.isEmpty ? ['No Known Drug Allergies (NKDA)'] : allergies,
        notes: _notesController.text.trim(),
        previousDiagnoses: [],
        previousPrescriptions: [],
        prescriptions: [],
        encounters: [],
        teamId: TeamService.instance.activeTeam?.id ?? '',
        lastVisitDate: DateTime.now().toString().substring(0, 10),
        totalVisits: 1,
      );

      try {
        PatientRepository.addPatient(newPatient);
      } on PatientLimitReachedException {
        showPaywallDialog(context, reason: PlanLimit.patients);
        return;
      } on FormatException catch (e) {
        _showError(e.message);
        return;
      }
      Navigator.pop(context);
      widget.onPatientCreated(newPatient);
      showActionSuccessModal(
        context: context,
        title: 'Patient Registered Successfully',
        message: 'Patient "${newPatient.fullName}" (MRN: ${newPatient.mrn}) has been registered and added to the clinic database.',
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  Future<void> _selectDob() async {
    final now = DateTime.now();
    final picked = await showClinicalDatePicker(
      context: context,
      initialDate: DateTime(1985, 6, 15),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _dobController.text = formatClinicalDate('${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
      });
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const FieldLabel('First Name', required: true, fontSize: 12),
                          const SizedBox(height: 6),
                          RequiredTextFormField(
                            controller: _firstNameController,
                            decoration: const InputDecoration(hintText: 'e.g. Elena'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const FieldLabel('Middle Name', fontSize: 12),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _middleNameController,
                            decoration: const InputDecoration(hintText: 'e.g. Marie'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const FieldLabel('Last Name', required: true, fontSize: 12),
                          const SizedBox(height: 6),
                          RequiredTextFormField(
                            controller: _lastNameController,
                            decoration: const InputDecoration(hintText: 'e.g. Rostova'),
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
                          const FieldLabel('Date of Birth', required: true, fontSize: 12),
                          const SizedBox(height: 6),
                          RequiredTextFormField(
                            controller: _dobController,
                            onChanged: (_) => setState(() {}), // keeps the age line below current
                            decoration: InputDecoration(
                              hintText: 'Jun 15, 1985',
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.calendar_month_outlined, size: 20, color: AppTheme.primaryBlue),
                                tooltip: 'Select Date of Birth from Calendar',
                                onPressed: _selectDob,
                              ),
                            ),
                            // Empty shakes; a filled-in but wrong date shakes and says why.
                            invalidMessage: (text) {
                              if (parseDateOfBirth(text) == null) return 'Enter a valid date, e.g. Jun 15, 1985';
                              if (formatAge(text) == null) return 'Date is in the future';
                              return null;
                            },
                          ),
                          // The age that goes with the birthday, so a wrong date is easy to spot.
                          if (formatAge(_dobController.text) != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6, left: 2),
                              child: Text(
                                'Age: ${formatAge(_dobController.text)}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const FieldLabel('Sex / Gender', required: true, fontSize: 12),
                          const SizedBox(height: 6),
                          ShakeWidget(
                            key: _genderShake,
                            child: FormField<String>(
                              validator: (_) {
                                if (_gender != null) return null;
                                _genderShake.currentState?.shake();
                                return ''; // no text: the field shakes and turns red
                              },
                              builder: (field) => ClinicalDropdownField<String>(
                                placeholder: 'Select gender',
                                value: _gender,
                                invalid: field.hasError,
                                items: const [
                                  ClinicalPickerItem(value: 'Male', label: 'Male'),
                                  ClinicalPickerItem(value: 'Female', label: 'Female'),
                                  ClinicalPickerItem(value: 'Other', label: 'Other'),
                                ],
                                onChanged: (selected) {
                                  setState(() => _gender = selected);
                                  field.didChange(selected);
                                },
                              ),
                            ),
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
                const SizedBox(height: 14),

                const FieldLabel('Notes', fontSize: 12),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _notesController,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: AppLimits.maxNotesLength,
                  decoration: const InputDecoration(hintText: 'Anything else worth knowing about this patient'),
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

void showPatientCreatedSuccessModal({
  required BuildContext context,
  required Patient patient,
  required VoidCallback onViewProfile,
  required VoidCallback onStartExam,
}) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      title: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 42),
          ),
          const SizedBox(height: 14),
          const Text(
            'Patient Registered Successfully!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          const Text(
            'Record saved locally & queued for Cloud Firestore sync.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        patient.fullName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          patient.mrn,
                          style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Gender & Age: ${patient.gender}, ${patient.age} years old', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  Text('Registered: ${formatRegistrationDate(patient.createdAt)}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                  Text('Contact Phone: ${patient.phone}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  Text('Address: ${patient.address}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      onStartExam();
                    },
                    icon: const Icon(Icons.draw_rounded, size: 16),
                    label: const Text('Start Exam', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      onViewProfile();
                    },
                    icon: const Icon(Icons.folder_shared_rounded, size: 16),
                    label: const Text('View Record', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
