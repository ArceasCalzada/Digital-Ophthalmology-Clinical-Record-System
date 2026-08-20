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
  final _searchController = TextEditingController();

  void _navigateToPatientProfile(Patient patient) {
    setState(() {
      _selectedPatient = patient;
      _isExamMode = false;
      _selectedIndex = 1; // Patients tab
    });
  }

  void _startExamForPatient(Patient patient) {
    setState(() {
      _selectedPatient = patient;
      _isExamMode = true;
      _selectedIndex = 2; // Examinations tab
    });
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarCollapsed = !_isSidebarCollapsed;
    });
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
                  elevation: 0,
                  iconTheme: const IconThemeData(color: AppTheme.textPrimary),
                  title: const Row(
                    children: [
                      Icon(Icons.remove_red_eye, color: AppTheme.primaryBlue, size: 22),
                      SizedBox(width: 8),
                      Text('DOCRS Workstation', style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                )
              : null,
          drawer: isMobile ? Drawer(child: _buildSidebarContent(isDrawer: true)) : null,
          body: Row(
            children: [
              if (!isMobile)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  width: _isSidebarCollapsed ? 72 : 240,
                  decoration: const BoxDecoration(
                    color: AppTheme.cardBg,
                    border: Border(right: BorderSide(color: AppTheme.borderColor)),
                  ),
                  child: _buildSidebarContent(isDrawer: false),
                ),

              // Main Workspace Area
              Expanded(
                child: Column(
                  children: [
                    if (!isMobile)
                      Container(
                        height: 64,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        decoration: const BoxDecoration(
                          color: AppTheme.cardBg,
                          border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
                        ),
                  child: Row(
                    children: [
                      // Sidebar Toggle Button
                      IconButton(
                        icon: Icon(_isSidebarCollapsed ? Icons.menu : Icons.menu_open, color: AppTheme.primaryBlue),
                        tooltip: _isSidebarCollapsed ? 'Expand Navigation Sidebar' : 'Collapse Navigation Sidebar',
                        onPressed: _toggleSidebar,
                      ),
                      const SizedBox(width: 12),

                      // Global Quick Search
                      Expanded(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 480),
                          height: 40,
                          child: TextField(
                            controller: _searchController,
                            onSubmitted: (query) {
                              if (query.trim().isNotEmpty) {
                                final results = PatientRepository.searchPatients(query);
                                if (results.isNotEmpty) {
                                  _navigateToPatientProfile(results.first);
                                }
                              }
                            },
                            style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                            decoration: const InputDecoration(
                              hintText: 'Search patient by name, ID, or DOB...',
                              prefixIcon: Icon(Icons.search, size: 18, color: AppTheme.primaryBlue),
                              contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Notifications Bell
                      IconButton(
                        icon: const Icon(Icons.notifications_none, color: AppTheme.textSecondary),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('No unread clinical alerts.')),
                          );
                        },
                      ),
                      const SizedBox(width: 8),

                      // Doctor Profile Quick Chip
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.local_hospital, size: 16, color: AppTheme.primaryBlue),
                              SizedBox(width: 8),
                              Flexible(
                                child: Text('Metro Eye Center • Room 402', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Content Display
                Expanded(
                  child: _buildBody(),
                ),
              ],
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
        // DOCRS Branding Header & Collapse Toggle
        Padding(
          padding: EdgeInsets.all(collapsed ? 12 : 16),
          child: Row(
            mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.remove_red_eye, color: AppTheme.primaryBlue, size: 24),
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
              ],
              if (!isDrawer)
                IconButton(
                  icon: Icon(collapsed ? Icons.chevron_right : Icons.chevron_left, color: AppTheme.textSecondary, size: 20),
                  tooltip: collapsed ? 'Expand Sidebar' : 'Collapse Sidebar',
                  onPressed: _toggleSidebar,
                ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppTheme.borderColor),
        const SizedBox(height: 12),

        // Navigation Links (Expanded or Icon-Only when Collapsed)
        _buildNavItem(0, Icons.dashboard_outlined, Icons.dashboard, 'Dashboard', isDrawer: isDrawer),
        _buildNavItem(1, Icons.people_outline, Icons.people, 'Patients', isDrawer: isDrawer),
        _buildNavItem(2, Icons.assignment_outlined, Icons.assignment, 'Examinations', isDrawer: isDrawer),
        _buildNavItem(3, Icons.local_pharmacy_outlined, Icons.local_pharmacy, 'Prescriptions', isDrawer: isDrawer),
        _buildNavItem(4, Icons.settings_outlined, Icons.settings, 'Settings', isDrawer: isDrawer),

        const Spacer(),
        const Divider(height: 1, color: AppTheme.borderColor),

        // Workstation Status & Doctor Info
        Padding(
          padding: EdgeInsets.all(collapsed ? 10 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  const Icon(Icons.circle, color: Color(0xFF059669), size: 8),
                  if (!collapsed) ...[
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text('Workstation Online', style: TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    child: const Text('SJ', style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  if (!collapsed) ...[
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Dr. Sarah Jenkins', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis),
                          Text('Ophthalmologist', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout, size: 18, color: AppTheme.textSecondary),
                      tooltip: 'Logout',
                      onPressed: widget.onLogout,
                    ),
                  ],
                ],
              ),
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
