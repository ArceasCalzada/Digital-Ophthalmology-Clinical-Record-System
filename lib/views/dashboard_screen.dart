import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/patient.dart';
import '../theme/app_theme.dart';
import 'new_patient_modal.dart';

class DashboardScreen extends StatefulWidget {
  final Function(Patient)? onSelectPatient;
  final Function(Patient?)? onStartExam;
  final Function(Patient)? onOpenPrescription;

  const DashboardScreen({
    super.key,
    this.onSelectPatient,
    this.onStartExam,
    this.onOpenPrescription,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Patient> _allPatients = [];
  List<Patient> _searchSuggestions = [];
  bool _isSearching = false;
  Timer? _clockTimer;
  String _currentTime = '';

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _updateClock();
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _updateClock() {
    final now = DateTime.now();
    final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    setState(() {
      _currentTime = '$hour:$minute $period';
    });
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  void _loadDashboardData() {
    setState(() {
      _allPatients = PatientRepository.getAllPatients();
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _searchSuggestions = [];
        _isSearching = false;
      } else {
        _searchSuggestions = PatientRepository.searchPatients(query);
        _isSearching = true;
      }
    });
  }

  void _openNewPatientModal() {
    showDialog(
      context: context,
      builder: (context) => NewPatientModal(
        onPatientCreated: (newPatient) {
          _loadDashboardData();
          if (widget.onSelectPatient != null) {
            widget.onSelectPatient!(newPatient);
          }
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
        } else if (widget.onSelectPatient != null) {
          widget.onSelectPatient!(patient);
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
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                        Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      autofocus: true,
                      onChanged: (val) => setModalState(() => filterText = val),
                      decoration: InputDecoration(
                        hintText: 'Search by patient name, MRN, or phone...',
                        hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                        prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.primaryBlue),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.borderColor),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: matchingPatients.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.person_off_outlined, size: 36, color: AppTheme.textSecondary),
                                  const SizedBox(height: 8),
                                  const Text('No patients match your search.', style: TextStyle(color: AppTheme.textSecondary)),
                                  const SizedBox(height: 12),
                                  TextButton.icon(
                                    onPressed: () {
                                      Navigator.pop(dialogCtx);
                                      _openNewPatientModal();
                                    },
                                    icon: const Icon(Icons.person_add, size: 16),
                                    label: const Text('Register New Patient', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: matchingPatients.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (ctx, idx) {
                                final p = matchingPatients[idx];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: color.withValues(alpha: 0.1),
                                    child: Text(
                                      p.fullName.isNotEmpty ? p.fullName[0].toUpperCase() : 'P',
                                      style: TextStyle(color: color, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  title: Text(p.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  subtitle: Text('${p.mrn} • ${p.gender}, ${p.age} yrs • ${p.phone}', style: const TextStyle(fontSize: 12)),
                                  trailing: ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(dialogCtx);
                                      onSelect(p);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: color,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      visualDensity: VisualDensity.compact,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: Text(actionLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                  onTap: () {
                                    Navigator.pop(dialogCtx);
                                    onSelect(p);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    _openNewPatientModal();
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New Patient'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // TOP "+ NEW" ACTION BUTTON & FLUSH DROPDOWN MENU (CONNECTED SEAMLESSLY)
  // =========================================================================
  Widget _buildNewActionsDropdownButton() {
    return PopupMenuButton<String>(
      tooltip: 'Create New Patient, Examination, or Prescription',
      offset: const Offset(0, 52), // Placed flush directly attached under the 54px button
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.zero, // Zero gap connection with top button
          topRight: Radius.zero,
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        side: BorderSide(color: Color(0xFF1D4ED8), width: 1.5),
      ),
      elevation: 12,
      color: Colors.white,
      constraints: const BoxConstraints(
        minWidth: 260,
        maxWidth: 260,
      ),
      onSelected: (action) {
        if (action == 'new_patient') {
          _openNewPatientModal();
        } else if (action == 'new_exam') {
          _openPatientSelectorForExam();
        } else if (action == 'new_rx') {
          _openPatientSelectorForPrescription();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'new_patient',
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_add_rounded, color: Color(0xFF10B981), size: 18),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('New Patient', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
                  Text('Register new clinical record', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<String>(
          value: 'new_exam',
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.draw_rounded, color: AppTheme.primaryBlue, size: 18),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('New Examination', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
                  Text('Open consultation sheet', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<String>(
          value: 'new_rx',
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.medication_rounded, color: Color(0xFF0284C7), size: 18),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('New Prescription', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
                  Text('Write digital Rx for patient', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            ],
          ),
        ),
      ],
      child: Container(
        height: 54,
        width: 260,
        decoration: BoxDecoration(
          color: AppTheme.primaryBlue,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryBlue.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Stack(
          alignment: Alignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Doctor Greeting Header
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good morning, Dr. Sigrid Robillos, MD',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary, letterSpacing: -0.5),
              ),
              SizedBox(height: 4),
              Text(
                'Manage patient records, review examination history, and create digital prescriptions.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 2. Today's Patient Queue Overview (Left) & Clinical Calendar with Date/Time (Right)
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 960;
              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTodayQueueCard(isNarrow: true),
                    const SizedBox(height: 16),
                    _buildMiniCalendarCard(isNarrow: true),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildTodayQueueCard(isNarrow: false)),
                  const SizedBox(width: 20),
                  _buildMiniCalendarCard(isNarrow: false),
                ],
              );
            },
          ),
          const SizedBox(height: 28),

          // 3. Search Bar Box + Dropdown Suggestions (Directly on top of Clinical Patient Records)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: _isSearching && _searchController.text.trim().isNotEmpty
                            ? const BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28))
                            : BorderRadius.circular(28),
                        border: Border.all(color: AppTheme.borderColor),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(Icons.search, color: AppTheme.primaryBlue, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: _onSearchChanged,
                              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                              decoration: const InputDecoration(
                                hintText: 'Search patient by name, patient ID (MRN), or date of birth...',
                                hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
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
                              icon: const Icon(Icons.close, size: 18, color: AppTheme.textSecondary),
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
                  const SizedBox(width: 14),
                  _buildNewActionsDropdownButton(),
                ],
              ),

              // Floating/Flush Dropdown of Patient Names attached below the Search Bar
              if (_isSearching && _searchController.text.trim().isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
                    border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 16,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'PATIENTS FOUND (${_searchSuggestions.length})',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                              child: const Text(
                                'Close',
                                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 8),
                      if (_searchSuggestions.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, size: 16, color: Color(0xFFE11D48)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'No patient matching "${_searchController.text}" found in database.',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                  _openNewPatientModal();
                                },
                                icon: const Icon(Icons.add, size: 14),
                                label: const Text('Register New Patient', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        )
                      else
                        ..._searchSuggestions.map((patient) {
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                _searchController.clear();
                                _onSearchChanged('');
                                if (widget.onSelectPatient != null) {
                                  widget.onSelectPatient!(patient);
                                }
                              },
                              borderRadius: BorderRadius.circular(8),
                              hoverColor: AppTheme.primaryBlue.withValues(alpha: 0.05),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                      child: Text(
                                        patient.fullName.isNotEmpty ? patient.fullName[0].toUpperCase() : 'P',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            patient.fullName,
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${patient.mrn} • ${patient.gender}, ${patient.age} yrs • ${patient.phone}',
                                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.folder_shared_outlined, size: 12, color: AppTheme.primaryBlue),
                                          SizedBox(width: 4),
                                          Text('View Records', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // 4. Patient Records Grid Header (Always visible and intact)
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Clinical Patient Records (${_allPatients.length})',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const Text(
                'Access clinical history or launch digital eye examination',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _allPatients.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('No patient records in database.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14))),
                )
              : _buildPatientGrid(),
        ],
      ),
    );
  }

  Widget _buildPatientGrid() {
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
          itemCount: _allPatients.length,
          itemBuilder: (context, index) {
            final patient = _allPatients[index];
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
                            onPressed: () {
                              if (widget.onSelectPatient != null) {
                                widget.onSelectPatient!(patient);
                              }
                            },
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
            } else if (widget.onSelectPatient != null) {
              widget.onSelectPatient!(patient);
            }
            break;
          case 'rx':
            if (widget.onOpenPrescription != null) {
              widget.onOpenPrescription!(patient);
            } else if (widget.onSelectPatient != null) {
              widget.onSelectPatient!(patient);
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

  // =========================================================================
  // CLINICAL MINI-CALENDAR CARD (NON-INTERACTIVE OVERVIEW)
  // =========================================================================
  Widget _buildMiniCalendarCard({bool isNarrow = false}) {
    final now = DateTime.now();
    final currentMonthName = _getMonthName(now.month);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final firstWeekday = DateTime(now.year, now.month, 1).weekday % 7; // 0 for Sun

    const weekdays = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

    final weekRows = <Widget>[];
    for (int week = 0; week < 5; week++) {
      final dayCells = <Widget>[];
      for (int day = 0; day < 7; day++) {
        final index = week * 7 + day;
        final dayNumber = index - firstWeekday + 1;
        if (dayNumber < 1 || dayNumber > daysInMonth) {
          dayCells.add(const Expanded(child: SizedBox(height: 28)));
        } else {
          final isToday = dayNumber == now.day;
          final hasAppointments = [2, 10, 21, 24, 30].contains(dayNumber);

          dayCells.add(
            Expanded(
              child: Container(
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isToday ? AppTheme.primaryBlue : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      '$dayNumber',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                        color: isToday ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                    if (hasAppointments && !isToday)
                      Positioned(
                        bottom: 1,
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: AppTheme.primaryBlue,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }
      }
      weekRows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: dayCells,
          ),
        ),
      );
    }

    return Container(
      width: isNarrow ? double.infinity : 360,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // STACKED DATE & TIME HEADER (Right on top of the Calendar)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time_filled_rounded, color: AppTheme.primaryBlue, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      _currentTime.isNotEmpty ? _currentTime : '11:45 AM',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontSize: 13),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_rounded, color: AppTheme.primaryBlue, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        formatClinicalDate(now.toString().substring(0, 10)),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // CALENDAR BODY
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$currentMonthName ${now.year}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                    ),
                    const Text(
                      'Clinic Calendar',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Weekday headers
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: weekdays.map((w) {
                    final isWeekend = w == 'Su' || w == 'Sa';
                    return Expanded(
                      child: Text(
                        w,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isWeekend ? const Color(0xFFEF4444) : AppTheme.textSecondary,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 6),

                // Days grid (5 rows)
                ...weekRows,
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TODAY'S PATIENT SCHEDULE / QUEUE CARD
  // =========================================================================
  Widget _buildTodayQueueCard({bool isNarrow = false}) {
    final queue = PatientRepository.getTodayQueue();
    return Container(
      width: isNarrow ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.people_alt_rounded, color: AppTheme.primaryBlue, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Today's Patient Queue & Consultations",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${queue.length} Scheduled',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...queue.map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.time,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.patient.fullName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                        ),
                        Text(
                          '${item.visitType} • ${item.patient.gender}, ${item.patient.age}y',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      if (widget.onStartExam != null) {
                        widget.onStartExam!(item.patient);
                      } else if (widget.onSelectPatient != null) {
                        widget.onSelectPatient!(item.patient);
                      }
                    },
                    icon: const Icon(Icons.draw, size: 12),
                    label: const Text('Start Exam', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      side: const BorderSide(color: AppTheme.primaryBlue),
                      foregroundColor: AppTheme.primaryBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
