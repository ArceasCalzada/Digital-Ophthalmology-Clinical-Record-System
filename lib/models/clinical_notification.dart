import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' show Query;
import 'package:flutter/material.dart';

import '../services/firebase_gate.dart';
import '../services/offline_sync_service.dart';
import '../services/team_service.dart';

enum NotificationSeverity { urgent, warning, info }

class ClinicalNotification {
  final String id;
  final String title;
  final String message;
  final String category; // UrgentAlert, Reminder, Refill, System
  final NotificationSeverity severity;
  final DateTime timestamp;
  final String? patientName;
  final String? patientId;
  final String teamId;
  bool isRead;

  ClinicalNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    required this.severity,
    required this.timestamp,
    this.patientName,
    this.patientId,
    this.teamId = '',
    this.isRead = false,
  });

  ClinicalNotification copyWith({
    String? id,
    String? title,
    String? message,
    String? category,
    NotificationSeverity? severity,
    DateTime? timestamp,
    String? patientName,
    String? patientId,
    String? teamId,
    bool? isRead,
  }) {
    return ClinicalNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      category: category ?? this.category,
      severity: severity ?? this.severity,
      timestamp: timestamp ?? this.timestamp,
      patientName: patientName ?? this.patientName,
      patientId: patientId ?? this.patientId,
      teamId: teamId ?? this.teamId,
      isRead: isRead ?? this.isRead,
    );
  }

  factory ClinicalNotification.fromJson(Map<String, dynamic> json) {
    final rawSeverity = json['severity']?.toString().toLowerCase() ?? json['urgency']?.toString().toLowerCase();
    NotificationSeverity severity = NotificationSeverity.info;
    if (rawSeverity != null) {
      if (rawSeverity.contains('urgent') || rawSeverity.contains('high') || rawSeverity.contains('critical')) {
        severity = NotificationSeverity.urgent;
      } else if (rawSeverity.contains('warn') || rawSeverity.contains('medium')) {
        severity = NotificationSeverity.warning;
      }
    }

    final title = json['title'] as String? ??
        json['subject'] as String? ??
        json['name'] as String? ??
        json['header'] as String? ??
        '';

    final message = json['message'] as String? ??
        json['body'] as String? ??
        json['content'] as String? ??
        json['description'] as String? ??
        json['details'] as String? ??
        json['text'] as String? ??
        json['note'] as String? ??
        '';

    final category = json['category'] as String? ??
        json['type'] as String? ??
        json['kind'] as String? ??
        (severity == NotificationSeverity.urgent ? 'Urgent Alert' : 'Reminder');

    final resolvedTitle = title.trim().isNotEmpty
        ? title.trim()
        : (message.trim().isNotEmpty ? message.trim() : '');

    return ClinicalNotification(
      id: json['id'] as String? ?? '',
      title: resolvedTitle,
      message: message.trim(),
      category: category,
      severity: severity,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      patientName: json['patientName'] as String? ?? json['patient_name'] as String? ?? json['patient'] as String?,
      patientId: json['patientId'] as String? ?? json['patient_id'] as String? ?? json['mrn'] as String?,
      teamId: json['teamId'] as String? ?? json['team_id'] as String? ?? '',
      isRead: json['isRead'] as bool? ?? json['read'] as bool? ?? false,
    );
  }

  /// Whether this notification is an empty, unconfigured, or dummy placeholder.
  bool get isPlaceholderOrEmpty {
    final t = title.trim();
    final m = message.trim();
    if (t.isEmpty && m.isEmpty) return true;
    if ((t.toLowerCase() == 'clinical alert' || t.toLowerCase() == 'reminder') && m.isEmpty) return true;
    return false;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'message': message,
    'category': category,
    'severity': severity.name,
    'timestamp': timestamp.toIso8601String(),
    'patientName': patientName,
    'patientId': patientId,
    'teamId': teamId,
    'isRead': isRead,
  };
}

class ClinicalNotificationRepository extends ChangeNotifier {
  static final ClinicalNotificationRepository _instance = ClinicalNotificationRepository._internal();
  factory ClinicalNotificationRepository() => _instance;

