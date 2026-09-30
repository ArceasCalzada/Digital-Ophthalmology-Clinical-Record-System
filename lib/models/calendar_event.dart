import 'dart:async';
import 'package:flutter/material.dart';

import '../services/firebase_gate.dart';
import '../services/offline_sync_service.dart';

class CalendarEvent {
  final String id;
  final String title;
  final String eventType; // Surgery, Checkup, Follow-up, IOP Check, Emergency, Laser Procedure
  final String location;  // Davao, Bukidnon, General Santos, Exam Room 1, Exam Room 2, OR Suite 3
  final DateTime dateTime;
  final String patientName;
  final String? patientId;
  final String notes;
  final int reminderMinutes; // Minutes before event to trigger notification (e.g., 15, 30, 60, 1440)
  bool isCompleted;
  bool notificationTriggered;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.eventType,
    required this.location,
    required this.dateTime,
    required this.patientName,
    this.patientId,
    this.notes = '',
    this.reminderMinutes = 30,
    this.isCompleted = false,
    this.notificationTriggered = false,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      eventType: json['eventType'] as String? ?? 'Checkup',
      location: json['location'] as String? ?? '',
      dateTime: json['dateTime'] != null
          ? DateTime.tryParse(json['dateTime'].toString()) ?? DateTime.now()
          : DateTime.now(),
      patientName: json['patientName'] as String? ?? '',
      patientId: json['patientId'] as String?,
      notes: json['notes'] as String? ?? '',
      reminderMinutes: json['reminderMinutes'] as int? ?? 30,
      isCompleted: json['isCompleted'] as bool? ?? false,
      notificationTriggered: json['notificationTriggered'] as bool? ?? false,
    );
  }
}

class CalendarEventRepository extends ChangeNotifier {
  static final CalendarEventRepository _instance = CalendarEventRepository._internal();
  factory CalendarEventRepository() => _instance;

  final List<CalendarEvent> _events = [];
  StreamSubscription? _eventsSub;

  CalendarEventRepository._internal() {
    _initSeedData();
  }

  void connect() {
    final firestore = FirebaseGate.firestoreIfReady();
    if (firestore == null) return;
    _eventsSub?.cancel();
    _eventsSub = firestore.collection('calendarEvents').snapshots().listen((snapshot) {
      _events.clear();
      for (final doc in snapshot.docs) {
        try {
          final data = FirebaseGate.decode(doc.data());
          data['id'] = doc.id;
          _events.add(CalendarEvent.fromJson(data));
        } catch (e) {
          debugPrint('Error parsing calendar event ${doc.id}: $e');
        }
      }
      notifyListeners();
    }, onError: (Object e) {
      debugPrint('Firestore calendar events stream error: $e');
    });
  }

  void disconnect() {
    _eventsSub?.cancel();
    _eventsSub = null;
    _events.clear();
    notifyListeners();
  }

  List<CalendarEvent> get events => List.unmodifiable(_events);

