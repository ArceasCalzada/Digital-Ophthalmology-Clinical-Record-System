import 'package:flutter/material.dart';
import '../models/patient.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'patients_screen.dart';
import 'patient_profile_view.dart';
import 'eye_exam_view.dart';
import 'prescription_view.dart';
import 'settings_view.dart';

class MainLayout extends StatefulWidget {
  final VoidCallback onLogout;

  const MainLayout({super.key, required this.onLogout});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  Patient? _selectedPatient;
  bool _isExamMode = false;
  bool _isSidebarCollapsed = false;
  bool _isPatientsMenuExpanded = true;
  final _searchController = TextEditingController();

  void _navigateToPatientProfile(Patient patient) {
    setState(() {
      _selectedPatient = patient;
      _isExamMode = false;
      _isPatientsMenuExpanded = true;
      _selectedIndex = 1; // Patients tab
    });
  }

  void _startExamForPatient(Patient? patient) {
    setState(() {
      _selectedPatient = patient;
      _isExamMode = true;
      _isPatientsMenuExpanded = true;
      _selectedIndex = 2; // Examinations tab
    });
  }

  void _openPrescriptionForPatient(Patient patient) {
    setState(() {
      _selectedPatient = patient;
      _isExamMode = false;
      _isPatientsMenuExpanded = true;
      _selectedIndex = 3; // Prescriptions tab
    });
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarCollapsed = !_isSidebarCollapsed;
    });
  }

  void _showMobileSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Search Patient Record', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: _searchController,
          autofocus: true,
          onSubmitted: (query) {
            if (query.trim().isNotEmpty) {
              final results = PatientRepository.searchPatients(query);
              if (results.isNotEmpty) {
                Navigator.pop(context);
                _navigateToPatientProfile(results.first);
              }
            }
          },
          decoration: const InputDecoration(
            hintText: 'Enter patient name, MRN, or DOB...',
            prefixIcon: Icon(Icons.search, color: AppTheme.primaryBlue),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final query = _searchController.text.trim();
              if (query.isNotEmpty) {
                final results = PatientRepository.searchPatients(query);
                if (results.isNotEmpty) {
                  Navigator.pop(context);
                  _navigateToPatientProfile(results.first);
                }
              }
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isExamMode && _selectedPatient != null && _selectedIndex == 2) {
      return EyeExamView(
        patient: _selectedPatient,
        onExamComplete: (completedPatient) {
          setState(() {
            _selectedPatient = completedPatient;
            _isExamMode = false;
            _selectedIndex = 1; // Return to Patient Profile
          });
        },
      );
    }

    switch (_selectedIndex) {
      case 0:
        return DashboardScreen(
          onSelectPatient: _navigateToPatientProfile,
          onStartExam: _startExamForPatient,
          onOpenPrescription: _openPrescriptionForPatient,
        );
      case 1:
        if (_selectedPatient != null) {
          return PatientProfileView(
            patientId: _selectedPatient!.id,
            onBack: () => setState(() => _selectedPatient = null),
            onStartNewExam: () {
              setState(() => _isExamMode = true);
            },
          );
        }
        return PatientsScreen(
          onSelectPatient: _navigateToPatientProfile,
          onStartExam: _startExamForPatient,
          onOpenPrescription: _openPrescriptionForPatient,
        );
      case 2:
        return EyeExamView(
          patient: _selectedPatient,
          onExamComplete: (completedPatient) {
            setState(() {
              _selectedPatient = completedPatient;
              _isExamMode = false;
              _selectedIndex = 1;
            });
          },
        );
      case 3:
        return PrescriptionView(
          initialPatient: _selectedPatient,
        );
      case 4:
        return const SettingsView();
      default:
        return DashboardScreen(
          onSelectPatient: _navigateToPatientProfile,
          onStartExam: _startExamForPatient,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;

        return Scaffold(
          backgroundColor: AppTheme.lightBg,
          appBar: isMobile
              ? AppBar(
                  backgroundColor: AppTheme.cardBg,
                  elevation: 0.5,
                  iconTheme: const IconThemeData(color: AppTheme.textPrimary),
                  title: const Row(
                    children: [
                      Icon(Icons.remove_red_eye, color: AppTheme.primaryBlue, size: 22),
                      SizedBox(width: 8),
                      Text('DOCRS', style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 0.5)),
                    ],
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.search, color: AppTheme.primaryBlue),
                      tooltip: 'Search Patient',
                      onPressed: () => _showMobileSearchDialog(context),
                    ),
                    IconButton(
                      icon: const Icon(Icons.notifications_none, color: AppTheme.textSecondary),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No unread clinical alerts.')),
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                  ],
                )
              : null,
          body: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMobile)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      height: constraints.maxHeight,
                      width: _isSidebarCollapsed ? 72 : 240,
                      decoration: const BoxDecoration(
                        color: AppTheme.cardBg,
                        border: Border(right: BorderSide(color: AppTheme.borderColor)),
                      ),
                      child: _buildSidebarContent(isDrawer: false),
                    ),

                  // Main Workspace Area (Anchored to the very top)
                  Expanded(
                    child: SizedBox(
                      height: constraints.maxHeight,
                      child: _buildBody(),
                    ),
                  ),
                ],
              ),

              // Floating Sidebar Toggle (Vertically centered along the sidebar edge)
              if (!isMobile)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  left: (_isSidebarCollapsed ? 72 : 240) - 14,
                  top: (constraints.maxHeight / 2) - 15,
                  child: Tooltip(
                    message: _isSidebarCollapsed ? 'Expand Sidebar' : 'Collapse Sidebar',
                    child: Material(
                      color: Colors.white,
                      elevation: 4,
                      shape: const CircleBorder(
                        side: BorderSide(color: AppTheme.borderColor, width: 1.2),
                      ),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _toggleSidebar,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            _isSidebarCollapsed ? Icons.chevron_right : Icons.chevron_left,
                            color: AppTheme.primaryBlue,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidebarContent({bool isDrawer = false}) {
    final collapsed = isDrawer ? false : _isSidebarCollapsed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // DOCRS Branding Header
        Padding(
          padding: EdgeInsets.all(collapsed ? 12 : 16),
          child: Row(
            mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              InkWell(
                onTap: collapsed ? _toggleSidebar : null,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.remove_red_eye, color: AppTheme.primaryBlue, size: 24),
                ),
              ),
              if (!collapsed) ...[
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('DOCRS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryBlue, letterSpacing: 0.5)),
                      Text('Clinical Record System', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.menu_open, color: AppTheme.primaryBlue, size: 20),
                  tooltip: 'Collapse Sidebar',
                  onPressed: _toggleSidebar,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ],
          ),
        ),

        const Divider(height: 1, color: AppTheme.borderColor),
        const SizedBox(height: 12),

        // Navigation Links:
        _buildNavItem(0, Icons.dashboard_outlined, Icons.dashboard, 'Dashboard', isDrawer: isDrawer),

        const SizedBox(height: 14),

        // Patients Section Group (Direct access, clearly labeled under Patients)
        if (!collapsed)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Icon(Icons.people_alt_outlined, size: 14, color: AppTheme.primaryBlue),
                SizedBox(width: 6),
                Text(
                  'PATIENTS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ],
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Divider(height: 1, color: AppTheme.borderColor),
          ),

        _buildNavItem(1, Icons.folder_shared_outlined, Icons.folder_shared, 'Records', isDrawer: isDrawer),
        _buildNavItem(2, Icons.assignment_outlined, Icons.assignment, 'Examinations', isDrawer: isDrawer),
        _buildNavItem(3, Icons.local_pharmacy_outlined, Icons.local_pharmacy, 'Prescriptions', isDrawer: isDrawer),

        // Active Patient Context Pill (if a patient is currently active)
        if (_selectedPatient != null && !collapsed)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_circle, size: 16, color: AppTheme.primaryBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedPatient!.fullName,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${_selectedPatient!.mrn} • ${_selectedPatient!.gender}, ${_selectedPatient!.age}y',
                        style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () {
                    setState(() {
                      _selectedPatient = null;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.close, size: 14, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
          ),

        // Spacer pushes Settings and Doctor info down to the very bottom
        const Spacer(),

        const Divider(height: 1, color: AppTheme.borderColor),
        const SizedBox(height: 4),

        // Settings - Fixed to the very, very bottom
        _buildNavItem(4, Icons.settings_outlined, Icons.settings, 'Settings', isDrawer: isDrawer),

        const SizedBox(height: 4),
        const Divider(height: 1, color: AppTheme.borderColor),

        // Doctor Info
        Padding(
          padding: EdgeInsets.all(collapsed ? 10 : 16),
          child: Row(
            mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                child: const Text('SR', style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              if (!collapsed) ...[
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dr. Sigrid Robillos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis),
                      Text('Ophthalmologist', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }



  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String title, {bool isDrawer = false}) {
    final isSelected = _selectedIndex == index;
    final collapsed = isDrawer ? false : _isSidebarCollapsed;

    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Tooltip(
            message: title,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                setState(() => _selectedIndex = index);
                if (isDrawer) Navigator.pop(context);
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryBlue.withValues(alpha: 0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isSelected ? activeIcon : icon,
                  color: isSelected ? AppTheme.primaryBlue : AppTheme.textSecondary,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: ListTile(
          dense: true,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          selected: isSelected,
          selectedTileColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
          leading: Icon(
            isSelected ? activeIcon : icon,
            color: isSelected ? AppTheme.primaryBlue : AppTheme.textSecondary,
            size: 20,
          ),
          title: Text(
            title,
            style: TextStyle(
              color: isSelected ? AppTheme.primaryBlue : AppTheme.textPrimary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 14,
            ),
          ),
          onTap: () {
            setState(() {
              _selectedIndex = index;
            });
            if (isDrawer) Navigator.pop(context);
          },
        ),
      ),
    );
  }
}
