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
        return TeamRole.owner;
      case 'editor':
        return TeamRole.editor;
      case 'assistant':
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

  const TeamMember({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.joinedAt,
  });

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'role': role.name,
        'joinedAt': joinedAt,
      };

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    return TeamMember(
      uid: json['uid'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'Team Member',
      role: TeamRole.parse(json['role'] as String?),
      joinedAt: json['joinedAt'] as String? ?? DateTime.now().toIso8601String(),
    );
  }
}

/// A team workspace that owns a collection of patient records.
class Team {
  final String id;
  final String name;
  final String ownerId;
  final String inviteCode;
  final String createdAt;
  final int patientCount;
  final int encounterCount;
  final int prescriptionCount;

  const Team({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.inviteCode,
    required this.createdAt,
    this.patientCount = 0,
    this.encounterCount = 0,
    this.prescriptionCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ownerId': ownerId,
        'inviteCode': inviteCode,
        'createdAt': createdAt,
        'patientCount': patientCount,
        'encounterCount': encounterCount,
        'prescriptionCount': prescriptionCount,
      };

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Clinic Team',
      ownerId: json['ownerId'] as String? ?? '',
      inviteCode: json['inviteCode'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      patientCount: (json['patientCount'] as num?)?.toInt() ?? 0,
      encounterCount: (json['encounterCount'] as num?)?.toInt() ?? 0,
      prescriptionCount: (json['prescriptionCount'] as num?)?.toInt() ?? 0,
    );
  }

  Team copyWith({
    String? id,
    String? name,
    String? ownerId,
    String? inviteCode,
    String? createdAt,
    int? patientCount,
    int? encounterCount,
    int? prescriptionCount,
  }) {
    return Team(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      inviteCode: inviteCode ?? this.inviteCode,
      createdAt: createdAt ?? this.createdAt,
      patientCount: patientCount ?? this.patientCount,
      encounterCount: encounterCount ?? this.encounterCount,
      prescriptionCount: prescriptionCount ?? this.prescriptionCount,
    );
  }
}
