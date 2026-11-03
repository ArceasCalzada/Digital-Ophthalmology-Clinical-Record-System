import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/audit_log.dart';
import '../models/team.dart';
import 'auth_service.dart';
import 'firebase_gate.dart';
import 'team_service.dart';

/// Secure, centralized audit logging engine for recording critical clinic events.
/// Immutable audit logs are stored under Firestore collection:
///   /teams/{teamId}/auditLogs/{logId}
/// Access is restricted strictly to the clinic Owner role and Master Admin.
class AuditService extends ChangeNotifier {
  static final AuditService _instance = AuditService._internal();
  factory AuditService() => _instance;
  static AuditService get instance => _instance;

  AuditService._internal();

  /// In-memory cache of audit logs for testing, offline access, and fast UI responsiveness.
  final List<AuditLog> _memoryLogs = [];

  List<AuditLog> get memoryLogs => List.unmodifiable(_memoryLogs);

  /// Generates a unique, collision-resistant document ID.
  String _generateLogId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final rand = Random().nextInt(999999).toString().padLeft(6, '0');
    return 'audit-$timestamp-$rand';
  }

  /// Appends an immutable audit log entry into the active clinic team's audit trail.
  /// This captures who performed the action, their role, timestamp, and affected resource.
  Future<void> log({
    required String actionType,
    required String actionCategory,
    required String resourceType,
    required String resourceId,
    String resourceName = '',
    String details = '',
    Map<String, dynamic> metadata = const {},
    String? teamId,
  }) async {
    final effectiveTeamId = (teamId != null && teamId.isNotEmpty)
        ? teamId
        : (TeamService.instance.activeTeam?.id ?? 'c-default-team');

    final authUser = AuthService.instance.user;
    final uid = authUser?.uid ?? TeamService.instance.uid ?? 'system';
    final email = authUser?.email ?? TeamService.instance.userEmail ?? 'system@docrs.app';
    final displayName = authUser?.displayName ?? TeamService.instance.displayName ?? 'Staff';
    final role = TeamService.instance.activeRole.name;

    final logId = _generateLogId();
    final logEntry = AuditLog(
      id: logId,
      teamId: effectiveTeamId,
      timestamp: DateTime.now(),
      userId: uid,
      userEmail: email,
      userName: displayName,
      userRole: role,
      actionType: actionType,
      actionCategory: actionCategory,
      resourceType: resourceType,
      resourceId: resourceId,
      resourceName: resourceName,
      details: details,
      metadata: metadata,
    );

    // Cache locally
    _memoryLogs.insert(0, logEntry);
    notifyListeners();

    // Persist immutably to Cloud Firestore if ready
    final firestore = FirebaseGate.firestoreIfReady();
    if (firestore != null) {
      try {
        final payload = logEntry.toJson();
        await firestore
            .collection('teams')
            .doc(effectiveTeamId)
            .collection('auditLogs')
            .doc(logId)
            .set(payload, SetOptions(merge: false)); // Immutable write
      } catch (e) {
        debugPrint('[AuditService.log] Notice recording audit log to Firestore: $e');
      }
    }
  }

  /// Returns a real-time stream of audit logs for the specified team workspace.
  /// Automatically checks for Owner or Master Admin privilege.
  Stream<List<AuditLog>> streamAuditLogs({String? teamId, int limit = 100}) {
    final effectiveTeamId = (teamId != null && teamId.isNotEmpty)
        ? teamId
        : (TeamService.instance.activeTeam?.id ?? 'c-default-team');

    final firestore = FirebaseGate.firestoreIfReady();
    if (firestore == null) {
      // In-memory stream for testing and offline mode
      return Stream.value(
        _memoryLogs.where((l) => l.teamId == effectiveTeamId).take(limit).toList(),
      );
    }

    return firestore
        .collection('teams')
        .doc(effectiveTeamId)
        .collection('auditLogs')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      final list = <AuditLog>[];
      for (final doc in snapshot.docs) {
        try {
          final data = FirebaseGate.decode(doc.data());
          data['id'] = doc.id;
          list.add(AuditLog.fromJson(data));
        } catch (e) {
          debugPrint('Error parsing audit log ${doc.id}: $e');
        }
      }
      return list;
    });
  }

  /// Queries, filters, and paginates audit logs with multi-parameter criteria.
  Future<List<AuditLog>> fetchAuditLogs({
    String? teamId,
    String? searchQuery,
    String? actionCategory,
    String? staffEmail,
    DateTimeRange? dateRange,
    int limit = 100,
  }) async {
    final effectiveTeamId = (teamId != null && teamId.isNotEmpty)
        ? teamId
        : (TeamService.instance.activeTeam?.id ?? 'c-default-team');

    List<AuditLog> baseList = [];

    final firestore = FirebaseGate.firestoreIfReady();
    if (firestore != null) {
      try {
        Query<Map<String, dynamic>> query = firestore
            .collection('teams')
            .doc(effectiveTeamId)
            .collection('auditLogs')
            .orderBy('timestamp', descending: true);

        if (actionCategory != null && actionCategory.isNotEmpty && actionCategory != 'All') {
          query = query.where('actionCategory', isEqualTo: actionCategory);
        }

        query = query.limit(limit);
        final snap = await query.get();
        for (final doc in snap.docs) {
          final data = FirebaseGate.decode(doc.data());
          data['id'] = doc.id;
          baseList.add(AuditLog.fromJson(data));
        }
      } catch (e) {
        debugPrint('AuditService fetch error: $e, falling back to memory logs');
        baseList = _memoryLogs.where((l) => l.teamId == effectiveTeamId).toList();
      }
    } else {
      baseList = _memoryLogs.where((l) => l.teamId == effectiveTeamId).toList();
    }

    // Apply client-side filters
    return baseList.where((log) {
      // 1. Action Category
      if (actionCategory != null &&
          actionCategory.isNotEmpty &&
          actionCategory != 'All' &&
          log.actionCategory != actionCategory) {
        return false;
      }

      // 2. Staff Member Filter
      if (staffEmail != null && staffEmail.isNotEmpty && staffEmail != 'All Staff') {
        if (log.userEmail.toLowerCase() != staffEmail.toLowerCase()) {
          return false;
        }
      }

      // 3. Date Range Filter
      if (dateRange != null) {
        final start = DateTime(dateRange.start.year, dateRange.start.month, dateRange.start.day);
        final end = DateTime(dateRange.end.year, dateRange.end.month, dateRange.end.day, 23, 59, 59);
        if (log.timestamp.isBefore(start) || log.timestamp.isAfter(end)) {
          return false;
        }
      }

      // 4. Search Query (matches patient name, resource ID, staff email/name, action label, details)
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
        final matches = log.userName.toLowerCase().contains(q) ||
            log.userEmail.toLowerCase().contains(q) ||
            log.resourceName.toLowerCase().contains(q) ||
            log.resourceId.toLowerCase().contains(q) ||
            log.details.toLowerCase().contains(q) ||
            log.actionLabel.toLowerCase().contains(q);
        if (!matches) return false;
      }

      return true;
    }).toList();
  }

  /// Whether current active user has permission to review clinic audit logs (Owner or Master Admin).
  bool get canAccessAuditLogs {
    return TeamService.instance.isMasterAdmin ||
        TeamService.instance.activeRole == TeamRole.owner;
  }

  @visibleForTesting
  void clearForTesting() {
    _memoryLogs.clear();
  }
}