  List<CalendarEvent> getEventsForDay(DateTime day) {
    return _events.where((e) {
      return e.dateTime.year == day.year &&
          e.dateTime.month == day.month &&
          e.dateTime.day == day.day;
    }).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  List<CalendarEvent> getFilteredEvents({
    String? typeFilter,
    String? locationFilter,
    DateTime? specificDay,
    bool? completedFilter,
  }) {
    return _events.where((e) {
      if (typeFilter != null && typeFilter != 'All' && e.eventType != typeFilter) {
        return false;
      }
      if (locationFilter != null && locationFilter != 'All' && e.location != locationFilter) {
        return false;
      }
      if (completedFilter != null && e.isCompleted != completedFilter) {
        return false;
      }
      if (specificDay != null) {
        return e.dateTime.year == specificDay.year &&
            e.dateTime.month == specificDay.month &&
            e.dateTime.day == specificDay.day;
      }
      return true;
    }).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  void addEvent(CalendarEvent event) {
    _events.add(event);
    OfflineSyncService().enqueueMutation(
      id: event.id,
      entityType: 'CalendarEvent',
      action: 'CREATE',
      payload: {
        'id': event.id,
        'title': event.title,
        'eventType': event.eventType,
        'location': event.location,
        'dateTime': event.dateTime.toIso8601String(),
        'patientName': event.patientName,
        'patientId': event.patientId,
        'notes': event.notes,
        'reminderMinutes': event.reminderMinutes,
        'isCompleted': event.isCompleted,
        'lastModified': DateTime.now().toIso8601String(),
      },
    );
    notifyListeners();
  }

  void updateEvent(CalendarEvent updated) {
    final idx = _events.indexWhere((e) => e.id == updated.id);
    if (idx == -1) return;
    _events[idx] = updated;
    OfflineSyncService().enqueueMutation(
      id: updated.id,
      entityType: 'CalendarEvent',
      action: 'UPDATE',
      payload: {
        'id': updated.id,
        'title': updated.title,
        'eventType': updated.eventType,
        'location': updated.location,
        'dateTime': updated.dateTime.toIso8601String(),
        'patientName': updated.patientName,
        'patientId': updated.patientId,
        'notes': updated.notes,
        'reminderMinutes': updated.reminderMinutes,
        'isCompleted': updated.isCompleted,
        'lastModified': DateTime.now().toIso8601String(),
      },
    );
    notifyListeners();
  }

  void toggleEventStatus(String id) {
    final idx = _events.indexWhere((e) => e.id == id);
    if (idx != -1) {
      _events[idx].isCompleted = !_events[idx].isCompleted;
      OfflineSyncService().enqueueMutation(
        id: id,
        entityType: 'CalendarEvent',
        action: 'UPDATE',
        payload: {
          'id': id,
          'isCompleted': _events[idx].isCompleted,
        },
      );
      notifyListeners();
    }
  }

  void deleteEvent(String id) {
    _events.removeWhere((e) => e.id == id);
    OfflineSyncService().enqueueMutation(
      id: id,
      entityType: 'CalendarEvent',
      action: 'DELETE',
      payload: {'id': id},
    );
    notifyListeners();
  }

  void _initSeedData() {
    final now = DateTime.now();
    _events.addAll([
      CalendarEvent(
        id: 'evt-101',
        title: 'Glaucoma Follow-up & IOP Check',
        eventType: 'IOP Check',
        location: 'Davao',
        dateTime: DateTime(now.year, now.month, now.day, 9, 30),
        patientName: 'Eleanor Vance',
        patientId: 'P-10024',
        reminderMinutes: 15,
        notes: 'Target IOP OD < 15 mmHg. Repeat applanation tonometer.',
      ),
      CalendarEvent(
        id: 'evt-102',
        title: 'Post-Op Cataract Evaluation',
        eventType: 'Follow-up',
        location: 'Bukidnon',
        dateTime: DateTime(now.year, now.month, now.day, 10, 45),
        patientName: 'Carlos Mendoza',
        patientId: 'P-10025',
        reminderMinutes: 30,
        notes: 'Check OD corneal clarity and IOL alignment.',
      ),
      CalendarEvent(
        id: 'evt-103',
        title: 'Phacoemulsification & IOL Surgery',
        eventType: 'Surgery',
        location: 'OR Suite 3',
        dateTime: DateTime(now.year, now.month, now.day, 14, 0),
        patientName: 'Lourdes Sterling',
        patientId: 'P-10026',
        reminderMinutes: 60,
        notes: 'Right eye phacoemulsification with toric IOL placement.',
      ),
      CalendarEvent(
        id: 'evt-104',
        title: 'Diabetic Retinopathy Screening',
        eventType: 'Checkup',
        location: 'Davao',
        dateTime: DateTime(now.year, now.month, now.day + 1, 11, 0),
        patientName: 'Arthur Pendelton',
        patientId: 'P-10027',
        reminderMinutes: 30,
        notes: 'Widefield fundus photos and OCT macula scan.',
      ),
      CalendarEvent(
        id: 'evt-105',
        title: 'Acute Red Eye Evaluation',
        eventType: 'Emergency',
        location: 'Bukidnon',
        dateTime: DateTime(now.year, now.month, now.day + 1, 15, 30),
        patientName: 'Sophia Reyes',
        patientId: 'P-10028',
        reminderMinutes: 15,
        notes: 'Rule out corneal ulcer vs anterior uveitis.',
      ),
      CalendarEvent(
        id: 'evt-106',
        title: 'YAG Laser Capsulotomy',
        eventType: 'Laser Procedure',
        location: 'General Santos',
        dateTime: DateTime(now.year, now.month, now.day + 2, 10, 0),
        patientName: 'Gabriel Santos',
        patientId: 'P-10029',
        reminderMinutes: 30,
        notes: 'Post-cataract posterior capsule opacification.',
      ),
    ]);
  }
}