  final List<ClinicalNotification> _allMemoryNotifications = [];
  final List<ClinicalNotification> _notifications = [];
  StreamSubscription? _notifSub;
  String? _activeTeamId;
  final ValueNotifier<bool> isLoading = ValueNotifier<bool>(false);

  ClinicalNotificationRepository._internal();

  /// Populates standard demo notifications for testing environments.
  void seedDefaultNotificationsForTesting() {
    _initSeedData();
    notifyListeners();
  }

  /// Clears notifications for testing environments.
  void clearForTesting() {
    _notifications.clear();
    _allMemoryNotifications.clear();
    _activeTeamId = null;
    notifyListeners();
  }

  String? get activeTeamId => _activeTeamId;

  void connect([String? teamId]) {
    final targetTeamId = teamId ?? _activeTeamId;
    final teamChanged = _activeTeamId != targetTeamId;
    _activeTeamId = targetTeamId;

    final isMasterAdmin = TeamService.instance.isMasterAdmin;
    final firestore = FirebaseGate.firestoreIfReady();
    if (firestore == null) {
      if (teamChanged) {
        _notifications.clear();
      }
      if (_notifications.isEmpty) {
        if (!isMasterAdmin && _activeTeamId != null && _activeTeamId!.isNotEmpty) {
          final isDefault = _activeTeamId == 'c-default-team' || _activeTeamId == 'default';
          _notifications.addAll(_allMemoryNotifications.where((n) =>
              n.teamId == _activeTeamId || (isDefault && n.teamId.isEmpty)));
        } else if (isMasterAdmin) {
          _notifications.addAll(_allMemoryNotifications);
        }
      }
      isLoading.value = false;
      notifyListeners();
      return;
    }

    isLoading.value = true;
    if (teamChanged) {
      notifyListeners();
    }

    _notifSub?.cancel();

    if (!isMasterAdmin && (targetTeamId == null || targetTeamId.isEmpty)) {
      _notifications.clear();
      isLoading.value = false;
      notifyListeners();
      return;
    }

    Query<Map<String, dynamic>> query = firestore.collection('notifications');
    if (!isMasterAdmin && targetTeamId != null && targetTeamId.isNotEmpty) {
      query = query.where('teamId', isEqualTo: targetTeamId);
    }
    query = query.limit(500);

    _notifSub = query.snapshots().listen((snapshot) {
      _notifications.clear();
      final seenIds = <String>{};
      final seenSigs = <String>{};

      for (final doc in snapshot.docs) {
        try {
          final data = FirebaseGate.decode(doc.data());
          data['id'] = doc.id;
          final n = ClinicalNotification.fromJson(data);

          // Discard empty, placeholder, or unconfigured entries
          if (n.isPlaceholderOrEmpty) continue;

          // Deduplicate by id
          if (n.id.isNotEmpty && !seenIds.add(n.id)) continue;

          // Deduplicate by content signature
          final sig = '${n.title.trim().toLowerCase()}|${n.message.trim().toLowerCase()}|${(n.patientId ?? '').trim().toLowerCase()}|${n.category.toLowerCase()}';
          if (!seenSigs.add(sig)) continue;

          final isDefault = targetTeamId == 'c-default-team' || targetTeamId == 'default';
          if (isMasterAdmin ||
              (targetTeamId != null &&
                  targetTeamId.isNotEmpty &&
                  (n.teamId == targetTeamId || (isDefault && n.teamId.isEmpty)))) {
            _notifications.add(n);
          }
        } catch (e) {
          debugPrint('Error parsing notification ${doc.id}: $e');
        }
      }
      isLoading.value = false;
      notifyListeners();
    }, onError: (Object e) {
      debugPrint('Firestore notifications stream error: $e');
      isLoading.value = false;
    });
  }

  void disconnect() {
    _notifSub?.cancel();
    _notifSub = null;
    _notifications.clear();
    _activeTeamId = null;
    isLoading.value = false;
    notifyListeners();
  }

