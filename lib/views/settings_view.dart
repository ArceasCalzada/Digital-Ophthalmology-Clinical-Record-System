import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final _doctorNameController = TextEditingController(text: 'Dr. Sarah Jenkins, MD');
  final _licenseController = TextEditingController(text: 'PRC Lic. No. 091823');
  final _clinicNameController = TextEditingController(text: 'Metro Eye Specialists & Refractive Center');
  final _clinicAddressController = TextEditingController(text: 'Suite 502, Medical Arts Tower, Quezon City');
  final _clinicPhoneController = TextEditingController(text: '+63 2 8920 1100');

  bool _isBackingUp = false;
  String _lastBackupDate = 'August 18, 2026 — 11:00 PM';

  void _triggerBackup() async {
    setState(() => _isBackingUp = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) {
      final now = DateTime.now();
      setState(() {
        _isBackingUp = false;
        _lastBackupDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} — ${now.hour}:${now.minute.toString().padLeft(2, '0')} PM';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Local clinic database backed up successfully to encrypted vault.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title Banner
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('System Settings & Workstation Configuration', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              SizedBox(height: 4),
              Text('Manage physician credentials, clinic information, Rx templates, and local encrypted backups.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 24),

          // 1. Local Data Backup Section
          Card(
            color: AppTheme.cardBg,
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppTheme.borderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.backup_rounded, color: AppTheme.primaryBlue),
                      SizedBox(width: 10),
                      Text('Local Data Backup Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Last Backup: $_lastBackupDate', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
                          const SizedBox(height: 4),
                          const Row(
                            children: [
                              Icon(Icons.check_circle, color: Color(0xFF059669), size: 16),
                              SizedBox(width: 6),
                              Text('Status: Backup Successful (Encrypted Local Storage)', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text('Storage Vault: Local Clinic Dedicated Vault (/var/docrs/vault)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        ],
                      ),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Backup Log History'),
                                  content: const Text('2026-08-18 23:00:00 - Complete sync (2,410 encounters, 4,820 vector drawings)\n2026-08-17 23:00:00 - Complete sync'),
                                  actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
                                ),
                              );
                            },
                            icon: const Icon(Icons.history, size: 16),
                            label: const Text('View Backup History'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _isBackingUp ? null : _triggerBackup,
                            icon: _isBackingUp
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.cloud_upload_outlined, size: 16),
                            label: Text(_isBackingUp ? 'Backing up...' : 'Backup Now'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 2. Doctor Profile Settings
          Card(
            color: AppTheme.cardBg,
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppTheme.borderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Physician & License Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                        child: const Icon(Icons.person, size: 36, color: AppTheme.primaryBlue),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Attending Ophthalmologist Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
                            const SizedBox(height: 6),
                            TextFormField(controller: _doctorNameController),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Medical License No.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
                            const SizedBox(height: 6),
                            TextFormField(controller: _licenseController),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 3. Clinic Information
          Card(
            color: AppTheme.cardBg,
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppTheme.borderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Clinic Details & Letterhead', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Clinic / Hospital Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
                            const SizedBox(height: 6),
                            TextFormField(controller: _clinicNameController),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Contact Phone', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
                            const SizedBox(height: 6),
                            TextFormField(controller: _clinicPhoneController),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Clinic Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
                  const SizedBox(height: 6),
                  TextFormField(controller: _clinicAddressController),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
