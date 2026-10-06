import '../widgets/clinic_dialogs.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/patient.dart';
import '../theme/app_theme.dart';
import '../widgets/clinical_modal_picker.dart';
import '../widgets/filter_pill.dart';
import '../widgets/page_header.dart';
import '../widgets/skeleton_loader.dart';
import '../services/team_service.dart';
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
  int _currentPage = 1;
  int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadPatients();
    TeamService.instance.addListener(_loadPatients);
  }

  @override
  void dispose() {
    TeamService.instance.removeListener(_loadPatients);
    _searchController.dispose();
    super.dispose();
  }

  void _loadPatients() {
    setState(() {
      _patients = PatientRepository.getAllPatients();
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _currentPage = 1;
      _patients = PatientRepository.searchPatients(query);
    });
  }

  Future<void> _openNewPatientModal() async {
    if (!TeamService.instance.canEditPatients) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${TeamService.instance.activeRole.label} role cannot register or edit patient records.')),
      );
      return;
    }
    if (!await ensureClinic(context) || !mounted) return;
    showDialog(
      context: context,
      builder: (dialogCtx) => NewPatientModal(
        onPatientCreated: (newPatient) {
          _loadPatients();
          showPatientCreatedSuccessModal(
            context: context,
            patient: newPatient,
            onViewProfile: () => widget.onSelectPatient(newPatient),
            onStartExam: () {
              if (widget.onStartExam != null) {
                widget.onStartExam!(newPatient);
              } else {
                widget.onSelectPatient(newPatient);
              }
            },
          );
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
      color: Color(0xFF0284C7),
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
              titlePadding: EdgeInsets.fromLTRB(24, 20, 16, 12),
              contentPadding: EdgeInsets.fromLTRB(24, 0, 24, 20),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: color, size: 22),
                      ),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                          Text(subtitle, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: AppTheme.textSecondary),
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
                        prefixIcon: Icon(Icons.search, size: 20),
                        filled: true,
                        fillColor: Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onChanged: (text) {
                        setModalState(() {
                          filterText = text;
                        });
                      },
                    ),
                    SizedBox(height: 12),
                    Expanded(
                      child: matchingPatients.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.person_off_outlined, size: 36, color: AppTheme.textSecondary),
                                  SizedBox(height: 8),
                                  Text(
                                    filterText.isEmpty ? 'No patients available' : 'No matching patient found',
                                    style: TextStyle(color: AppTheme.textSecondary),
                                  ),
                                  SizedBox(height: 12),
                                  TextButton.icon(
                                    onPressed: () {
                                      Navigator.pop(dialogCtx);
                                      _openNewPatientModal();
                                    },
                                    icon: Icon(Icons.person_add),
                                    label: Text('+ Register New Patient'),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: matchingPatients.length,
                              separatorBuilder: (_, _) => Divider(height: 1, color: Color(0xFFE2E8F0)),
                              itemBuilder: (context, idx) {
                                final p = matchingPatients[idx];
                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  leading: CircleAvatar(
                                    radius: 18,
                                    backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                    child: Text(
                                      p.fullName.isNotEmpty ? p.fullName[0] : 'P',
                                      style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  title: Text(p.fullName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  subtitle: Text('${p.mrn} • ${p.gender}, ${p.age}y • Last: ${formatClinicalDate(p.lastVisitDate)}', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                  trailing: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(dialogCtx);
                                      onSelect(p);
                                    },
                                    icon: Icon(icon, size: 14),
                                    label: Text(actionLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: color,
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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

  Widget _buildNewActionsDropdownButton({double? width}) {
    final double dropdownWidth = width ?? 260.0;

    return InkWell(
      onTap: () {
        showNewRecordActionModal(
          context: context,
          onNewExam: _openPatientSelectorForExam,
          onNewRx: _openPatientSelectorForPrescription,
          onRegisterPatient: _openNewPatientModal,
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: dropdownWidth,
        height: 54,
        decoration: BoxDecoration(
          color: AppTheme.primaryBlue,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryBlue.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'New',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        PatientRepository.changeNotifier,
        PatientRepository.isLoading,
        TeamService.instance,
      ]),
      builder: (context, child) {
        final isLoading = PatientRepository.isLoading.value;
        final query = _searchController.text.trim();
        final paginatedResult = PatientRepository.getPaginatedPatients(
          page: _currentPage,
          pageSize: _pageSize,
          searchQuery: query,
          filter: _selectedFilter,
        );
        _patients = PatientRepository.searchPatients(query);

        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 768;

        return SingleChildScrollView(
          padding: EdgeInsets.all(PageHeader.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Title & New Action Dropdown CTA
              PageHeader(
                title: 'Patient Directory',
                subtitle: 'Search and manage clinical patient records with modern patient cards.',
                stackBelow: 768,
                action: _buildNewActionsDropdownButton(width: isMobile ? double.infinity : 260.0),
              ),

          // Search, Filter & Layout View Toggle Card
          Card(
            color: AppTheme.cardBg,
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppTheme.borderColor),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        // Same search bar as the dashboard. The input is explicitly unfilled:
                        // the app theme fills text fields, which drew a grey box inside the pill.
                        child: Container(
                          height: 54,
                          decoration: BoxDecoration(
                            color: AppTheme.cardBg,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: AppTheme.borderColor),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 18),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(Icons.search, color: AppTheme.primaryBlue, size: 22),
                              SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: _onSearchChanged,
                                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                                  decoration: InputDecoration(
                                    hintText: 'Search patient by name, phone, or DOB...',
                                    hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                    filled: false,
                                    fillColor: Colors.transparent,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                                  ),
                                ),
                              ),
                              if (_searchController.text.isNotEmpty)
                                IconButton(
                                  icon: Icon(Icons.close, size: 18, color: AppTheme.textSecondary),
                                  tooltip: 'Clear search',
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged('');
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 16),

                      // View Toggle Buttons (Cards vs Table)
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg,
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
                    SizedBox(height: 12),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
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
                                  Icon(Icons.person_search, size: 16, color: AppTheme.primaryBlue),
                                  SizedBox(width: 6),
                                  Text(
                                    'DATABASE RESULTS (${_patients.length} MATCHES)',
                                    style: TextStyle(
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
                                child: Text('Clear', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          if (_patients.isEmpty)
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, size: 16, color: Color(0xFFE11D48)),
                                  SizedBox(width: 8),
                                  Text('No patient named "${_searchController.text}" found.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                  Spacer(),
                                  TextButton.icon(
                                    onPressed: _openNewPatientModal,
                                    icon: Icon(Icons.add, size: 14),
                                    label: Text('Register New Patient', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                                  padding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 13,
                                        backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                        child: Text(
                                          patient.fullName.isNotEmpty ? patient.fullName[0].toUpperCase() : 'P',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          '${patient.fullName} (${patient.mrn}) • ${patient.gender}, ${patient.age}y',
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
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
                                        icon: Icon(Icons.draw, size: 13),
                                        label: Text('Exam', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                        style: OutlinedButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          side: BorderSide(color: AppTheme.primaryBlue),
                                          foregroundColor: AppTheme.primaryBlue,
                                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                  SizedBox(height: 12),

                  // Filter Chips. A single Wrap, so on a narrow screen the pills drop to the
                  // next line instead of running past the card's edge. Full width so it
                  // stays left-aligned (the card's Column centres its children).
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Text('Quick Filters:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                        ),
                        ...['All', 'Glaucoma', 'Diabetic Retinopathy', 'Cataract'].map((filter) {
                          final isSelected = _selectedFilter == filter;
                          return FilterPill(
                            label: filter,
                            selected: isSelected,
                            onSelected: () {
                              setState(() {
                                _selectedFilter = filter;
                                _currentPage = 1;
                                if (filter == 'All') {
                                  _patients = PatientRepository.getAllPatients();
                                } else {
                                  _patients = PatientRepository.searchPatients(filter);
                                }
                              });
                            },
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 24),

          // Patients Display: Skeleton Loaders OR Modern Grid Cards OR Table List
          isLoading
              ? (_isGridView ? _buildSkeletonGrid() : _buildSkeletonTable())
              : paginatedResult.items.isEmpty
                  ? Card(
                      color: AppTheme.cardBg,
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: AppTheme.borderColor),
                      ),
                      child: Padding(
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
                              Text('Try searching with a different name or phone number.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    )
                  : _isGridView
                      ? _buildModernCardGrid(paginatedResult.items)
                      : _buildTableView(paginatedResult.items, paginatedResult.totalCount),

          if (!isLoading && paginatedResult.totalCount > 0)
            _buildPaginationControls(paginatedResult),
            ],
          ),
        );
      },
    );
  },
);
  }

  Widget _buildSkeletonGrid() {
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
          itemCount: 6,
          itemBuilder: (context, index) => const SkeletonPatientCard(),
        );
      },
    );
  }

  Widget _buildSkeletonTable() {
    return Card(
      color: AppTheme.cardBg,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.borderColor),
      ),
      child: Column(
        children: List.generate(
          6,
          (index) => Column(
            children: [
              const SkeletonTableRow(),
              Divider(height: 1, color: AppTheme.borderColor),
            ],
          ),
        ),
      ),
    );
  }

  // Modern Cards Grid Layout (Unified with Dashboard Homepage)
  Widget _buildModernCardGrid(List<Patient> patients) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = math.max(1, (constraints.maxWidth / 420).floor());
        return GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisExtent: 220,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: patients.length,
          itemBuilder: (context, index) {
            final patient = patients[index];
            final hasDiagnosis = patient.previousDiagnoses.isNotEmpty;

            return Card(
              color: AppTheme.cardBg,
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppTheme.borderColor),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
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
                            style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                patient.fullName,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${patient.mrn} • ${patient.gender}, ${patient.age}y',
                                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${patient.totalVisits} Visits',
                            style: TextStyle(color: AppTheme.primaryBlue, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 6),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.phone_outlined, size: 12, color: AppTheme.textSecondary),
                            SizedBox(width: 4),
                            Text(patient.phone, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(Icons.history_outlined, size: 12, color: AppTheme.textSecondary),
                            SizedBox(width: 4),
                            Text('Last: ${formatClinicalDate(patient.lastVisitDate)}', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          ],
                        ),
                      ],
                    ),

                    SizedBox(height: 6),

                    Row(
                      children: [
                        Icon(Icons.medical_information_outlined, size: 12, color: Color(0xFFD97706)),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            hasDiagnosis ? patient.previousDiagnoses.first : 'No prior registered conditions',
                            style: TextStyle(fontSize: 11, color: Color(0xFFD97706), fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: OutlinedButton(
                            onPressed: () {
                              widget.onSelectPatient(patient);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryBlue,
                              side: BorderSide(color: AppTheme.borderColor),
                              padding: EdgeInsets.symmetric(vertical: 9),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text('View History', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        SizedBox(width: 8),
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
    return InkWell(
      onTap: () {
        showClinicalActionModal(
          context: context,
          title: 'Action for ${patient.fullName}',
          subtitle: 'MRN: ${patient.mrn} • ${patient.age} yrs, ${patient.gender}',
          actions: [
            ClinicalActionItem(
              id: 'exam',
              title: 'New Examination',
              subtitle: 'Open consultation paper sheet for ${patient.fullName}',
              icon: Icons.draw_rounded,
              color: AppTheme.primaryBlue,
              onTap: () {
                if (widget.onStartExam != null) {
                  widget.onStartExam!(patient);
                } else {
                  widget.onSelectPatient(patient);
                }
              },
            ),
            ClinicalActionItem(
              id: 'rx',
              title: 'New Prescription (Rx)',
              subtitle: 'Write digital prescription for ${patient.fullName}',
              icon: Icons.medication_rounded,
              color: Color(0xFF0284C7),
              onTap: () {
                if (widget.onOpenPrescription != null) {
                  widget.onOpenPrescription!(patient);
                } else {
                  widget.onSelectPatient(patient);
                }
              },
            ),
          ],
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.primaryBlue,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: Colors.white, size: 15),
            SizedBox(width: 4),
            Text(
              'New',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // Classic Table View Fallback
  Widget _buildTableView(List<Patient> patients, int totalCount) {
    return Card(
      color: AppTheme.cardBg,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Patient Records ($totalCount)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
                ),
                Text('Click "View Profile" to open clinical profile', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.borderColor),
          LayoutBuilder(
            builder: (context, constraints) {
              final double cardWidth = constraints.maxWidth;
              final double minContentWidth = 780.0;
              final double dynamicSpacing = cardWidth > minContentWidth
                  ? 24.0 + ((cardWidth - minContentWidth) / 6.0).clamp(0.0, 60.0)
                  : 24.0;

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: cardWidth),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(AppTheme.cardBg),
                    horizontalMargin: 24,
                    columnSpacing: dynamicSpacing,
                    columns: [
                DataColumn(label: Text('Patient Name', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary))),
                DataColumn(label: Text('Patient ID (MRN)', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary))),
                DataColumn(label: Text('Age / Sex', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary))),
                DataColumn(label: Text('Phone Contact', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary))),
                DataColumn(label: Text('Last Visit', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary))),
                DataColumn(label: Text('Visits', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary))),
                DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary))),
              ],
              rows: patients.map((patient) {
                return DataRow(
                  cells: [
                    DataCell(
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                            child: Text(
                              patient.fullName.isNotEmpty ? patient.fullName.substring(0, 1) : 'P',
                              style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(patient.fullName, style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                        ],
                      ),
                    ),
                    DataCell(Text(patient.mrn, style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w500))),
                    DataCell(Text('${patient.age}y / ${patient.gender}', style: TextStyle(color: AppTheme.textPrimary))),
                    DataCell(Text(patient.phone, style: TextStyle(color: AppTheme.textSecondary))),
                    DataCell(Text(formatClinicalDate(patient.lastVisitDate), style: TextStyle(color: AppTheme.textPrimary))),
                    DataCell(
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('${patient.totalVisits} Visits', style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ),
                    DataCell(
                      ElevatedButton(
                        onPressed: () {
                          widget.onSelectPatient(patient);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text('View Profile', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    ),
  ],
),
);
  }

  Widget _buildPaginationControls(PaginatedResult<Patient> result) {
    if (result.totalCount == 0) return SizedBox.shrink();

    final startItem = (result.page - 1) * result.pageSize + 1;
    final endItem = math.min(result.page * result.pageSize, result.totalCount);

    return Card(
      color: AppTheme.cardBg,
      elevation: 1,
      margin: EdgeInsets.only(top: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.borderColor),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 600;

            final infoText = Text(
              'Showing $startItem–$endItem of ${result.totalCount} records',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            );

            final pageSizeSelector = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Rows per page: ',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _pageSize,
                      isDense: true,
                      items: const [10, 20, 50].map((size) {
                        return DropdownMenuItem<int>(
                          value: size,
                          child: Text('$size', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        );
                      }).toList(),
                      onChanged: (newSize) {
                        if (newSize != null) {
                          setState(() {
                            _pageSize = newSize;
                            _currentPage = 1;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            );

            final pageNavControls = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.first_page_rounded),
                  tooltip: 'First Page',
                  iconSize: 20,
                  visualDensity: VisualDensity.standard,
                  onPressed: result.hasPrevious
                      ? () => setState(() => _currentPage = 1)
                      : null,
                ),
                IconButton(
                  icon: Icon(Icons.chevron_left_rounded),
                  tooltip: 'Previous Page',
                  iconSize: 20,
                  visualDensity: VisualDensity.standard,
                  onPressed: result.hasPrevious
                      ? () => setState(() => _currentPage--)
                      : null,
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'Page ${result.page} of ${result.totalPages}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right_rounded),
                  tooltip: 'Next Page',
                  iconSize: 20,
                  visualDensity: VisualDensity.standard,
                  onPressed: result.hasNext
                      ? () => setState(() => _currentPage++)
                      : null,
                ),
                IconButton(
                  icon: Icon(Icons.last_page_rounded),
                  tooltip: 'Last Page',
                  iconSize: 20,
                  visualDensity: VisualDensity.standard,
                  onPressed: result.hasNext
                      ? () => setState(() => _currentPage = result.totalPages)
                      : null,
                ),
              ],
            );

            if (isNarrow) {
              return Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      infoText,
                      pageSizeSelector,
                    ],
                  ),
                  SizedBox(height: 10),
                  Divider(height: 1, color: AppTheme.borderColor),
                  SizedBox(height: 6),
                  pageNavControls,
                ],
              );
            }

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                infoText,
                Row(
                  children: [
                    pageSizeSelector,
                    SizedBox(width: 16),
                    pageNavControls,
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