  List<ClinicalNotification> get notifications {
    final isMasterAdmin = TeamService.instance.isMasterAdmin;
    List<ClinicalNotification> raw;
    if (isMasterAdmin) {
      if (_activeTeamId != null && _activeTeamId!.isNotEmpty) {
        final teamMatches = _notifications.where((n) =>
            n.teamId == _activeTeamId ||
            n.teamId.isEmpty ||
            (_activeTeamId == 'c-default-team' || _activeTeamId == 'default')).toList();
        raw = teamMatches.isNotEmpty ? teamMatches : _notifications;
      } else {
        raw = _notifications;
      }
    } else if (_activeTeamId != null && _activeTeamId!.isNotEmpty) {
      raw = _notifications.where((n) =>
          n.teamId == _activeTeamId ||
          n.teamId.isEmpty ||
          (_activeTeamId == 'c-default-team' || _activeTeamId == 'default')).toList();
    } else {
      raw = _notifications;
    }

    // Filter out dummy placeholders and deduplicate
    final seen = <String>{};
    final result = <ClinicalNotification>[];
    for (final n in raw) {
      if (n.isPlaceholderOrEmpty) continue;
      final key = n.id.isNotEmpty
          ? n.id
          : '${n.title.trim().toLowerCase()}|${n.message.trim().toLowerCase()}|${(n.patientId ?? '').toLowerCase()}|${n.category.toLowerCase()}';
      if (seen.add(key)) {
        result.add(n);
      }
    }
    result.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return List.unmodifiable(result);
  }

