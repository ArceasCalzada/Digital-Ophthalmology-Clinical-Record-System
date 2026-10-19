import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Permission levels for members within a team.
enum TeamRole {
  owner('Owner'),
  editor('Editor'),
  assistant('Assistant'),
  viewer('Viewer');

  final String label;
  TeamRole(this.label);

  static TeamRole parse(String? value) {
    if (value == null) return TeamRole.viewer;
    final lower = value.trim().toLowerCase();
    switch (lower) {
      case 'owner':
      case 'leader':
      case 'admin':
        return TeamRole.owner;
      case 'editor':
      case 'physician':
      case 'doctor':
        return TeamRole.editor;
      case 'assistant':
      case 'staff':
        return TeamRole.assistant;
      case 'viewer':
      case 'member':
      default:
        return TeamRole.viewer;
    }
  }

  /// Whether this role can view patient demographic records.
  bool get canViewPatients => true;

  /// Whether this role can create or edit patient demographic records.
  bool get canEditPatients => this == TeamRole.owner || this == TeamRole.editor || this == TeamRole.assistant;

  /// Whether this role can view clinical visits and prescriptions.
  bool get canSeeVisits => this == TeamRole.owner || this == TeamRole.editor || this == TeamRole.viewer;

  /// Whether this role can write/create clinical visits and prescriptions.
  bool get canWriteVisits => this == TeamRole.owner || this == TeamRole.editor;

  /// Whether this role can invite members, change roles, or remove members.
  bool get canManageMembers => this == TeamRole.owner;

  /// Whether this role can delete or transfer team ownership.
  bool get canDeleteOrTransfer => this == TeamRole.owner;

  Color get color {
    switch (this) {
      case TeamRole.owner:
        return AppTheme.primaryBlue;
      case TeamRole.editor:
        return Color(0xFF059669); // Green
      case TeamRole.assistant:
        return Color(0xFFD97706); // Amber
      case TeamRole.viewer:
        return AppTheme.textSecondary;
    }
  }
}

/// A member of a clinical team.
class TeamMember {
  final String uid;
  final String email;
  final String displayName;
  final TeamRole role;
  final String joinedAt;
  final String status; // 'active' or 'pending'
  final String? requestedWorkspaceId;

  bool get isPending => status == 'pending';

  const TeamMember({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.joinedAt,
    this.status = 'active',
    this.requestedWorkspaceId,
  });

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'role': role.name,
        'joinedAt': joinedAt,
        'status': status,
        'isApproved': !isPending,
        if (requestedWorkspaceId != null) 'requestedWorkspaceId': requestedWorkspaceId,
      };

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    final statusStr = (json['status'] as String?)?.toLowerCase();
    final isApproved = json['isApproved'] as bool?;
    final roleRaw = json['role'] as String?;
    final isPending = statusStr == 'pending' ||
        statusStr == 'pending_approval' ||
        statusStr == 'awaiting_approval' ||
        isApproved == false ||
        roleRaw == 'pending' ||
        roleRaw == null;

    final workspaceId = json['requestedWorkspaceId'] as String? ??
        json['workspaceId'] as String? ??
        json['teamId'] as String?;

    return TeamMember(
      uid: json['uid'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'Team Member',
      role: TeamRole.parse(roleRaw),
      joinedAt: json['joinedAt'] as String? ?? DateTime.now().toIso8601String(),
      status: isPending ? 'pending' : (statusStr ?? 'active'),
      requestedWorkspaceId: workspaceId,
    );
  }

  TeamMember copyWith({
    String? uid,
    String? email,
    String? displayName,
    TeamRole? role,
    String? joinedAt,
    String? status,
    String? requestedWorkspaceId,
  }) {
    return TeamMember(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      status: status ?? this.status,
      requestedWorkspaceId: requestedWorkspaceId ?? this.requestedWorkspaceId,
    );
  }
}

/// A team workspace that owns a collection of patient records.
class Team {
  final String id;
  final String name;
  final String location;
  final String ownerId;
  final String inviteCode;
  final String createdAt;
  final int patientCount;
  final int encounterCount;
  final int prescriptionCount;
  final bool isArchived;

  const Team({
    required this.id,
    required this.name,
    this.location = '',
    required this.ownerId,
    required this.inviteCode,
    required this.createdAt,
    this.patientCount = 0,
    this.encounterCount = 0,
    this.prescriptionCount = 0,
    this.isArchived = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'location': location,
        'ownerId': ownerId,
        'inviteCode': inviteCode,
        'createdAt': createdAt,
        'patientCount': patientCount,
        'encounterCount': encounterCount,
        'prescriptionCount': prescriptionCount,
        'isArchived': isArchived,
      };

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Clinic Team',
      location: json['location'] as String? ?? json['clinicLocation'] as String? ?? json['address'] as String? ?? '',
      ownerId: json['ownerId'] as String? ?? '',
      inviteCode: json['inviteCode'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      patientCount: (json['patientCount'] as num?)?.toInt() ?? 0,
      encounterCount: (json['encounterCount'] as num?)?.toInt() ?? 0,
      prescriptionCount: (json['prescriptionCount'] as num?)?.toInt() ?? 0,
      isArchived: json['isArchived'] as bool? ?? false,
    );
  }

  Team copyWith({
    String? id,
    String? name,
    String? location,
    String? ownerId,
    String? inviteCode,
    String? createdAt,
    int? patientCount,
    int? encounterCount,
    int? prescriptionCount,
    bool? isArchived,
  }) {
    return Team(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      ownerId: ownerId ?? this.ownerId,
      inviteCode: inviteCode ?? this.inviteCode,
      createdAt: createdAt ?? this.createdAt,
      patientCount: patientCount ?? this.patientCount,
      encounterCount: encounterCount ?? this.encounterCount,
      prescriptionCount: prescriptionCount ?? this.prescriptionCount,
      isArchived: isArchived ?? this.isArchived,
    );
  }
}
