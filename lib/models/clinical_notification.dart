import 'package:flutter/material.dart';

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
}

class ClinicalNotificationRepository extends ChangeNotifier {
  static final ClinicalNotificationRepository _instance = ClinicalNotificationRepository._internal();
  factory ClinicalNotificationRepository() => _instance;

  final List<ClinicalNotification> _notifications = [];

  ClinicalNotificationRepository._internal() {
    _initSeedData();
  }

  List<ClinicalNotification> get notifications => List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  void markAsRead(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1 && !_notifications[idx].isRead) {
      _notifications[idx].isRead = true;
      notifyListeners();
    }
  }

  void markAllAsRead() {
    bool changed = false;
    for (var n in _notifications) {
      if (!n.isRead) {
        n.isRead = true;
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  void dismissNotification(String id) {
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  void addNotification(ClinicalNotification notification) {
    _notifications.insert(0, notification);
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
