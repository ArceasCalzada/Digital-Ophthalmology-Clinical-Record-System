import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' show Query;
import 'package:flutter/material.dart';

import '../services/firebase_gate.dart';
import '../services/offline_sync_service.dart';

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

    return ClinicalNotification(
      id: json['id'] as String? ?? '',
      title: title.isNotEmpty ? title : (message.isNotEmpty ? message : 'Clinical Alert'),
      message: message,
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

  ClinicalNotificationRepository._internal() {
    _initSeedData();
  }

  String? get activeTeamId => _activeTeamId;

  void connect([String? teamId]) {
    final targetTeamId = teamId ?? _activeTeamId;
    final teamChanged = _activeTeamId != targetTeamId;
    _activeTeamId = targetTeamId;

    final firestore = FirebaseGate.firestoreIfReady();
    if (firestore == null) {
      if (teamChanged) {
        _notifications.clear();
      }
      if (_notifications.isEmpty) {
        if (_activeTeamId != null && _activeTeamId!.isNotEmpty) {
          _notifications.addAll(_allMemoryNotifications.where((n) =>
              n.teamId == _activeTeamId ||
              n.teamId.isEmpty ||
              (_activeTeamId == 'c-default-team' || _activeTeamId == 'default')));
        } else {
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
    Query<Map<String, dynamic>> query = firestore.collection('notifications');
    if (targetTeamId != null && targetTeamId.isNotEmpty) {
      query = query.where('teamId', isEqualTo: targetTeamId);
    }
    query = query.limit(500);

    _notifSub = query.snapshots().listen((snapshot) {
      _notifications.clear();
      for (final doc in snapshot.docs) {
        try {
          final data = FirebaseGate.decode(doc.data());
          data['id'] = doc.id;
          final n = ClinicalNotification.fromJson(data);
          if (targetTeamId == null ||
              targetTeamId.isEmpty ||
              n.teamId.isEmpty ||
              n.teamId == targetTeamId) {
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
    if (_activeTeamId != null && _activeTeamId!.isNotEmpty) {
      return List.unmodifiable(_notifications.where((n) =>
          n.teamId == _activeTeamId ||
          n.teamId.isEmpty ||
          (_activeTeamId == 'c-default-team' || _activeTeamId == 'default')));
    }
    return List.unmodifiable(_notifications);
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

  void addNotification(ClinicalNotification notification) {
    final notifWithTeam = notification.teamId.isEmpty && _activeTeamId != null && _activeTeamId!.isNotEmpty
        ? notification.copyWith(teamId: _activeTeamId)
        : notification;

    _allMemoryNotifications.insert(0, notifWithTeam);
    if (_activeTeamId == null ||
        _activeTeamId!.isEmpty ||
        notifWithTeam.teamId.isEmpty ||
        notifWithTeam.teamId == _activeTeamId) {
      _notifications.insert(0, notifWithTeam);
    }
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
    _allMemoryNotifications.addAll(seeds);
    _notifications.addAll(seeds);
  }
}
