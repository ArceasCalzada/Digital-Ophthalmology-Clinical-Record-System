import 'package:flutter/material.dart';

/// Pre-defined standard action categories for clinic auditing.
class AuditActionCategory {
  static const String patientRecords = 'Patient Records';
  static const String prescriptions = 'Prescriptions';
  static const String teamManagement = 'Team Management';
  static const String branchClinic = 'Branch & Clinic';

  static const List<String> all = [
    patientRecords,
    prescriptions,
    teamManagement,
    branchClinic,
  ];
}

/// Standard action types recorded in the clinic audit log.
class AuditActionType {
  // Patient actions
  static const String patientCreate = 'patient_create';
  static const String patientEdit = 'patient_edit';
  static const String patientDelete = 'patient_delete';

  // Prescription actions
  static const String prescriptionCreate = 'prescription_create';
  static const String prescriptionPrint = 'prescription_print';

  // Team & staff actions
  static const String memberApprove = 'member_approve';
  static const String memberRoleUpdate = 'member_role_update';
  static const String memberRemove = 'member_remove';

  // Branch & Workspace actions
  static const String branchArchive = 'branch_archive';
  static const String branchRestore = 'branch_restore';
  static const String teamArchive = 'team_archive';
  static const String teamRestore = 'team_restore';
}

/// Immutable record representing a critical clinic event in Firestore.
/// Path: /teams/{teamId}/auditLogs/{logId}
class AuditLog {
  final String id;
  final String teamId;
  final DateTime timestamp;
  final String userId;
  final String userEmail;
  final String userName;
  final String userRole;
  final String actionType;
  final String actionCategory;
  final String resourceType;
  final String resourceId;
  final String resourceName;
  final String details;
  final Map<String, dynamic> metadata;

