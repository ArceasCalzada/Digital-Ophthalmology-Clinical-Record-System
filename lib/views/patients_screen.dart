import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/patient.dart';
import '../theme/app_theme.dart';
import 'new_patient_modal.dart';

class PatientsScreen extends StatefulWidget {
  final Function(Patient) onSelectPatient;
  final Function(Patient?)? onStartExam;
  final Function(Patient)? onOpenPrescription;

  const PatientsScreen({
    super.key,
    required this.onSelectPatient,
    this.onStartExam,
    this.onOpenPrescription,
  });

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  final _searchController = TextEditingController();
  List<Patient> _patients = [];
  bool _isGridView = true; // Toggle between Modern Cards & Table
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  void _loadPatients() {
    setState(() {
      _patients = PatientRepository.getAllPatients();
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _patients = PatientRepository.searchPatients(query);
    });
  }

  void _openNewPatientModal() {
    showDialog(
      context: context,
      builder: (context) => NewPatientModal(
        onPatientCreated: (newPatient) {
          _loadPatients();
          widget.onSelectPatient(newPatient);
        },
      ),
    );
  }

  void _openPatientSelectorForExam() {
    if (widget.onStartExam != null) {
      widget.onStartExam!(null);
    }
  }

  void _openPatientSelectorForPrescription() {
    _openPatientSelectorModal(
      title: 'Create New Prescription (Rx)',
      subtitle: 'Select patient to generate ophthalmic prescription',
      icon: Icons.medication_rounded,
      color: const Color(0xFF0284C7),
      actionLabel: 'Write Rx',
      onSelect: (patient) {
        if (widget.onOpenPrescription != null) {
          widget.onOpenPrescription!(patient);
        } else {
          widget.onSelectPatient(patient);
        }
      },
    );
  }

