import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/team.dart';
import '../services/profile_store.dart';
import '../services/team_service.dart';
import '../theme/app_theme.dart';
import '../widgets/page_header.dart';
import '../widgets/success_modal.dart';

/// The Teams Management View: create teams, join via code, manage members, roles,
/// ownership transfer, and view permission matrix.
class TeamsView extends StatelessWidget {
  const TeamsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([TeamService.instance, ProfileStore.instance]),
      builder: (context, _) {
        final teamService = TeamService.instance;
        final activeTeam = teamService.activeTeam;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(PageHeader.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(
                title: 'Teams & Collaboration',
                subtitle: 'Manage your clinical teams, invite staff, and configure member access levels.',
              ),
              _TeamsListCard(teamService: teamService),
              const SizedBox(height: 20),
              if (activeTeam != null) ...[
                _ActiveTeamMembersCard(teamService: teamService, team: activeTeam),
                const SizedBox(height: 20),
              ],
              const _PermissionsMatrixCard(),
            ],
          ),
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Widget child;

  const _Card({required this.title, this.trailing, required this.child});

  @override
  Widget build(BuildContext context) {
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  final TeamRole role;
  const _RolePill(this.role);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: role.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        role.label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: role.color,
        ),
      ),
    );
  }
}

class _TeamsListCard extends StatelessWidget {
  final TeamService teamService;
  const _TeamsListCard({required this.teamService});

