import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/clinic_store.dart';
import '../services/profile_store.dart';
import '../theme/app_theme.dart';
import '../widgets/account_menu.dart';
import '../widgets/success_modal.dart';

/// The signed-in user's own page (opened from the account menu in the sidebar):
/// their doctor profile and the clinic information printed on prescriptions.
class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

enum _ProfileTab { doctor, clinic }

class _ProfileViewState extends State<ProfileView> {
  final _store = ProfileStore.instance;
  _ProfileTab _tab = _ProfileTab.doctor;

  void _showSaveFeedback(String message) {
    showActionSuccessModal(
      context: context,
      title: 'Profile Updated Successfully',
      message: message,
      icon: Icons.person_outline_rounded,
    );
  }

  void _save(String message) {
    _store.save();
    setState(() {});
    _showSaveFeedback(message);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Profile', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          const Text('Your account, doctor profile and clinic information.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          const SizedBox(height: 20),
          _buildAccountCard(),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _tabChip(_ProfileTab.doctor, 'Doctor Profile', Icons.person_outline),
              _tabChip(_ProfileTab.clinic, 'Clinic Information', Icons.local_hospital_outlined),
            ],
          ),
          const SizedBox(height: 20),
          if (_tab == _ProfileTab.doctor) _buildDoctorProfile() else _buildClinicInfo(),
        ],
      ),
    );
  }

  Widget _tabChip(_ProfileTab tab, String label, IconData icon) {
    final selected = _tab == tab;
    return ChoiceChip(
      selected: selected,
      showCheckmark: false,
      avatar: Icon(icon, size: 16, color: selected ? Colors.white : AppTheme.primaryBlue),
      label: Text(label, style: TextStyle(color: selected ? Colors.white : AppTheme.textPrimary, fontSize: 12, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
      selectedColor: AppTheme.primaryBlue,
      backgroundColor: Colors.transparent,
      onSelected: (_) => setState(() => _tab = tab),
    );
  }

  /// Who is signed in, their role and team (read-only; the team comes from Teams).
  Widget _buildAccountCard() {
    final auth = AuthService.instance;
    final name = _store.doctorName.text.trim();
    final role = roleLabel(auth.role);
    return _card(
      title: 'Account',
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
            child: Text(
              ProfileStore.initialsOf(name),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isEmpty ? 'Unnamed user' : name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                if (auth.email case final email?) Text(email, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 4),
                Text(
                  [?role, if (ClinicStore.instance.active case final clinic?) '${clinic.name} (${clinic.role.label})'].join('  •  '),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorProfile() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Doctor Profile', 'Manage your personal and professional information.'),
        const SizedBox(height: 20),
        _card(
          title: 'Profile Photo',
          child: Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                child: Text(
                  ProfileStore.initialsOf(_store.doctorName.text),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.upload, size: 16),
                          label: const Text('Change Photo'),
                          onPressed: () => _showSaveFeedback('Photo updated successfully.'),
                        ),
                        OutlinedButton(onPressed: () {}, child: const Text('Remove')),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text('JPG, PNG or GIF. Max file size 2MB.', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _card(
          title: 'Personal Information',
          child: Column(
            children: [
              _responsiveRow([
                _field('Full Name', _store.doctorName, Icons.person_outline),
                _field('Email Address', _store.doctorEmail, Icons.email_outlined),
              ]),
              const SizedBox(height: 12),
              _responsiveRow([
                _field('Contact Number', _store.doctorPhone, Icons.phone_outlined),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _card(
          title: 'Professional Information',
          child: Column(
            children: [
              _responsiveRow([
                _field('Professional Title', _store.doctorTitle, Icons.badge_outlined),
                _field('Specialization', _store.specialization, Icons.medical_services_outlined),
              ]),
              const SizedBox(height: 12),
              _responsiveRow([
                _field('License Number', _store.license, Icons.assignment_ind_outlined),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _actionButtons(onSave: () => _save('Doctor profile changes saved successfully.')),
      ],
    );
  }

  Widget _buildClinicInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Clinic Information', 'Manage the clinic details displayed on prescriptions and documents.'),
        const SizedBox(height: 20),
        _card(
          title: 'Clinic Branding',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.remove_red_eye_rounded, size: 36, color: AppTheme.primaryBlue),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                          label: const Text('Upload Logo'),
                          onPressed: () => _showSaveFeedback('Clinic logo uploaded.'),
                        ),
                        const SizedBox(height: 6),
                        const Text('Recommended: 300x300 PNG with transparent background.', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _field('Clinic Name', _store.clinicName, Icons.local_hospital_outlined),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _card(
          title: 'Contact Information',
          child: Column(
            children: [
              _field('Clinic Address', _store.clinicAddress, Icons.location_on_outlined),
              const SizedBox(height: 16),
              _responsiveRow([
                _field('Contact Number', _store.clinicPhone, Icons.phone_outlined),
                _field('Email Address', _store.clinicEmail, Icons.email_outlined),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _card(
          title: 'Optional Information',
          child: _responsiveRow([
            _field('Clinic Website', _store.clinicWebsite, Icons.language_outlined),
            const SizedBox.shrink(),
          ]),
        ),
        const SizedBox(height: 20),
        _card(
          title: 'Prescription Header Live Preview',
          child: ListenableBuilder(
            listenable: Listenable.merge([_store.clinicName, _store.clinicAddress, _store.clinicPhone, _store.clinicEmail]),
            builder: (context, _) => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Row(
                children: [
                  const Icon(Icons.remove_red_eye_rounded, size: 36, color: AppTheme.primaryBlue),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_store.clinicName.text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryBlue)),
                        const SizedBox(height: 2),
                        Text(_store.clinicAddress.text, style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary)),
                        Text('Tel: ${_store.clinicPhone.text} • Email: ${_store.clinicEmail.text}', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        _actionButtons(onSave: () => _save('Clinic information updated successfully.')),
      ],
    );
  }

  // ------------------------------------------------------------ building blocks --

  Widget _sectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Card(
      color: AppTheme.cardBg,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  /// Side by side on a wide screen, stacked on a phone.
  Widget _responsiveRow(List<Widget> children) {
    if (MediaQuery.of(context).size.width < 640) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final c in children)
            if (c is! SizedBox) Padding(padding: const EdgeInsets.only(bottom: 12), child: c),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          Expanded(child: children[i]),
        ],
      ],
    );
  }

  Widget _field(String label, TextEditingController controller, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: AppTheme.primaryBlue),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _actionButtons({required VoidCallback onSave}) {
    return Row(
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.save_outlined, size: 16),
          label: const Text('Save Changes'),
          onPressed: onSave,
        ),
      ],
    );
  }
}
