import 'dart:async';
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
    this.isRead = false,
  });

  factory ClinicalNotification.fromJson(Map<String, dynamic> json) {
    return ClinicalNotification(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      category: json['category'] as String? ?? 'Reminder',
      severity: NotificationSeverity.values.firstWhere(
        (s) => s.name == json['severity'],
        orElse: () => NotificationSeverity.info,
      ),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      patientName: json['patientName'] as String?,
      patientId: json['patientId'] as String?,
      isRead: json['isRead'] as bool? ?? false,
    );
  }
}

class ClinicalNotificationRepository extends ChangeNotifier {
  static final ClinicalNotificationRepository _instance = ClinicalNotificationRepository._internal();
  factory ClinicalNotificationRepository() => _instance;

  final List<ClinicalNotification> _notifications = [];
  StreamSubscription? _notifSub;

  ClinicalNotificationRepository._internal() {
    _initSeedData();
  }

  void connect() {
    final firestore = FirebaseGate.firestoreIfReady();
    if (firestore == null) return;
    _notifSub?.cancel();
    _notifSub = firestore.collection('notifications').snapshots().listen((snapshot) {
      _notifications.clear();
      for (final doc in snapshot.docs) {
        try {
          final data = FirebaseGate.decode(doc.data());
          data['id'] = doc.id;
          _notifications.add(ClinicalNotification.fromJson(data));
        } catch (e) {
          debugPrint('Error parsing notification ${doc.id}: $e');
        }
      }
      notifyListeners();
    }, onError: (Object e) {
      debugPrint('Firestore notifications stream error: $e');
    });
  }

  void disconnect() {
    _notifSub?.cancel();
    _notifSub = null;
    _notifications.clear();
    notifyListeners();
  }

  List<ClinicalNotification> get notifications => List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  void markAsRead(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1 && !_notifications[idx].isRead) {
      _notifications[idx].isRead = true;
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
    OfflineSyncService().enqueueMutation(
      id: id,
      entityType: 'Notification',
      action: 'DELETE',
      payload: {'id': id},
    );
    notifyListeners();
  }

  void addNotification(ClinicalNotification notification) {
    _notifications.insert(0, notification);
    OfflineSyncService().enqueueMutation(
      id: notification.id,
      entityType: 'Notification',
      action: 'CREATE',
      payload: {
        'id': notification.id,
        'title': notification.title,
        'message': notification.message,
        'category': notification.category,
        'severity': notification.severity.name,
        'timestamp': notification.timestamp.toIso8601String(),
        'patientName': notification.patientName,
        'patientId': notification.patientId,
        'isRead': notification.isRead,
      },
    );
    notifyListeners();
  }

  void _initSeedData() {
    final now = DateTime.now();
    _notifications.addAll([
      ClinicalNotification(
        id: 'notif-201',
        title: 'Elevated IOP Alert — 28 mmHg (OD)',
        message: 'Patient Eleanor Vance recorded critical IOP elevation during preliminary screening. Immediate ophthalmology review advised.',
        category: 'Urgent Alert',
        severity: NotificationSeverity.urgent,
        timestamp: now.subtract(const Duration(minutes: 15)),
        patientName: 'Eleanor Vance',
        patientId: 'P-10024',
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
      ),
    ]);
  }
}