  @override
  Widget build(BuildContext context) {
    final active = teamService.activeTeam;
    return _Card(
      title: 'Your Teams',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (teamService.teams.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No teams found. Create a team or join with an invite code.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          for (final team in teamService.teams)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: team.id == active?.id
                      ? AppTheme.primaryBlue.withValues(alpha: 0.06)
                      : AppTheme.lightBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: team.id == active?.id
                        ? AppTheme.primaryBlue.withValues(alpha: 0.4)
                        : AppTheme.borderColor,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.groups_rounded, size: 22, color: AppTheme.primaryBlue),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            team.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Invite Code: ${team.inviteCode}',
                                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                              if (team.id == active?.id)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF059669).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Active Workspace',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF059669),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (team.id != active?.id)
                      ElevatedButton(
                        onPressed: () => teamService.switchTo(team.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        child: const Text('Switch', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Create a Team'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onPressed: () => _showCreateTeamDialog(context),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.vpn_key_rounded, size: 18),
                label: const Text('Join with Code'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  side: const BorderSide(color: AppTheme.borderColor),
                ),
                onPressed: () => _showJoinTeamDialog(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCreateTeamDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Team'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter a name for your clinical team or practice. You will be assigned as Team Owner.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Team Name',
                hintText: 'e.g. Metro Eye Clinic',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await TeamService.instance.createTeam(name);
                if (context.mounted) {
                  showActionSuccessModal(
                    context: context,
                    title: 'Team Created Successfully',
                    message: 'Team "$name" has been created. You are now the Team Owner.',
                    icon: Icons.groups_rounded,
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to create team: $e')),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showJoinTeamDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join Team with Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ask your team owner for their 6-character team invite code (e.g. DOC-1234).',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Invite Code',
                hintText: 'DOC-XXXX',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = controller.text.trim();
              if (code.isEmpty) return;
              Navigator.pop(ctx);
              try {
                final team = await TeamService.instance.joinWithCode(code);
                if (context.mounted) {
                  showActionSuccessModal(
                    context: context,
                    title: 'Joined Team Successfully',
                    message: 'You have joined team "${team.name}" as a member.',
                    icon: Icons.group_add_rounded,
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error joining team: $e')),
                  );
                }
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }
}

class _ActiveTeamMembersCard extends StatelessWidget {
  final TeamService teamService;
  final Team team;

  const _ActiveTeamMembersCard({required this.teamService, required this.team});

  @override
  Widget build(BuildContext context) {
    final isOwner = teamService.canManageMembers;

    return _Card(
      title: 'Members in ${team.name}',
      trailing: Wrap(
        spacing: 8,
        children: [
          IconButton(
            tooltip: 'Copy Invite Code',
            icon: const Icon(Icons.content_copy_rounded, size: 18, color: AppTheme.primaryBlue),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: team.inviteCode));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Copied invite code "${team.inviteCode}" to clipboard!')),
              );
            },
          ),
          if (isOwner)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textSecondary),
              onSelected: (val) {
                if (val == 'regenerate') {
                  _confirmRegenerateCode(context);
                } else if (val == 'delete') {
                  _confirmDeleteTeam(context);
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'regenerate',
                  child: Row(
                    children: [
                      Icon(Icons.refresh_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Regenerate Invite Code'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_forever_rounded, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete Team', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            )
          else
            TextButton.icon(
              icon: const Icon(Icons.logout_rounded, size: 16, color: Colors.red),
              label: const Text('Leave Team', style: TextStyle(color: Colors.red, fontSize: 13)),
              onPressed: () => _confirmLeaveTeam(context),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.lightBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 20, color: AppTheme.primaryBlue),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Invite Code: ${team.inviteCode} — Share this code with staff or assistants so they can join ${team.name}.',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final member in teamService.members)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: member.role.color.withValues(alpha: 0.15),
                    child: Text(
                      ProfileStore.initialsOf(member.displayName),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: member.role.color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.displayName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          member.email,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  _RolePill(member.role),
                  if (isOwner && member.role != TeamRole.owner) ...[
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.settings_outlined, size: 18, color: AppTheme.textSecondary),
                      onSelected: (val) {
                        if (val == 'role') {
                          _showEditRoleDialog(context, member);
                        } else if (val == 'transfer') {
                          _confirmTransferOwnership(context, member);
                        } else if (val == 'remove') {
                          _confirmRemoveMember(context, member);
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'role',
                          child: Text('Change Role'),
                        ),
                        const PopupMenuItem(
                          value: 'transfer',
                          child: Text('Transfer Ownership'),
                        ),
                        const PopupMenuItem(
                          value: 'remove',
                          child: Text('Remove from Team', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showEditRoleDialog(BuildContext context, TeamMember member) {
    TeamRole selected = member.role;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Change Role for ${member.displayName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final r in [TeamRole.editor, TeamRole.assistant, TeamRole.viewer])
                RadioListTile<TeamRole>(
                  title: Text(r.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(_roleDescription(r), style: const TextStyle(fontSize: 12)),
                  value: r,
                  groupValue: selected,
                  onChanged: (val) {
                    if (val != null) setState(() => selected = val);
                  },
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await teamService.updateMemberRole(member.uid, selected);
                  if (context.mounted) {
                    showActionSuccessModal(
                      context: context,
                      title: 'Role Updated Successfully',
                      message: '${member.displayName}\'s role has been changed to ${selected.label}.',
                      icon: Icons.admin_panel_settings_rounded,
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating role: $e')),
                    );
                  }
                }
              },
              child: const Text('Save Role'),
            ),
          ],
        ),
      ),
    );
  }

  String _roleDescription(TeamRole role) {
    switch (role) {
      case TeamRole.owner:
        return 'Full workspace access, manage members, delete team.';
      case TeamRole.editor:
        return 'View/edit patients, write visits & prescriptions.';
      case TeamRole.assistant:
        return 'View/edit patient demographics ONLY (no access to clinical visits/prescriptions).';
      case TeamRole.viewer:
        return 'Read-only access to patient records and clinical history.';
    }
  }

  void _confirmRemoveMember(BuildContext context, TeamMember member) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${member.displayName}?'),
        content: const Text('This will immediately revoke their access to this team\'s patient records.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await teamService.removeMember(member.uid);
              if (context.mounted) {
                showActionSuccessModal(
                  context: context,
                  title: 'Member Removed',
                  message: '${member.displayName} has been removed from the team.',
                  icon: Icons.person_remove_rounded,
                );
              }
            },
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmTransferOwnership(BuildContext context, TeamMember member) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Transfer Ownership to ${member.displayName}?'),
        content: Text(
          'You will become an Editor, and ${member.displayName} will become the Team Owner.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await teamService.transferOwnership(member.uid);
              if (context.mounted) {
                showActionSuccessModal(
                  context: context,
                  title: 'Ownership Transferred',
                  message: '${member.displayName} is now the owner of this team.',
                  icon: Icons.verified_user_rounded,
                );
              }
            },
            child: const Text('Transfer'),
          ),
        ],
      ),
    );
  }

  void _confirmLeaveTeam(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Team?'),
        content: const Text('You will lose access to this team\'s patient records.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await teamService.leaveTeam();
              if (context.mounted) {
                showActionSuccessModal(
                  context: context,
                  title: 'Left Team',
                  message: 'You have left the team.',
                  icon: Icons.exit_to_app_rounded,
                );
              }
            },
            child: const Text('Leave', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmRegenerateCode(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Regenerate Invite Code?'),
        content: const Text('The old invite code will no longer work for new members.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final code = await teamService.regenerateInviteCode();
              if (context.mounted) {
                showActionSuccessModal(
                  context: context,
                  title: 'New Invite Code Generated',
                  message: 'The new invite code for this team is "$code".',
                  icon: Icons.qr_code_rounded,
                );
              }
            },
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteTeam(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Team?'),
        content: const Text('Are you sure you want to delete this team? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await teamService.deleteTeam();
              if (context.mounted) {
                showActionSuccessModal(
                  context: context,
                  title: 'Team Deleted',
                  message: 'The team has been deleted successfully.',
                  icon: Icons.delete_forever_rounded,
                );
              }
            },
            child: const Text('Delete Team', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _PermissionsMatrixCard extends StatelessWidget {
  const _PermissionsMatrixCard();

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Permission Levels Reference',
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.borderColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Role Level', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('View Patients', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Edit Patients', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('See Visits & Rx', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Write Visits & Rx', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Manage Members', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: [
              DataRow(cells: [
                const DataCell(Text('Owner', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue))),
                const DataCell(Icon(Icons.check_circle, color: Color(0xFF059669), size: 18)),
                const DataCell(Icon(Icons.check_circle, color: Color(0xFF059669), size: 18)),
                const DataCell(Icon(Icons.check_circle, color: Color(0xFF059669), size: 18)),
                const DataCell(Icon(Icons.check_circle, color: Color(0xFF059669), size: 18)),
                const DataCell(Icon(Icons.check_circle, color: Color(0xFF059669), size: 18)),
              ]),
              DataRow(cells: [
                const DataCell(Text('Editor', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF059669)))),
                const DataCell(Icon(Icons.check_circle, color: Color(0xFF059669), size: 18)),
                const DataCell(Icon(Icons.check_circle, color: Color(0xFF059669), size: 18)),
                const DataCell(Icon(Icons.check_circle, color: Color(0xFF059669), size: 18)),
                const DataCell(Icon(Icons.check_circle, color: Color(0xFF059669), size: 18)),
                const DataCell(Icon(Icons.cancel, color: Colors.grey, size: 18)),
              ]),
              DataRow(cells: [
                const DataCell(Text('Assistant', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD97706)))),
                const DataCell(Icon(Icons.check_circle, color: Color(0xFF059669), size: 18)),
                const DataCell(Icon(Icons.check_circle, color: Color(0xFF059669), size: 18)),
                const DataCell(Icon(Icons.cancel, color: Colors.grey, size: 18)),
                const DataCell(Icon(Icons.cancel, color: Colors.grey, size: 18)),
                const DataCell(Icon(Icons.cancel, color: Colors.grey, size: 18)),
              ]),
              DataRow(cells: [
                const DataCell(Text('Viewer', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary))),
                const DataCell(Icon(Icons.check_circle, color: Color(0xFF059669), size: 18)),
                const DataCell(Icon(Icons.cancel, color: Colors.grey, size: 18)),
                const DataCell(Icon(Icons.check_circle, color: Color(0xFF059669), size: 18)),
                const DataCell(Icon(Icons.cancel, color: Colors.grey, size: 18)),
                const DataCell(Icon(Icons.cancel, color: Colors.grey, size: 18)),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
