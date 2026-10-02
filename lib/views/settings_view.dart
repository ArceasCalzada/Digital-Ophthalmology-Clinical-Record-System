import 'package:flutter/material.dart';
import '../models/patient.dart';
import '../models/prescription.dart';
import '../services/profile_store.dart';
import '../services/reminder_settings_store.dart';
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

  // 4. Security State & Controllers
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _autoLockEnabled = true;
  String _autoLockDuration = '15 minutes';
  bool _twoFactorEnabled = false;

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
  }

  @override
  void dispose() {
    ThemeController.instance.removeListener(_onThemeChanged);
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

        // Doctor Information Summary Card
        _buildCardContainer(
          title: 'Doctor Information',
          child: Container(
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
                      Text('${_profile.doctorName.text} — ${_profile.doctorTitle.text}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
                      Text('${_profile.license.text} • Specialization: ${_profile.specialization.text}', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
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

        // Prescription Template Preview Card
        _buildCardContainer(
          title: 'Prescription Template Layout',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPrescriptionPreviewCard(),
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

        _buildActionButtons(onSave: () => _showSaveFeedback('Prescription settings updated.')),
      ],
    );
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
      licenseNo: _profile.license.text.isNotEmpty ? _profile.license.text : '100064',
      showBorder: true,
    );
  }

  // ==========================================
  // SECTION 4: SECURITY
  // ==========================================
  Widget _buildSecuritySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Security', 'Manage access and protect your clinical records.'),
        SizedBox(height: 20),

        // Change Password Card
        _buildCardContainer(
          title: 'Change Password',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPasswordField('Current Password', _currentPasswordController),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildPasswordField('New Password', _newPasswordController, onChanged: (_) => setState(() {})),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildPasswordField('Confirm New Password', _confirmPasswordController),
                  ),
                ],
              ),
              SizedBox(height: 12),
              
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
                        color: _newPasswordController.text.length > 8 ? Color(0xFF059669) : Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_newPasswordController.text.length / 12).clamp(0.1, 1.0),
                    backgroundColor: Color(0xFFE2E8F0),
                    color: _newPasswordController.text.length > 8 ? Color(0xFF059669) : Color(0xFFDC2626),
                    minHeight: 4,
                  ),
                ),
                SizedBox(height: 16),
              ],

              ElevatedButton.icon(
                icon: Icon(Icons.lock_reset, size: 16),
                label: Text('Update Password'),
                onPressed: () {
                  _currentPasswordController.clear();
                  _newPasswordController.clear();
                  _confirmPasswordController.clear();
                  _showSaveFeedback('Password updated successfully.');
                },
              ),
            ],
          ),
        ),
        SizedBox(height: 20),

        // Session Security Card
        _buildCardContainer(
          title: 'Session Security & Auto-Lock',
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppTheme.primaryBlue,
                activeTrackColor: AppTheme.primaryBlue.withValues(alpha: 0.3),
                title: Text('Auto-Lock System', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
                subtitle: Text('Automatically lock system after a period of inactivity to protect patient privacy.', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                value: _autoLockEnabled,
                onChanged: (val) => setState(() => _autoLockEnabled = val),
              ),
              if (_autoLockEnabled) ...[
                SizedBox(height: 12),
                Row(
                  children: [
                    Text('Inactivity Timeout:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
                    SizedBox(width: 16),
                    Expanded(
                      child: ClinicalDropdownField<String>(
                        placeholder: 'Select timeout...',
                        value: _autoLockDuration,
                        items: [
                          ClinicalPickerItem<String>(value: '5 minutes', label: '5 minutes'),
                          ClinicalPickerItem<String>(value: '10 minutes', label: '10 minutes'),
                          ClinicalPickerItem<String>(value: '15 minutes', label: '15 minutes'),
                          ClinicalPickerItem<String>(value: '30 minutes', label: '30 minutes'),
                          ClinicalPickerItem<String>(value: 'Never', label: 'Never'),
                        ],
                        onChanged: (v) => setState(() => _autoLockDuration = v),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: 20),

        // Two-Factor Authentication Card
        _buildCardContainer(
          title: 'Two-Factor Authentication',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppTheme.primaryBlue,
                activeTrackColor: AppTheme.primaryBlue.withValues(alpha: 0.3),
                title: Text('Two-Factor Authentication (2FA)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
                subtitle: Text('Add an extra layer of security when signing into the DOCRS workstation.', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                value: _twoFactorEnabled,
                onChanged: (val) => setState(() => _twoFactorEnabled = val),
              ),
              if (_twoFactorEnabled) ...[
                SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: Icon(Icons.qr_code, size: 16),
                  label: Text('Set Up Two-Factor Authentication'),
                  onPressed: () {
                    _showSaveFeedback('2FA Authenticator setup initialized.');
                  },
                ),
              ],
            ],
          ),
        ),
      ],
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

  Widget _buildCardContainer({required String title, required Widget child}) {
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
            Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordField(String label, TextEditingController controller, {ValueChanged<String>? onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
        SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: true,
          onChanged: onChanged,
          style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.lock_outline, size: 18, color: AppTheme.primaryBlue),
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
