import 'package:flutter/material.dart';
import '../models/clinic_branch.dart';
import '../models/patient.dart';
import '../models/prescription.dart';
import '../services/auth_service.dart';
import '../services/profile_store.dart';
import '../services/reminder_settings_store.dart';
import '../services/security_settings_store.dart';
import '../services/team_service.dart';
import '../theme/app_theme.dart';
import '../widgets/clinical_dropdown_field.dart';
import '../widgets/clinical_modal_picker.dart';
import '../widgets/field_label.dart';
import '../widgets/filter_pill.dart';
import '../widgets/rx_pad_widget.dart';
import '../widgets/success_modal.dart';

/// SettingsView - Complete Settings & Workstation Configuration UI/UX for DOCRS
/// Tailored specifically for a single attending ophthalmologist / physician.
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  // Navigation State
  String _activeSection = 'prescription_settings';

  // Doctor profile and clinic details are edited on the Profile page.
  final _profile = ProfileStore.instance;

  // 3. Prescription Settings State
  bool _hasSignature = true;
  bool _isEditingDoctorInfo = false;
  bool _isEditingClinicHeaders = false;

  // 4. Security State & Controllers
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool _autoLockEnabled = true;
  String _autoLockDuration = '15 minutes';
  bool _twoFactorEnabled = false;
  bool _isUpdatingPassword = false;
  String? _passwordError;

  // 5. Backup & Data State
  bool _isBackingUp = false;
  String _lastBackupDate = 'August 20, 2026 — 11:00 PM';
  bool _autoBackupEnabled = true;
  String _backupFrequency = 'Daily';
  String _backupTime = '11:00 PM';
  final String _backupLocation = '/Users/drjenkins/DOCRS/Backups';
  final bool _locationAvailable = true;

  // 8. System Preferences State
  String _appearanceMode = ThemeController.instance.currentModeName;
  String _dateFormat = 'MM/DD/YYYY';
  String _timeFormat = '12-hour';
  String _defaultExamLayout = 'Standard 2-Column';
  String _defaultDrawingTemplate = 'Fundus / Retina Map';
  String _defaultPatientView = 'Patient EHR Profile';

  @override
  void initState() {
    super.initState();
    ThemeController.instance.addListener(_onThemeChanged);
    _profile.addListener(_onProfileChanged);
    _profile.loadFromFirestore(teamId: TeamService.instance.activeTeam?.id);

    _autoLockEnabled = SecuritySettingsStore.instance.autoLockEnabled;
    _autoLockDuration = SecuritySettingsStore.instance.autoLockDuration;
    _twoFactorEnabled = SecuritySettingsStore.instance.twoFactorEnabled;
    SecuritySettingsStore.instance.addListener(_onSecuritySettingsChanged);
    final currentUid = AuthService.instance.user?.uid;
    if (currentUid != null) {
      SecuritySettingsStore.instance.loadFromFirestore(currentUid);
    }
  }

  void _onProfileChanged() {
    if (mounted) setState(() {});
  }

  void _onSecuritySettingsChanged() {
    if (mounted) {
      setState(() {
        _autoLockEnabled = SecuritySettingsStore.instance.autoLockEnabled;
        _autoLockDuration = SecuritySettingsStore.instance.autoLockDuration;
        _twoFactorEnabled = SecuritySettingsStore.instance.twoFactorEnabled;
      });
    }
  }

  @override
  void dispose() {
    ThemeController.instance.removeListener(_onThemeChanged);
    _profile.removeListener(_onProfileChanged);
    SecuritySettingsStore.instance.removeListener(_onSecuritySettingsChanged);
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {
        _appearanceMode = ThemeController.instance.currentModeName;
      });
    }
  }

  void _showSaveFeedback(String message) {
    showActionSuccessModal(
      context: context,
      title: 'Settings Saved Successfully',
      message: message,
      icon: Icons.settings_suggest_rounded,
    );
  }

  void _triggerManualBackup() async {
    setState(() => _isBackingUp = true);
    await Future.delayed(Duration(milliseconds: 1400));
    if (mounted) {
      setState(() {
        _isBackingUp = false;
        _lastBackupDate = 'August 20, 2026 — 11:15 PM';
      });
      _showSaveFeedback('Local clinic database backed up successfully (4.8 GB encrypted vault).');
    }
  }

  void _showRestoreDialog(Map<String, String> backup) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 28),
            SizedBox(width: 10),
            Text('Restore Backup?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Color(0xFFF59E0B).withValues(alpha: 0.5)),
              ),
              child: Text(
                'Restoring a previous backup may replace the current system data. Ensure you have backed up any unsaved patient encounters before continuing.',
                style: TextStyle(fontSize: 13, color: Color(0xFF92400E), height: 1.4),
              ),
            ),
            SizedBox(height: 16),
            _buildDetailRow('Backup Date:', backup['date'] ?? ''),
            SizedBox(height: 6),
            _buildDetailRow('Backup Time:', backup['time'] ?? '11:00 PM'),
            SizedBox(height: 6),
            _buildDetailRow('Backup Size:', backup['size'] ?? ''),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              _showSaveFeedback('System successfully restored to backup state (${backup['date']}).');
            },
            child: Text('Continue to Restore'),
          ),
        ],
      ),
    );
  }

  void _showRxPreviewDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 580,
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Prescription Document Preview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  IconButton(
                    icon: Icon(Icons.close, color: AppTheme.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Divider(height: 24),
              _buildPrescriptionPreviewCard(),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    icon: Icon(Icons.check, size: 16),
                    label: Text('Close Preview'),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textSecondary)),
        SizedBox(width: 8),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;

        return SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page Header
              Text('System Settings & Preferences', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              SizedBox(height: 4),
              Text('Manage your Rx layout, security, preferences, and local backups.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
              SizedBox(height: 24),

              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Navigation Column
                    SizedBox(
                      width: 260,
                      child: _buildLeftNavigation(),
                    ),
                    SizedBox(width: 24),
                    // Right Content Area
                    Expanded(
                      child: _buildActiveContentSection(),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    _buildMobileNavSelector(),
                    SizedBox(height: 20),
                    _buildActiveContentSection(),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  // Mobile Top Selector Tab Bar
  Widget _buildMobileNavSelector() {
    return Card(
      color: AppTheme.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppTheme.borderColor)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            _buildMobileNavItem('prescription_settings', 'Prescription', Icons.description_outlined),
            _buildMobileNavItem('security', 'Security', Icons.security_outlined),
            _buildMobileNavItem('backup_data', 'Backup & Data', Icons.backup_outlined),
            _buildMobileNavItem('system_preferences', 'Preferences', Icons.tune_outlined),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileNavItem(String key, String title, IconData icon) {
    final isSelected = _activeSection == key;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        selected: isSelected,
        showCheckmark: false,
        avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : AppTheme.primaryBlue),
        label: Text(title, style: TextStyle(color: isSelected ? Colors.white : AppTheme.textPrimary, fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        selectedColor: AppTheme.primaryBlue,
        backgroundColor: Colors.transparent,
        onSelected: (_) => setState(() => _activeSection = key),
      ),
    );
  }

  // Left Settings Navigation Menu
  Widget _buildLeftNavigation() {
    return Card(
      color: AppTheme.cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.borderColor),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNavCategoryHeader('General'),
            _buildNavItem('prescription_settings', 'Prescription Settings', Icons.description_outlined, Icons.description_rounded),
            
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: Divider(height: 1, color: AppTheme.borderColor),
            ),
            
            _buildNavCategoryHeader('Data & Security'),
            _buildNavItem('security', 'Security', Icons.security_outlined, Icons.security_rounded),
            _buildNavItem('backup_data', 'Backup & Data', Icons.backup_outlined, Icons.backup_rounded),
            
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: Divider(height: 1, color: AppTheme.borderColor),
            ),
            
            _buildNavCategoryHeader('Preferences'),
            _buildNavItem('system_preferences', 'System Preferences', Icons.tune_outlined, Icons.tune_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildNavCategoryHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(left: 12, top: 8, bottom: 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 0.8),
      ),
    );
  }

  Widget _buildNavItem(String key, String title, IconData icon, IconData activeIcon) {
    final isSelected = _activeSection == key;

    return Material(
      color: Colors.transparent,
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        selected: isSelected,
        selectedTileColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
        leading: Icon(
          isSelected ? activeIcon : icon,
          color: isSelected ? AppTheme.primaryBlue : AppTheme.textSecondary,
          size: 18,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? AppTheme.primaryBlue : AppTheme.textPrimary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
        onTap: () {
          setState(() {
            _activeSection = key;
          });
        },
      ),
    );
  }

  // Right Content Router
  Widget _buildActiveContentSection() {
    switch (_activeSection) {
      case 'prescription_settings':
        return _buildPrescriptionSettingsSection();
      case 'security':
        return _buildSecuritySection();
      case 'backup_data':
        return _buildBackupDataSection();
      case 'system_preferences':
        return _buildSystemPreferencesSection();
      default:
        return _buildPrescriptionSettingsSection();
    }
  }

  // ==========================================
  // SECTION 3: PRESCRIPTION SETTINGS
  // ==========================================
  Widget _buildPrescriptionSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Prescription Settings', 'Customize the information and layout used for prescriptions.'),
        SizedBox(height: 20),

        // 1. Doctor Information Summary / Edit Card
        _buildCardContainer(
          title: 'Doctor Information',
          trailing: OutlinedButton.icon(
            key: Key('edit_doctor_info_button'),
            icon: Icon(_isEditingDoctorInfo ? Icons.check : Icons.edit_outlined, size: 14),
            label: Text(_isEditingDoctorInfo ? 'Done' : 'Edit'),
            onPressed: () {
              setState(() => _isEditingDoctorInfo = !_isEditingDoctorInfo);
            },
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_isEditingDoctorInfo)
                Container(
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppTheme.primaryBlue, size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_profile.doctorName.text} — ${_profile.doctorTitle.text}',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '${_profile.license.text} • ${_profile.ptrNo.text} • Specialization: ${_profile.specialization.text}',
                              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildTextFieldItem(
                            fieldKey: const Key('doctor_name_input'),
                            label: 'Doctor Name *',
                            controller: _profile.doctorName,
                            hint: 'e.g. Dr. Sigrid Robillos, MD',
                            icon: Icons.person_outline,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: _buildTextFieldItem(
                            fieldKey: const Key('doctor_title_input'),
                            label: 'Professional Title',
                            controller: _profile.doctorTitle,
                            hint: 'e.g. Attending Ophthalmologist',
                            icon: Icons.badge_outlined,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildTextFieldItem(
                            fieldKey: const Key('doctor_license_input'),
                            label: 'PRC License Number *',
                            controller: _profile.license,
                            hint: 'e.g. PRC Lic. No. 091823',
                            icon: Icons.assignment_ind_outlined,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: _buildTextFieldItem(
                            fieldKey: const Key('doctor_ptr_input'),
                            label: 'PTR Number',
                            controller: _profile.ptrNo,
                            hint: 'e.g. PTR No. 7821940',
                            icon: Icons.confirmation_number_outlined,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 14),
                    _buildTextFieldItem(
                      fieldKey: const Key('doctor_specialization_input'),
                      label: 'Specialization',
                      controller: _profile.specialization,
                      hint: 'e.g. Cornea & Anterior Segment Specialist',
                      icon: Icons.medical_services_outlined,
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
            ],
          ),
        ),
        SizedBox(height: 20),

        // Signature Upload & Management Card
        _buildCardContainer(
          title: 'Signature',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 180,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: _hasSignature
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Sarah Jenkins',
                                  style: TextStyle(fontFamily: 'serif', fontStyle: FontStyle.italic, fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                                ),
                                Container(width: 100, height: 1, color: Colors.blue.shade900),
                              ],
                            ),
                          )
                        : Center(
                            child: Text('No Signature Uploaded', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          ),
                  ),
                  SizedBox(width: 20),
                  Expanded(
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            icon: Icon(Icons.draw, size: 16),
                            label: Text('Upload Signature Image'),
                            onPressed: () {
                              setState(() => _hasSignature = true);
                              _showSaveFeedback('Signature uploaded.');
                            },
                          ),
                          if (_hasSignature)
                            OutlinedButton(
                              onPressed: () {
                                setState(() => _hasSignature = false);
                                _showSaveFeedback('Signature removed.');
                              },
                              child: Text('Remove Signature'),
                            ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text('PNG with transparent background (Max 1MB). Appears on exported PDFs.', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 20),

        // 2. Clinic Branch Headers & Schedules Card
        _buildCardContainer(
          title: 'Clinic Branch Headers & Schedules',
          trailing: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ElevatedButton.icon(
                key: const Key('add_branch_button'),
                icon: const Icon(Icons.add, size: 14),
                label: const Text('+ Add Branch'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: _showAddBranchModal,
              ),
              OutlinedButton.icon(
                key: const Key('edit_clinic_headers_button'),
                icon: Icon(_isEditingClinicHeaders ? Icons.check : Icons.edit_outlined, size: 14),
                label: Text(_isEditingClinicHeaders ? 'Done' : 'Edit'),
                onPressed: () {
                  if (_isEditingClinicHeaders) {
                    _profile.syncControllersToBranches();
                    _profile.saveToFirestore(teamId: TeamService.instance.activeTeam?.id);
                  }
                  setState(() => _isEditingClinicHeaders = !_isEditingClinicHeaders);
                },
              ),
            ],
          ),
          child: ListenableBuilder(
            listenable: _profile,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manage clinic locations and consultation hours printed at the top of the prescription pad.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                SizedBox(height: 14),
                if (!_isEditingClinicHeaders) ...[
                  if (_profile.activeBranches.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          'No active clinic branches. Click "+ Add Branch" to add one.',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ),
                    )
                  else
                    Column(
                      children: _profile.activeBranches.map((branch) => _buildBranchCard(branch)).toList(),
                    ),
                  if (_profile.archivedBranches.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Divider(color: AppTheme.borderColor),
                    const SizedBox(height: 8),
                    Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        initiallyExpanded: false,
                        tilePadding: EdgeInsets.zero,
                        leading: Icon(Icons.archive_outlined, size: 18, color: AppTheme.textSecondary),
                        title: Text(
                          'Archived Branches (${_profile.archivedBranches.length})',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                        ),
                        subtitle: Text(
                          'Retired clinic locations preserved for audit logs and historical records.',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                        children: _profile.archivedBranches.map((branch) => _buildArchivedBranchCard(branch)).toList(),
                      ),
                    ),
                  ],
                ] else ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildClinicBranchEditor('Clinic Branch 1', _profile.clinic1Name, _profile.clinic1Location, _profile.clinic1Days, _profile.clinic1Hours),
                      SizedBox(height: 16),
                      Divider(color: AppTheme.borderColor),
                      SizedBox(height: 12),
                      _buildClinicBranchEditor('Clinic Branch 2', _profile.clinic2Name, _profile.clinic2Location, _profile.clinic2Days, _profile.clinic2Hours),
                      SizedBox(height: 16),
                      Divider(color: AppTheme.borderColor),
                      SizedBox(height: 12),
                      _buildClinicBranchEditor('Clinic Branch 3', _profile.clinic3Name, _profile.clinic3Location, _profile.clinic3Days, _profile.clinic3Hours),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        SizedBox(height: 20),

        // 3. Prescription Template Preview Card
        _buildCardContainer(
          title: 'Prescription Template Layout',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Live Prescription Pad Preview dynamically reflects your active doctor credentials and clinic schedules.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              SizedBox(height: 14),
              ListenableBuilder(
                listenable: _profile,
                builder: (context, _) => _buildPrescriptionPreviewCard(),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: Icon(Icons.visibility_outlined, size: 16),
                    label: Text('Preview Prescription'),
                    onPressed: _showRxPreviewDialog,
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 24),

        _buildActionButtons(onSave: _savePrescriptionSettings),
      ],
    );
  }

  void _savePrescriptionSettings() async {
    final validationError = _profile.validatePrescriptionSettings();
    if (validationError != null) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationError),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await _profile.saveToFirestore(teamId: TeamService.instance.activeTeam?.id);
    if (mounted) {
      _showSaveFeedback('Prescription settings and clinic headers updated.');
    }
  }

  Widget _buildPrescriptionPreviewCard() {
    final demoPatients = PatientRepository.getAllPatients();
    final demoPatient = demoPatients.isNotEmpty ? demoPatients.first : null;
    return RxPadWidget(
      patient: demoPatient,
      items: [
        PrescriptionItem(
          id: 'rx-1',
          medicationName: 'Moxifloxacin 0.5% Ophthalmic Solution',
          strength: '0.5%',
          dosage: '1 drop OD',
          frequency: '4 times daily',
          duration: '7 days',
          instructions: 'Instill 1 drop in Right Eye (OD) 4 times daily for 7 days.',
        ),
        PrescriptionItem(
          id: 'rx-2',
          medicationName: 'Sodium Hyaluronate 0.18% Artificial Tears',
          strength: '0.18%',
          dosage: '1 drop OU',
          frequency: 'QID',
          duration: '30 days',
          instructions: 'Instill 1 drop in Both Eyes (OU) every 4 hours as needed.',
        ),
      ],
      date: '2026-08-20',
      doctorName: _profile.doctorName.text.isNotEmpty ? _profile.doctorName.text : 'Dr. Sigrid T. Robillos',
      specialization: _profile.specialization.text.isNotEmpty ? _profile.specialization.text : 'OPHTHALMOLOGY / MICROSURGERY',
      licenseNo: _profile.license.text.isNotEmpty ? _profile.license.text : '100064',
      ptrNo: _profile.ptrNo.text.isNotEmpty ? _profile.ptrNo.text : 'PTR No. 7821940',
      clinic1Name: _profile.clinic1Name.text,
      clinic1Location: _profile.clinic1Location.text,
      clinic1Days: _profile.clinic1Days.text,
      clinic1Hours: _profile.clinic1Hours.text,
      clinic2Name: _profile.clinic2Name.text,
      clinic2Location: _profile.clinic2Location.text,
      clinic2Days: _profile.clinic2Days.text,
      clinic2Hours: _profile.clinic2Hours.text,
      clinic3Name: _profile.clinic3Name.text,
      clinic3Location: _profile.clinic3Location.text,
      clinic3Days: _profile.clinic3Days.text,
      clinic3Hours: _profile.clinic3Hours.text,
      showBorder: true,
    );
  }

  // ==========================================
  // SECTION 4: SECURITY
  // ==========================================
  Widget _buildSecuritySection() {
    final securityStore = SecuritySettingsStore.instance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Security', 'Manage access and protect your clinical records.'),
        const SizedBox(height: 20),

        // Change Password Card
        _buildCardContainer(
          title: 'Change Password',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPasswordField(
                'Current Password',
                _currentPasswordController,
                obscureText: !_showCurrentPassword,
                onToggleVisibility: () => setState(() => _showCurrentPassword = !_showCurrentPassword),
                visibilityKey: const Key('toggle_current_password_visibility'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildPasswordField(
                      'New Password',
                      _newPasswordController,
                      obscureText: !_showNewPassword,
                      onToggleVisibility: () => setState(() => _showNewPassword = !_showNewPassword),
                      visibilityKey: const Key('toggle_new_password_visibility'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildPasswordField(
                      'Confirm New Password',
                      _confirmPasswordController,
                      obscureText: !_showConfirmPassword,
                      onToggleVisibility: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
                      visibilityKey: const Key('toggle_confirm_password_visibility'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Password Strength Indicator
              if (_newPasswordController.text.isNotEmpty) ...[
                Row(
                  children: [
                    Text('Password Strength: ', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    Text(
                      _newPasswordController.text.length > 8 ? 'Strong' : 'Weak',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: _newPasswordController.text.length > 8 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_newPasswordController.text.length / 12).clamp(0.1, 1.0),
                    backgroundColor: const Color(0xFFE2E8F0),
                    color: _newPasswordController.text.length > 8 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (_passwordError != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _passwordError!,
                          style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              ElevatedButton.icon(
                key: const Key('update_password_button'),
                icon: _isUpdatingPassword
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.lock_reset, size: 16),
                label: Text(_isUpdatingPassword ? 'Updating...' : 'Update Password'),
                onPressed: _isUpdatingPassword ? null : _handlePasswordUpdate,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Session Security Card
        _buildCardContainer(
          title: 'Session Security & Auto-Lock',
          child: Column(
            children: [
              SwitchListTile(
                key: const Key('auto_lock_switch'),
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppTheme.primaryBlue,
                activeTrackColor: AppTheme.primaryBlue.withValues(alpha: 0.3),
                title: Text('Auto-Lock System', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
                subtitle: Text('Automatically lock system after a period of inactivity to protect patient privacy.', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                value: _autoLockEnabled,
                onChanged: (val) async {
                  setState(() => _autoLockEnabled = val);
                  final uid = AuthService.instance.user?.uid;
                  await securityStore.updateAutoLock(
                    enabled: val,
                    duration: _autoLockDuration,
                    uid: uid,
                  );
                  _showSaveFeedback(val ? 'Auto-lock system enabled ($_autoLockDuration).' : 'Auto-lock system disabled.');
                },
              ),
              if (_autoLockEnabled) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('Inactivity Timeout:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ClinicalDropdownField<String>(
                        key: const Key('inactivity_timeout_dropdown'),
                        placeholder: 'Select timeout...',
                        value: _autoLockDuration,
                        items: [
                          ClinicalPickerItem<String>(value: '5 minutes', label: '5 minutes'),
                          ClinicalPickerItem<String>(value: '10 minutes', label: '10 minutes'),
                          ClinicalPickerItem<String>(value: '15 minutes', label: '15 minutes'),
                          ClinicalPickerItem<String>(value: '30 minutes', label: '30 minutes'),
                          ClinicalPickerItem<String>(value: 'Never', label: 'Never'),
                        ],
                        onChanged: (v) async {
                          setState(() => _autoLockDuration = v);
                          final uid = AuthService.instance.user?.uid;
                          await securityStore.updateAutoLock(
                            enabled: _autoLockEnabled,
                            duration: v,
                            uid: uid,
                          );
                          _showSaveFeedback('Inactivity timeout set to $v.');
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Two-Factor Authentication Card
        _buildCardContainer(
          title: 'Two-Factor Authentication',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                key: const Key('two_factor_switch'),
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppTheme.primaryBlue,
                activeTrackColor: AppTheme.primaryBlue.withValues(alpha: 0.3),
                title: Text('Two-Factor Authentication (2FA)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
                subtitle: Text('Add an extra layer of security when signing into the DOCRS workstation.', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                value: _twoFactorEnabled,
                onChanged: (val) {
                  if (val) {
                    _showTwoFactorEnrollmentDialog();
                  } else {
                    _confirmDisableTwoFactor();
                  }
                },
              ),
              if (_twoFactorEnabled) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_user_rounded, color: Color(0xFF059669), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Two-Factor Authentication Active',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                            ),
                            Text(
                              'SMS verification code will be sent to ${securityStore.maskedPhoneNumber} on login.',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF047857)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  key: const Key('setup_2fa_button'),
                  icon: const Icon(Icons.phone_android_rounded, size: 16),
                  label: const Text('Update Enrolled Phone Number'),
                  onPressed: _showTwoFactorEnrollmentDialog,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handlePasswordUpdate() async {
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (currentPassword.isEmpty) {
      setState(() => _passwordError = 'Please enter your current password.');
      return;
    }
    if (newPassword.isEmpty) {
      setState(() => _passwordError = 'Please enter a new password.');
      return;
    }
    if (newPassword.length < 6) {
      setState(() => _passwordError = 'New password must be at least 6 characters long.');
      return;
    }
    if (newPassword != confirmPassword) {
      setState(() => _passwordError = 'New password and confirmation do not match.');
      return;
    }
    if (newPassword == currentPassword) {
      setState(() => _passwordError = 'New password must be different from current password.');
      return;
    }

    setState(() {
      _isUpdatingPassword = true;
      _passwordError = null;
    });

    try {
      await AuthService.instance.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _showCurrentPassword = false;
      _showNewPassword = false;
      _showConfirmPassword = false;
      if (mounted) {
        showActionSuccessModal(
          context: context,
          title: 'Password Updated',
          message: 'Your account password has been successfully updated in Firebase Authentication.',
        );
      }
    } on AuthFailure catch (e) {
      if (mounted) {
        setState(() => _passwordError = e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _passwordError = 'Failed to update password: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingPassword = false);
      }
    }
  }

  void _showTwoFactorEnrollmentDialog() {
    final phoneController = TextEditingController(
      text: SecuritySettingsStore.instance.twoFactorPhoneNumber ?? _profile.doctorPhone.text.trim(),
    );
    final otpControllers = List.generate(6, (_) => TextEditingController());
    final otpFocusNodes = List.generate(6, (_) => FocusNode());
    int step = 1;
    bool isLoading = false;
    String? dialogError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.shield_outlined, color: AppTheme.primaryBlue, size: 24),
                const SizedBox(width: 10),
                const Text(
                  'Two-Factor Authentication',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: step == 1
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Protect your clinical workstation by requiring an SMS verification code whenever signing into DOCRS.',
                          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Mobile Phone Number',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          key: const Key('two_factor_phone_field'),
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            hintText: '+63 917 555 0192',
                            prefixIcon: const Icon(Icons.phone_iphone_rounded, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        if (dialogError != null) ...[
                          const SizedBox(height: 10),
                          Text(dialogError!, style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
                        ],
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enter the 6-digit verification code sent to ${phoneController.text.trim()}:',
                          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(6, (index) {
                            return SizedBox(
                              width: 46,
                              height: 52,
                              child: TextField(
                                key: Key('two_factor_enroll_otp_$index'),
                                controller: otpControllers[index],
                                focusNode: otpFocusNodes[index],
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                maxLength: 1,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  counterText: '',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: (value) {
                                  if (value.isNotEmpty && index < 5) {
                                    otpFocusNodes[index + 1].requestFocus();
                                  } else if (value.isEmpty && index > 0) {
                                    otpFocusNodes[index - 1].requestFocus();
                                  }
                                },
                              ),
                            );
                          }),
                        ),
                        if (dialogError != null) ...[
                          const SizedBox(height: 10),
                          Text(dialogError!, style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
                        ],
                      ],
                    ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading
                    ? null
                    : () {
                        for (final c in otpControllers) {
                          c.dispose();
                        }
                        for (final f in otpFocusNodes) {
                          f.dispose();
                        }
                        phoneController.dispose();
                        Navigator.pop(dialogCtx);
                      },
                child: const Text('Cancel'),
              ),
              if (step == 1)
                ElevatedButton(
                  key: const Key('send_enrollment_sms_button'),
                  onPressed: isLoading
                      ? null
                      : () async {
                          final phone = phoneController.text.trim();
                          if (phone.isEmpty || phone.length < 7) {
                            setModalState(() => dialogError = 'Please enter a valid mobile number.');
                            return;
                          }
                          setModalState(() {
                            isLoading = true;
                            dialogError = null;
                          });
                          try {
                            await AuthService.instance.sendTwoFactorEnrollmentSms(phone);
                            setModalState(() {
                              step = 2;
                              isLoading = false;
                            });
                          } catch (e) {
                            setModalState(() {
                              dialogError = 'Failed to send SMS code: $e';
                              isLoading = false;
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue, foregroundColor: Colors.white),
                  child: isLoading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Send Verification Code'),
                )
              else
                ElevatedButton(
                  key: const Key('verify_enrollment_sms_button'),
                  onPressed: isLoading
                      ? null
                      : () async {
                          final enteredCode = otpControllers.map((c) => c.text.trim()).join();
                          if (enteredCode.length < 6) {
                            setModalState(() => dialogError = 'Please enter all 6 digits.');
                            return;
                          }
                          setModalState(() {
                            isLoading = true;
                            dialogError = null;
                          });
                          final phone = phoneController.text.trim();
                          final success = await AuthService.instance.verifyTwoFactorEnrollmentSms(phone, enteredCode);
                          if (!success) {
                            setModalState(() {
                              dialogError = 'Invalid code. Please try again.';
                              isLoading = false;
                            });
                            return;
                          }
                          final uid = AuthService.instance.user?.uid;
                          await SecuritySettingsStore.instance.updateTwoFactor(
                            enabled: true,
                            phoneNumber: phone,
                            uid: uid,
                          );
                          for (final c in otpControllers) {
                            c.dispose();
                          }
                          for (final f in otpFocusNodes) {
                            f.dispose();
                          }
                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx);
                          }
                          if (!mounted) return;
                          showActionSuccessModal(
                            context: context,
                            title: 'Two-Factor Authentication Enabled',
                            message: 'SMS-based 2FA is now active. Your account is protected by two-factor verification on sign-in.',
                          );
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
                  child: isLoading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Verify & Activate 2FA'),
                ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDisableTwoFactor() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Disable Two-Factor Authentication?'),
        content: Text(
          'Removing Two-Factor Authentication will reduce the security level of your DOCRS workstation access.',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Keep 2FA Enabled'),
          ),
          ElevatedButton(
            key: const Key('confirm_disable_2fa_button'),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final uid = AuthService.instance.user?.uid;
              await SecuritySettingsStore.instance.updateTwoFactor(
                enabled: false,
                phoneNumber: null,
                uid: uid,
              );
              _showSaveFeedback('Two-factor authentication disabled.');
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            child: const Text('Disable 2FA'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SECTION 5, 6, & 7: BACKUP & DATA
  // ==========================================
  Widget _buildBackupDataSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Backup & Data', 'Manage local backups and protect patient clinical records.'),
        SizedBox(height: 20),

        // Backup Status Banner Card
        Card(
          color: AppTheme.cardBg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppTheme.borderColor),
          ),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.backup_rounded, color: AppTheme.primaryBlue, size: 24),
                        SizedBox(width: 10),
                        Text('Local Backup Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                      ],
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Color(0xFF166534).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, color: Color(0xFF15803D), size: 14),
                          SizedBox(width: 6),
                          Text('Backup Successful', style: TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.bold, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Last Backup: $_lastBackupDate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
                        SizedBox(height: 4),
                        Text('Storage Location: $_backupLocation', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                        SizedBox(height: 2),
                        Text('Next Scheduled Backup: August 21, 2026 — 11:00 PM', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      ],
                    ),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isBackingUp ? null : _triggerManualBackup,
                          icon: _isBackingUp
                              ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Icon(Icons.cloud_upload_outlined, size: 16),
                          label: Text(_isBackingUp ? 'Backing up...' : 'Backup Now'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 20),

        // Automatic Backup Card
        _buildCardContainer(
          title: 'Automatic Backup Settings',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppTheme.primaryBlue,
                activeTrackColor: AppTheme.primaryBlue.withValues(alpha: 0.3),
                title: Text('Enable Automatic Backup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
                subtitle: Text('Automatically backup local encrypted clinical database at specified intervals.', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                value: _autoBackupEnabled,
                onChanged: (val) => setState(() => _autoBackupEnabled = val),
              ),
              if (_autoBackupEnabled) ...[
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Backup Frequency', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
                          SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _backupFrequency,
                            decoration: InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                            items: ['Daily', 'Weekly', 'Monthly']
                                .map((val) => DropdownMenuItem(value: val, child: Text(val, style: TextStyle(fontSize: 13))))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _backupFrequency = val);
                            },
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Backup Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
                          SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _backupTime,
                            decoration: InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                            items: ['10:00 PM', '11:00 PM', '12:00 AM', '01:00 AM']
                                .map((val) => DropdownMenuItem(value: val, child: Text(val, style: TextStyle(fontSize: 13))))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _backupTime = val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Local Backup Folder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            readOnly: true,
                            controller: TextEditingController(text: _backupLocation),
                            decoration: InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                          ),
                        ),
                        SizedBox(width: 12),
                        OutlinedButton.icon(
                          icon: Icon(Icons.folder_open, size: 16),
                          label: Text('Change Location'),
                          onPressed: () {
                            _showSaveFeedback('Backup folder updated.');
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    if (_locationAvailable)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Color(0xFF10B981).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, size: 14, color: Color(0xFF10B981)),
                            SizedBox(width: 6),
                            Text('Backup folder verified and available.', style: TextStyle(fontSize: 11, color: Color(0xFF047857))),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: 20),

        // SECTION 7: STORAGE INFORMATION
        _buildCardContainer(
          title: 'Storage Usage (Local Disk)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total Storage: 1 TB', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
                  Row(
                    children: [
                      Text('Used: 650 GB ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryBlue)),
                      Text('• Available: 350 GB', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: 0.65,
                  backgroundColor: Color(0xFFE2E8F0),
                  color: AppTheme.primaryBlue,
                  minHeight: 10,
                ),
              ),
              SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _buildStorageLegend('Patient Records', '210 GB', AppTheme.primaryBlue),
                  _buildStorageLegend('Eye Drawings', '320 GB', Color(0xFF06B6D4)),
                  _buildStorageLegend('Prescriptions', '40 GB', Color(0xFF10B981)),
                  _buildStorageLegend('Backup Files', '80 GB', Color(0xFFD97706)),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 20),

        // Backup History Table (Section 5 & 6)
        _buildCardContainer(
          title: 'Backup History Log',
          child: Column(
            children: [
              _buildBackupHistoryTable(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStorageLegend(String label, String size, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        SizedBox(width: 6),
        Text('$label: ', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        Text(size, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.textPrimary)),
      ],
    );
  }

  Widget _buildBackupHistoryTable() {
    final history = [
      {'date': 'Aug 20, 2026', 'time': '11:00 PM', 'type': 'Full Backup', 'size': '4.8 GB', 'status': 'Successful'},
      {'date': 'Aug 19, 2026', 'time': '11:00 PM', 'type': 'Full Backup', 'size': '4.7 GB', 'status': 'Successful'},
      {'date': 'Aug 18, 2026', 'time': '11:00 PM', 'type': 'Full Backup', 'size': '4.6 GB', 'status': 'Successful'},
    ];

    return Table(
      columnWidths: {
        0: FlexColumnWidth(1.2),
        1: FlexColumnWidth(1.2),
        2: FlexColumnWidth(1),
        3: FlexColumnWidth(1),
        4: FlexColumnWidth(1.4),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.borderColor))),
          children: ['Date', 'Backup Type', 'Size', 'Status', 'Action'].map((heading) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(heading, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.textSecondary)),
            );
          }).toList(),
        ),
        ...history.map((row) {
          return TableRow(
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
            children: [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(row['date']!, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(row['type']!, style: TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(row['size']!, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Color(0xFF10B981), size: 14),
                    SizedBox(width: 4),
                    Text(row['status']!, style: TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.bold, fontSize: 11)),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: 8), minimumSize: Size.zero),
                      onPressed: () {
                        _showSaveFeedback('Backup log verified: ${row['date']}');
                      },
                      child: Text('View', style: TextStyle(fontSize: 11)),
                    ),
                    SizedBox(width: 4),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        side: BorderSide(color: Color(0xFFF59E0B)),
                      ),
                      onPressed: () => _showRestoreDialog(row),
                      child: Text('Restore', style: TextStyle(fontSize: 11, color: Color(0xFFD97706))),
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  // ==========================================
  // SECTION 8: SYSTEM PREFERENCES
  // ==========================================
  Widget _buildSystemPreferencesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('System Preferences', 'Customize your DOCRS experience.'),
        SizedBox(height: 20),

        // Appearance Card
        _buildCardContainer(
          title: 'Appearance',
          child: Row(
            children: [
              Expanded(child: _buildAppearanceCard('Light', Icons.light_mode, _appearanceMode == 'Light')),
              SizedBox(width: 12),
              Expanded(child: _buildAppearanceCard('Dark', Icons.dark_mode, _appearanceMode == 'Dark')),
              SizedBox(width: 12),
              Expanded(child: _buildAppearanceCard('System Default', Icons.settings_brightness, _appearanceMode == 'System Default')),
            ],
          ),
        ),
        SizedBox(height: 20),

        // Date Format Card
        _buildCardContainer(
          title: 'Date Format',
          child: Wrap(
            runSpacing: 8,
            children: ['DD/MM/YYYY', 'MM/DD/YYYY', 'YYYY-MM-DD'].map((fmt) {
              final isSelected = _dateFormat == fmt;
              return Padding(
                padding: EdgeInsets.only(right: 16),
                child: ChoiceChip(
                  selected: isSelected,
                  showCheckmark: false,
                  backgroundColor: AppTheme.cardBg,
                  selectedColor: AppTheme.primaryBlue,
                  side: BorderSide(color: isSelected ? AppTheme.primaryBlue : AppTheme.borderColor),
                  label: Text(fmt),
                  labelStyle: TextStyle(color: isSelected ? Colors.white : AppTheme.textPrimary, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                  onSelected: (_) => setState(() => _dateFormat = fmt),
                ),
              );
            }).toList(),
          ),
        ),
        SizedBox(height: 20),

        // Time Format Card
        _buildCardContainer(
          title: 'Time Format',
          child: Wrap(
            runSpacing: 8,
            children: ['12-hour', '24-hour'].map((fmt) {
              final isSelected = _timeFormat == fmt;
              return Padding(
                padding: EdgeInsets.only(right: 16),
                child: ChoiceChip(
                  selected: isSelected,
                  showCheckmark: false,
                  backgroundColor: AppTheme.cardBg,
                  selectedColor: AppTheme.primaryBlue,
                  side: BorderSide(color: isSelected ? AppTheme.primaryBlue : AppTheme.borderColor),
                  label: Text(fmt),
                  labelStyle: TextStyle(color: isSelected ? Colors.white : AppTheme.textPrimary, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                  onSelected: (_) => setState(() => _timeFormat = fmt),
                ),
              );
            }).toList(),
          ),
        ),
        SizedBox(height: 20),

        // Notification Reminder Alert Card. One choice for every appointment, applied
        // when an event is scheduled (the scheduling form no longer asks).
        _buildCardContainer(
          title: 'Notification Reminder Alert',
          child: ListenableBuilder(
            listenable: ReminderSettingsStore.instance,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How long before an appointment its reminder alert is sent. Applies to events you schedule from now on.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                ),
                SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in ReminderSettingsStore.options.entries)
                        FilterPill(
                          label: option.value,
                          selected: ReminderSettingsStore.instance.minutesBefore == option.key,
                          onSelected: () => ReminderSettingsStore.instance.minutesBefore = option.key,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 20),

        // Examination Preferences Card
        _buildCardContainer(
          title: 'Examination Preferences',
          child: Column(
            children: [
              _buildDropdownField(
                'Default Examination Layout',
                _defaultExamLayout,
                ['Standard 2-Column', 'Expanded Single Canvas', 'Clinical Tabbed'],
                (val) => setState(() => _defaultExamLayout = val!),
              ),
              SizedBox(height: 16),
              _buildDropdownField(
                'Default Eye Drawing Template',
                _defaultDrawingTemplate,
                ['Fundus / Retina Map', 'Anterior Segment / Cornea', 'External Eye & Lids'],
                (val) => setState(() => _defaultDrawingTemplate = val!),
              ),
              SizedBox(height: 16),
              _buildDropdownField(
                'Default View When Opening a Patient',
                _defaultPatientView,
                ['Patient EHR Profile', 'New Eye Exam Workstation', 'Past Encounters Timeline'],
                (val) => setState(() => _defaultPatientView = val!),
              ),
            ],
          ),
        ),
        SizedBox(height: 24),

        _buildActionButtons(
          saveLabel: 'Save Preferences',
          onSave: () => _showSaveFeedback('System preferences saved.'),
        ),
      ],
    );
  }

  Widget _buildAppearanceCard(String mode, IconData icon, bool isSelected) {
    return InkWell(
      onTap: () {
        setState(() => _appearanceMode = mode);
        ThemeController.instance.setThemeModeByName(mode);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlue.withValues(alpha: 0.12) : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryBlue : AppTheme.borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? AppTheme.primaryBlue : AppTheme.textSecondary, size: 28),
            SizedBox(height: 8),
            Text(mode, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, fontSize: 12, color: isSelected ? AppTheme.primaryBlue : AppTheme.textPrimary)),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // SHARED REUSABLE UTILITIES
  // ==========================================
  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        SizedBox(height: 4),
        Text(subtitle, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildCardContainer({required String title, Widget? trailing, required Widget child}) {
    return Card(
      color: AppTheme.cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.borderColor),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                if (trailing == null) {
                  return Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary));
                }
                if (constraints.maxWidth < 500) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                      SizedBox(height: 10),
                      trailing,
                    ],
                  );
                }
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    ),
                    SizedBox(width: 12),
                    trailing,
                  ],
                );
              },
            ),
            SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildTextFieldItem({
    Key? fieldKey,
    required String label,
    required TextEditingController controller,
    String? hint,
    IconData? icon,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
        SizedBox(height: 6),
        TextFormField(
          key: fieldKey,
          controller: controller,
          onChanged: onChanged,
          style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon != null ? Icon(icon, size: 18, color: AppTheme.primaryBlue) : null,
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildClinicBranchEditor(
    String title,
    TextEditingController nameCtrl,
    TextEditingController locCtrl,
    TextEditingController daysCtrl,
    TextEditingController hoursCtrl,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryBlue)),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildTextFieldItem(
                label: 'Clinic Name',
                controller: nameCtrl,
                hint: 'e.g. St. Joseph Hospital',
                onChanged: (_) => setState(() {}),
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: _buildTextFieldItem(
                label: 'Location / City',
                controller: locCtrl,
                hint: 'e.g. Maramag, Bukidnon',
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildTextFieldItem(
                label: 'Schedule Days',
                controller: daysCtrl,
                hint: 'e.g. Monday & Tuesday',
                onChanged: (_) => setState(() {}),
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: _buildTextFieldItem(
                label: 'Schedule Hours',
                controller: hoursCtrl,
                hint: 'e.g. 9am - 12nn',
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBranchCard(ClinicBranch branch) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.location_on_outlined, color: AppTheme.primaryBlue, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  branch.name,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 3),
                Text(
                  branch.address,
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 13, color: AppTheme.primaryBlue),
                    const SizedBox(width: 4),
                    Text(
                      '${branch.days} • ${branch.hours}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            key: Key('archive_branch_${branch.id}'),
            icon: Icon(Icons.archive_outlined, size: 14, color: Colors.orange.shade800),
            label: Text('Archive', style: TextStyle(color: Colors.orange.shade800, fontSize: 12)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.orange.shade300),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => _confirmArchiveBranch(branch),
          ),
        ],
      ),
    );
  }

  Widget _buildArchivedBranchCard(ClinicBranch branch) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Icon(Icons.archive, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      branch.name,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('Archived', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(branch.address, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          TextButton.icon(
            key: Key('restore_branch_${branch.id}'),
            icon: const Icon(Icons.unarchive_outlined, size: 14, color: Color(0xFF059669)),
            label: const Text('Restore', style: TextStyle(color: Color(0xFF059669), fontSize: 12, fontWeight: FontWeight.bold)),
            onPressed: () async {
              await _profile.restoreBranch(branch.id, teamId: TeamService.instance.activeTeam?.id);
              if (mounted) {
                _showSaveFeedback('Clinic branch "${branch.name}" restored.');
              }
            },
          ),
        ],
      ),
    );
  }

  void _showAddBranchModal() {
    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final daysCtrl = TextEditingController(text: 'Monday - Friday');
    final hoursCtrl = TextEditingController(text: '9am - 12nn');
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add_business_rounded, color: AppTheme.primaryBlue, size: 20),
                ),
                const SizedBox(width: 12),
                const Text('Add Clinic Branch', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add a new clinic branch location and consultation schedule to appear on prescription headers.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    if (errorText != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, size: 16, color: Colors.redAccent),
                            const SizedBox(width: 8),
                            Expanded(child: Text(errorText!, style: const TextStyle(fontSize: 12, color: Colors.redAccent))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _buildTextFieldItem(
                      fieldKey: const Key('new_branch_name_input'),
                      label: 'Clinic Name *',
                      controller: nameCtrl,
                      hint: 'e.g. Metro Vision Center',
                    ),
                    const SizedBox(height: 12),
                    _buildTextFieldItem(
                      fieldKey: const Key('new_branch_address_input'),
                      label: 'Address / Location *',
                      controller: addressCtrl,
                      hint: 'e.g. J.P. Laurel Ave, Davao City',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextFieldItem(
                            fieldKey: const Key('new_branch_days_input'),
                            label: 'Consultation Days',
                            controller: daysCtrl,
                            hint: 'e.g. Wednesday & Friday',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextFieldItem(
                            fieldKey: const Key('new_branch_hours_input'),
                            label: 'Consultation Hours',
                            controller: hoursCtrl,
                            hint: 'e.g. 1pm - 5pm',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                key: const Key('submit_add_branch_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) {
                    setModalState(() => errorText = 'Clinic Name is required.');
                    return;
                  }
                  if (addressCtrl.text.trim().isEmpty) {
                    setModalState(() => errorText = 'Address / Location is required.');
                    return;
                  }
                  Navigator.pop(dialogCtx);
                  await _profile.addBranch(
                    name: nameCtrl.text.trim(),
                    address: addressCtrl.text.trim(),
                    days: daysCtrl.text.trim(),
                    hours: hoursCtrl.text.trim(),
                    teamId: TeamService.instance.activeTeam?.id,
                  );
                  if (mounted) {
                    _showSaveFeedback('Clinic branch "${nameCtrl.text.trim()}" added successfully.');
                  }
                },
                child: const Text('Add Branch'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmArchiveBranch(ClinicBranch branch) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.archive_outlined, color: Colors.orange.shade800),
            const SizedBox(width: 8),
            const Text('Archive Clinic Branch'),
          ],
        ),
        content: Text(
          'Are you sure you want to archive "${branch.name}"? '
          'This branch will no longer appear on new prescription headers, '
          'but historical records will remain intact.',
          style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            key: const Key('confirm_archive_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _profile.archiveBranch(branch.id, teamId: TeamService.instance.activeTeam?.id);
              if (mounted) {
                _showSaveFeedback('Clinic branch "${branch.name}" archived.');
              }
            },
            child: const Text('Archive Branch'),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField(
    String label,
    TextEditingController controller, {
    bool obscureText = true,
    VoidCallback? onToggleVisibility,
    Key? visibilityKey,
    ValueChanged<String>? onChanged,
  }) {
    final isMasked = obscureText;
    final toggleTooltip = isMasked ? 'Show password' : 'Hide password';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          onChanged: onChanged,
          style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.lock_outline, size: 18, color: AppTheme.primaryBlue),
            suffixIcon: onToggleVisibility != null
                ? Semantics(
                    label: toggleTooltip,
                    button: true,
                    child: IconButton(
                      key: visibilityKey,
                      icon: Icon(
                        isMasked ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 20,
                        color: AppTheme.textSecondary,
                      ),
                      tooltip: toggleTooltip,
                      onPressed: onToggleVisibility,
                    ),
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return ClinicalDropdownField<String>(
      label: FieldLabel(label, fontSize: 12),
      placeholder: 'Select option...',
      value: value,
      items: [for (final item in items) ClinicalPickerItem<String>(value: item, label: item)],
      onChanged: onChanged,
    );
  }

  Widget _buildActionButtons({String saveLabel = 'Save Changes', required VoidCallback onSave}) {
    return Row(
      children: [
        ElevatedButton.icon(
          icon: Icon(Icons.save_outlined, size: 16),
          label: Text(saveLabel),
          onPressed: onSave,
        ),
        SizedBox(width: 12),
        OutlinedButton(
          onPressed: () {
            _showSaveFeedback('Form reset to default.');
          },
          child: Text('Cancel'),
        ),
      ],
    );
  }
}
