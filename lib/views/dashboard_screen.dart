import '../widgets/clinic_dialogs.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/calendar_event.dart';
import '../models/patient.dart';
import '../services/profile_store.dart';
import '../theme/app_theme.dart';
import '../widgets/clinical_modal_picker.dart';
import '../widgets/page_header.dart';
import 'new_patient_modal.dart';
import 'patient_profile_view.dart';

class DashboardScreen extends StatefulWidget {
  final Function(Patient)? onSelectPatient;
  final Function(Patient?)? onStartExam;
  final Function(Patient)? onOpenPrescription;
  /// Opens the calendar page. [date] is the day to select, or null to open it as-is.
  final ValueChanged<DateTime?>? onOpenCalendar;

  const DashboardScreen({
    super.key,
    this.onSelectPatient,
    this.onStartExam,
    this.onOpenPrescription,
    this.onOpenCalendar,
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
    PatientRepository.changeNotifier.addListener(_loadDashboardData);
    CalendarEventRepository().addListener(_loadDashboardData);
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _updateClock();
    });
  }

  @override
  void dispose() {
    PatientRepository.changeNotifier.removeListener(_loadDashboardData);
    CalendarEventRepository().removeListener(_loadDashboardData);
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

  Future<void> _openNewPatientModal() async {
    if (!await ensureClinic(context) || !mounted) return;
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
                        hintText: 'Search by patient name or phone...',
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
                              separatorBuilder: (_, _) => const Divider(height: 1),
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
                                  subtitle: Text('${p.mrn} â€¢ ${p.gender}, ${p.age} yrs â€¢ ${p.phone}', style: const TextStyle(fontSize: 12)),
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
  Widget _buildNewActionsDropdownButton({double? width}) {
    return InkWell(
      onTap: () {
        showClinicalActionModal(
          context: context,
          title: 'Create New Record',
          subtitle: 'Choose an action to create a clinical entry',
          actions: [
            ClinicalActionItem(
              id: 'new_patient',
              title: 'New Patient',
              subtitle: 'Register a new patient record in the system',
              icon: Icons.person_add_rounded,
              color: const Color(0xFF10B981),
              onTap: _openNewPatientModal,
            ),
            ClinicalActionItem(
              id: 'new_exam',
              title: 'New Examination',
              subtitle: 'Open clinical consultation paper sheet',
              icon: Icons.draw_rounded,
              color: AppTheme.primaryBlue,
              onTap: _openPatientSelectorForExam,
            ),
            ClinicalActionItem(
              id: 'new_rx',
              title: 'New Prescription',
              subtitle: 'Write digital prescription (Rx) for patient',
              icon: Icons.medication_rounded,
              color: const Color(0xFF0284C7),
              onTap: _openPatientSelectorForPrescription,
            ),
          ],
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 54,
        width: width ?? 260,
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
        child: const Row(
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(PageHeader.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Doctor Greeting Header
          ListenableBuilder(
            listenable: ProfileStore.instance,
            builder: (context, _) {
              final rawName = ProfileStore.instance.doctorName.text.trim();
              final name = rawName.isNotEmpty ? rawName : 'Dr. Sigrid Robillos, MD';
              return PageHeader(
                title: 'Good morning, $name',
                subtitle: 'Manage patient records, review examination history, and create digital prescriptions.',
              );
            },
          ),

          // 2. Today's Patient Queue Overview (Left) & Clinical Calendar with Date/Time (Right)
          // Both cards read the calendar's events, so they refresh when one is added or changed.
          ListenableBuilder(
            listenable: CalendarEventRepository(),
            builder: (context, _) => LayoutBuilder(
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

                // Wide: the queue card is as tall as the calendar and its list scrolls
                // inside, so a long queue never stretches the calendar.
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _buildTodayQueueCard(isNarrow: false)),
                      const SizedBox(width: 20),
                      _buildMiniCalendarCard(isNarrow: false),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 28),

          // 3. Search Bar Box + Dropdown Suggestions (Directly on top of Clinical Patient Records)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;

                  final searchBarContainer = Container(
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
                              hintText: 'Search patient by name or phone...',
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
                            icon: const Icon(Icons.close, size: 18, color: AppTheme.textSecondary),
                            tooltip: 'Clear search',
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          ),
                      ],
                    ),
                  );

                  if (isMobile) {
                    return Column(
                      children: [
                        searchBarContainer,
                        const SizedBox(height: 12),
                        _buildNewActionsDropdownButton(width: double.infinity),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: searchBarContainer),
                      const SizedBox(width: 14),
                      _buildNewActionsDropdownButton(),
                    ],
                  );
                },
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
                                            '${patient.mrn} â€¢ ${patient.gender}, ${patient.age} yrs â€¢ ${patient.phone}',
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
          const Text(
            'Clinical Patient Records',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
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
                                '${patient.mrn} â€¢ ${patient.gender}, ${patient.age}y',
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
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PatientProfileView(patientId: patient.id),
                                  ),
                                );
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
    return InkWell(
      onTap: () {
        showClinicalActionModal(
          context: context,
          title: 'Action for ${patient.fullName}',
          subtitle: 'MRN: ${patient.mrn} â€¢ ${patient.age} yrs, ${patient.gender}',
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
                } else if (widget.onSelectPatient != null) {
                  widget.onSelectPatient!(patient);
                }
              },
            ),
            ClinicalActionItem(
              id: 'rx',
              title: 'New Prescription (Rx)',
              subtitle: 'Write digital prescription for ${patient.fullName}',
              icon: Icons.medication_rounded,
              color: const Color(0xFF0284C7),
              onTap: () {
                if (widget.onOpenPrescription != null) {
                  widget.onOpenPrescription!(patient);
                } else if (widget.onSelectPatient != null) {
                  widget.onSelectPatient!(patient);
                }
              },
            ),
          ],
        );
      },
      borderRadius: BorderRadius.circular(8),
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
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // CLINICAL MINI-CALENDAR CARD (TAP TO OPEN THE CALENDAR PAGE)
  // =========================================================================
  Widget _buildMiniCalendarCard({bool isNarrow = false}) {
    final onOpenCalendar = widget.onOpenCalendar;
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final firstWeekday = DateTime(now.year, now.month, 1).weekday % 7; // 0 for Sun

    // Days of this month that have at least one calendar event.
    final daysWithEvents = {
      for (final e in CalendarEventRepository().events)
        if (e.dateTime.year == now.year && e.dateTime.month == now.month) e.dateTime.day,
    };

    const weekdays = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];
    // Time and date share one style in the calendar header.
    const headerTextStyle = TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontSize: 13);

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
          final hasAppointments = daysWithEvents.contains(dayNumber);
          final date = DateTime(now.year, now.month, dayNumber);

          dayCells.add(
            Expanded(
              child: Center(
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child: Material(
                    color: isToday ? AppTheme.primaryBlue : Colors.transparent,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      key: Key('dashboard_calendar_day_$dayNumber'),
                      customBorder: const CircleBorder(),
                      hoverColor: AppTheme.primaryBlue.withValues(alpha: isToday ? 0.25 : 0.12),
                      onTap: onOpenCalendar == null ? null : () => onOpenCalendar(date),
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
                          // Blue dot under the number when the day has an event or reminder.
                          if (hasAppointments)
                            Positioned(
                              bottom: 3,
                              child: Container(
                                key: const Key('dashboard_calendar_dot'),
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: isToday ? Colors.white : AppTheme.primaryBlue,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
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

    // Clicking the header opens the calendar as-is; clicking a day opens it on that day.
    final header = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      // No fill of its own: the Material below paints it, so the hover ripple shows.
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              formatClinicalDate(now.toString().substring(0, 10)),
              style: headerTextStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _currentTime.isNotEmpty ? _currentTime : '11:45 AM',
            style: headerTextStyle,
          ),
        ],
      ),
    );
    const headerShape = RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16)));
    final headerButton = Material(
      color: const Color(0xFFF8FAFC),
      shape: headerShape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('dashboard_mini_calendar_header'),
        onTap: onOpenCalendar == null ? null : () => onOpenCalendar(null),
        child: header,
      ),
    );

    final card = Container(
      key: const Key('dashboard_mini_calendar_body'),
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
          if (onOpenCalendar == null)
            headerButton
          else
            Tooltip(message: 'Open calendar', child: headerButton),

          // CALENDAR BODY
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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

    return card;
  }

  // =========================================================================
  // TODAY'S PATIENT SCHEDULE / QUEUE CARD
  // =========================================================================
  Widget _buildTodayQueueCard({bool isNarrow = false}) {
    final queue = CalendarEventRepository().getEventsForDay(DateTime.now());
    final queueItems = _buildQueueItems(queue);
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
          // Named "Schedules" (not "Patient Queue") because it will hold more than patient visits.
          const Text(
            'Schedules',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          if (isNarrow)
            ...queueItems
          else
            // The Stack + Positioned.fill contributes no height of its own, so the
            // card takes the calendar's height and the list scrolls within it.
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: queue.isEmpty
                        ? const Center(
                            child: Text(
                              'Nothing scheduled for today',
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          )
                        : ListView(padding: EdgeInsets.zero, children: queueItems),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildQueueItems(List<CalendarEvent> events) {
    return [
      for (final event in events)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: const Color(0xFFF8FAFC),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: InkWell(
              key: Key('schedule_event_${event.id}'),
              borderRadius: BorderRadius.circular(10),
              onTap: widget.onOpenCalendar == null ? null : () => widget.onOpenCalendar!(event.dateTime),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        TimeOfDay.fromDateTime(event.dateTime).format(context),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.patientName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppTheme.textPrimary,
                              decoration: event.isCompleted ? TextDecoration.lineThrough : null,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${event.title} • ${event.location}',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (event.isCompleted)
                      const Icon(Icons.check_circle, size: 16, color: Color(0xFF10B981)),
                  ],
                ),
              ),
            ),
          ),
        ),
    ];
  }
}
