import 'package:flutter/material.dart';
import '../models/clinic_branch.dart';
import '../models/patient.dart';
import '../models/prescription.dart';
import '../services/prescription_pdf_service.dart';
import '../services/profile_store.dart';
import '../theme/app_theme.dart';
import '../widgets/clinical_dropdown_field.dart';
import '../widgets/clinical_modal_picker.dart';
import '../widgets/page_header.dart';
import '../widgets/rx_pad_widget.dart';
import '../widgets/success_modal.dart';

class PrescriptionView extends StatefulWidget {
  final Patient? initialPatient;

  const PrescriptionView({super.key, this.initialPatient});

  @override
  State<PrescriptionView> createState() => _PrescriptionViewState();
}

class _PrescriptionViewState extends State<PrescriptionView> {
  Patient? _selectedPatient;
  ClinicBranch? _selectedBranch;
  final List<PrescriptionItem> _medications = [];
  final _doctorName = 'Dr. Sigrid T. Robillos';

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
    final active = ProfileStore.instance.activeBranches;
    if (active.isNotEmpty) {
      _selectedBranch = active.first;
    }
    final allPatients = PatientRepository.getAllPatients();
    _resolveAndSetPatient(widget.initialPatient, allPatients);
  }

  @override
  void didUpdateWidget(covariant PrescriptionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPatient != null &&
        (widget.initialPatient?.id != oldWidget.initialPatient?.id ||
         widget.initialPatient?.id != _selectedPatient?.id)) {
      final allPatients = PatientRepository.getAllPatients();
      _resolveAndSetPatient(widget.initialPatient, allPatients);
    }
  }

  void _resolveAndSetPatient(Patient? candidate, List<Patient> allPatients) {
    if (candidate != null) {
      Patient? matched;
      try {
        matched = allPatients.firstWhere((p) => p.id == candidate.id);
      } catch (_) {
        matched = candidate;
      }
      _selectedPatient = matched;
    } else {
      _selectedPatient = allPatients.isNotEmpty ? allPatients.first : null;
    }
    _loadPatientPrescriptionData(_selectedPatient);
  }

  void _loadPatientPrescriptionData(Patient? patient) {
    _medications.clear();
    if (patient != null && patient.prescriptions.isNotEmpty) {
      final latestRx = patient.prescriptions.first;
      _medications.addAll(latestRx.items);
      if (latestRx.clinicBranch.isNotEmpty) {
        final allBranches = ProfileStore.instance.branches;
        try {
          _selectedBranch = allBranches.firstWhere((b) => b.name == latestRx.clinicBranch);
        } catch (_) {
          _selectedBranch = ClinicBranch(
            id: 'historical',
            name: latestRx.clinicBranch,
            address: '',
            days: '',
            hours: '',
          );
        }
      } else {
        final active = ProfileStore.instance.activeBranches;
        if (active.isNotEmpty) {
          _selectedBranch = active.first;
        }
      }
    } else {
      final active = ProfileStore.instance.activeBranches;
      if (active.isNotEmpty) {
        _selectedBranch = active.first;
      }
    }
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
      clinicBranch: _selectedBranch?.name ?? '',
    );

    try {
      PatientRepository.addPrescription(_selectedPatient!.id, newRx);
    } on FormatException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Not saved: ${e.message}'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    _showSaveSuccessModal(newRx);
  }

  void _showSaveSuccessModal(Prescription rx) {
    showActionSuccessModal(
      context: context,
      title: 'Prescription Saved Successfully',
      message: 'The prescription for ${_selectedPatient!.fullName} has been saved to the patient\'s clinical record.',
      onDismissed: () => _showPdfPreviewModal(rx),
    );
  }

  void _showPdfPreviewModal(Prescription rx) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 620,
          padding: EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Official Prescription Document Preview',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(icon: Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                SizedBox(height: 16),
                RxPadWidget(
                  patient: _selectedPatient,
                  items: rx.items,
                  date: rx.date,
                  doctorName: rx.doctorName.isNotEmpty ? rx.doctorName : ProfileStore.instance.doctorName.text,
                  showBorder: true,
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        await PrescriptionPdfService.downloadPdf(
                          patient: _selectedPatient,
                          items: rx.items,
                          date: rx.date,
                          doctorName: rx.doctorName.isNotEmpty ? rx.doctorName : ProfileStore.instance.doctorName.text,
                        );
                        if (context.mounted) {
                          showActionSuccessModal(
                            context: context,
                            title: 'Prescription PDF Downloaded',
                            message: 'The official prescription document for ${_selectedPatient?.fullName ?? "patient"} has been exported to PDF.',
                            icon: Icons.file_download_outlined,
                          );
                        }
                      },
                      icon: Icon(Icons.download, size: 16),
                      label: Text('Download PDF'),
                    ),
                    SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await PrescriptionPdfService.printPrescription(
                          patient: _selectedPatient,
                          items: rx.items,
                          date: rx.date,
                          doctorName: rx.doctorName.isNotEmpty ? rx.doctorName : 'Dr. Sigrid T. Robillos',
                        );
                      },
                      icon: Icon(Icons.print, size: 16),
                      label: Text('Print Prescription'),
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
    final List<Patient> dropdownPatients = List.from(allPatients);
    if (_selectedPatient != null && !dropdownPatients.any((p) => p.id == _selectedPatient!.id)) {
      dropdownPatients.insert(0, _selectedPatient!);
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(PageHeader.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Banner
          PageHeader(
            title: 'Prescriptions Workspace',
            subtitle: 'Create, preview, and print clinical eye prescriptions.',
            action: ElevatedButton.icon(
              onPressed: _medications.isEmpty ? null : _savePrescription,
              icon: Icon(Icons.picture_as_pdf, size: 18),
              label: Text('Generate Printable PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ),

          // Patient Selector Bar
          Card(
            color: AppTheme.cardBg,
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppTheme.borderColor),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, selectorConstraints) {
                  final isNarrow = selectorConstraints.maxWidth < 500;
                  final dropdown = ClinicalDropdownField<Patient>(
                    placeholder: 'Search & select patient...',
                    value: _selectedPatient,
                    displayText: _selectedPatient != null ? '${_selectedPatient!.fullName} (${_selectedPatient!.mrn})' : null,
                    searchable: true,
                    searchHint: 'Type patient name...',
                    items: [
                      for (final p in dropdownPatients)
                        ClinicalPickerItem<Patient>(
                          value: p,
                          label: p.fullName,
                          subtitle: '${p.mrn} • ${p.gender}, ${p.age} yrs • ${p.phone}',
                        ),
                    ],
                    onChanged: (patient) {
                      setState(() {
                        _selectedPatient = patient;
                        _loadPatientPrescriptionData(patient);
                      });
                    },
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person, color: AppTheme.primaryBlue),
                            SizedBox(width: 12),
                            Text('Select Patient:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary)),
                          ],
                        ),
                        SizedBox(height: 10),
                        dropdown,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Icon(Icons.person, color: AppTheme.primaryBlue),
                      SizedBox(width: 12),
                      Text('Select Patient:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary)),
                      SizedBox(width: 16),
                      Expanded(child: dropdown),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Clinic Branch Selector Bar
          Card(
            color: AppTheme.cardBg,
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppTheme.borderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ListenableBuilder(
                listenable: ProfileStore.instance,
                builder: (context, _) {
                  final activeBranches = ProfileStore.instance.activeBranches;
                  return LayoutBuilder(
                    builder: (context, selectorConstraints) {
                      final isNarrow = selectorConstraints.maxWidth < 500;
                      final branchDropdown = ClinicalDropdownField<ClinicBranch>(
                        key: const Key('prescription_clinic_branch_dropdown'),
                        placeholder: 'Select Clinic Branch Location...',
                        value: activeBranches.any((b) => b.id == _selectedBranch?.id) ? _selectedBranch : null,
                        displayText: _selectedBranch != null
                            ? '${_selectedBranch!.name} (${_selectedBranch!.address})'
                            : (activeBranches.isNotEmpty ? '${activeBranches.first.name} (${activeBranches.first.address})' : 'No Active Branches'),
                        searchable: activeBranches.length > 3,
                        searchHint: 'Search branch...',
                        items: [
                          for (final b in activeBranches)
                            ClinicalPickerItem<ClinicBranch>(
                              value: b,
                              label: b.name,
                              subtitle: '${b.address} • ${b.days} ${b.hours}',
                            ),
                        ],
                        onChanged: (branch) {
                          setState(() {
                            _selectedBranch = branch;
                          });
                        },
                      );

                      if (isNarrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.business_outlined, color: AppTheme.primaryBlue),
                                const SizedBox(width: 12),
                                Text('Clinic Branch:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            branchDropdown,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          const Icon(Icons.business_outlined, color: AppTheme.primaryBlue),
                          const SizedBox(width: 12),
                          Text('Clinic Branch:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary)),
                          const SizedBox(width: 16),
                          Expanded(child: branchDropdown),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Add Medication Form & Active Items (Responsive Stacking)
          LayoutBuilder(
            builder: (context, constraints) {
              final isStacked = constraints.maxWidth < 1024;

              final medicationFormCard = Card(
                color: AppTheme.cardBg,
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: AppTheme.borderColor),
                ),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add Ophthalmic Medication', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary)),
                      SizedBox(height: 16),
                      Text('Medication Name *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
                      SizedBox(height: 6),
                      TextFormField(
                        controller: _medNameController,
                        decoration: InputDecoration(hintText: 'e.g. Timolol 0.5% Maleate Drops'),
                      ),
                      SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (ctx, formConstraints) {
                          final isNarrowForm = formConstraints.maxWidth < 450;
                          if (isNarrowForm) {
                            return Column(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Strength', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
                                    SizedBox(height: 6),
                                    TextFormField(controller: _strengthController, decoration: InputDecoration(hintText: '0.5%')),
                                  ],
                                ),
                                SizedBox(height: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Dosage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
                                    SizedBox(height: 6),
                                    TextFormField(controller: _dosageController, decoration: InputDecoration(hintText: '1 drop OU')),
                                  ],
                                ),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Strength', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
                                    SizedBox(height: 6),
                                    TextFormField(controller: _strengthController, decoration: InputDecoration(hintText: '0.5%')),
                                  ],
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Dosage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
                                    SizedBox(height: 6),
                                    TextFormField(controller: _dosageController, decoration: InputDecoration(hintText: '1 drop OU')),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (ctx, formConstraints) {
                          final isNarrowForm = formConstraints.maxWidth < 450;
                          if (isNarrowForm) {
                            return Column(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Frequency', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
                                    SizedBox(height: 6),
                                    TextFormField(controller: _frequencyController, decoration: InputDecoration(hintText: 'Twice daily (BID)')),
                                  ],
                                ),
                                SizedBox(height: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Duration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
                                    SizedBox(height: 6),
                                    TextFormField(controller: _durationController, decoration: InputDecoration(hintText: '30 days')),
                                  ],
                                ),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Frequency', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
                                    SizedBox(height: 6),
                                    TextFormField(controller: _frequencyController, decoration: InputDecoration(hintText: 'Twice daily (BID)')),
                                  ],
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Duration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
                                    SizedBox(height: 6),
                                    TextFormField(controller: _durationController, decoration: InputDecoration(hintText: '30 days')),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      SizedBox(height: 12),
                      Text('Special Instructions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
                      SizedBox(height: 6),
                      TextFormField(
                        controller: _instructionsController,
                        decoration: InputDecoration(hintText: 'Instill 1 drop in morning and evening.'),
                      ),
                      SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _addMedicationFromInput,
                        icon: Icon(Icons.add, size: 16),
                        label: Text('Add Medication to Prescription'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                          minimumSize: Size(double.infinity, 44),
                        ),
                      ),
                    ],
                  ),
                ),
              );

              final livePreviewColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Live Prescription Pad Preview',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_medications.isNotEmpty)
                        TextButton.icon(
                          onPressed: () => setState(() => _medications.clear()),
                          icon: Icon(Icons.clear_all, size: 16, color: Colors.redAccent),
                          label: Text('Clear All', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                        ),
                    ],
                  ),
                  SizedBox(height: 12),
                  ListenableBuilder(
                    listenable: ProfileStore.instance,
                    builder: (context, _) => RxPadWidget(
                      patient: _selectedPatient,
                      items: _medications,
                      date: DateTime.now().toString().substring(0, 10),
                      doctorName: ProfileStore.instance.doctorName.text,
                      showBorder: true,
                    ),
                  ),
                ],
              );

              if (isStacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    medicationFormCard,
                    SizedBox(height: 24),
                    livePreviewColumn,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: medicationFormCard),
                  SizedBox(width: 20),
                  Expanded(flex: 6, child: livePreviewColumn),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
