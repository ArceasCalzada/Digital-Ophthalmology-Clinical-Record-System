import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/patient.dart';
import '../theme/app_theme.dart';
import 'new_patient_modal.dart';

class PatientsScreen extends StatefulWidget {
  final Function(Patient) onSelectPatient;
  final Function(Patient)? onStartExam;

  const PatientsScreen({
    super.key,
    required this.onSelectPatient,
    this.onStartExam,
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

  @override
  Widget build(BuildContext context) {
    final allPatients = PatientRepository.getAllPatients();
    final totalEncounters = allPatients.fold<int>(0, (sum, p) => sum + p.encounters.length);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 12 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Title & New Patient CTA
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
                  ElevatedButton.icon(
                    onPressed: _openNewPatientModal,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('+ New Patient', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 20, vertical: isMobile ? 10 : 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Overview Stats Row / Column
              if (isMobile)
                Column(
                  children: [
                    _buildStatCard('Total Patients', '${allPatients.length}', Icons.people_outline, AppTheme.primaryBlue),
                    const SizedBox(height: 10),
                    _buildStatCard('Encounters Recorded', '$totalEncounters', Icons.assignment_outlined, const Color(0xFF059669)),
                    const SizedBox(height: 10),
                    _buildStatCard('Active Workstation', 'Online', Icons.wifi_tethering, const Color(0xFFD97706)),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard('Total Patients', '${allPatients.length}', Icons.people_outline, AppTheme.primaryBlue),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard('Encounters Recorded', '$totalEncounters', Icons.assignment_outlined, const Color(0xFF059669)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard('Active Workstation', 'Online', Icons.wifi_tethering, const Color(0xFFD97706)),
                    ),
                  ],
                ),
              const SizedBox(height: 24),

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
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                          decoration: const InputDecoration(
                            hintText: 'Search patient by name, patient ID (MRN), phone, or DOB...',
                            prefixIcon: Icon(Icons.search, color: AppTheme.primaryBlue),
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

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      color: AppTheme.cardBg,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTheme.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
                Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Modern Cards Grid Layout
  Widget _buildModernCardGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = math.max(1, (constraints.maxWidth / 440).floor());
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisExtent: 260,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: _patients.length,
          itemBuilder: (context, index) {
            final patient = _patients[index];
            final initial = patient.fullName.isNotEmpty ? patient.fullName.substring(0, 1) : 'P';
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
                  children: [
                    // Header: Patient Avatar & MRN Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                              child: Text(
                                initial,
                                style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  patient.fullName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary),
                                ),
                                Text(
                                  '${patient.gender}, ${patient.age}y  •  DOB: ${patient.dateOfBirth}',
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            patient.mrn,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue, fontFamily: 'monospace'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    const Divider(color: AppTheme.borderColor, height: 1),
                    const SizedBox(height: 12),

                    // Phone & Contact Metadata
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined, size: 14, color: AppTheme.textSecondary),
                        const SizedBox(width: 6),
                        Text(patient.phone, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: Text(
                            '${patient.encounters.length} Encounters',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Medical History / Diagnosis Chips
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('PRIMARY DIAGNOSIS / HISTORY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 0.5)),
                          const SizedBox(height: 4),
                          if (hasDiagnosis)
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: patient.previousDiagnoses.take(2).map((diag) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFFDE68A)),
                                  ),
                                  child: Text(
                                    diag,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                            )
                          else
                            const Text('No prior recorded conditions.', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Bottom Action Buttons Row
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => widget.onSelectPatient(patient),
                            icon: const Icon(Icons.person_search_outlined, size: 14),
                            label: const Text('View Profile', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryBlue,
                              side: const BorderSide(color: AppTheme.borderColor),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (widget.onStartExam != null) {
                                widget.onStartExam!(patient);
                              } else {
                                widget.onSelectPatient(patient);
                              }
                            },
                            icon: const Icon(Icons.draw_outlined, size: 14),
                            label: const Text('New Exam', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
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
                    DataCell(Text(patient.lastVisitDate, style: const TextStyle(color: AppTheme.textPrimary))),
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