  static bool _isDuplicate(ClinicalNotification a, ClinicalNotification b) {
    if (a.id.isNotEmpty && b.id.isNotEmpty && a.id == b.id) return true;
    final aTitle = a.title.trim().toLowerCase();
    final bTitle = b.title.trim().toLowerCase();
    final aMsg = a.message.trim().toLowerCase();
    final bMsg = b.message.trim().toLowerCase();
    final aPid = (a.patientId ?? '').trim().toLowerCase();
    final bPid = (b.patientId ?? '').trim().toLowerCase();
    return aTitle == bTitle &&
        aMsg == bMsg &&
        aPid == bPid &&
        a.category.toLowerCase() == b.category.toLowerCase();
  }

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  void markAsRead(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1 && !_notifications[idx].isRead) {
      _notifications[idx].isRead = true;
      final memIdx = _allMemoryNotifications.indexWhere((n) => n.id == id);
      if (memIdx != -1) {
        _allMemoryNotifications[memIdx].isRead = true;
      }
      OfflineSyncService().enqueueMutation(
        id: id,
        entityType: 'Notification',
        action: 'UPDATE',
        payload: {'id': id, 'isRead': true},
      );
      notifyListeners();
    }
  }

  void markAllAsRead() {
    bool changed = false;
    for (var n in _notifications) {
      if (!n.isRead) {
        n.isRead = true;
        changed = true;
        final memIdx = _allMemoryNotifications.indexWhere((m) => m.id == n.id);
        if (memIdx != -1) {
          _allMemoryNotifications[memIdx].isRead = true;
        }
        OfflineSyncService().enqueueMutation(
          id: n.id,
          entityType: 'Notification',
          action: 'UPDATE',
          payload: {'id': n.id, 'isRead': true},
        );
      }
    }
    if (changed) notifyListeners();
  }

  void dismissNotification(String id) {
    _notifications.removeWhere((n) => n.id == id);
    _allMemoryNotifications.removeWhere((n) => n.id == id);
    OfflineSyncService().enqueueMutation(
      id: id,
      entityType: 'Notification',
      action: 'DELETE',
      payload: {'id': id},
    );
    notifyListeners();
  }

  void clearAllNotifications() {
    for (final n in List.of(_notifications)) {
      OfflineSyncService().enqueueMutation(
        id: n.id,
        entityType: 'Notification',
        action: 'DELETE',
        payload: {'id': n.id},
      );
    }
    _notifications.clear();
    _allMemoryNotifications.clear();
    notifyListeners();
  }

  void addNotification(ClinicalNotification notification, {bool enqueueSync = true}) {
    if (notification.isPlaceholderOrEmpty) return;

    final notifWithTeam = notification.teamId.isEmpty && _activeTeamId != null && _activeTeamId!.isNotEmpty
        ? notification.copyWith(teamId: _activeTeamId)
        : notification;

    // Deduplicate in _allMemoryNotifications
    final memIdx = _allMemoryNotifications.indexWhere((n) => _isDuplicate(n, notifWithTeam));
    if (memIdx != -1) {
      _allMemoryNotifications[memIdx] = notifWithTeam;
    } else {
      _allMemoryNotifications.insert(0, notifWithTeam);
    }

    final isMasterAdmin = TeamService.instance.isMasterAdmin;
    if (isMasterAdmin ||
        _activeTeamId == null ||
        _activeTeamId!.isEmpty ||
        notifWithTeam.teamId.isEmpty ||
        notifWithTeam.teamId == _activeTeamId) {
      final notifIdx = _notifications.indexWhere((n) => _isDuplicate(n, notifWithTeam));
      if (notifIdx != -1) {
        _notifications[notifIdx] = notifWithTeam;
      } else {
        _notifications.insert(0, notifWithTeam);
      }
    }
    if (enqueueSync) {
      OfflineSyncService().enqueueMutation(
        id: notifWithTeam.id,
        entityType: 'Notification',
        action: 'CREATE',
        payload: {
          'id': notifWithTeam.id,
          'title': notifWithTeam.title,
          'message': notifWithTeam.message,
          'category': notifWithTeam.category,
          'severity': notifWithTeam.severity.name,
          'timestamp': notifWithTeam.timestamp.toIso8601String(),
          'patientName': notifWithTeam.patientName,
          'patientId': notifWithTeam.patientId,
          'teamId': notifWithTeam.teamId,
          'isRead': notifWithTeam.isRead,
        },
      );
    }
    notifyListeners();
  }

  void _initSeedData() {
    final now = DateTime.now();
    final seeds = [
      ClinicalNotification(
        id: 'notif-201',
        title: 'Elevated IOP Alert — 28 mmHg (OD)',
        message: 'Patient Eleanor Vance recorded critical IOP elevation during preliminary screening. Immediate ophthalmology review advised.',
        category: 'Urgent Alert',
        severity: NotificationSeverity.urgent,
        timestamp: now.subtract(const Duration(minutes: 15)),
        patientName: 'Eleanor Vance',
        patientId: 'P-10024',
        teamId: 'c-default-team',
      ),
      ClinicalNotification(
        id: 'notif-202',
        title: 'Prescription Refill Request',
        message: 'Latanoprost 0.005% ophthalmic drops refill requested for Carlos Mendoza (OD/OS 1 drop QHS).',
        category: 'Refill',
        severity: NotificationSeverity.warning,
        timestamp: now.subtract(const Duration(hours: 1, minutes: 40)),
        patientName: 'Carlos Mendoza',
        patientId: 'P-10025',
        teamId: 'c-default-team',
      ),
      ClinicalNotification(
        id: 'notif-203',
        title: 'Surgical Prep Confirmation',
        message: 'OR Suite 3 pre-op checklist cleared for Lourdes Sterling phacoemulsification at 2:00 PM.',
        category: 'Reminder',
        severity: NotificationSeverity.info,
        timestamp: now.subtract(const Duration(hours: 3)),
        patientName: 'Lourdes Sterling',
        patientId: 'P-10026',
        teamId: 'c-default-team',
      ),
      ClinicalNotification(
        id: 'notif-204',
        title: 'OCT Scan Laboratory Result Ready',
        message: 'Bilateral macula spectral-domain OCT scan uploaded for Arthur Pendelton. Macular thickness report attached.',
        category: 'System',
        severity: NotificationSeverity.info,
        timestamp: now.subtract(const Duration(hours: 5, minutes: 12)),
        patientName: 'Arthur Pendelton',
        patientId: 'P-10027',
        teamId: 'c-default-team',
      ),
    ];
    for (final s in seeds) {
      if (!_allMemoryNotifications.any((n) => n.id == s.id)) {
        _allMemoryNotifications.add(s);
      }
      if (!_notifications.any((n) => n.id == s.id)) {
        _notifications.add(s);
      }
    }
  }
}
