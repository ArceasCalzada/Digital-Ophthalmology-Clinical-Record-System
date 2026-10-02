import 'package:flutter/material.dart';

import '../models/clinic.dart';
import '../services/auth_service.dart';
import '../services/clinic_store.dart';
import '../services/profile_store.dart';
import '../theme/app_theme.dart';

/// The account card at the bottom of the sidebar: the user's name and their team.
/// Tapping it opens a pop-up menu above it (like the account menu in Canva) with
/// Profile, Teams, Settings and Log out. The card and the menu show the active
/// clinic and the user's role in it, and the menu lists the other clinics to switch to.
class AccountMenuTrigger extends StatelessWidget {
  /// The narrow icon-only sidebar: just the avatar, with the menu opening beside it.
  final bool collapsed;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenTeams;
  final VoidCallback onOpenSettings;
  final VoidCallback onLogout;

  const AccountMenuTrigger({
    super.key,
    required this.collapsed,
    required this.onOpenProfile,
    required this.onOpenTeams,
    required this.onOpenSettings,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AuthService.instance,
        ProfileStore.instance,
        ClinicStore.instance,
      ]),
      builder: (context, _) {
        final email = AuthService.instance.email;
        final name = ProfileStore.instance.doctorName.text.trim();
        final clinic = ClinicStore.instance.active;
        return Padding(
          padding: EdgeInsets.all(8),
          child: Tooltip(
            message: 'Account',
            // A Material of its own so the hover highlight paints like the sidebar's other buttons.
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                key: ValueKey('account-menu-trigger'),
                borderRadius: BorderRadius.circular(10),
                onTap: () => _open(context, name: name),
                child: Padding(
                  padding: EdgeInsets.all(4),
                  child: Row(
                    mainAxisAlignment: collapsed
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start,
                    children: [
                      AccountAvatar(name: name, radius: 16),
                      if (!collapsed) ...[
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name.isEmpty ? (email ?? 'Signed in') : name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppTheme.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (clinic != null)
                                Text(
                                  clinic.name,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _open(BuildContext context, {required String name}) {
    final box = context.findRenderObject() as RenderBox;
    final anchor = box.localToGlobal(Offset.zero) & box.size;
    const menuWidth = 280.0;
    const gap = 8.0;

    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close account menu',
      barrierColor: Colors.transparent,
      transitionDuration: Duration(milliseconds: 120),
      transitionBuilder: (context, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
      pageBuilder: (dialogContext, _, _) {
        final screen = MediaQuery.sizeOf(dialogContext);
        final left = (collapsed ? anchor.right + gap : anchor.left)
            .clamp(gap, screen.width - menuWidth - gap)
            .toDouble();
        // Above the account row in the wide sidebar; beside the avatar in the narrow one.
        final bottom = collapsed
            ? screen.height - anchor.bottom
            : screen.height - anchor.top + gap;
        return Stack(
          children: [
            Positioned(
              left: left,
              bottom: bottom.clamp(gap, double.infinity).toDouble(),
              width: menuWidth,
              child: _AccountPanel(
                name: name,
                clinic: ClinicStore.instance.active,
                clinics: ClinicStore.instance.clinics,
                onSwitchClinic: (id) {
                  Navigator.pop(dialogContext);
                  ClinicStore.instance.switchTo(id);
                },
                onProfile: () {
                  Navigator.pop(dialogContext);
                  onOpenProfile();
                },
                onTeams: () {
                  Navigator.pop(dialogContext);
                  onOpenTeams();
                },
                onSettings: () {
                  Navigator.pop(dialogContext);
                  onOpenSettings();
                },
                onLogout: () {
                  Navigator.pop(dialogContext);
                  onLogout();
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Human-readable role for the menu.
String? roleLabel(UserRole? role) {
  switch (role) {
    case UserRole.admin:
      return 'Administrator';
    case UserRole.physician:
      return 'Physician';
    case UserRole.staff:
      return 'Staff';
    case null:
      return null;
  }
}

/// Circle with the user's initials ("SR" for "Dr. Sigrid Robillos, MD").
class AccountAvatar extends StatelessWidget {
  final String name;
  final double radius;

  const AccountAvatar({super.key, required this.name, required this.radius});

  String get _initials => ProfileStore.initialsOf(name);

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
      child: Text(
        _initials,
        style: TextStyle(
          color: AppTheme.primaryBlue,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.75,
        ),
      ),
    );
  }
}

class _AccountPanel extends StatelessWidget {
  final String name;
  final Clinic? clinic;
  final List<Clinic> clinics;
  final ValueChanged<String> onSwitchClinic;
  final VoidCallback onProfile;
  final VoidCallback onTeams;
  final VoidCallback onSettings;
  final VoidCallback onLogout;

  const _AccountPanel({
    required this.name,
    required this.clinic,
    required this.clinics,
    required this.onSwitchClinic,
    required this.onProfile,
    required this.onTeams,
    required this.onSettings,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle('Account'),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: Row(
                children: [
                  AccountAvatar(name: name, radius: 22),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty ? 'Signed in' : name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (clinic != null)
                          Text(
                            'Clinic: ${clinic!.name}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (clinic != null)
                          Text(
                            clinic!.role.label,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (clinics.length > 1) ...[
              Divider(height: 1, color: AppTheme.borderColor),
              const _SectionTitle('Switch clinic'),
              for (final c in clinics)
                _MenuRow(
                  icon: c.id == clinic?.id ? Icons.check_rounded : Icons.local_hospital_outlined,
                  label: c.name,
                  onTap: () => onSwitchClinic(c.id),
                ),
              SizedBox(height: 6),
            ],
            Divider(height: 1, color: AppTheme.borderColor),
            _MenuRow(
              icon: Icons.person_outline_rounded,
              label: 'Profile',
              onTap: onProfile,
            ),
            _MenuRow(
              icon: Icons.groups_outlined,
              label: 'Teams',
              onTap: onTeams,
            ),
            _MenuRow(
              icon: Icons.settings_outlined,
              label: 'Settings',
              onTap: onSettings,
            ),
            Divider(height: 1, color: AppTheme.borderColor),
            _MenuRow(
              icon: Icons.logout_rounded,
              label: 'Log out',
              color: Color(0xFFE11D48),
              onTap: onLogout,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: AppTheme.textSecondary,
      ),
    ),
  );
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = color ?? AppTheme.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 20, color: textColor),
            SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