  void _openPatientSelectorModal({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String actionLabel,
    required Function(Patient) onSelect,
  }) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        String filterText = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final allPatients = PatientRepository.getAllPatients();
            final matchingPatients = filterText.isEmpty
                ? allPatients
                : allPatients.where((p) =>
                    p.fullName.toLowerCase().contains(filterText.toLowerCase()) ||
                    p.mrn.toLowerCase().contains(filterText.toLowerCase()) ||
                    p.phone.contains(filterText)
                  ).toList();

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              titlePadding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
              contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: color, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                          Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                    onPressed: () => Navigator.pop(dialogCtx),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                height: 380,
                child: Column(
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Type patient name, ID, or phone...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onChanged: (text) {
                        setModalState(() {
                          filterText = text;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: matchingPatients.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.person_off_outlined, size: 36, color: AppTheme.textSecondary),
                                  const SizedBox(height: 8),
                                  Text(
                                    filterText.isEmpty ? 'No patients available' : 'No matching patient found',
                                    style: const TextStyle(color: AppTheme.textSecondary),
                                  ),
                                  const SizedBox(height: 12),
                                  TextButton.icon(
                                    onPressed: () {
                                      Navigator.pop(dialogCtx);
                                      _openNewPatientModal();
                                    },
                                    icon: const Icon(Icons.person_add),
                                    label: const Text('+ Register New Patient'),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: matchingPatients.length,
                              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                              itemBuilder: (context, idx) {
                                final p = matchingPatients[idx];
                                return ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  leading: CircleAvatar(
                                    radius: 18,
                                    backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                    child: Text(
                                      p.fullName.isNotEmpty ? p.fullName[0] : 'P',
                                      style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  title: Text(p.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  subtitle: Text('${p.mrn} • ${p.gender}, ${p.age}y • Last: ${formatClinicalDate(p.lastVisitDate)}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                  trailing: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(dialogCtx);
                                      onSelect(p);
                                    },
                                    icon: Icon(icon, size: 14),
                                    label: Text(actionLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: color,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      elevation: 0,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNewActionsDropdownButton() {
    const double dropdownWidth = 260.0;

    return PopupMenuButton<String>(
      tooltip: 'Create New Item',
      offset: const Offset(0, 52),
      constraints: const BoxConstraints(minWidth: dropdownWidth, maxWidth: dropdownWidth),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(14),
          bottomRight: Radius.circular(14),
          topLeft: Radius.zero,
          topRight: Radius.zero,
        ),
      ),
      color: Colors.white,
      elevation: 6,
      onSelected: (value) {
        switch (value) {
          case 'exam':
            _openPatientSelectorForExam();
            break;
          case 'rx':
            _openPatientSelectorForPrescription();
            break;
          case 'patient':
            _openNewPatientModal();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'exam',
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.draw_rounded, color: AppTheme.primaryBlue, size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('New Examination', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
                    Text('Consultation sheet & matrix', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'rx',
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.medication_rounded, color: Color(0xFF0284C7), size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('New Prescription', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
                    Text('Write digital ophthalmic Rx', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'patient',
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF10B981), size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Register New Patient', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
                    Text('Add new patient profile', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        width: dropdownWidth,
        height: 54,
        decoration: BoxDecoration(
          color: AppTheme.primaryBlue,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryBlue.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Stack(
          alignment: Alignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, color: Colors.white, size: 20),
                SizedBox(width: 6),
                Text(
                  'New',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            Positioned(
              right: 16,
              child: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 22),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 12 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Title & New Action Dropdown CTA
              Flex(
                direction: isMobile ? Axis.vertical : Axis.horizontal,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: isMobile ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Patient Directory',
                        style: TextStyle(fontSize: isMobile ? 22 : 28, fontWeight: FontWeight.bold, color: AppTheme.textPrimary, letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Search and manage clinical patient records with modern patient cards.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                  if (isMobile) const SizedBox(height: 12),
                  _buildNewActionsDropdownButton(),
                ],
              ),
              const SizedBox(height: 20),

          // Search, Filter & Layout View Toggle Card
          Card(
            color: AppTheme.cardBg,
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppTheme.borderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: TextField(
                            controller: _searchController,
                            onChanged: _onSearchChanged,
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Search patient by name, patient ID (MRN), phone, or DOB...',
                              hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                              prefixIcon: const Icon(Icons.search, color: AppTheme.primaryBlue, size: 20),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.close, size: 18, color: AppTheme.textSecondary),
                                      onPressed: () {
                                        _searchController.clear();
                                        _onSearchChanged('');
                                      },
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // View Toggle Buttons (Cards vs Table)
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.grid_view_rounded, color: _isGridView ? AppTheme.primaryBlue : AppTheme.textSecondary, size: 20),
                              tooltip: 'Modern Cards View',
                              onPressed: () => setState(() => _isGridView = true),
                            ),
                            IconButton(
                              icon: Icon(Icons.table_rows_rounded, color: !_isGridView ? AppTheme.primaryBlue : AppTheme.textSecondary, size: 20),
                              tooltip: 'Table List View',
                              onPressed: () => setState(() => _isGridView = false),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Search Suggestions Dropdown / Quick Matches Box
                  if (_searchController.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.person_search, size: 16, color: AppTheme.primaryBlue),
                                  const SizedBox(width: 6),
                                  Text(
                                    'DATABASE RESULTS (${_patients.length} MATCHES)',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                      color: AppTheme.primaryBlue,
                                    ),
                                  ),
                                ],
                              ),
                              InkWell(
                                onTap: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                                child: const Text('Clear', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_patients.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline, size: 16, color: Color(0xFFE11D48)),
                                  const SizedBox(width: 8),
                                  Text('No patient named "${_searchController.text}" found.', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                  const Spacer(),
                                  TextButton.icon(
                                    onPressed: _openNewPatientModal,
                                    icon: const Icon(Icons.add, size: 14),
                                    label: const Text('Register New Patient', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            )
                          else
                            ..._patients.take(4).map((patient) {
                              return InkWell(
                                onTap: () => widget.onSelectPatient(patient),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 13,
                                        backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                        child: Text(
                                          patient.fullName.isNotEmpty ? patient.fullName[0].toUpperCase() : 'P',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          '${patient.fullName} (${patient.mrn}) • ${patient.gender}, ${patient.age}y',
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                        ),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          if (widget.onStartExam != null) {
                                            widget.onStartExam!(patient);
                                          } else {
                                            widget.onSelectPatient(patient);
                                          }
                                        },
                                        icon: const Icon(Icons.draw, size: 13),
                                        label: const Text('Exam', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                        style: OutlinedButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          side: const BorderSide(color: AppTheme.primaryBlue),
                                          foregroundColor: AppTheme.primaryBlue,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Filter Chips
                  Row(
                    children: [
                      const Text('Quick Filters:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                      const SizedBox(width: 12),
                      Wrap(
                        spacing: 8,
                        children: ['All', 'Glaucoma', 'Diabetic Retinopathy', 'Cataract'].map((filter) {
                          final isSelected = _selectedFilter == filter;
                          return ChoiceChip(
                            label: Text(filter, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : AppTheme.textPrimary, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                            selected: isSelected,
                            selectedColor: AppTheme.primaryBlue,
                            backgroundColor: const Color(0xFFF8FAFC),
                            side: BorderSide(color: isSelected ? AppTheme.primaryBlue : AppTheme.borderColor),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedFilter = filter;
                                  if (filter == 'All') {
                                    _patients = PatientRepository.getAllPatients();
                                  } else {
                                    _patients = PatientRepository.searchPatients(filter);
                                  }
                                });
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Patients Display: Modern Grid Cards OR Table List
          _patients.isEmpty
              ? Card(
                  color: AppTheme.cardBg,
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppTheme.borderColor),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.person_search_outlined, size: 48, color: AppTheme.textSecondary),
                          SizedBox(height: 12),
                          Text(
                            'No matching patient records found.',
                            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          SizedBox(height: 4),
                          Text('Try searching with a different name, MRN, or phone number.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                )
              : _isGridView
                  ? _buildModernCardGrid()
                  : _buildTableView(),
            ],
          ),
        );
      },
    );
  }

  // Modern Cards Grid Layout (Unified with Dashboard Homepage)
  Widget _buildModernCardGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = math.max(1, (constraints.maxWidth / 420).floor());
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisExtent: 220,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: _patients.length,
          itemBuilder: (context, index) {
            final patient = _patients[index];
            final hasDiagnosis = patient.previousDiagnoses.isNotEmpty;

            return Card(
              color: AppTheme.cardBg,
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppTheme.borderColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                          child: Text(
                            patient.fullName.isNotEmpty ? patient.fullName[0] : 'P',
                            style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                patient.fullName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${patient.mrn} • ${patient.gender}, ${patient.age}y',
                                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${patient.totalVisits} Visits',
                            style: const TextStyle(color: AppTheme.primaryBlue, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.phone_outlined, size: 12, color: AppTheme.textSecondary),
                            const SizedBox(width: 4),
                            Text(patient.phone, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(Icons.history_outlined, size: 12, color: AppTheme.textSecondary),
                            const SizedBox(width: 4),
                            Text('Last: ${formatClinicalDate(patient.lastVisitDate)}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    Row(
                      children: [
                        const Icon(Icons.medical_information_outlined, size: 12, color: Color(0xFFD97706)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            hasDiagnosis ? patient.previousDiagnoses.first : 'No prior registered conditions',
                            style: const TextStyle(fontSize: 11, color: Color(0xFFD97706), fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: OutlinedButton(
                            onPressed: () => widget.onSelectPatient(patient),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryBlue,
                              side: const BorderSide(color: AppTheme.borderColor),
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('View History', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 5,
                          child: _buildPatientCardNewActionsButton(patient),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPatientCardNewActionsButton(Patient patient) {
    return PopupMenuButton<String>(
      tooltip: 'New action for ${patient.fullName}',
      offset: const Offset(0, 38),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      elevation: 4,
      onSelected: (value) {
        switch (value) {
          case 'exam':
            if (widget.onStartExam != null) {
              widget.onStartExam!(patient);
            } else {
              widget.onSelectPatient(patient);
            }
            break;
          case 'rx':
            if (widget.onOpenPrescription != null) {
              widget.onOpenPrescription!(patient);
            } else {
              widget.onSelectPatient(patient);
            }
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'exam',
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.draw_rounded, color: AppTheme.primaryBlue, size: 16),
              ),
              const SizedBox(width: 10),
              const Text('New Examination', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'rx',
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.medication_rounded, color: Color(0xFF0284C7), size: 16),
              ),
              const SizedBox(width: 10),
              const Text('New Prescription (Rx)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.primaryBlue,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: Colors.white, size: 15),
            SizedBox(width: 4),
            Text(
              'New',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
            SizedBox(width: 2),
            Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  // Classic Table View Fallback
  Widget _buildTableView() {
    return Card(
      color: AppTheme.cardBg,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Patient Records (${_patients.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
                ),
                const Text('Click "View Profile" to open clinical profile', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.borderColor),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              horizontalMargin: 20,
              columnSpacing: 24,
              columns: const [
                DataColumn(label: Text('Patient Name', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary))),
                DataColumn(label: Text('Patient ID (MRN)', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary))),
                DataColumn(label: Text('Age / Sex', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary))),
                DataColumn(label: Text('Phone Contact', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary))),
                DataColumn(label: Text('Last Visit', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary))),
                DataColumn(label: Text('Visits', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary))),
                DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary))),
              ],
              rows: _patients.map((patient) {
                return DataRow(
                  cells: [
                    DataCell(
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                            child: Text(
                              patient.fullName.substring(0, 1),
                              style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(patient.fullName, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                        ],
                      ),
                    ),
                    DataCell(Text(patient.mrn, style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w500))),
                    DataCell(Text('${patient.age}y / ${patient.gender}', style: const TextStyle(color: AppTheme.textPrimary))),
                    DataCell(Text(patient.phone, style: const TextStyle(color: AppTheme.textSecondary))),
                    DataCell(Text(formatClinicalDate(patient.lastVisitDate), style: const TextStyle(color: AppTheme.textPrimary))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('${patient.encounters.length} Visits', style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ),
                    DataCell(
                      ElevatedButton(
                        onPressed: () => widget.onSelectPatient(patient),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('View Profile', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
