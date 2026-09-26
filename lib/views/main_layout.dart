import 'package:flutter/material.dart';
import '../models/clinical_notification.dart';
import '../models/patient.dart';
import '../theme/app_theme.dart';
import '../widgets/add_event_modal.dart';
import '../widgets/sync_status_indicator.dart';
import 'calendar_page_view.dart';
import 'dashboard_screen.dart';
import 'eye_exam_view.dart';
import 'notification_center_view.dart';
import 'patient_profile_view.dart';
import 'patients_screen.dart';
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
  int _mobileTabIndex = 0; // 0: Calendar, 1: Agenda, 2: Alerts, 3: Records/Menu
  Patient? _selectedPatient;
  bool _isExamMode = false;
  bool _isSidebarCollapsed = false;
  final _searchController = TextEditingController();

  void _navigateToPatientProfile(Patient patient) {
    setState(() {
      _selectedPatient = patient;
      _isExamMode = false;
      _selectedIndex = 2; // Desktop Patients/Records tab
      _mobileTabIndex = 3; // Mobile Records tab
    });
  }

  void _startExamForPatient(Patient? patient, {bool isMobileScreen = false}) {
    if (isMobileScreen) {
      _showMobileExamNotice();
      return;
    }
    setState(() {
      _selectedPatient = patient;
      _isExamMode = true;
      _selectedIndex = 3; // Desktop Examinations tab
    });
  }

  void _openPrescriptionForPatient(Patient patient, {bool isMobileScreen = false}) {
    if (isMobileScreen) {
      _showMobileExamNotice(title: 'Prescription Generator Disabled on Mobile');
      return;
    }
    setState(() {
      _selectedPatient = patient;
      _isExamMode = false;
      _selectedIndex = 4; // Desktop Prescriptions tab
    });
  }

  void _showMobileExamNotice({String title = 'Clinical Exam Disabled on Mobile'}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFD97706).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.important_devices_rounded, color: Color(0xFFD97706), size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Text(
          'Comprehensive ocular drawing and clinical examination modules are optimized for tablet and desktop workstations.\n\nMobile view focuses on Calendar scheduling, Agenda queue management, and Clinical Notifications.',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Understand'),
          ),
        ],
      ),
    );
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
            hintText: 'Enter patient name, MRN, or phone...',
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

  void _showNotificationCenterModal(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    if (isMobile) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          height: MediaQuery.of(ctx).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: const ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            child: NotificationCenterView(),
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
            child: const NotificationCenterView(),
          ),
        ),
      );
    }
  }

  Widget _buildDesktopBody() {
    if (_isExamMode && _selectedPatient != null && _selectedIndex == 3) {
      return EyeExamView(
        patient: _selectedPatient,
        onExamComplete: (completedPatient) {
          setState(() {
            _selectedPatient = completedPatient;
            _isExamMode = false;
            _selectedIndex = 2;
          });
        },
      );
    }

    switch (_selectedIndex) {
      case 0:
        return DashboardScreen(
          onSelectPatient: _navigateToPatientProfile,
          onStartExam: (p) => _startExamForPatient(p, isMobileScreen: false),
          onOpenPrescription: (p) => _openPrescriptionForPatient(p, isMobileScreen: false),
        );
      case 1:
        return CalendarPageView(
          onSelectPatient: _navigateToPatientProfile,
        );
      case 2:
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
          onStartExam: (p) => _startExamForPatient(p, isMobileScreen: false),
          onOpenPrescription: (p) => _openPrescriptionForPatient(p, isMobileScreen: false),
        );
      case 3:
        return EyeExamView(
          patient: _selectedPatient,
          onExamComplete: (completedPatient) {
            setState(() {
              _selectedPatient = completedPatient;
              _isExamMode = false;
              _selectedIndex = 2;
            });
          },
        );
      case 4:
        return PrescriptionView(
          initialPatient: _selectedPatient,
        );
      case 5:
        return const SettingsView();
      default:
        return DashboardScreen(
          onSelectPatient: _navigateToPatientProfile,
          onStartExam: (p) => _startExamForPatient(p, isMobileScreen: false),
        );
    }
  }

  Widget _buildMobileBody() {
    switch (_mobileTabIndex) {
      case 0:
        return CalendarPageView(
          onSelectPatient: _navigateToPatientProfile,
        );
      case 1:
        return _buildMobileAgendaTab();
      case 2:
        return const NotificationCenterView();
      case 3:
      default:
        if (_selectedPatient != null) {
          return PatientProfileView(
            patientId: _selectedPatient!.id,
            onBack: () => setState(() => _selectedPatient = null),
            onStartNewExam: () => _showMobileExamNotice(),
          );
        }
        return PatientsScreen(
          onSelectPatient: _navigateToPatientProfile,
          onStartExam: (p) => _showMobileExamNotice(),
          onOpenPrescription: (p) => _showMobileExamNotice(title: 'Prescriptions Disabled on Mobile'),
        );
    }
  }



  Widget _buildMobileAgendaTab() {
    final queue = PatientRepository.getTodayQueue();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Today's Clinic Agenda",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${queue.length} Consultations',
                  style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: queue.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, idx) {
              final item = queue[idx];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.borderColor),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.time,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.visitType,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                          child: Text(
                            item.patient.fullName.isNotEmpty ? item.patient.fullName[0].toUpperCase() : 'P',
                            style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.patient.fullName,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                              ),
                              Text(
                                '${item.patient.mrn} • ${item.patient.gender}, ${item.patient.age} yrs',
                                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Calling ${item.patient.phone}...')),
                              );
                            },
                            icon: const Icon(Icons.phone, size: 14),
                            label: const Text('Call Patient', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _navigateToPatientProfile(item.patient),
                            icon: const Icon(Icons.folder_shared, size: 14),
                            label: const Text('View Record', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlue,
                              foregroundColor: Colors.white,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Scaffold(
          backgroundColor: AppTheme.lightBg,
          appBar: isMobile
              ? AppBar(
                  backgroundColor: AppTheme.cardBg,
                  elevation: 0.5,
                  title: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.remove_red_eye, color: AppTheme.primaryBlue, size: 20),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'DOCRS',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Center(child: SyncStatusIndicator(compact: true)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primaryBlue),
                      tooltip: 'Add Event',
                      onPressed: () => AddEventModal.show(context),
                    ),
                    IconButton(
                      icon: const Icon(Icons.search, color: AppTheme.textPrimary),
                      tooltip: 'Search Patient',
                      onPressed: () => _showMobileSearchDialog(context),
                    ),
                  ],
                )
              : null,
          body: isMobile
              ? _buildMobileBody()
              : Stack(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                        Expanded(
                          child: SizedBox(
                            height: constraints.maxHeight,
                            child: _buildDesktopBody(),
                          ),
                        ),
                      ],
                    ),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      left: (_isSidebarCollapsed ? 72 : 240) - 14,
                      top: (constraints.maxHeight / 2) - 15,
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
                  ],
                ),
          bottomNavigationBar: isMobile
              ? ListenableBuilder(
                  listenable: ClinicalNotificationRepository(),
                  builder: (context, child) {
                    final unread = ClinicalNotificationRepository().unreadCount;

                    return BottomNavigationBar(
                      currentIndex: _mobileTabIndex,
                      onTap: (index) => setState(() => _mobileTabIndex = index),
                      type: BottomNavigationBarType.fixed,
                      selectedItemColor: AppTheme.primaryBlue,
                      unselectedItemColor: AppTheme.textSecondary,
                      selectedFontSize: 11,
                      unselectedFontSize: 11,
                      backgroundColor: Colors.white,
                      elevation: 8,
                      items: [
                        const BottomNavigationBarItem(
                          icon: Icon(Icons.calendar_month_rounded),
                          activeIcon: Icon(Icons.calendar_month),
                          label: 'Calendar',
                        ),
                        const BottomNavigationBarItem(
                          icon: Icon(Icons.view_agenda_outlined),
                          activeIcon: Icon(Icons.view_agenda_rounded),
                          label: 'Agenda',
                        ),
                        BottomNavigationBarItem(
                          icon: Badge(
                            isLabelVisible: unread > 0,
                            label: Text('$unread', style: const TextStyle(fontSize: 10)),
                            child: const Icon(Icons.notifications_active_outlined),
                          ),
                          activeIcon: Badge(
                            isLabelVisible: unread > 0,
                            label: Text('$unread', style: const TextStyle(fontSize: 10)),
                            child: const Icon(Icons.notifications_active_rounded),
                          ),
                          label: 'Alerts',
                        ),
                        const BottomNavigationBarItem(
                          icon: Icon(Icons.folder_shared_outlined),
                          activeIcon: Icon(Icons.folder_shared_rounded),
                          label: 'Records',
                        ),
                      ],
                    );
                  },
                )
              : null,
        );
      },
    );
  }

  Widget _buildSidebarContent({bool isDrawer = false}) {
    final collapsed = isDrawer ? false : _isSidebarCollapsed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              ],
            ],
          ),
        ),
        if (!collapsed)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: SyncStatusIndicator(compact: false),
          )
        else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Center(child: SyncStatusIndicator(compact: true)),
          ),
        const SizedBox(height: 6),
        const Divider(height: 1, color: AppTheme.borderColor),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                _buildNavItem(0, Icons.dashboard_outlined, Icons.dashboard, 'Dashboard', isDrawer: isDrawer),
                _buildNavItem(1, Icons.calendar_month_outlined, Icons.calendar_month, 'Calendar', isDrawer: isDrawer),
                const SizedBox(height: 14),
                if (!collapsed)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                      children: [
                        Icon(Icons.people_alt_outlined, size: 14, color: AppTheme.primaryBlue),
                        SizedBox(width: 6),
                        Text(
                          'PATIENTS',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: AppTheme.primaryBlue),
                        ),
                      ],
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Divider(height: 1, color: AppTheme.borderColor),
                  ),
                _buildNavItem(2, Icons.folder_shared_outlined, Icons.folder_shared, 'Records', isDrawer: isDrawer),
                _buildNavItem(3, Icons.assignment_outlined, Icons.assignment, 'Examinations', isDrawer: isDrawer),
                _buildNavItem(4, Icons.local_pharmacy_outlined, Icons.local_pharmacy, 'Prescriptions', isDrawer: isDrawer),
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
                          onTap: () => setState(() => _selectedPatient = null),
                          borderRadius: BorderRadius.circular(8),
                          child: const Padding(
                            padding: EdgeInsets.all(2),
                            child: Icon(Icons.close, size: 14, color: AppTheme.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        ListenableBuilder(
          listenable: ClinicalNotificationRepository(),
          builder: (context, child) {
            final unread = ClinicalNotificationRepository().unreadCount;

            if (collapsed) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Center(
                  child: Tooltip(
                    message: 'Notifications ($unread)',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _showNotificationCenterModal(context),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        child: Badge(
                          isLabelVisible: unread > 0,
                          label: Text('$unread', style: const TextStyle(fontSize: 10)),
                          child: const Icon(
                            Icons.notifications_active_outlined,
                            color: AppTheme.textSecondary,
                            size: 22,
                          ),
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
                  leading: Badge(
                    isLabelVisible: unread > 0,
                    label: Text('$unread', style: const TextStyle(fontSize: 10)),
                    child: const Icon(
                      Icons.notifications_active_outlined,
                      color: AppTheme.textSecondary,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Notifications',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  trailing: unread > 0
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$unread NEW',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                          ),
                        )
                      : null,
                  onTap: () => _showNotificationCenterModal(context),
                ),
              ),
            );
          },
        ),
        const Divider(height: 1, color: AppTheme.borderColor),
        const SizedBox(height: 4),
        _buildNavItem(5, Icons.settings_outlined, Icons.settings, 'Settings', isDrawer: isDrawer),
        const SizedBox(height: 4),
        const Divider(height: 1, color: AppTheme.borderColor),
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