  const AuditLog({
    required this.id,
    required this.teamId,
    required this.timestamp,
    required this.userId,
    required this.userEmail,
    this.userName = '',
    this.userRole = 'viewer',
    required this.actionType,
    required this.actionCategory,
    required this.resourceType,
    required this.resourceId,
    this.resourceName = '',
    this.details = '',
    this.metadata = const {},
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    DateTime parsedTime;
    final rawTs = json['timestamp'];
    if (rawTs is DateTime) {
      parsedTime = rawTs;
    } else if (rawTs != null) {
      parsedTime = DateTime.tryParse(rawTs.toString()) ?? DateTime.now();
    } else {
      parsedTime = DateTime.now();
    }

    Map<String, dynamic> meta = const {};
    if (json['metadata'] is Map) {
      meta = Map<String, dynamic>.from(json['metadata'] as Map);
    }

    return AuditLog(
      id: json['id'] as String? ?? '',
      teamId: json['teamId'] as String? ?? json['team_id'] as String? ?? '',
      timestamp: parsedTime,
      userId: json['userId'] as String? ?? json['user_id'] as String? ?? '',
      userEmail: json['userEmail'] as String? ?? json['user_email'] as String? ?? '',
      userName: json['userName'] as String? ?? json['user_name'] as String? ?? '',
      userRole: json['userRole'] as String? ?? json['user_role'] as String? ?? 'viewer',
      actionType: json['actionType'] as String? ?? json['action_type'] as String? ?? '',
      actionCategory: json['actionCategory'] as String? ?? json['action_category'] as String? ?? AuditActionCategory.patientRecords,
      resourceType: json['resourceType'] as String? ?? json['resource_type'] as String? ?? '',
      resourceId: json['resourceId'] as String? ?? json['resource_id'] as String? ?? '',
      resourceName: json['resourceName'] as String? ?? json['resource_name'] as String? ?? '',
      details: json['details'] as String? ?? '',
      metadata: meta,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'teamId': teamId,
      'timestamp': timestamp.toIso8601String(),
      'userId': userId,
      'userEmail': userEmail,
      'userName': userName,
      'userRole': userRole,
      'actionType': actionType,
      'actionCategory': actionCategory,
      'resourceType': resourceType,
      'resourceId': resourceId,
      'resourceName': resourceName,
      'details': details,
      'metadata': metadata,
    };
  }

  /// Human-readable label describing the action
  String get actionLabel {
    switch (actionType) {
      case AuditActionType.patientCreate:
        return 'Patient Created';
      case AuditActionType.patientEdit:
        return 'Patient Record Edited';
      case AuditActionType.patientDelete:
        return 'Patient Deleted';
      case AuditActionType.prescriptionCreate:
        return 'Prescription Generated';
      case AuditActionType.prescriptionPrint:
        return 'Prescription Printed';
      case AuditActionType.memberApprove:
        return 'Staff Approved';
      case AuditActionType.memberRoleUpdate:
        return 'Role Updated';
      case AuditActionType.memberRemove:
        return 'Staff Removed';
      case AuditActionType.branchArchive:
        return 'Branch Archived';
      case AuditActionType.branchRestore:
        return 'Branch Restored';
      case AuditActionType.teamArchive:
        return 'Workspace Archived';
      case AuditActionType.teamRestore:
        return 'Workspace Restored';
      default:
        return actionType.replaceAll('_', ' ').toUpperCase();
    }
  }

  /// Distinct visual color theme for action categorization
  Color get categoryColor {
    switch (actionCategory) {
      case AuditActionCategory.patientRecords:
        return const Color(0xFF2563EB); // Blue
      case AuditActionCategory.prescriptions:
        return const Color(0xFF7C3AED); // Purple
      case AuditActionCategory.teamManagement:
        return const Color(0xFF059669); // Emerald
      case AuditActionCategory.branchClinic:
        return const Color(0xFFD97706); // Amber
      default:
        return const Color(0xFF64748B); // Slate
    }
  }

  /// Distinct icon for action type
  IconData get actionIcon {
    switch (actionType) {
      case AuditActionType.patientCreate:
        return Icons.person_add_rounded;
      case AuditActionType.patientEdit:
        return Icons.edit_note_rounded;
      case AuditActionType.patientDelete:
        return Icons.person_remove_rounded;
      case AuditActionType.prescriptionCreate:
        return Icons.medication_liquid_rounded;
      case AuditActionType.prescriptionPrint:
        return Icons.print_rounded;
      case AuditActionType.memberApprove:
        return Icons.how_to_reg_rounded;
      case AuditActionType.memberRoleUpdate:
        return Icons.admin_panel_settings_rounded;
      case AuditActionType.memberRemove:
        return Icons.group_remove_rounded;
      case AuditActionType.branchArchive:
      case AuditActionType.teamArchive:
        return Icons.archive_rounded;
      case AuditActionType.branchRestore:
      case AuditActionType.teamRestore:
        return Icons.unarchive_rounded;
      default:
        return Icons.history_rounded;
    }
  }

  /// Formatted date and time (e.g., Nov 3, 2026 • 08:30 PM)
  String get formattedTimestamp {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final m = months[timestamp.month - 1];
    final hour = timestamp.hour % 12 == 0 ? 12 : timestamp.hour % 12;
    final ampm = timestamp.hour >= 12 ? 'PM' : 'AM';
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$m ${timestamp.day}, ${timestamp.year} • $hour:$minute $ampm';
  }

  /// Relative time string (e.g. "Just now", "5m ago", "2h ago", "Yesterday")
  String get relativeTime {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${timestamp.month}/${timestamp.day}/${timestamp.year}';
  }

  AuditLog copyWith({
    String? id,
    String? teamId,
    DateTime? timestamp,
    String? userId,
    String? userEmail,
    String? userName,
    String? userRole,
    String? actionType,
    String? actionCategory,
    String? resourceType,
    String? resourceId,
    String? resourceName,
    String? details,
    Map<String, dynamic>? metadata,
  }) {
    return AuditLog(
      id: id ?? this.id,
      teamId: teamId ?? this.teamId,
      timestamp: timestamp ?? this.timestamp,
      userId: userId ?? this.userId,
      userEmail: userEmail ?? this.userEmail,
      userName: userName ?? this.userName,
      userRole: userRole ?? this.userRole,
      actionType: actionType ?? this.actionType,
      actionCategory: actionCategory ?? this.actionCategory,
      resourceType: resourceType ?? this.resourceType,
      resourceId: resourceId ?? this.resourceId,
      resourceName: resourceName ?? this.resourceName,
      details: details ?? this.details,
      metadata: metadata ?? this.metadata,
    );
  }
}
